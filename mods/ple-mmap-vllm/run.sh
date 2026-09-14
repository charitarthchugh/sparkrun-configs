#!/bin/bash
set -euo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$MOD_DIR/vllm_ple_mmap.py"
PREFIX="[ple-mmap-vllm]"
MARKER="qwen38-flash-dgx: serve the PLE n-gram table from disk"

# Pinned to blazux/qwen3.8-Flash-DGX @ d2854bfff0a0b6f46984b0941ed1db6010031295
# (2026-08-27), src/vllm_ple_mmap.py, Apache-2.0. The file is vendored verbatim
# and byte-for-byte identical to upstream — this mod carries no local delta, so
# a checksum mismatch means the copy was edited, not that upstream moved.
EXPECTED_SHA=2bca73dd0f77e72937cdfc43312c3fc4d217847d4bb126cf3665bd8caa3108c8

if [ ! -f "$SOURCE" ]; then
  echo "$PREFIX vllm_ple_mmap.py is missing from $MOD_DIR" >&2
  exit 1
fi

ACTUAL_SHA=$(sha256sum "$SOURCE" | cut -d' ' -f1)
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "$PREFIX checksum mismatch on vllm_ple_mmap.py." >&2
  echo "$PREFIX expected $EXPECTED_SHA" >&2
  echo "$PREFIX got      $ACTUAL_SHA" >&2
  echo "$PREFIX If you deliberately re-vendored from upstream, update" >&2
  echo "$PREFIX EXPECTED_SHA and the pinned revision in run.sh and README.md" >&2
  echo "$PREFIX together." >&2
  exit 1
fi

# The upstream Dockerfile hardcodes python3.12/dist-packages. Discover instead,
# so a rebuilt Flash-Next image on a different interpreter still works and a
# genuinely missing vLLM fails with a clear message rather than a stale path.
PYTHON_ROOT="${PYTHON_ROOT:-}"
if [ -z "$PYTHON_ROOT" ]; then
  PYTHON_ROOT=$(python3 -c 'import os, vllm; print(os.path.dirname(os.path.dirname(vllm.__file__)))' 2>/dev/null || true)
fi
if [ -z "$PYTHON_ROOT" ] || [ ! -d "$PYTHON_ROOT/vllm" ]; then
  echo "$PREFIX vLLM package not found (PYTHON_ROOT=${PYTHON_ROOT:-unset})" >&2
  exit 1
fi

# The PLE layer only exists in the Flash-Next build of vLLM. Its absence means
# the recipe is pointed at the wrong image, which is worth failing loudly for:
# without the hook the engine would try to materialise the 44 GiB table and die
# on OOM ten minutes into loading, with nothing pointing back at this mod.
PLE="$PYTHON_ROOT/vllm/models/qwen3_8_flash_next/nvidia/ple_layer.py"
if [ ! -f "$PLE" ]; then
  FOUND=$(find "$PYTHON_ROOT/vllm" -path '*qwen3_8_flash_next*' -name ple_layer.py -print -quit 2>/dev/null || true)
  if [ -n "$FOUND" ]; then
    PLE="$FOUND"
    echo "$PREFIX ple_layer.py is at $PLE, not the path the upstream Dockerfile assumes."
  else
    echo "$PREFIX ple_layer.py not found under $PYTHON_ROOT/vllm." >&2
    echo "$PREFIX This mod only applies to the Qwen3.8-Flash-Next build of vLLM" >&2
    echo "$PREFIX (vllm/vllm-openai:qwen38-flash-next). Check the recipe's container." >&2
    exit 1
  fi
fi

cp "$SOURCE" "$PYTHON_ROOT/vllm_ple_mmap.py"

# Idempotent: containers are fresh per launch, but a re-run against a live
# container must not append the hook twice.
if grep -qF "$MARKER" "$PLE"; then
  echo "$PREFIX Hook already present in $PLE; nothing to append."
else
  cp "$PLE" "$PLE.orig"
  cat >> "$PLE" <<'PY'


# --- qwen38-flash-dgx: serve the PLE n-gram table from disk (VLLM_PLE_MMAP=1) ---
from vllm_ple_mmap import apply as _ple_mmap_apply
_ple_mmap_apply(Qwen3_8FlashNextNGramEmbedding)
PY
  echo "$PREFIX Appended the mmap hook to $PLE."
fi

# Syntax-check before the engine spends ~8 minutes loading weights and then
# fails on an import. Also confirms the module itself imports cleanly.
python3 - "$PLE" <<'PY'
import ast
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    ast.parse(fh.read())
print("[ple-mmap-vllm] %s parses OK." % path)

import vllm_ple_mmap

assert hasattr(vllm_ple_mmap, "apply"), "vllm_ple_mmap.apply is missing"
print("[ple-mmap-vllm] vllm_ple_mmap imports, enabled=%s" % vllm_ple_mmap.enabled())
PY

echo "=====> PLE table will be served from disk. Requires VLLM_PLE_MMAP=1, a local"
echo "=====> snapshot path as the model argument, and -cc.cudagraph_mode=PIECEWISE"
echo "=====> with vllm::ple_mmap_lookup in -cc.splitting_ops."
