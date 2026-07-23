# Charitarth's Sparkrun Registry

This repository is a personal Sparkrun registry. Publish it somewhere Git can
reach, then replace `<repository-url>` below with that repository URL.

```bash
sparkrun registry add <repository-url>
sparkrun registry list
sparkrun recipe validate recipes/qwen/qwen3-32b-vllm.yaml
sparkrun run recipes/qwen/qwen3-32b-vllm.yaml --solo --dry-run
```

## Layout

The registry uses a creator-first recipe layout: recipes are organized by
creator under `recipes/` (for example, `recipes/qwen/`). Use runtime-specific
filenames so a recipe's intended engine is clear, such as
`qwen3-32b-vllm.yaml`.

`tuning/`, `benchmarking/`, and `mods/` are optional content directories for
tuning configurations, benchmarks, and modifications. Sparkrun discovers
supported content recursively, so nested directories can be used to keep a
creator's or runtime's recipes organized.

## Safe use

Validate every recipe before running it, and use `--solo --dry-run` to inspect
a personal recipe without starting a workload. Recipe files must not include
secrets. Keep credentials and local configuration in ignored files such as
`.env` or `.sparkrun-local/`.
