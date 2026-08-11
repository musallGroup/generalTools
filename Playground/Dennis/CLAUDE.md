# Playground/Dennis

Personal working folder for Dennis Laufs within the shared `generalTools` lab repo.
Claude Code project files live here rather than at the repo root, since
`generalTools` is shared across the lab (see sibling `Playground/<Name>` folders)
and a root-level CLAUDE.md would apply to everyone's sessions, not just his.

## Current work: GPU-accelerated TIF compression

`compressComplete2pSessions_DL.m` is a GPU variant of the repo's
`compressComplete2pSessions.m` (CPU, 7-Zip/LZMA). It compresses large
ScanImage TIFFs from completed 2p sessions on GPU instead of CPU, using
NVIDIA nvCOMP instead of 7-Zip, then deletes the original only after a
verified-lossless integrity check - same failsafe design as the original.
**This machine (host `CMP0437`) is the actual RTX 5090 deployment machine,
running Linux** - not a separate test box, and not Windows (the CPU-era
scripts' `F:\...` paths were from an earlier/different deployment context).

Files (all in this folder):
- `compressComplete2pSessions_DL.m` - driver, same session-discovery/skip
  logic as the CPU version, outputs `.nvcz` instead of `.7z`
- `gpuCompressTIFwithNvcomp.m` - MATLAB wrapper around a single merged
  compress+verify `nvcompTIF.py` call
- `nvcompTIF.py` - does the actual GPU work via `from nvidia import nvcomp`;
  also has `stage`/`benchmark` subcommands (see Benchmark suite below)
- `unzipNvcomp.m` - restores a `.nvcz` archive back to `.tif` (GPU or CPU)
- `benchmarkNvcompAlgorithms.m` - MATLAB wrapper for the benchmark suite

Why nvCOMP rather than NVENC/ffmpeg for "GPU compression": the data is
16-bit ScanImage TIFFs; NVENC lossless video encoding tops out at 12-bit
even on Blackwell, so it would silently lose precision. nvCOMP compresses
raw bytes (not video/pixels), so there's no bit-depth ceiling.

### Environment

Requires `pip install nvidia-nvcomp-cu13 numpy zstandard lz4` (or
`nvidia-nvcomp-cu12` instead of `-cu13`, matching your CUDA/driver) in
whatever Python environment `pythonPath` resolves to. On this machine
that's `~/nvcomp-env`. `zstandard`/`lz4` are only needed for the CPU
decompression fallback, not for compression or GPU decode.

MATLAB's `system()` does not reliably inherit shell `PATH` edits (e.g. venv
activation) - every `.m` file here takes an explicit `pythonPath` parameter
for this reason (default `'python'`, override with the venv's absolute
interpreter path). `nvidia-smi` on this machine intermittently reports a
driver/NVML version mismatch (kernel module older than installed userspace
packages, fixed by a reboot) - this does NOT block actual CUDA/nvcomp
compute, which goes through `libcuda.so` rather than NVML.

### Archive format & RAW bitstream mode (v2, with chunking)

`.nvcz` v2 header: magic `b'NVCZ2'` + algorithm + orig_size + sha256 +
**a list of per-chunk compressed sizes** (see below). Compression always
uses `bitstream_kind=RAW` rather than nvCOMP's default `NVCOMP_NATIVE`
container: `NVCOMP_NATIVE` is not decodable by anything but nvcomp itself
even for algorithms named after standard formats (confirmed - the real
`zstd` CLI rejects it as "unsupported format"), whereas `RAW` output for
`'Zstd'`/`'LZ4'` is genuinely standard-format compatible, which is what
makes CPU-only decompression possible at all.

