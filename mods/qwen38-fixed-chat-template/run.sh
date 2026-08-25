#!/bin/bash
set -euo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$MOD_DIR/chat_template.jinja"
PREFIX="[qwen38-fixed-chat-template]"

# Pinned to froggeric/Qwen-Fixed-Chat-Templates @ 756cfb69d742355fd310b4ba9d50815a27d9d241
# (v22.4, 2026-08-24). The file is vendored, not fetched, so a launch never
# depends on the Hub being reachable and never silently picks up a new version.
EXPECTED_SHA=c47c82b0544752d454f4e427228d9d9d8c3df64c9e446cbd0229362f67948009

if [ ! -f "$TEMPLATE" ]; then
  echo "$PREFIX chat_template.jinja is missing from $MOD_DIR" >&2
  exit 1
fi

# The extension matters and is not cosmetic: SGLang's template_manager only
# takes the jinja branch when the path ends in .jinja, and parses anything else
# as its own JSON conversation format. Renaming this file breaks SGLang loudly.
case "$TEMPLATE" in
  *.jinja) ;;
  *) echo "$PREFIX template must keep its .jinja extension for SGLang" >&2; exit 1 ;;
esac

ACTUAL_SHA=$(sha256sum "$TEMPLATE" | cut -d' ' -f1)
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "$PREFIX checksum mismatch on chat_template.jinja." >&2
  echo "$PREFIX expected $EXPECTED_SHA" >&2
  echo "$PREFIX got      $ACTUAL_SHA" >&2
  echo "$PREFIX If you deliberately updated the template, update EXPECTED_SHA" >&2
  echo "$PREFIX and the pinned revision in run.sh and README.md together." >&2
  exit 1
fi

# Compile-only check. Catches a corrupted copy before the engine spends several
# minutes booting and then fails on the first chat request instead of at launch.
python3 - "$TEMPLATE" <<'PY'
import sys

path = sys.argv[1]
try:
    from jinja2 import Environment
except ImportError:
    print("[qwen38-fixed-chat-template] jinja2 not importable; skipping compile check.")
    sys.exit(0)

with open(path, encoding="utf-8") as fh:
    source = fh.read()

Environment().parse(source)
marker = 'qwen3.8-froggeric-v22.4'
assert marker in source, "template_version marker %r not found" % marker
print("[qwen38-fixed-chat-template] Template parses and reports %s." % marker)
PY

echo "$PREFIX Ready at $TEMPLATE"
echo "=====> Pass --chat-template $TEMPLATE to the serve command to use it."
