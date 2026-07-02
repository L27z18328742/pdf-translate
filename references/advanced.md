# Advanced reference — pdf-translate

This file holds the details you only need sometimes. The main workflow is in `SKILL.md`.

## Table of contents
1. [Engines in depth](#engines-in-depth)
2. [Language codes](#language-codes)
3. [All translate.sh options](#all-translatesh-options)
4. [Tuning speed (qps / pool-max-workers)](#tuning-speed)
5. [Translating to other languages / other directions](#other-languages)
6. [Glossaries](#glossaries)
7. [Partial translation & scanned PDFs](#partial--scanned)
8. [Offline / air-gapped use](#offline)
9. [Config file alternative](#config-file)
10. [Troubleshooting](#troubleshooting)

---

## Engines in depth

`pdf2zh_next` supports many translation engines. This skill exposes three directly and you can reach the rest via passthrough flags.

### openai (default when a key exists)
Calls `/v1/chat/completions` on an OpenAI-compatible endpoint. The skill auto-fills:
- `--openai-base-url` — from `--base-url`, else `OPENAI_BASE_URL` env, else the active provider's `base_url` in `~/.codex/config.toml`.
- `--openai-api-key` — from `--api-key`, else `OPENAI_API_KEY` env.
- `--openai-model` — from `--model`, else the `model` field in `~/.codex/config.toml`, else `gpt-4o-mini`.

This is the recommended engine for full papers: it's a plain HTTP API so `--pool-max-workers` can run many segments in parallel.

If your gateway only speaks the OpenAI **Responses** API (the `wire_api = "responses"` in Codex config), chat-completions may still be available — the skill assumes it is. If requests fail with 404/400, the gateway likely doesn't expose `/chat/completions`; switch to `--engine siliconflowfree` or `--engine claudecode`.

Related engines you can pass through with `--`: `--deepseek` (preset base_url `https://api.deepseek.com/v1`), `--zhipu` (preset `https://open.bigmodel.cn/api/paas/v4`, model `glm-4-flash`), `--siliconflow` (public SiliconFlow with your own key), `--openaicompatible` (generic, same params as openai but under `--openai-compatible-*` flags). Example:

```bash
translate.sh paper.pdf -- --zhipu --zhipu-api-key "$ZHIPU_KEY" --zhipu-model glm-4-flash
```

### claudecode
Shells out to `claude -p --model <model> --input-format stream-json ...` once per text segment. Uses Claude Code's own model resolution, so `--claude-code-model sonnet` lands on whatever `ANTHROPIC_DEFAULT_SONNET_MODEL` points to. No API key needed beyond Claude Code's existing config. Slower (subprocess overhead per segment) — keep `--pool-max-workers` low (default 8). Best for short docs or when you specifically want Claude Code's model.

### siliconflowfree
The project's free service (GLM-4-9B). No key, no config. Fetches its own qps/pool limits from the server. Privacy: content is forwarded through the project maintainer's server to SiliconFlow.

---

## Language codes

Default direction is `en` → `zh-CN` (Simplified Chinese). Common codes:

| Language | Code |
|---|---|
| English | `en` |
| Simplified Chinese | `zh-CN` |
| Traditional Chinese | `zh-TW` |
| Japanese | `ja` |
| Korean | `ko` |
| French | `fr` |
| German | `de` |
| Spanish | `es` |
| Russian | `ru` |

Full list: https://pdf2zh-next.com/advanced/Language-Codes.html

Pass via `--lang-in` / `--lang-out`, e.g. `--lang-in ja --lang-out zh-CN`.

---

## All translate.sh options

| Option | Default | Notes |
|---|---|---|
| `<input.pdf>` | (required) | positional; spaces OK if quoted |
| `--output <dir>` | `<input_dir>/output` | where mono/dual PDFs land |
| `--engine` | auto | `openai` / `siliconflowfree` / `claudecode` |
| `--model <name>` | from codex config / `sonnet` | engine-dependent |
| `--base-url <url>` | from codex config | openai engine only |
| `--api-key <key>` | `OPENAI_API_KEY` | openai engine only |
| `--lang-in` | `en` | source language code |
| `--lang-out` | `zh-CN` | target language code |
| `--pages "1-5,8"` | all | partial translation |
| `--qps N` | 10 (openai) / 4 (claudecode) | rate limit |
| `--pool-max-workers N` | 30 (openai) / 8 (claudecode) | concurrency |
| `--no-dual` | off | skip bilingual PDF |
| `--no-mono` | off | skip monolingual PDF |
| `-- <flag> <value>` | — | pass any other `pdf2zh_next` flag through |

---

## Tuning speed

Translation throughput is governed by `--qps` (requests/sec cap) and `--pool-max-workers` (concurrent in-flight requests). For an OpenAI-compatible internal gateway with no published limit, `--qps 20 --pool-max-workers 50` is a reasonable step up from the defaults. If you see 429s or timeouts, back off.

The official guidance:
- RPM-limited service: `qps = floor(rpm/60)`, `pool = qps * 10`.
- Concurrency-limited service (e.g. some official APIs cap concurrent connections): `pool = max(floor(0.9 * limit), limit - 20)`, `qps = pool`.

Reasoning models are slow per-request; high concurrency with a reasoning model can saturate the gateway — prefer a lighter chat model (`--model`) and moderate concurrency.

---

## Other languages

Same script, different `--lang-in`/`--lang-out`. Examples:
- Japanese → Chinese: `--lang-in ja --lang-out zh-CN`
- Chinese → English: `--lang-in zh-CN --lang-out en`
- English → French: `--lang-in en --lang-out fr`

The skill's name and description emphasize English→Chinese because that's the primary use case, but the tool itself supports all listed languages.

---

## Glossaries

Provide a CSV with columns `source,target,tgt_lng` to lock in terminology (proper nouns, acronyms). Pass via passthrough:

```bash
translate.sh paper.pdf -- --glossaries "terms.csv"
```

Add `--save-auto-extracted-glossary` to dump the terms the tool auto-extracts, or `--no-auto-extract-glossary` to disable that step (faster).

---

## Partial / scanned

- **Partial**: `--pages "1-3,10,25-"` (25- means 25 to end).
- **Scanned PDFs**: the tool detects scanned docs. If it mis-detects, use `--skip-scanned-detection` or `--ocr-workaround` (forces black text on white background) via passthrough. `--auto-enable-ocr-workaround` lets it switch modes automatically.

---

## Offline

For air-gapped machines, pre-generate an assets bundle on an online machine and restore it offline:

```bash
# online machine
pdf2zh_next dummy.pdf --generate-offline-assets /path/to/bundle
# offline machine (copy bundle over)
translate.sh paper.pdf -- --restore-offline-assets /path/to/bundle
```

---

## Config file

`pdf2zh_next` can also read a TOML config (`--config-file`). The skill uses CLI flags for transparency, but for repeated custom setups you can write one and pass it through:

```bash
translate.sh paper.pdf -- --config-file ~/.config/pdf2zh/config.v3.toml
```

Priority (high → low): CLI/GUI args > environment variables (`PDF2ZH_*`) > user config file > default config file.

---

## Troubleshooting

- **`command not found: pdf2zh_next`** — run `setup.sh`; ensure `~/.local/bin` is on PATH.
- **First run is slow** — one-time download of DocLayout-YOLO + fonts. Cached afterward.
- **429 / rate limit** — lower `--qps` and `--pool-max-workers`.
- **openai engine 404/400** — gateway may not expose `/chat/completions`. Use `--engine siliconflowfree` or `--engine claudecode`.
- **claudecode engine: "Claude Code CLI not found"** — ensure `claude` is on PATH, or pass the full path: edit the command to use `--claude-code-path` (passthrough).
- **Translation quality** — try a stronger model via `--model`, or add a glossary. For Qwen-3-family models, `--custom-system-prompt "/no_think ..."` reduces reasoning noise.
- **Very large PDF** — `--pages` to chunk, or `--max-pages-per-part 50`.
- **Output files missing** — check the script's final `ls`; if translation failed mid-way, cached partial results live in the output dir and rerunning resumes (unless `--ignore-cache`).
