#!/bin/bash
set -euo pipefail

PYTHON_ROOT="${PYTHON_ROOT:-/usr/local/lib/python3.12/dist-packages}"
MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$MOD_DIR/dflash2-vllm.patch"
LMHEAD_PATCH="$MOD_DIR/dflash2-modelopt-lmhead.patch"
PREFIX="[dflash2-vllm]"

if [ ! -d "$PYTHON_ROOT/vllm" ]; then
  echo "$PREFIX vLLM package not found at $PYTHON_ROOT/vllm" >&2
  exit 1
fi

cd "$PYTHON_ROOT"

# Once PR #52816 merges and lands in the image, qwen3_dflash2.py ships with
# vLLM and this mod must not touch anything. Bail out first, before the
# git-apply checks, so a future image is never downgraded by a stale patch.
SHIPPED="$PYTHON_ROOT/vllm/model_executor/models/qwen3_dflash2.py"
if [ -f "$SHIPPED" ]; then
  echo "$PREFIX vLLM already ships qwen3_dflash2.py; skipping the PR patch."
  # The lm_head guard broadening is a LOCAL delta, not part of #52816, so a
  # merged upstream may still carry the narrow isinstance check. Re-apply just
  # that hunk, or ModelOpt NVFP4 targets break again on the first post-merge
  # image with no obvious cause.
  if grep -q "UnquantizedLinearMethod" "$SHIPPED"; then
    echo "$PREFIX Shipped copy already accepts UnquantizedLinearMethod; nothing to do."
    echo "$PREFIX Drop this mod from the recipe once that is true on every image you run."
  elif command -v git >/dev/null 2>&1 && git apply --check "$LMHEAD_PATCH" 2>/dev/null; then
    git apply "$LMHEAD_PATCH"
    echo "$PREFIX Re-applied the lm_head guard broadening to the shipped copy."
    echo "$PREFIX Only that hunk is still needed; the PR itself has landed."
  else
    echo "$PREFIX WARNING: shipped qwen3_dflash2.py still has the narrow lm_head" >&2
    echo "$PREFIX guard and the broadening patch no longer applies. ModelOpt NVFP4" >&2
    echo "$PREFIX targets will fail at engine init; FP8 targets are unaffected." >&2
    echo "$PREFIX Re-cut dflash2-modelopt-lmhead.patch against the shipped file." >&2
  fi
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "$PREFIX git is required to apply this mod." >&2
  exit 1
fi

if git apply --check "$PATCH_FILE" 2>/dev/null; then
  git apply "$PATCH_FILE"
  echo "$PREFIX Applied DFlash2 speculator (vllm-project/vllm#52816)."
else
  echo "$PREFIX Patch does not apply to the installed vLLM." >&2
  echo "$PREFIX Pinned to PR head 19c93519, which applied cleanly to" >&2
  echo "$PREFIX vllm 0.27.2rc1.dev209+gf9f066d19 in eugr/spark-vllm:latest." >&2
  echo "$PREFIX The image has almost certainly drifted; re-cut the patch from" >&2
  echo "$PREFIX https://github.com/vllm-project/vllm/pull/52816 (runtime files only)." >&2
  exit 1
fi

# Local delta on top of the PR, not part of #52816. The PR guards the candidate
# TopK with isinstance(lm_head.quant_method, UnquantizedEmbeddingMethod), but a
# ModelOpt checkpoint that *excludes* lm_head hands it an UnquantizedLinearMethod
# instead. The two are sibling classes with the same apply() signature and both
# do a plain unquantized matmul, so the narrow check rejects targets that in fact
# satisfy the requirement. Without this, Inferact/Qwen3.8-27B-NVFP4 dies at engine
# init with "DFlash2 requires an unquantized target LM head for candidate TopK."
if git apply --check "$LMHEAD_PATCH" 2>/dev/null; then
  git apply "$LMHEAD_PATCH"
  echo "$PREFIX Broadened the target lm_head check to accept UnquantizedLinearMethod."
else
  echo "$PREFIX lm_head guard patch did not apply; ModelOpt NVFP4 targets will be" >&2
  echo "$PREFIX rejected at engine init. FP8 targets are unaffected." >&2
  exit 1
fi

python3 - <<'PY'
from vllm.model_executor.models.registry import ModelRegistry
archs = ModelRegistry.get_supported_archs()
assert "DFlash2DraftModel" in archs, "DFlash2DraftModel did not register"
print("[dflash2-vllm] DFlash2DraftModel registered.")
PY

echo "=====> DFlash2 drafting enabled; use --speculative-config method \"dflash\" with a DFlash2DraftModel checkpoint."
