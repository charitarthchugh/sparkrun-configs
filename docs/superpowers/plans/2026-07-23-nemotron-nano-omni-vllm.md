# Nemotron 3 Nano Omni vLLM-Omni Recipe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Sparkrun recipe for NVIDIA's official NVFP4 Nemotron 3 Nano Omni checkpoint in vLLM-Omni.

**Architecture:** One recipe under NVIDIA's creator directory points to the official NVFP4 model and vLLM-Omni image. It uses the normal `vllm serve` path without the Omni-only `--omni` flag, because this is a text-output autoregressive model rather than a registered multi-stage pipeline.

**Tech Stack:** Sparkrun recipe YAML, Docker, vLLM-Omni.

## Global Constraints

- Model: `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4`.
- Container: `vllm/vllm-omni:latest`.
- Use the official NVFP4 checkpoint, FP8 KV cache, and `nemotron_v3` reasoning parser.
- Do not add `--omni`.

---

### Task 1: Add and validate the NVIDIA recipe

**Files:**

- Create: `recipes/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning-nvfp4-vllm-omni.yaml`

**Interfaces:**

- Consumes: Sparkrun `recipe_version: "2"` YAML schema.
- Produces: A single-node `vllm serve` launch for an OpenAI-compatible endpoint on `{host}:{port}`.

- [ ] **Step 1: Create the recipe**

Define the vLLM-Omni container, model metadata, and defaults for host, port,
tensor parallelism, GPU memory utilization, context, batch-token capacity,
sequence capacity, and served model name. The command installs `vllm[audio]`,
then invokes `vllm serve {model}` with NVIDIA's remote-code, video sampling,
multimodal limits, FP8 KV cache, reasoning, tool-calling, and capacity flags.

- [ ] **Step 2: Validate the recipe**

Run: `sparkrun recipe validate recipes/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning-nvfp4-vllm-omni.yaml`

Expected: validation succeeds without schema errors.

- [ ] **Step 3: Inspect the rendered launch**

Run: `sparkrun run recipes/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning-nvfp4-vllm-omni.yaml --solo --dry-run`

Expected: the command uses `vllm/vllm-omni:latest`, the NVIDIA NVFP4 model ID,
and does not include `--omni`.

- [ ] **Step 4: Commit the recipe**

Run: `git add recipes/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning-nvfp4-vllm-omni.yaml && git commit -m "feat: add Nemotron Nano Omni vLLM recipe"`
