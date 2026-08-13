"""GPU (NVIDIA nvCOMP) compress / verify / decompress for arbitrary files, with
an optional CPU-only fallback decode path for Zstd/LZ4 archives.

Used by gpuCompressTIFwithNvcomp.m and unzipNvcomp.m as the GPU-accelerated,
lossless counterpart to the CPU 7-Zip pipeline (compressTIFwith7zip.m /
unzip7z.m). Written as raw byte compression (not video/pixel encoding), so
there is no bit-depth limitation - it does not care that the payload happens
to be 16-bit ScanImage TIFF data.

Requires: pip install nvidia-nvcomp-cu13 numpy zstandard lz4 (or
nvidia-nvcomp-cu12 instead of -cu13, matching whatever CUDA your driver
supports) in this Python environment. numpy is a hard dependency of
nvcomp.as_array(). zstandard/lz4 are only needed for the CPU-fallback decode
path - not needed at all to compress, or to decode on a machine with a
working nvcomp/GPU install.

Archive format (.nvcz v2), all integers little-endian:
    b'NVCZ2'            magic (5 bytes)
    algo_len             uint8
    algorithm            algo_len bytes, ascii (e.g. 'Zstd', 'Bitcomp')
    orig_size            uint64
    sha256               32 bytes, checksum of the original uncompressed bytes
    num_chunks           uint32
    chunk_sizes           num_chunks x uint64 (each chunk's COMPRESSED byte length)
    payload               concatenation of each chunk's compressed bytes, in order

RAW bitstream (not nvCOMP's default NVCOMP_NATIVE container) is used
deliberately: NVCOMP_NATIVE is not decodable by anything but nvcomp itself,
even for algorithms named after standard formats - confirmed empirically
(the real `zstd` CLI rejects a NVCOMP_NATIVE 'Zstd' payload as "unsupported
format"). RAW output for 'Zstd' and 'LZ4' is genuinely standard-format
compatible (confirmed: the real `zstd` CLI and the `lz4` Python package
decode it correctly) - this is what makes the CPU-fallback path possible.
Confirmed this doesn't change GPU decode behavior, as long as the decoding
Codec also specifies bitstream_kind=RAW, which every function in this file
does consistently. GDeflate/Bitcomp/ANS/Cascaded remain GPU-only regardless
of bitstream_kind - no external decoder exists for them.

Chunking (v2 change): RAW bitstream mode has a hard single-buffer limit that
turns out to be wildly algorithm-dependent (confirmed empirically by probing
every algorithm from 1 MB to 2 GB - see the _TIGHT_LIMIT_ALGORITHMS comment
below): 'Zstd' holds up to just under 2**31 bytes (a 32-bit overflow inside
nvCOMP itself - "Could not determine the maximum compressed chunk size" -
right at that exact boundary), but 'LZ4'/'Snappy'/'ANS'/'Bitcomp'/'Cascaded'
all fail between 16 and 32 MB regardless of algorithm. The `uncomp_chunk_size`
Codec option does NOT help avoid this (tested - it's ignored under RAW mode,
which always treats the whole input as one unchunked buffer). Real ScanImage
session TIFs routinely exceed even the smallest of these limits, so data is
split into algorithm-appropriate fixed-size pieces before encoding (see
_encode_chunk_size()), each RAW-encoded independently, with a byte-exact
record of each chunk's compressed size in the header. LZ4's raw block format
isn't self-delimiting, so explicit chunk boundaries are required for LZ4 to
decode at all, not just an optimization - the same explicit-boundary scheme
is used uniformly for every algorithm rather than special-casing.

Two-stage integrity model, controlled by `verify_tier` (compress() only):
  - Every compress() call does a mandatory in-memory decode-and-compare of
    EACH chunk right after encoding it, before that chunk is trusted. This
    is free (no extra I/O) and catches encode-logic bugs; compression is
    refused (COMPRESSION_FAIL, nothing left on disk) on the first bad chunk.
  - After writing, `verify_tier` controls how much of the on-disk archive
    gets re-checked:
      'full'   (default) - reread the whole archive from disk and fully
                decode it, checked against the original checksum. Only tier
                that catches corruption/truncation/bit-rot introduced during
                or after the write.
      'quick'  - reread just the header and the last ~16MB of the archive
                and compare against the known-correct in-memory bytes from
                this same process. Catches truncated/interrupted writes (the
                dominant failure mode on an unreliable network link) at
                near-zero I/O cost, but not silent corruption in the
                untouched middle of the file.
      'memory' - no post-write check at all; only the mandatory pre-write
                in-memory check applies. verifiedOnDisk is false for this
                tier from the MATLAB caller's perspective.
  verify()/decompress() have no in-memory reference to compare against (they
  may run long after compression, from just the archive) - mirroring how
  `7z t` only tests the archive - so they always do a full decode; a
  meaningful "quick" check isn't possible without the original bytes to
  compare against, so it isn't offered there.

Streaming (required for files larger than available RAM): compress(),
decompress(), verify(), and the 'full' verify tier all read/write/decode ONE
CHUNK at a time from/to disk - never the whole file as a single in-memory
object. This is not an optimization, it's a correctness requirement,
confirmed the hard way: a 107 GB real ScanImage TIF on a 60 GB RAM machine
silently OOM-killed the original whole-file-in-memory implementation with no
graceful error at all (an empty error message - a SIGKILL gives no chance to
report anything). The original file is read directly from disk in
chunk-sized pieces (never `Path(in_path).read_bytes()`), SHA-256 is computed
incrementally via `hashlib`'s streaming `.update()` API rather than over one
big buffer, and the archive header (which needs each chunk's compressed
size, only known after encoding it) is written as a same-length placeholder
first and overwritten in place once the real values are known - avoiding a
second pass over the payload. Peak memory use is therefore bounded by chunk
size (at most 512 MB - see _encode_chunk_size()), regardless of whether the
file is 4 GB or 400 GB.
"""

