# Qwen and Laguna Recipe Additions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add validated vLLM Sparkrun recipes for NVIDIA Qwen3.6-27B-NVFP4 and Poolside Laguna-S-2.1.

**Architecture:** Each recipe uses the registry's creator-first directory layout and `vllm-distributed` runtime. Qwen follows NVIDIA's documented ModelOpt invocation. Laguna follows Poolside's documented four-way tensor parallelism and parser configuration, starting conservatively below its 1M-token maximum context.

**Tech Stack:** YAML, Python standard library, Sparkrun 0.2.40.

## Global Constraints

- Do not include credentials or tokens in recipes.
- Use `ghcr.io/spark-arena/dgx-vllm-eugr-nightly-tf5:latest` and runtime `vllm-distributed`.
- Qwen recipe model is `nvidia/Qwen3.6-27B-NVFP4`, quantization is `modelopt`, and reasoning parser is `qwen3`.
- Laguna recipe model is `poolside/Laguna-S-2.1`, requires `tensor_parallel: 4`, uses `poolside_v1` for both tool and reasoning parsing, and enables automatic tool choice and thinking by default.
- Limit initial contexts to 131072 tokens for Qwen and 32768 tokens for Laguna; users may override after validating capacity.

---

### Task 1: Add recipes and a Python manifest validator

**Files:**

- Create: `recipes/qwen/qwen3.6-27b-nvfp4-vllm.yaml`
- Create: `recipes/poolside/laguna-s-2.1-vllm.yaml`
- Create: `scripts/validate_registry_manifest.py`

**Interfaces:**

- Consumes: `.sparkrun/registry.yaml` and the model providers' documented vLLM flags.
- Produces: Two valid Sparkrun recipes and a dependency-free structural manifest check.

- [ ] **Step 1: Write the Qwen recipe**

Set `model`, `runtime`, `container`, `metadata`, and defaults for one-node NVFP4 serving. The command must use `--quantization modelopt`, `--reasoning-parser qwen3`, `{max_model_len}`, `{tensor_parallel}`, `{gpu_memory_utilization}`, `{host}`, and `{port}`.

- [ ] **Step 2: Write the Laguna recipe**

Set a four-node minimum and `tensor_parallel: 4`. The command must use `--tool-call-parser poolside_v1`, `--reasoning-parser poolside_v1`, `--enable-auto-tool-choice`, and `--default-chat-template-kwargs '{"enable_thinking": true}'`.

- [ ] **Step 3: Write the Python validator**

Use only the Python standard library. Read `.sparkrun/registry.yaml` as text and require the exact scalar mappings from the registry manifest: name `charitarth`, recipes `recipes`, tuning `tuning`, benchmarks `benchmarking`, mods `mods`, enabled `true`, and visible `true`. Print `registry manifest valid` and exit zero only when every mapping is present; otherwise print missing mappings to stderr and exit nonzero.

- [ ] **Step 4: Validate**

Run:

```bash
python3 scripts/validate_registry_manifest.py
sparkrun recipe validate recipes/qwen/qwen3.6-27b-nvfp4-vllm.yaml
sparkrun recipe validate recipes/poolside/laguna-s-2.1-vllm.yaml
sparkrun run recipes/qwen/qwen3.6-27b-nvfp4-vllm.yaml --solo --dry-run
```

Expected: every command exits zero; the Python command prints `registry manifest valid`.

- [ ] **Step 5: Commit**

```bash
git add recipes/qwen recipes/poolside scripts/validate_registry_manifest.py
git commit -m "feat: add qwen and laguna recipes"
```
