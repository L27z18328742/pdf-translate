---
name: pdf-translate
description: Translate English PDF documents (especially academic papers) into Chinese using PDFMathTranslate-next (pdf2zh), producing a monolingual Chinese PDF and a bilingual side-by-side PDF with formulas, figures, and layout preserved. Automatically installs the pdf2zh_next environment via uv and reuses the model/API the user already configured in Codex or Claude Code (any OpenAI-compatible gateway), falling back to the free SiliconFlow service when no key is present. Use this skill whenever the user wants to translate a PDF to Chinese (or another language), translate a paper/论文, produce a bilingual PDF, or mentions pdf2zh / PDFMathTranslate — even if they don't name the tool explicitly. Proactively invoke this skill (do not translate manually) whenever a PDF translation task appears.
---

# PDF Translate (English → Chinese)

This skill translates PDF documents using **PDFMathTranslate-next** (`pdf2zh_next`), the BabelDOC-based translator that preserves formulas, charts, table of contents, and page layout. It produces two files per input:

- `*-mono.pdf` — monolingual translated PDF (Chinese only)
- `*-dual.pdf` — bilingual PDF (original + translation, side by side or alternating)

## Why this skill exists

Translating an academic PDF well requires preserving math, figures, and layout — something plain LLM translation can't do. `pdf2zh_next` handles that, but it has a non-trivial install (Python 3.12, model assets) and many engine options. This skill automates the environment setup and picks a translation engine that reuses credentials the user already has, so translation "just works" without manual configuration.

## Workflow

Run the setup script first (installs `pdf2zh_next` if missing, verifies it), then the translate script (detects the best engine and runs the translation). Both scripts are idempotent.

### Step 1 — Ensure the environment is ready

```bash
bash ~/.claude/skills/pdf-translate/scripts/setup.sh
```

This installs `pdf2zh_next` via `uv tool install --python 3.12 pdf2zh-next` (the project requires Python ≥3.10,<3.14; 3.12 is the documented recommendation) and confirms it is on PATH. It is fast and safe to re-run. The first real translation will download layout/translation model assets (DocLayout-YOLO + fonts, ~hundreds of MB) — tell the user the first run is slow because of this one-time download.

### Step 2 — Translate

```bash
bash ~/.claude/skills/pdf-translate/scripts/translate.sh "<input.pdf>" [options]
```

The script auto-detects a translation engine:

1. **OpenAI-compatible (default when a key exists)** — reuses the model the user configured for Codex. It reads `base_url` + `model` from `~/.codex/config.toml` (the active `model_provider`'s `base_url` and the top-level `model`) and the API key from `OPENAI_API_KEY`. The OpenAI engine calls `/v1/chat/completions` on that gateway — fast, high-concurrency, ideal for full papers. Verified to work with OpenAI-compatible gateways (including Codex-style internal gateways that expose chat-completions alongside the responses API).
2. **SiliconFlowFree (zero-config fallback)** — used when no API key is detectable. The project's free GLM-4-9B service; needs no key. Note: file content is forwarded through the project maintainer's server.
3. **ClaudeCode (explicit option)** — `--engine claudecode` shells out to the `claude` CLI (`claude -p --model sonnet ...`), so it uses the exact model Claude Code is configured to use (resolved via `ANTHROPIC_DEFAULT_SONNET_MODEL`, etc.). This is the most literal "use my Claude Code model" path, but it spawns one `claude -p` subprocess per text segment, so it is much slower than the OpenAI engine — prefer it for short documents or when you specifically want Claude Code's model.

Override detection with flags: `--engine openai|siliconflowfree|claudecode`, `--model <name>`, `--base-url <url>`, `--api-key <key>`.

Common options:
- `--output <dir>` — output directory (default: an `output/` folder next to the input PDF)
- `--pages "1-5,8"` — translate only some pages
- `--lang-in en --lang-out zh-CN` — language codes (defaults: en → zh-CN)
- `--qps N --pool-max-workers N` — concurrency tuning (see `references/advanced.md`)
- `--no-dual` / `--no-mono` — suppress one of the two outputs
- Pass any other `pdf2zh_next` flag through with `-- <flag> <value>`

### Step 3 — Report results

After the script finishes, it prints the paths of the generated `*-mono.pdf` and `*-dual.pdf`. Tell the user where these files are (relative to the input), open/preview them if asked, and note the engine + model that was used. If the user wants different quality or speed, suggest overrides (see `references/advanced.md`).

## Default behavior choices (and how to change them)

- **Source/target language**: English → Simplified Chinese (`en` → `zh-CN`). Override with `--lang-in` / `--lang-out`. Full language code list is in `references/advanced.md`.
- **Engine**: OpenAI-compatible when a key is found, else SiliconFlowFree. Use `--engine claudecode` to drive the Claude Code CLI instead. The OpenAI engine reuses the model named in `~/.codex/config.toml`; the claudecode engine reuses Claude Code's configured model.
- **Model**: for the openai engine, the model from `~/.codex/config.toml`; for claudecode, `sonnet` (resolved by Claude Code to the user's configured model). Reasoning models (e.g. `gpt-5.5`, `glm-5.2`) work but are slower and use more tokens; for large papers consider a lighter chat model via `--model`.
- **Concurrency**: modest defaults (`--qps 10 --pool-max-workers 30` for the OpenAI engine; `--qps 4 --pool-max-workers 8` for claudecode since each segment is a subprocess). Increase for faster translation if the gateway allows it.

## When something goes wrong

- **`command not found: pdf2zh_next`** after install — the uv tool bin dir isn't on PATH. The scripts add `~/.local/bin` to PATH themselves, but if the user runs `pdf2zh_next` directly in their own shell, they need `export PATH="$HOME/.local/bin:$PATH"` (Linux/macOS).
- **First translation hangs on "loading assets" / downloading** — normal one-time model download. Wait it out.
- **429 / rate-limit errors** — lower `--qps` and `--pool-max-workers`.
- **Gateway returns errors for the OpenAI engine** — the detected base_url may only expose the responses API, not chat-completions. Run with `--engine siliconflowfree` to bypass, or point `--base-url` at a chat-completions endpoint.
- **Out-of-memory / very large PDFs** — use `--pages` to translate in chunks, or `--max-pages-per-part 50`.

For the full option reference, engine configuration details, translating to other languages, glossaries, and offline/air-gapped usage, read `references/advanced.md`.