import sys
import argparse
import hashlib
import struct
from pathlib import Path

MAGIC = b'NVCZ2'
TAIL_CHECK_BYTES = 16 * 1024 * 1024

# RAW bitstream mode's safe chunk size varies dramatically by algorithm, and by two
# DIFFERENT kinds of failure - confirmed empirically (see module docstring):
#  - a hard API size limit ("Could not determine the maximum compressed chunk size"):
#    'LZ4'/'Snappy'/'ANS'/'Bitcomp'/'Cascaded' all fail between 16-32 MB; 'Zstd' holds up
#    to just under 2**31 bytes (~2 GiB).
#  - separately, a GPU out-of-memory failure that only shows up at larger sizes even
#    though the size-limit check itself passes: 'GDeflate' (and, not individually
#    confirmed but grouped conservatively for the same reason, 'Deflate'/'Gzip') OOM'd at
#    512 MB despite each easily clearing the size-limit check up to 256 MB alone - tested
#    and confirmed OOM-free holding 6 concurrent 128 MB chunks. These algorithms were
#    already the slowest by a wide margin regardless (GDeflate: ~5s per 64 MB, i.e. ~5
#    min for a 3.9 GB file) - a real, expected characteristic the benchmark suite
#    surfaces, not something chunk size can fix.
# Using per-algorithm chunk sizes (rather than one tiny universal size) keeps the
# production default ('Zstd') efficient - ~8 chunks for a 3.9 GB file instead of ~500 -
# while keeping every other algorithm correct.
_TIGHT_LIMIT_ALGORITHMS = {'LZ4', 'Snappy', 'ANS', 'Bitcomp', 'Cascaded'}
_MEMORY_LIMITED_ALGORITHMS = {'GDeflate', 'Deflate', 'Gzip'}
ENCODE_CHUNK_SIZE_TIGHT = 8 * 1024 * 1024        # confirmed-safe 16 MB, halved for margin
ENCODE_CHUNK_SIZE_MEDIUM = 128 * 1024 * 1024     # confirmed OOM-free (512 MB was not)
ENCODE_CHUNK_SIZE_DEFAULT = 512 * 1024 * 1024    # confirmed-safe ~2 GiB (Zstd), 4x margin


def _encode_chunk_size(algorithm):
    if algorithm in _TIGHT_LIMIT_ALGORITHMS:
        return ENCODE_CHUNK_SIZE_TIGHT
    if algorithm in _MEMORY_LIMITED_ALGORITHMS:
        return ENCODE_CHUNK_SIZE_MEDIUM
    return ENCODE_CHUNK_SIZE_DEFAULT


# Algorithms with a genuine CPU-only decoder available (see module docstring).
CPU_DECODABLE_ALGORITHMS = {'Zstd', 'LZ4'}


def _chunk_bounds(total_size, chunk_size):
    """Yield (start, end) byte offsets into the ORIGINAL uncompressed data for
    each chunk - used identically by both encode and decode so chunk
    boundaries never have to be guessed, only the compressed sizes need to be
    stored in the header. chunk_size must match _encode_chunk_size(algorithm)
    - it's algorithm-dependent (see module docstring), not a single constant."""
    start = 0
    if total_size == 0:
        yield 0, 0
        return
    while start < total_size:
        end = min(start + chunk_size, total_size)
        yield start, end
        start = end


