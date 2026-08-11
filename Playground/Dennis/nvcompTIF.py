"""GPU (NVIDIA nvCOMP) compress / verify / decompress for arbitrary files.

Used by gpuCompressTIFwithNvcomp.m and unzipNvcomp.m as the GPU-accelerated,
lossless counterpart to the CPU 7-Zip pipeline (compressTIFwith7zip.m /
unzip7z.m). Written as raw byte compression (not video/pixel encoding), so
there is no bit-depth limitation - it does not care that the payload happens
to be 16-bit ScanImage TIFF data.

Requires: pip install nvidia-nvcomp-cu13 numpy (or nvidia-nvcomp-cu12 instead
of -cu13, matching whatever CUDA your driver supports) in this Python
environment. numpy is a hard dependency of nvcomp.as_array().

Archive format (.nvcz), all integers little-endian:
    b'NVCZ1'            magic (5 bytes)
    algo_len             uint8
    algorithm            algo_len bytes, ascii (e.g. 'Zstd', 'Bitcomp')
    orig_size            uint64
    sha256               32 bytes, checksum of the original uncompressed bytes
    payload               nvCOMP-compressed bytes

verify/decompress only ever read the archive itself (never the original file),
mirroring how `7z t` only tests the archive - so integrity can be checked even
after the original TIF has been deleted.

Tested end-to-end (compress -> verify -> decompress -> sha256 compare, plus a
deliberately corrupted archive) against a real nvcomp install. A corrupted
archive correctly fails verify/decompress with exit code 1 and writes no
output file, but does so via a noisy CUDA "illegal memory access" error
logged a few times during GPU cleanup - harmless (each CLI invocation is a
fresh process), just alarming-looking in the log.
"""

import sys
import argparse
import hashlib
import struct
from pathlib import Path

MAGIC = b'NVCZ1'


def _pack_header(algorithm, orig_size, checksum):
    algo_bytes = algorithm.encode('ascii')
    return MAGIC + struct.pack('<B', len(algo_bytes)) + algo_bytes + struct.pack('<Q', orig_size) + checksum


def _read_header(f):
    magic = f.read(len(MAGIC))
    if magic != MAGIC:
        raise ValueError('Not a valid .nvcz archive (bad magic bytes)')
    (algo_len,) = struct.unpack('<B', f.read(1))
    algorithm = f.read(algo_len).decode('ascii')
    (orig_size,) = struct.unpack('<Q', f.read(8))
    checksum = f.read(32)
    return algorithm, orig_size, checksum


def compress(in_path, out_path, algorithm='Zstd'):
    from nvidia import nvcomp

    data = Path(in_path).read_bytes()
    checksum = hashlib.sha256(data).digest()

    codec = nvcomp.Codec(algorithm=algorithm)
    src_arr = nvcomp.as_array(data).cuda()
    compressed = codec.encode(src_arr)
    payload = bytes(compressed.cpu())

    with open(out_path, 'wb') as f:
        f.write(_pack_header(algorithm, len(data), checksum))
        f.write(payload)

    print('COMPRESSION_OK')


def _decode_archive(archive_path):
    from nvidia import nvcomp

    with open(archive_path, 'rb') as f:
        algorithm, orig_size, checksum = _read_header(f)
        payload = f.read()

    codec = nvcomp.Codec(algorithm=algorithm)
    compressed_arr = nvcomp.as_array(payload).cuda()
    decoded_arr = codec.decode(compressed_arr)
    decoded = bytes(decoded_arr.cpu())
    return decoded, orig_size, checksum


def verify(archive_path):
    decoded, orig_size, checksum = _decode_archive(archive_path)
    if len(decoded) != orig_size:
        print(f'INTEGRITY_FAIL: decoded size {len(decoded)} != expected {orig_size}')
        return 1
    if hashlib.sha256(decoded).digest() != checksum:
        print('INTEGRITY_FAIL: checksum mismatch')
        return 1
    print('INTEGRITY_OK')
    return 0


def decompress(archive_path, out_path):
    decoded, orig_size, checksum = _decode_archive(archive_path)
    if len(decoded) != orig_size or hashlib.sha256(decoded).digest() != checksum:
        print('DECOMPRESS_FAIL: integrity check failed, refusing to write output')
        return 1
    Path(out_path).write_bytes(decoded)
    print('DECOMPRESS_OK')
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='GPU (NVIDIA nvCOMP) compress/verify/decompress.')
    sub = parser.add_subparsers(dest='mode', required=True)

    p_compress = sub.add_parser('compress')
    p_compress.add_argument('in_path')
    p_compress.add_argument('out_path')
    p_compress.add_argument('--algorithm', default='Zstd')

    p_verify = sub.add_parser('verify')
    p_verify.add_argument('archive_path')

    p_decompress = sub.add_parser('decompress')
    p_decompress.add_argument('archive_path')
    p_decompress.add_argument('out_path')

    args = parser.parse_args()

    try:
        if args.mode == 'compress':
            compress(args.in_path, args.out_path, args.algorithm)
            sys.exit(0)
        elif args.mode == 'verify':
            sys.exit(verify(args.archive_path))
        elif args.mode == 'decompress':
            sys.exit(decompress(args.archive_path, args.out_path))
    except Exception as exc:
        print(f'ERROR: {exc}')
        sys.exit(1)