**RAW mode's safe single-buffer size is wildly algorithm-dependent - found
by actually probing every algorithm from 1 MB up to 2 GB, not assumed:**
- `'Zstd'` holds up to just under `2**31` bytes (fails at exactly that
  boundary - a 32-bit overflow inside nvCOMP itself, "Could not determine
  the maximum compressed chunk size").
- `'LZ4'`, `'Snappy'`, `'ANS'`, `'Bitcomp'`, `'Cascaded'` all fail with the
  *same* error between 16-32 MB - a completely different ceiling from Zstd,
  not a smaller version of the same limit.
- `'GDeflate'`/`'Deflate'`/`'Gzip'` clear the size check up to 256 MB+ (like
  Zstd) but hit a *separate* GPU out-of-memory failure at 512 MB despite
  each chunk individually fitting - confirmed OOM-free holding 6 concurrent
  128 MB chunks instead. These three are also just slow regardless of chunk
  size (`GDeflate`: ~5s per 64 MB, i.e. ~5 min encode alone for a 3.9 GB
  file) - a real characteristic, not a bug, and exactly what the benchmark
  suite exists to surface before you pick an algorithm.
- The `uncomp_chunk_size` Codec option does **not** help avoid any of this -
  tested, it's silently ignored under `RAW` mode.

Because of this, data is split into **algorithm-appropriate fixed-size
chunks** before encoding (`_encode_chunk_size()` in `nvcompTIF.py`: 8 MB for
the tight-limit group, 128 MB for the memory-limited group, 512 MB default
for everything else, each with a real safety margin under its confirmed
failure point), each chunk RAW-encoded independently, with an exact record
of each chunk's compressed size in the header so decode can slice correctly.
LZ4's raw block format isn't self-delimiting, so explicit chunk boundaries
are required for LZ4 to decode at all, not just an optimization.

**Practical consequence for algorithm choice**: `'LZ4'` is technically
correct at any file size but ~40x slower than `'Zstd'` on large files
(confirmed: 1.5 GB took 3m12s vs Zstd's ~4s-equivalent scale) purely from
per-chunk overhead at the forced 8 MB chunk size - GPU decode of an LZ4
archive is similarly slow, but **CPU decode of the same archive is fast**
(2.9s for the same 1.5 GB file) since it doesn't pay per-chunk GPU
kernel-launch overhead. `'Zstd'` remains the sensible default for large
files.

### Integrity model: verify tiers (compress() only)

`compress()` in `nvcompTIF.py` and `gpuCompressTIFwithNvcomp.m` take a
`verifyTier` parameter: `'full'` (default, and the **only tier actually
used in production** - the user explicitly chose this over speed when given
the tradeoff), `'quick'`, or `'memory'`. Every tier always runs a mandatory
**in-memory** decode-and-compare right after encoding, before anything is
written to disk - free, catches encode bugs, refuses to write bad data.
After writing, the tier controls the *post-write* on-disk check:
- `'full'`: reread and fully decode the whole archive from disk. Only tier
  that catches corruption/truncation introduced during or after the write -
  the failure mode most relevant to writing large archives over this
  machine's real-world network throughput (see naskampa/lts numbers below).
- `'quick'`: reread just the header + last ~16 MB and compare against the
  known-correct in-memory bytes from the same process. Catches truncated/
  interrupted writes (the dominant real failure mode for network
  interruptions) at near-zero I/O cost, but not silent bit-rot in the
  untouched middle of the file - confirmed empirically with a deliberate
  mid-file byte flip that `'full'` catches and `'quick'` does not.
- `'memory'`: no post-write check at all.

`gpuCompressTIFwithNvcomp.m` returns a tri-state
`[integrityCheck, zipOutputPath, verifiedOnDisk]` so a caller using a
non-`'full'` tier can't miss that a file was deleted without on-disk
verification; `compressComplete2pSessions_DL.m` prints an unmissable
warning immediately before deleting the original whenever that's the case.

**Implementation detail that matters, not polish**: Python's stdout is
block-buffered when piped (MATLAB's `system()` case) - a merged process
that prints `COMPRESSION_OK` and then crashes later during the post-write
check could lose that earlier line from MATLAB's captured output without
explicit `flush=True` on every status print. Confirmed both the failure
mode (a `SIGKILL` right after an unflushed print loses it entirely) and the
fix (survives even `SIGKILL` with `flush=True`) before relying on it.

### CPU-only decompression fallback

`unzipNvcomp.m`/`nvcompTIF.py decompress` work without any GPU at all for
`'Zstd'`/`'LZ4'` archives - auto-detects via `ImportError` on
`from nvidia import nvcomp` and falls back to `zstandard`/`lz4.block`
automatically; `--force-cpu` forces the path for testing even when a GPU is
present. Every other algorithm (`Bitcomp`/`GDeflate`/`ANS`/`Cascaded`, plus
`Snappy`/`Deflate`/`Gzip` which were never tested for CPU compatibility)
fails with an explicit `NO_CPU_FALLBACK` message rather than attempting
something broken - these are NVIDIA-proprietary GPU bitstreams with no
external decoder regardless of `bitstream_kind`.

### Benchmark suite

`nvcompTIF.py stage`/`benchmark` + `benchmarkNvcompAlgorithms.m` compare
algorithms against a real file staged on the server
(`Team/Dennis/nvcomp_benchmark_scratch/` - safe personal scratch location,
confirmed empty/no-collision before use). Reads the source once, reused
across every algorithm's encode(); each algorithm gets its own
appropriately-sized chunks (see above) so numbers reflect what `compress()`
would really do, not an artificially-uniform comparison. Only **one** real
network write+read-back happens, for a reference algorithm (default
`'Zstd'`) - every other algorithm's network-inclusive time is an ESTIMATE
derived from that one measured MB/s applied to its own real compressed
size, clearly labeled as such in both the console table and the CSV
(written to `Playground/Dennis/benchmark_results/`, timestamped).

Real measured network numbers on this machine's path to `naskampa/lts`
(confirmed via `ethtool`: this machine has a genuine 10Gbps NIC) with a
real `dd` sequential-read test: only **~60 MB/s** sustained - nowhere near
the link's theoretical capacity, meaning the bottleneck is server-side
storage/protocol overhead, not the client's network link. A full 3.9 GB
production compress+full-verify round trip against this server took
**3m16s** end-to-end through the real MATLAB pipeline (vs. 12s on local
disk) - the network, not GPU compute, dominates real-world timing.

### Verified so far

- Real 3.9 GB ScanImage TIF (`Desktop/test/F95_S1_300um_20220407_092703_00001_00004.tif`,
  sha256 `440c214a566bad485e6af76026796d987f225b4cfbf2448ff43df3f116165b78`),
  compressed/verified/deleted/restored through the actual MATLAB production
  pipeline against the real `naskampa/lts` server path, byte-identical
  restore confirmed against the known hash.
- CPU comparison: 7z `-mx=9` on the same file took 5m13.9s (75.9% ratio) vs
  GPU Zstd's 12s (82.1% ratio) on local disk - ~26x faster, smaller ratio
  advantage than expected.
- Multi-chunk correctness (1.5 GB, spanning multiple chunks) confirmed for
  `Zstd`, `LZ4` (GPU + CPU-fallback), `GDeflate`, `Bitcomp`.
- Verify-tier corruption detection confirmed with deliberate truncation and
  mid-file byte-flip tests, matching the documented `'full'` vs `'quick'`
  guarantee gap exactly.

Still open: results from the full 9-algorithm benchmark against the real
3.9 GB file (running - GDeflate/Deflate/Gzip alone are expected to take
several minutes each given their confirmed slowness, so the whole run may
take up to an hour).