def _pack_header(algorithm, orig_size, checksum, chunk_sizes):
    algo_bytes = algorithm.encode('ascii')
    parts = [MAGIC, struct.pack('<B', len(algo_bytes)), algo_bytes,
             struct.pack('<Q', orig_size), checksum, struct.pack('<I', len(chunk_sizes))]
    parts.extend(struct.pack('<Q', cs) for cs in chunk_sizes)
    return b''.join(parts)


def _read_header(f):
    magic = f.read(len(MAGIC))
    if magic != MAGIC:
        raise ValueError('Not a valid .nvcz archive (bad magic bytes)')
    (algo_len,) = struct.unpack('<B', f.read(1))
    algorithm = f.read(algo_len).decode('ascii')
    (orig_size,) = struct.unpack('<Q', f.read(8))
    checksum = f.read(32)
    (num_chunks,) = struct.unpack('<I', f.read(4))
    chunk_sizes = [struct.unpack('<Q', f.read(8))[0] for _ in range(num_chunks)]
    return algorithm, orig_size, checksum, chunk_sizes


def _gpu_codec(algorithm):
    from nvidia import nvcomp
    return nvcomp.Codec(algorithm=algorithm, bitstream_kind=nvcomp.BitstreamKind.RAW)


def _gpu_encode_chunks(data, algorithm):
    """Encode data in fixed-size chunks - RAW bitstream mode has a hard ~2GB
    single-buffer limit (see module docstring). Returns a list of
    independently-encoded compressed chunk payloads."""
    from nvidia import nvcomp
    codec = _gpu_codec(algorithm)
    chunks = []
    for start, end in _chunk_bounds(len(data), _encode_chunk_size(algorithm)):
        src_arr = nvcomp.as_array(data[start:end]).cuda()
        compressed = codec.encode(src_arr)
        chunks.append(bytes(compressed.cpu()))
    return chunks


def _gpu_decode_chunks(chunk_payloads, algorithm):
    from nvidia import nvcomp
    codec = _gpu_codec(algorithm)
    parts = []
    for payload in chunk_payloads:
        compressed_arr = nvcomp.as_array(payload).cuda()
        decoded_arr = codec.decode(compressed_arr)
        parts.append(bytes(decoded_arr.cpu()))
    return b''.join(parts)


def _cpu_decode_one(payload, algorithm, orig_chunk_size):
    if algorithm == 'Zstd':
        import zstandard
        return zstandard.ZstdDecompressor().decompress(payload, max_output_size=orig_chunk_size)
    elif algorithm == 'LZ4':
        import lz4.block
        return lz4.block.decompress(payload, uncompressed_size=orig_chunk_size)
    else:
        raise RuntimeError(
            f"NO_CPU_FALLBACK: algorithm '{algorithm}' requires GPU/nvcomp to decompress "
            "(no standard CPU decoder exists for this GPU-native bitstream)")


def _cpu_decode_chunks(chunk_payloads, algorithm, orig_size):
    chunk_orig_sizes = [end - start for start, end in _chunk_bounds(orig_size, _encode_chunk_size(algorithm))]
    return b''.join(_cpu_decode_one(payload, algorithm, sz)
                     for payload, sz in zip(chunk_payloads, chunk_orig_sizes))


def _stream_decode_archive(archive_path, sink, force_cpu=False):
    """Decode archive_path chunk-by-chunk, calling sink(chunk_bytes) for each
    decoded chunk instead of ever accumulating the whole file in memory -
    critical for files larger than available RAM (see module docstring).
    Used by verify()/decompress() and the 'full' verify tier - the only path
    that validates the bytes actually persisted on disk. Returns
    (total_decoded_size, algorithm, orig_size, checksum) from the header."""
    with open(archive_path, 'rb') as f:
        algorithm, orig_size, checksum, chunk_sizes = _read_header(f)

        use_cpu = force_cpu
        if not use_cpu:
            try:
                from nvidia import nvcomp  # noqa: F401
            except ImportError:
                use_cpu = True
        if not use_cpu:
            codec = _gpu_codec(algorithm)

        chunk_orig_sizes = [end - start for start, end in
                             _chunk_bounds(orig_size, _encode_chunk_size(algorithm))]
        if len(chunk_orig_sizes) != len(chunk_sizes):
            raise ValueError(
                f'Archive header has {len(chunk_sizes)} chunks but {algorithm} at '
                f'orig_size={orig_size} implies {len(chunk_orig_sizes)} - archive is '
                'corrupt, truncated, or from an incompatible version')

        total_decoded = 0
        for comp_size, orig_chunk_size in zip(chunk_sizes, chunk_orig_sizes):
            payload = f.read(comp_size)
            if len(payload) != comp_size:
                raise IOError(f'short read: expected {comp_size} bytes, got {len(payload)} '
                               '(archive truncated?)')
            if use_cpu:
                decoded_chunk = _cpu_decode_one(payload, algorithm, orig_chunk_size)
            else:
                from nvidia import nvcomp
                compressed_arr = nvcomp.as_array(payload).cuda()
                decoded_chunk = bytes(codec.decode(compressed_arr).cpu())
            sink(decoded_chunk)
            total_decoded += len(decoded_chunk)

    return total_decoded, algorithm, orig_size, checksum


