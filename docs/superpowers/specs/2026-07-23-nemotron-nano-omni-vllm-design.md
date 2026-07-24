# Nemotron 3 Nano Omni vLLM Recipe Design

## Goal

Add one Sparkrun recipe for NVIDIA's official NVFP4 Nemotron 3 Nano Omni
checkpoint.

## Model and runtime selection

The recipe serves
`nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4`, the NVIDIA-published
NVFP4 checkpoint. It is configured for single-GPU DGX Spark use: tensor
parallelism of one, 128K context, eight sequences, and an FP8 KV cache.

The preferred vLLM-Omni runtime was manually attempted on the local GB10 host.
Its Docker image did not finish downloading in the available command window, so
no compatibility result was available. Per the requested fallback rule, the
recipe uses the latest upstream `vllm/vllm-openai:latest` image rather than an
untested Omni image.

## Serving behavior

The command uses NVIDIA's required remote-code, multimodal video, reasoning,
and tool-calling options. It also installs vLLM's audio extra before startup,
which is required when handling audio or video audio tracks. The recipe does
not enable local-media filesystem access; clients can use supported remote URLs
or data URLs unless the deployment intentionally adds a constrained media mount.

## Validation

Validate the YAML with `sparkrun recipe validate` and inspect its rendered
single-node launch with `sparkrun run --solo --dry-run`.
