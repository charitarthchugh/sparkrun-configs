# ple-mmap-vllm

Serves Qwen3.8-Flash-Next's 51B-parameter n-gram ("PLE") embedding table from
disk via `mmap` instead of keeping it resident, so the ~122 GiB NVFP4 checkpoint
fits next to a usable KV cache in a DGX Spark's 128 GB unified pool.

This is [blazux/qwen3.8-Flash-DGX][repo]'s `src/vllm_ple_mmap.py`, vendored
verbatim and applied at launch instead of baked into an image. Upstream ships it
as a `Dockerfile` on top of `vllm/vllm-openai:qwen38-flash-next`; this mod does
exactly what that Dockerfile's two layers do — copy the module next to `vllm`,
append the hook to `ple_layer.py` — so no image has to be built or hosted.

Apache-2.0, © 2026 blazux. `LICENSE.upstream` is the license as shipped in that
repo; the vendored file carries no local delta.

## Why the table can live on disk

The table is a lookup, not compute: a token reads 16 rows × 160 bytes ≈ 2.5 KB at
hashed addresses. A 20k-token prefill is ~1.3 GB of small reads, under a second
on NVMe, and natural text and code concentrate on a small hot set that the page
cache keeps. vLLM's own `VLLM_PLE_CPU_OFFLOAD=1` moves the table to pinned host
RAM, which frees VRAM on a discrete GPU but nothing at all on a Spark, where
host and device are the same physical pool.

With the hook active, weights drop from ~122 GiB resident to under 80 GiB and the
rest of the pool goes to KV.

Verified on this node 2026-08-29 against the pinned image: the hook reports layer
1, 128 shards, 320,001,536 rows x 160 B (47.7 GiB left on disk), dtype F8_E4M3,
32 workers; the model loads at 79.31 GiB resident and leaves a 771,621-token KV
pool. Prefill on a 47.6k-token prompt ran 1725 tok/s cold and 2298 tok/s warm —
that cold-to-warm gap is the page cache filling with the n-gram rows the prompt
touches, and it is the most direct evidence the table really is being served
from disk rather than quietly materialised.

## What it does

1. Checksums the vendored `vllm_ple_mmap.py` (see the pin below) and copies it to
   the dist-packages root next to `vllm/`.
2. Appends `_ple_mmap_apply(Qwen3_8FlashNextNGramEmbedding)` to
   `vllm/models/qwen3_8_flash_next/nvidia/ple_layer.py`, keeping a `.orig` copy.
3. `ast.parse`s the patched file and imports the module, so a bad copy fails the
   launch instead of the engine dying eight minutes into loading weights.

The hook is a no-op unless `VLLM_PLE_MMAP=1` is set at runtime, so a container
that ran this mod still behaves exactly like the stock image with the flag off.

The upstream Dockerfile hardcodes `/usr/local/lib/python3.12/dist-packages`; this
mod asks the interpreter instead and falls back to a `find` for `ple_layer.py`,
so a rebuilt image on a different interpreter still works. A missing
`ple_layer.py` is a hard error: it means the recipe is pointed at a vLLM without
Flash-Next support, and without the hook the engine would try to materialise the
47.7 GiB table and OOM with nothing pointing back here.

## What the recipe must also do

The mod alone is not enough. Three things belong in the recipe and will fail
loudly (or, worse, quietly) if they are missing:

- **`VLLM_PLE_MMAP=1`**, or the hook does nothing and the table is materialised.
- **A local snapshot directory as the model argument.** The module reads
  `model_config.model` and raises `PLE mmap: model path ... is not a local
  directory` on a bare Hub repo id, because it has to glob the checkpoint's
  `model-plefp8-*.safetensors` shards itself.
- **`-cc.cudagraph_mode=PIECEWISE` with `vllm::ple_mmap_lookup` in
  `-cc.splitting_ops`.** The gather is CPU work plus a pageable host→device copy,
  which cannot run inside a captured CUDA graph; without the splitting op the
  engine dies with `Cannot copy between CPU and CUDA tensors during CUDA graph
  capture`. `--enforce-eager` avoids that too but is slower, and upstream notes
  it does not fully suppress capture here (the mamba/short-conv path still
  captures), so PIECEWISE plus the splitting op is the right answer.

Optional knobs the module reads: `VLLM_PLE_MMAP_WORKERS` (gather threads,
default 32), `VLLM_PLE_MMAP_CHUNK` (rows per task, default 2048), and
`VLLM_PLE_MMAP_PREWARM=1` (stream the table once at boot to warm the page cache,
~10 s, steadier first-request latency).

## Pin and the exit ramp

Vendored from [blazux/qwen3.8-Flash-DGX][repo] at
`d2854bfff0a0b6f46984b0941ed1db6010031295` (2026-08-27), sha256
`2bca73dd0f77e72937cdfc43312c3fc4d217847d4bb126cf3665bd8caa3108c8`. The file is
vendored rather than fetched, so a launch never depends on GitHub being
reachable and never silently picks up a new version. Re-vendoring means updating
`EXPECTED_SHA` and the revision in `run.sh` and here together.

As of 2026-09-14 upstream vLLM `main` has only `VLLM_PLE_CPU_OFFLOAD`, which
frees nothing on a Spark. The upstream path to watch is
[vllm-project/vllm#54129][pr] ("Support disk-backed (mmap) PLE table for
Qwen3.8-Flash-Next", `VLLM_PLE_MMAP`), still open; #54070
(`VLLM_PLE_DISK_OFFLOAD_DIR`) and #53899 are parallel attempts. Drop the mod once
one of them merges and a Flash-Next image ships with it. The b12x fork's
`VLLM_PLE_TABLE_MEMORY=disk` (used by `qwen3.8-flash-next-nvfp4-vllm`) is a
separate, non-upstream implementation and does not make this mod redundant for
the RadixArk checkpoint on the stock image. The `.orig` sidecar the mod leaves
next to `ple_layer.py` is the way to tell, by hand, what the stock file looked
like.

## Correctness

Upstream ships a CPU unit test (`src/test_ple_mmap_cpu.py` in that repo) that
builds synthetic FP8 shards with the real safetensors layout and checks the gather
bit-for-bit against a reference `table[ids]`. It is not vendored here — this mod
carries only the runtime file — but it is the thing to run if the gather is ever
suspected. End to end, a wrong gather turns the n-gram contribution to noise and
the model degrades immediately, so a coherent first response is a real signal —
verified here, answering "The capital of France is Paris." on the first request.

[repo]: https://github.com/blazux/qwen3.8-Flash-DGX
[pr]: https://github.com/vllm-project/vllm/pull/54129