def _check_written_archive(out_path, header, tail_bytes, total_size, verify_tier):
    """Post-write check of what's actually on disk, tiered. header/tail_bytes
    are the known-correct in-memory bytes from the encode that just streamed
    - only the header and the last TAIL_CHECK_BYTES of the payload are kept
    in memory (not the whole payload, which may be far larger than RAM) -
    this is what makes the 'quick' tier meaningful without a full re-decode."""
    if verify_tier == 'memory':
        print('INTEGRITY_SKIPPED (memory tier: only the pre-write in-memory check ran)', flush=True)
        return 0

    if verify_tier == 'quick':
        with open(out_path, 'rb') as f:
            f.seek(0, 2)
            actual_size = f.tell()
            if actual_size != total_size:
                print(f'INTEGRITY_FAIL: on-disk size {actual_size} != expected {total_size} '
                      '(likely a truncated write)', flush=True)
                return 1
            f.seek(0)
            if f.read(len(header)) != header:
                print('INTEGRITY_FAIL: on-disk header does not match', flush=True)
                return 1
            tail_len = len(tail_bytes)
            if tail_len > 0:
                f.seek(-tail_len, 2)
                if f.read(tail_len) != tail_bytes:
                    print('INTEGRITY_FAIL: on-disk tail bytes do not match '
                          '(likely a truncated/corrupted write)', flush=True)
                    return 1
        print('INTEGRITY_OK (quick tier: size+header+tail check, does not rule out mid-file bit-rot)',
              flush=True)
        return 0

    # 'full' (default): stream-decode the whole archive from disk, hashing as we go -
    # never materializes the whole decoded file in memory - the only tier that
    # validates against corruption introduced anywhere during/after the write.
    hasher = hashlib.sha256()
    total_decoded, _algo, expected_orig_size, expected_checksum = _stream_decode_archive(
        out_path, hasher.update)
    if total_decoded != expected_orig_size or hasher.digest() != expected_checksum:
        print('INTEGRITY_FAIL: full on-disk decode did not match', flush=True)
        return 1
    print('INTEGRITY_OK', flush=True)
    return 0


def compress(in_path, out_path, algorithm='Zstd', verify_tier='full'):
    from nvidia import nvcomp

    chunk_size = _encode_chunk_size(algorithm)
    orig_size = Path(in_path).stat().st_size
    bounds = list(_chunk_bounds(orig_size, chunk_size))

    codec = _gpu_codec(algorithm)
    hasher = hashlib.sha256()
    chunk_sizes = []
    tail_buffer = bytearray()

    # algorithm/num_chunks are fixed before any encoding happens, so the header's byte
    # length is already known even though its checksum/chunk_sizes values aren't yet -
    # reserve that much space with a placeholder, overwrite it in place once the real
    # values are known. Avoids a second pass over a payload that may be far too large
    # to buffer and rewrite.
    placeholder_header = _pack_header(algorithm, orig_size, b'\x00' * 32, [0] * len(bounds))

    try:
        with open(in_path, 'rb') as fin, open(out_path, 'wb') as fout:
            fout.write(placeholder_header)

            for start, end in bounds:
                n = end - start
                chunk_data = fin.read(n)
                if len(chunk_data) != n:
                    raise IOError(f'short read from {in_path}: expected {n} bytes at offset '
                                   f'{start}, got {len(chunk_data)}')
                hasher.update(chunk_data)

                src_arr = nvcomp.as_array(chunk_data).cuda()
                compressed = codec.encode(src_arr)

                # Mandatory in-memory check, per chunk, before that chunk is trusted -
                # free (no extra I/O), catches encode-logic bugs, fails fast on the
                # first bad chunk. Mathematically equivalent to one whole-file
                # comparison (every byte is compared exactly once, in order) - just
                # computed incrementally so memory stays bounded to one chunk.
                if bytes(codec.decode(compressed).cpu()) != chunk_data:
                    print('COMPRESSION_FAIL: in-memory encode/decode round trip did not '
                          f'match original (chunk at offset {start})', flush=True)
                    fout.close()
                    Path(out_path).unlink(missing_ok=True)
                    return 1

                payload_chunk = bytes(compressed.cpu())
                fout.write(payload_chunk)
                chunk_sizes.append(len(payload_chunk))

                tail_buffer.extend(payload_chunk)
                if len(tail_buffer) > TAIL_CHECK_BYTES:
                    del tail_buffer[:-TAIL_CHECK_BYTES]

            real_header = _pack_header(algorithm, orig_size, hasher.digest(), chunk_sizes)
            if len(real_header) != len(placeholder_header):
                raise AssertionError('header size changed after encoding - internal bug')
            fout.seek(0)
            fout.write(real_header)
    except Exception:
        Path(out_path).unlink(missing_ok=True)
        raise

    print('COMPRESSION_OK', flush=True)

    total_size = len(real_header) + sum(chunk_sizes)
    return _check_written_archive(out_path, real_header, bytes(tail_buffer), total_size, verify_tier)


