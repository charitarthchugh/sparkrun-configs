# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal **Sparkrun** recipe **registry** — not application code. It is a
collection of YAML recipes that describe how to serve LLM checkpoints (almost all
NVFP4/FP8-quantized) with vLLM on a single NVIDIA **DGX Spark** node. There is no build step and
almost no executable code; the deliverable is the recipes themselves.

## Commands

```bash
# Validate a recipe before running or committing it (always do this after editing a recipe)
sparkrun recipe validate recipes/qwen/qwen3.6-27b-nvfp4-vllm.yaml

# Inspect the resolved launch without starting a workload (single-node)
sparkrun run recipes/qwen/qwen3.6-27b-nvfp4-vllm.yaml --solo --dry-run

# Validate the registry manifest (.sparkrun/registry.yaml) — the only script in the repo
python scripts/validate_registry_manifest.py
```

`.sparkrun/registry.yaml` is the manifest and must keep the exact key→value mappings that
`scripts/validate_registry_manifest.py` enforces (`name: charitarth`, and the content-dir
mappings `recipes`, `tuning`, `benchmarks: benchmarking`, `mods`, plus `enabled/visible: true`).

## Layout

- `recipes/<creator>/<model>-<runtime>.yaml` — creator-first layout (e.g. `recipes/qwen/`,
  `recipes/nvidia/`). Filenames encode the intended engine (`-vllm`) so a recipe's runtime is
  obvious. Sparkrun discovers content recursively, so nesting is allowed.
- `tuning/`, `benchmarking/`, `mods/` — optional content dirs declared in the manifest. Currently
  only `.gitkeep` placeholders. `mods:` in a recipe references entries here.
- `.sparkrun-local/`, `.env*`, `*.pem`, `*.key` — gitignored. **Recipes must never contain
  secrets**; keep credentials in these ignored paths.

## Recipe schema (the thing you'll actually edit)

Two `recipe_version` formats coexist; match the style of the file you're editing.

- **v2 with `runtime: vllm-distributed`** (e.g. `recipes/poolside/laguna-s-2.1-vllm.yaml`,
  `recipes/nvidia/nemotron-...omni.yaml`): has a `metadata:` block (`description`, `model_params`,
  `model_dtype`, `model_vram`, `kv_dtype`, `quantization`) and `min_nodes`/`max_nodes`.
- **v2/v1 flat style** (e.g. the `recipes/qwen/*-27b-*.yaml`): top-level `description`, `name`,
  `container`, `cluster_only`/`solo_only`, no `metadata`/`runtime` block.

Common to all: `model`, `container`, `defaults:` (a map of `{placeholder}` values), optional
`env:`, and a `command:` block heredoc. `command` uses `{name}` placeholders that resolve from
`defaults` (and `{model}`). When adding a knob, add it to `defaults` **and** reference it as
`{name}` in `command` — don't hardcode values that already have a default.

## DGX Spark serving conventions

These recur across recipes and are the reason most tuning values look the way they do:

- Single Spark node: `tensor_parallel: 1`, `min_nodes/max_nodes: 1`, run with `--solo`.
- NVFP4 checkpoints use `--quantization modelopt` and `--load-format fastsafetensors`;
  `--kv-cache-dtype fp8` for the KV cache.
- Spark-specific env: `CUTE_DSL_ARCH: sm_121a`, and build-parallelism caps
  (`MAX_JOBS`, `NVCC_THREADS`, `FLASHINFER_NVCC_THREADS`) to avoid OOM during on-node compiles.
- "Max-throughput text profile" = `--async-scheduling`, `--enable-chunked-prefill`,
  `--enable-prefix-caching`, and MTP speculative decoding
  (`--speculative-config '{"method":"mtp","num_speculative_tokens":3}'`).
- Match `--reasoning-parser` / `--tool-call-parser` to the model family (e.g. `qwen3` +
  `qwen3_xml`, `poolside_v1`, `nemotron_v3`); keep `--enable-auto-tool-choice` when a tool parser
  is set.

Tuning changes (VRAM budget via `gpu_memory_utilization`, `max_num_seqs`, `max_num_batched_tokens`,
`max_model_len`) are workload trade-offs — carry the rationale in the recipe `description`, as the
existing recipes do.
