# dflash2-vllm

Applies [vllm-project/vllm#52816][pr] — the DFlash2 speculator — to the vLLM
installed in the container, so a `DFlash2DraftModel` checkpoint can draft for a
Qwen3.8-27B target. The PR was still open when this mod was written
(2026-08-19); delete the mod once it merges and reaches the image.

## Why a mod and not a newer container

There is no image that can run DFlash2 today. The vLLM PR is open, and SGLang's
`DFlash2DraftModel` landed in main only at 2026-08-19T00:07Z — after
`scitrera/dgx-spark-sglang:0.5.17` (built 2026-08-16 from the v0.5.17 tag, which
carries DFlash **v1** only) and after the 2026-08-18 `lmsysorg/sglang` arm64
nightly. The stock arm64 nightlies also target GH200/GB200 rather than sm_121a,
which is why a DGX Spark SGLang image is built separately in the first place.

The PR is pure Python — 7 runtime files, 3 of them new — so overlaying it onto
the vLLM already in `eugr/spark-vllm:latest` is cheaper and more honest than
waiting for a rebuild.

## What it does

Two `git apply -p1` passes from the dist-packages root. The first is the PR
itself, pinned to PR head
`19c9351904df4c63042671bc67a866ca48dc7d6f` (the PR is a single commit). Only the
runtime files are carried; the four test files in the PR are stripped. The patch
applied at zero fuzz to `vllm 0.27.2rc1.dev209+gf9f066d19` in
`eugr/spark-vllm:latest`, and `DFlash2DraftModel` then appears in
`ModelRegistry.get_supported_archs()` — the mod asserts that before returning, so
a silent no-op fails the launch instead of quietly degrading the draft.

Three of the four touched existing files take small additive hunks;
`qwen3_dflash.py` is the drift-sensitive one, since the PR refactors it to
subclass-friendly `model_cls` / `decoder_layer_cls` hooks that DFlash2 overrides.

## Idempotence and the exit ramp

The first check is whether `vllm/model_executor/models/qwen3_dflash2.py` already
exists. If it does — because the PR merged and the image picked it up — the mod
skips the PR patch entirely, so a future image is never downgraded by a stale
copy. That check runs before the git-apply checks, so it also covers a re-run
against an already-patched container.

There is one wrinkle in that exit ramp. The lm_head guard broadening is a local
delta, so a merged upstream may still carry the narrow check. In the
already-ships branch the mod therefore greps the shipped file for
`UnquantizedLinearMethod` and, if it is missing, re-applies *only*
`dflash2-modelopt-lmhead.patch`. Without that, ModelOpt NVFP4 targets would break
again on the first post-merge image with nothing pointing at the cause. When the
grep finds it, the mod is genuinely finished and should be dropped from the
recipes.

## Method string

DFlash2 is **not** a new speculative method. It stays `"method": "dflash"`; vLLM
selects the v2 speculator by reading `DFlash2DraftModel` out of the draft
checkpoint's `architectures`. The PR also forces the V2 model runner for these
checkpoints, because on V1 the same weights would draft through `DFlashProposer`,
which never calls the candidate selector — the draft would silently degrade to
DFlash1 rather than fail.

## Target constraint

`qwen3_dflash2.py` raises `DFlash2 requires an unquantized target LM head for
candidate TopK` unless the *target* model's `lm_head` is unquantized. That rules
out `unsloth/Qwen3.8-27B-NVFP4`, whose `config_groups` include `re:.*lm_head` at
FP8 W8A8. `Qwen/Qwen3.8-27B-FP8` leaves `lm_head` out of quantization and
passes the check as the PR writes it.

`Inferact/Qwen3.8-27B-NVFP4` also leaves `lm_head` unquantized but still failed,
which is why this mod carries a second patch. vLLM's ModelOpt path returns
`UnquantizedLinearMethod` for an excluded `lm_head`, while the PR's guard accepts
only `UnquantizedEmbeddingMethod`. The two are sibling classes — neither inherits
from the other — with identical `apply(layer, x, bias)` signatures, both doing a
plain unquantized matmul, so the narrow check rejects targets that satisfy the
actual requirement. `dflash2-modelopt-lmhead.patch` broadens the isinstance to
accept either. It is a **local delta, not part of PR #52816**, and is worth
reporting upstream. The FP8 path never hits it, because the fp8 quant config
returns `UnquantizedEmbeddingMethod` for the same exclusion.

[pr]: https://github.com/vllm-project/vllm/pull/52816