def verify(archive_path, force_cpu=False):
    """Standalone integrity check reading only the archive (never the original,
    and with no in-memory reference) - always a full, memory-bounded streaming
    decode, mirroring `7z t`."""
    hasher = hashlib.sha256()
    try:
        total_decoded, _algo, orig_size, checksum = _stream_decode_archive(
            archive_path, hasher.update, force_cpu=force_cpu)
    except Exception as exc:
        print(f'INTEGRITY_FAIL: {exc}')
        return 1
    if total_decoded != orig_size:
        print(f'INTEGRITY_FAIL: decoded size {total_decoded} != expected {orig_size}')
        return 1
    if hasher.digest() != checksum:
        print('INTEGRITY_FAIL: checksum mismatch')
        return 1
    print('INTEGRITY_OK')
    return 0


def decompress(archive_path, out_path, force_cpu=False):
    # Stream decoded bytes straight to a .tmp path and rename only after validating -
    # never expose a partially-written or unverified file under the real out_path,
    # same "never trust an unverified result" principle used elsewhere in this file.
    tmp_path = str(out_path) + '.tmp'
    hasher = hashlib.sha256()
    try:
        with open(tmp_path, 'wb') as fout:
            def sink(chunk):
                hasher.update(chunk)
                fout.write(chunk)
            total_decoded, _algo, orig_size, checksum = _stream_decode_archive(
                archive_path, sink, force_cpu=force_cpu)
    except Exception as exc:
        print(f'DECOMPRESS_FAIL: {exc}')
        Path(tmp_path).unlink(missing_ok=True)
        return 1

    if total_decoded != orig_size or hasher.digest() != checksum:
        print('DECOMPRESS_FAIL: integrity check failed, refusing to keep output')
        Path(tmp_path).unlink(missing_ok=True)
        return 1

    Path(tmp_path).rename(out_path)
    print('DECOMPRESS_OK')
    return 0


_CHUNK = 64 * 1024 * 1024


def stage(local_src, server_dst):
    """One-time copy of a local file to a (typically network) destination,
    verified via a dual checksum: the source hash is computed while copying,
    the destination hash is computed by reading back what was actually
    written - fails closed (STAGE_FAIL) rather than silently trusting the
    copy, since everything built on top of this (the benchmark) assumes the
    staged file is byte-identical to the source."""
    src_path = Path(local_src)
    dst_path = Path(server_dst)
    dst_path.parent.mkdir(parents=True, exist_ok=True)

    src_hash = hashlib.sha256()
    with open(src_path, 'rb') as fsrc, open(dst_path, 'wb') as fdst:
        while True:
            chunk = fsrc.read(_CHUNK)
            if not chunk:
                break
            src_hash.update(chunk)
            fdst.write(chunk)

    dst_hash = hashlib.sha256()
    with open(dst_path, 'rb') as fdst:
        while True:
            chunk = fdst.read(_CHUNK)
            if not chunk:
                break
            dst_hash.update(chunk)

    if src_hash.digest() != dst_hash.digest():
        print(f'STAGE_FAIL: checksum mismatch after copy (src={src_hash.hexdigest()}, '
              f'dst={dst_hash.hexdigest()})')
        return 1
    print(f'STAGE_OK: {dst_path} ({dst_path.stat().st_size} bytes, sha256={dst_hash.hexdigest()})')
    return 0


DEFAULT_BENCHMARK_ALGORITHMS = ['LZ4', 'Snappy', 'Zstd', 'Deflate', 'GDeflate', 'ANS', 'Bitcomp',
                                 'Gzip', 'Cascaded']


