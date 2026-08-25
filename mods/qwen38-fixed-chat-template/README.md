# qwen38-fixed-chat-template

Ships froggeric's community-fixed Qwen chat template into the container so the
serve command can point `--chat-template` at it, instead of falling through to
the template baked into the checkpoint's `tokenizer_config.json`.

Source: [froggeric/Qwen-Fixed-Chat-Templates][repo], pinned to revision
`756cfb69d742355fd310b4ba9d50815a27d9d241` (v22.4, 2026-08-24). One file,
`chat_template.jinja`, covering Qwen 3.5, 3.6 and 3.8 at every size. Apache-2.0,
inherited from Qwen.

## Why a mod and not an edit

The template is a property of the checkpoint, and every Qwen3.8 checkpoint in
this registry — `RadixArk/Qwen3.8-27B-NVFP4`, `unsloth/Qwen3.8-27B-NVFP4`,
`Qwen/Qwen3.8-27B-FP8` — carries its own copy of the official one. Patching them
would mean writing into `~/.cache/huggingface`, which is a shared host mount:
the edit would outlive the container, leak into every other recipe reading the
same checkpoint, and be silently reverted by the next `huggingface-cli` pull. A
mod that drops one file into `/workspace/mods/` and hands the path to the engine
touches nothing outside the container's lifetime and is undone by removing the
`mods:` entry.

The file is vendored rather than fetched at launch. A `curl` in `run.sh` would
make every boot depend on the Hub being up and would silently pick up whatever
the `main` branch happens to say that day — for a file that decides how every
prompt is rendered, that is the wrong trade. `run.sh` checks the vendored copy
against a pinned sha256 and refuses to run on a mismatch.

## What it fixes

The upstream README lists the full set; these are the ones that matter for how
this registry's recipes are actually driven.

- **`xhigh` reasoning by default.** The official Qwen3.8 template hardcodes
  `reasoning_effort` at `xhigh`, which spends a large share of the token budget
  thinking before any content is emitted, and on a capped `max_tokens` can
  return an empty completion. This template defaults to `medium`, which injects
  no instruction text at all. **This is a behavioural change, not just a bug
  fix** — pass `chat_template_kwargs: {"reasoning_effort": "xhigh"}` per request
  to get the old depth back.
- **Blank `<think></think>` poisoning in history.** The official 3.8 template
  drops in-content thinking extraction, so real prior thoughts get a duplicate
  empty think block prepended. This one extracts reasoning from OpenAI
  (`reasoning_content`), Anthropic (`thinking`) and in-content `<think>` tags
  without duplicating the tag.
- **Stringified tool arguments.** Standard OpenAI clients send `arguments` as a
  serialized JSON string; the official template crashes on it. Handled here for
  mappings, JSON strings and scalars alike.
- **Prefix cache stability.** Past turns are rendered chronologically and
  unmutated, so the rendered prefix matches what was cached. Relevant to every
  recipe here, which all run with prefix caching on.
- **Agentic stalls.** Two-tier tool-error escalation, and the `<IMPORTANT>`
  directives rewritten so the model does not abort a turn when it wants to emit
  both conversational text and a tool call.

Reasoning effort can also be steered inline with `<|think_low|>`,
`<|think_medium|>`, `<|think_xhigh|>`, `<|think_ultracode|>` and `<|think_off|>`
in the message text; the tags are sticky and stripped before inference. The
`<|think_off|>` tag is a template-internal state, so vLLM's and SGLang's
reasoning parsers do not see it — to actually disable reasoning end to end,
send `enable_thinking: false` or `reasoning_effort: "none"` as request
parameters rather than relying on the inline tag.

## Tool format

The template keeps Qwen's canonical **XML** tool format (`<function=name>` with
`<parameter=...>` blocks) as its default, which is what the model was trained
on. That means the parsers already set in the recipes are correct as they stand
and need no change: `--tool-call-parser qwen3_xml` on the vLLM recipe,
`--tool-call-parser qwen3_coder` on the SGLang one. Only if you opt into
`tool_call_format: "json"` via template kwargs would you need `hermes` instead.

## The `.jinja` extension is load-bearing

Do not rename `chat_template.jinja`. SGLang's `TemplateManager` takes the Jinja
branch only when the path ends in `.jinja`, and parses anything else as its own
JSON conversation format — a rename produces a confusing JSON decode error at
startup rather than a missing-template one. `run.sh` asserts the extension for
that reason. vLLM does not care about the extension.

## Exit ramp

Delete this mod when Qwen ships an official template with these fixes and the
checkpoints you serve have picked it up. There is no in-container signal to
detect that, unlike `mods/dflash2-vllm` — the checkpoint's own template is not
versioned — so the check is manual: diff the checkpoint's
`tokenizer_config.json` chat template against this file, or watch the upstream
repo for a note that a fix has landed upstream.

## Verifying it is live

The engine logs the load at startup. SGLang prints
`Loading chat template from argument: /workspace/mods/...`; vLLM logs the
resolved chat template source. For an end-to-end check, send a request with
`chat_template_kwargs: {"reasoning_effort": "xhigh"}` — the fixed template
injects Qwen's deep-reasoning instruction only on that value, whereas the
official template applies it unconditionally, so a visible difference in
behaviour between `medium` and `xhigh` means the override took.

[repo]: https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates
