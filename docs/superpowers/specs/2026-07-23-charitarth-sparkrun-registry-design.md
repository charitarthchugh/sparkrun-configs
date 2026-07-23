# Charitarth Sparkrun Registry Design

## Purpose

Create a personal Git-backed Sparkrun recipe registry that can be added with
`sparkrun registry add <repository-url>` and referenced as `@charitarth/<recipe>`.

## Repository layout

```text
.
├── .sparkrun/
│   └── registry.yaml
├── recipes/
│   ├── deepseek/
│   ├── google/
│   ├── meta/
│   ├── mistral/
│   └── qwen/
├── tuning/
├── benchmarking/
├── mods/
├── README.md
└── .gitignore
```

`recipes/` is the registry root. Recipe YAML files are grouped by model creator.
Creator directories use lowercase, stable identifiers. Individual recipe filenames
identify the model and runtime when more than one runtime is supported, for example
`qwen3-32b-vllm.yaml` and `qwen3-32b-sglang.yaml`.

## Registry manifest

`.sparkrun/registry.yaml` declares one enabled, visible registry named
`charitarth`, with `recipes`, `tuning`, `benchmarking`, and `mods` mapped to the
corresponding top-level directories. It uses Sparkrun's supported short manifest
keys, making all optional content sparse-checkout eligible.

## Documentation and workflow

The README will explain the directory layout, adding the published repository,
running a recipe, and validating and dry-running new YAML recipes. It will avoid
committing credentials, tokens, local cache directories, and editor files.

New recipes should be validated with `sparkrun recipe validate <path>` and checked
with `sparkrun run <path> --solo --dry-run` before being relied on.

## Scope and non-goals

This initial setup creates the registry framework and documentation only. It does
not include a sample recipe, configure a Git remote, publish the repository, or
change the user's local Sparkrun registry configuration.
