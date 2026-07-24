# Charitarth Sparkrun Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Git-backed personal Sparkrun registry named `charitarth`, ready to hold creator-organized recipes.

**Architecture:** A `.sparkrun/registry.yaml` manifest exposes the top-level recipe, tuning, benchmark, and mod directories. Creator-specific subdirectories organize recipe YAML without affecting Sparkrun's recursive discovery. README documents publishing, registering, and validating recipes.

**Tech Stack:** Git, YAML, Markdown, Sparkrun CLI.

## Global Constraints

- Use `charitarth` as the enabled, visible registry name.
- Put recipes beneath `recipes/<creator>/` using lowercase creator identifiers.
- Keep runtime variants distinct in filenames, e.g. `qwen3-32b-vllm.yaml`.
- Do not include credentials, tokens, caches, or a Git remote.
- Include framework directories for tuning, benchmarking, and mods without recipe content.

---

## File Structure

- `.sparkrun/registry.yaml`: Sparkrun registry manifest.
- `recipes/{deepseek,google,meta,mistral,qwen}/.gitkeep`: Creator-specific empty recipe directories.
- `tuning/.gitkeep`, `benchmarking/.gitkeep`, `mods/.gitkeep`: Empty optional registry directories.
- `.gitignore`: Excludes local secrets, caches, and editor artifacts.
- `README.md`: Registry usage and contribution guide.

### Task 1: Scaffold the registry contract

**Files:**

- Create: `.sparkrun/registry.yaml`
- Create: `recipes/deepseek/.gitkeep`
- Create: `recipes/google/.gitkeep`
- Create: `recipes/meta/.gitkeep`
- Create: `recipes/mistral/.gitkeep`
- Create: `recipes/qwen/.gitkeep`
- Create: `tuning/.gitkeep`
- Create: `benchmarking/.gitkeep`
- Create: `mods/.gitkeep`

**Interfaces:**

- Consumes: Sparkrun repository manifest format.
- Produces: Registry `@charitarth` with recipe root `recipes` and optional content roots.

- [ ] **Step 1: Add the manifest**

```yaml
registries:
  - name: charitarth
    description: Charitarth's personal Sparkrun recipes
    recipes: recipes
    tuning: tuning
    benchmarks: benchmarking
    mods: mods
    enabled: true
    visible: true
```

- [ ] **Step 2: Add the tracked empty directories**

Run: `mkdir -p recipes/{deepseek,google,meta,mistral,qwen} tuning benchmarking mods && touch recipes/{deepseek,google,meta,mistral,qwen}/.gitkeep tuning/.gitkeep benchmarking/.gitkeep mods/.gitkeep`

Expected: Each declared manifest path exists and each creator directory is present in Git.

- [ ] **Step 3: Validate manifest structure**

Run: `ruby -e 'require "yaml"; data = YAML.load_file(".sparkrun/registry.yaml"); abort "bad manifest" unless data.dig("registries", 0, "name") == "charitarth"; puts "manifest valid"'`

Expected: `manifest valid`.

- [ ] **Step 4: Commit**

```bash
git add .sparkrun recipes tuning benchmarking mods
git commit -m "feat: scaffold charitarth registry"
```

### Task 2: Document safe use and repository hygiene

**Files:**

- Create: `.gitignore`
- Create: `README.md`

**Interfaces:**

- Consumes: Registry name and directory paths from Task 1.
- Produces: Clear instructions to publish, add, validate, and dry-run personal recipes.

- [ ] **Step 1: Add `.gitignore`**

```gitignore
.env
.env.*
!.env.example
*.pem
*.key
.sparkrun-local/
.cache/
.vscode/
.idea/
```

- [ ] **Step 2: Write the README**

Include these exact commands, replacing `<repository-url>` after the user publishes:

```bash
sparkrun registry add <repository-url>
sparkrun registry list
sparkrun recipe validate recipes/qwen/qwen3-32b-vllm.yaml
sparkrun run recipes/qwen/qwen3-32b-vllm.yaml --solo --dry-run
```

Explain the creator-first layout, runtime-specific filenames, optional content directories, recursive discovery, and that recipe files must not include secrets.

- [ ] **Step 3: Review static repository contract**

Run: `test -f README.md && test -f .gitignore && test -f .sparkrun/registry.yaml && test -d recipes/qwen && test -d tuning && test -d benchmarking && test -d mods && git check-ignore -q .env && git check-ignore -q .cache/example && echo "registry scaffold verified"`

Expected: `registry scaffold verified`.

- [ ] **Step 4: Commit**

```bash
git add README.md .gitignore
git commit -m "docs: document registry workflow"
```

### Task 3: Verify the completed repository

**Files:**

- Verify: `.sparkrun/registry.yaml`
- Verify: `README.md`

**Interfaces:**

- Consumes: Completed repository scaffold and documentation.
- Produces: Evidence that the initial local Git source is clean and ready for a remote.

- [ ] **Step 1: Inspect the working tree**

Run: `git status --short`

Expected: No files created by these tasks are uncommitted. Preserve unrelated pre-existing files.

- [ ] **Step 2: Inspect commits**

Run: `git log --oneline -3`

Expected: Includes `feat: scaffold charitarth registry` and `docs: document registry workflow`.

- [ ] **Step 3: Check local usage prerequisites**

Run: `command -v sparkrun || true`

Expected: If installed, print the executable path; otherwise the repository remains valid and can be registered after Sparkrun is installed and a remote is published.