def _print_benchmark_table(results, t_read, mbps_read, mbps_write, mbps_readback, network_ref_algorithm):
    hdr = (f"{'algorithm':<10} {'status':<8} {'chunks':>6} {'encode_s':>9} {'MB/s':>7} "
           f"{'ratio%':>7} {'decode_s':>9} {'mem_ok':>7} | {'est_write_s':>11} {'est_read_s':>10} "
           f"{'est_total_s':>11}")
    print(hdr, flush=True)
    print('-' * len(hdr), flush=True)
    for r in results:
        if r['status'] != 'OK':
            print(f"{r['algorithm']:<10} {r['status']}", flush=True)
            continue
        est_write = r['compressed_size'] / 1024 / 1024 / mbps_write if mbps_write else float('nan')
        est_read = r['compressed_size'] / 1024 / 1024 / mbps_readback if mbps_readback else float('nan')
        est_total = t_read + r['encode_s'] + est_write + est_read
        r['est_write_s'], r['est_readback_s'], r['est_total_s'] = est_write, est_read, est_total
        print(f"{r['algorithm']:<10} {'OK':<8} {r['num_chunks']:>6} "
              f"{r['encode_s']:>9.2f} {r['encode_MBps']:>7.1f} {r['ratio_pct']:>7.1f} "
              f"{r['decode_s']:>9.2f} {str(r['in_memory_verify']):>7} | "
              f"{est_write:>11.1f} {est_read:>10.1f} {est_total:>11.1f}", flush=True)

    print(flush=True)
    measured_note = f'MEASURED: read={mbps_read:.1f} MB/s (per-algorithm encode/decode/chunks in table above; '\
                     'H2D transfer time is folded into encode_s, matching how production compress() reports it)'
    if mbps_write:
        measured_note += (f', write({network_ref_algorithm})={mbps_write:.1f} MB/s, '
                           f'readback({network_ref_algorithm})={mbps_readback:.1f} MB/s')
    else:
        measured_note += ' (no real network round trip - see message above if one was attempted and failed)'
    print(measured_note, flush=True)
    print('ESTIMATED (derived from the measured MB/s above applied to each algorithm\'s own real '
          'compressed size): est_write_s / est_read_s / est_total_s columns - not independently measured.',
          flush=True)


def _write_benchmark_csv(csv_path, server_src, src_size, mbps_read, mbps_write, mbps_readback,
                          network_ref_algorithm, results):
    import csv as csv_module
    from datetime import datetime, timezone
    Path(csv_path).parent.mkdir(parents=True, exist_ok=True)
    with open(csv_path, 'w', newline='') as f:
        f.write(f'# source,{server_src}\n')
        f.write(f'# source_size_bytes,{src_size}\n')
        f.write(f'# timestamp_utc,{datetime.now(timezone.utc).isoformat()}\n')
        f.write(f'# measured_read_MBps,{mbps_read:.2f}\n')
        if mbps_write:
            f.write(f'# measured_write_MBps,{mbps_write:.2f}\n')
            f.write(f'# measured_readback_MBps,{mbps_readback:.2f}\n')
            f.write(f'# network_reference_algorithm,{network_ref_algorithm}\n')
        writer = csv_module.writer(f)
        writer.writerow(['algorithm', 'status', 'num_chunks', 'encode_s', 'encode_MBps',
                          'compressed_size', 'ratio_pct', 'decode_s', 'in_memory_verify',
                          'est_write_s', 'est_readback_s', 'est_total_s'])
        for r in results:
            writer.writerow([r['algorithm'], r['status'], r.get('num_chunks', ''),
                              r.get('encode_s', ''),
                              r.get('encode_MBps', ''), r.get('compressed_size', ''),
                              r.get('ratio_pct', ''), r.get('decode_s', ''),
                              r.get('in_memory_verify', ''), r.get('est_write_s', ''),
                              r.get('est_readback_s', ''), r.get('est_total_s', '')])


