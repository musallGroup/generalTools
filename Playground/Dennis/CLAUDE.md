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

Files (all in this folder):
- `compressComplete2pSessions_DL.m` - driver, same session-discovery/skip
  logic as the CPU version, outputs `.nvcz` instead of `.7z`
- `gpuCompressTIFwithNvcomp.m` - MATLAB wrapper, compress-then-verify,
  mirrors `compressTIFwith7zip.m`'s contract
- `nvcompTIF.py` - does the actual GPU work via `from nvidia import nvcomp`
- `unzipNvcomp.m` - restores a `.nvcz` archive back to `.tif`

Why nvCOMP rather than NVENC/ffmpeg for "GPU compression": the data is
16-bit ScanImage TIFFs; NVENC lossless video encoding tops out at 12-bit
even on Blackwell, so it would silently lose precision. nvCOMP compresses
raw bytes (not video/pixels), so there's no bit-depth ceiling.

Key nvCOMP Python API gotchas (found by actually running it, not just docs):
- `Codec.encode()` requires an `nvcomp.Array`, not raw bytes - wrap with
  `nvcomp.as_array(data).cuda()` first.
- `nvcomp.as_array()` has a hard dependency on `numpy` even for plain bytes
  input.
- Requires `pip install nvidia-nvcomp-cu13` (or `-cu12`, matching your
  CUDA/driver) plus `numpy`.
- Default algorithm is `'Zstd'` - empirically beat `'GDeflate'` and
  `'Bitcomp'` on a synthetic 16-bit test file (Bitcomp needs an explicit
  `data_type` hint to get its usual numeric-array advantage, which isn't
  set here since the whole file is compressed as opaque bytes).
- Verified end-to-end (compress -> verify -> decompress -> sha256 compare,
  plus a deliberately corrupted archive) on a Linux test machine
  (`~/nvcomp-env` venv, host `CMP0437`). A corrupted archive fails closed
  (exit 1, no output written) but logs a noisy "CUDA illegal memory access"
  during GPU cleanup - harmless, just alarming-looking.
- On that test machine, `nvidia-smi` reports a driver/NVML version mismatch
  (kernel module loaded at boot is older than the userspace packages
  installed since, fixed by a reboot) - but this did NOT block actual
  CUDA/nvcomp compute, since CUDA compute goes through `libcuda.so` rather
  than NVML.

Still needed before trusting this on real data: run on the actual RTX 5090
deployment machine, confirm `nvidia-smi` is clean there (or verify compute
still works despite any mismatch, as it did on the test machine), and do
one real compress/restore/checksum round-trip on an actual session before
running unattended on irreplaceable data.