def benchmark(server_src, algorithms=None, network_ref_algorithm='Zstd', network_out=None,
              csv_path=None, keep_staged=False):
    """Benchmark multiple nvCOMP algorithms against one real, already-staged
    server-hosted file. Reads the source once, reused (as host bytes) across
    every algorithm's encode() - no repeated network reads. Each algorithm
    uses ITS OWN chunk size (_encode_chunk_size()) and gets its own
    Host->GPU transfer, rather than sharing one set of GPU-resident chunks
    across algorithms: RAW bitstream mode's safe chunk size varies hugely by
    algorithm (16 MB for some, ~2 GB for others - see module docstring), so
    forcing every algorithm through one shared chunking scheme would either
    break the tight-limit algorithms or make the production default pay
    unnecessary small-chunk overhead it wouldn't actually incur - this way
    each algorithm's numbers reflect what compress() would really do for it.
    Only one real network write + read-back happens, for
    network_ref_algorithm - everything else's network-inclusive time is an
    ESTIMATE derived from that one measured MB/s figure applied to each
    algorithm's own real compressed size, labeled as such in the output."""
    import time
    import gc
    from nvidia import nvcomp

    algorithms = list(algorithms) if algorithms else list(DEFAULT_BENCHMARK_ALGORITHMS)
    if network_ref_algorithm not in algorithms:
        algorithms = [network_ref_algorithm] + algorithms

    t0 = time.perf_counter()
    data = Path(server_src).read_bytes()
    t_read = time.perf_counter() - t0
    src_size = len(data)
    mbps_read = (src_size / 1024 / 1024) / t_read if t_read > 0 else float('inf')
    print(f'Read {src_size/1024/1024:.1f} MB from {server_src} in {t_read:.1f}s '
          f'({mbps_read:.1f} MB/s) [MEASURED]', flush=True)

    results = []
    for algo in algorithms:
        row = {'algorithm': algo, 'status': None}
        try:
            # Reuse the same _gpu_encode_chunks/_gpu_decode_chunks production functions
            # compress()/decompress() use, rather than reimplementing the chunk loop here -
            # they hold only ONE chunk's GPU objects alive at a time via transient
            # per-iteration variables (each reassigned next loop, so the previous chunk's
            # CUDA memory is eligible for collection immediately). An earlier version of
            # this function instead built full Python lists of every chunk's GPU objects
            # via list comprehensions, keeping ALL of them (503 for LZ4's 8 MB chunks on a
            # 3.9 GB file) alive simultaneously - confirmed empirically this OOM'd and left
            # the GPU in a bad-enough state that every algorithm after LZ4 failed too, even
            # with explicit del+gc.collect() between algorithms (the leak was WITHIN one
            # algorithm's processing, not just across algorithms).
            num_chunks = len(list(_chunk_bounds(src_size, _encode_chunk_size(algo))))

            t0 = time.perf_counter()
            payload_chunks = _gpu_encode_chunks(data, algo)
            t_encode = time.perf_counter() - t0
            comp_size = sum(len(c) for c in payload_chunks)

            t0 = time.perf_counter()
            decoded = _gpu_decode_chunks(payload_chunks, algo)
            t_decode = time.perf_counter() - t0
            in_memory_ok = decoded == data
            del decoded

            row.update(status='OK', num_chunks=num_chunks, encode_s=t_encode,
                       encode_MBps=(src_size / 1024 / 1024) / t_encode if t_encode > 0 else float('inf'),
                       compressed_size=comp_size, ratio_pct=100.0 * comp_size / src_size,
                       decode_s=t_decode, in_memory_verify=in_memory_ok)
            print(f'  {algo}: encode {t_encode:.1f}s, decode {t_decode:.1f}s, '
                  f'ratio {row["ratio_pct"]:.1f}%, verify_ok={in_memory_ok}', flush=True)
            gc.collect()
        except Exception as exc:
            row['status'] = f'FAILED: {exc}'
            print(f'  {algo}: FAILED - {exc}', flush=True)
            gc.collect()
        results.append(row)

    # Print + CSV-write the compute comparison BEFORE attempting the network round trip,
    # so a failure there (see try/except below) can never discard already-computed
    # per-algorithm results - confirmed this was a real risk, not hypothetical: an
    # earlier unguarded version of this round trip OOM'd and silently discarded an
    # entire completed benchmark run.
    print()
    _print_benchmark_table(results, t_read, mbps_read, None, None, None)
    if csv_path:
        _write_benchmark_csv(csv_path, server_src, src_size, mbps_read, None, None, None, results)
        print(f'BENCHMARK_CSV (compute-only, network round trip not yet attempted): {csv_path}',
              flush=True)

    mbps_write = mbps_readback = None
    if network_out:
        ref_row = next((r for r in results if r['algorithm'] == network_ref_algorithm
                         and r['status'] == 'OK'), None)
        if ref_row is None:
            print(f'Skipping real network round trip: reference algorithm '
                  f"'{network_ref_algorithm}' did not encode successfully", flush=True)
        else:
            try:
                payload_chunks = _gpu_encode_chunks(data, network_ref_algorithm)
                chunk_sizes = [len(c) for c in payload_chunks]
                payload = b''.join(payload_chunks)
                gc.collect()
                checksum = hashlib.sha256(data).digest()
                header = _pack_header(network_ref_algorithm, src_size, checksum, chunk_sizes)
                archive_size_mb = (len(header) + len(payload)) / 1024 / 1024

                t0 = time.perf_counter()
                with open(network_out, 'wb') as f:
                    f.write(header)
                    f.write(payload)
                t_write = time.perf_counter() - t0
                mbps_write = archive_size_mb / t_write if t_write > 0 else float('inf')
                print(f'Reference write ({network_ref_algorithm}) to {network_out}: '
                      f'{t_write:.1f}s ({mbps_write:.1f} MB/s) [MEASURED]', flush=True)

                t0 = time.perf_counter()
                readback_hasher = hashlib.sha256()
                total_decoded, _algo, orig_size, chk = _stream_decode_archive(
                    network_out, readback_hasher.update)
                t_readback = time.perf_counter() - t0
                readback_ok = total_decoded == orig_size and readback_hasher.digest() == chk
                mbps_readback = archive_size_mb / t_readback if t_readback > 0 else float('inf')
                print(f'Reference read-back+decode ({network_ref_algorithm}): {t_readback:.1f}s '
                      f'({mbps_readback:.1f} MB/s) [MEASURED] - on-disk correctness: {readback_ok}',
                      flush=True)

                if not keep_staged:
                    Path(network_out).unlink(missing_ok=True)
            except Exception as exc:
                mbps_write = mbps_readback = None
                print(f'Network round trip FAILED (compute-only results above are still valid): '
                      f'{exc}', flush=True)

    print()
    _print_benchmark_table(results, t_read, mbps_read, mbps_write, mbps_readback, network_ref_algorithm)
    if csv_path:
        _write_benchmark_csv(csv_path, server_src, src_size, mbps_read, mbps_write, mbps_readback,
                              network_ref_algorithm, results)
        print(f'BENCHMARK_CSV: {csv_path}', flush=True)

    print('BENCHMARK_OK', flush=True)
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='GPU (NVIDIA nvCOMP) compress/verify/decompress.')
    sub = parser.add_subparsers(dest='mode', required=True)

    p_compress = sub.add_parser('compress')
    p_compress.add_argument('in_path')
    p_compress.add_argument('out_path')
    p_compress.add_argument('--algorithm', default='Zstd')
    p_compress.add_argument('--verify-tier', default='full', choices=['full', 'quick', 'memory'])

    p_verify = sub.add_parser('verify')
    p_verify.add_argument('archive_path')
    p_verify.add_argument('--force-cpu', action='store_true')

    p_decompress = sub.add_parser('decompress')
    p_decompress.add_argument('archive_path')
    p_decompress.add_argument('out_path')
    p_decompress.add_argument('--force-cpu', action='store_true')

    p_stage = sub.add_parser('stage')
    p_stage.add_argument('local_src')
    p_stage.add_argument('server_dst')

    p_benchmark = sub.add_parser('benchmark')
    p_benchmark.add_argument('server_src')
    p_benchmark.add_argument('--algorithms', default=None,
                              help='Comma-separated algorithm list, default: all of ' +
                                   ','.join(DEFAULT_BENCHMARK_ALGORITHMS))
    p_benchmark.add_argument('--network-ref-algorithm', default='Zstd')
    p_benchmark.add_argument('--network-out', default=None,
                              help='Server-side path for the one real write+read-back round trip; '
                                   'omit to skip real network measurement (compute-only benchmark)')
    p_benchmark.add_argument('--csv', dest='csv_path', default=None)
    p_benchmark.add_argument('--keep-staged', action='store_true')

    args = parser.parse_args()

    try:
        if args.mode == 'compress':
            sys.exit(compress(args.in_path, args.out_path, args.algorithm, args.verify_tier))
        elif args.mode == 'verify':
            sys.exit(verify(args.archive_path, args.force_cpu))
        elif args.mode == 'decompress':
            sys.exit(decompress(args.archive_path, args.out_path, args.force_cpu))
        elif args.mode == 'stage':
            sys.exit(stage(args.local_src, args.server_dst))
        elif args.mode == 'benchmark':
            algos = args.algorithms.split(',') if args.algorithms else None
            sys.exit(benchmark(args.server_src, algorithms=algos,
                                network_ref_algorithm=args.network_ref_algorithm,
                                network_out=args.network_out, csv_path=args.csv_path,
                                keep_staged=args.keep_staged))
    except Exception as exc:
        print(f'ERROR: {exc}', flush=True)
        sys.exit(1)
