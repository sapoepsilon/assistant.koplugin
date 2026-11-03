# Inference reader

A KOReader + assistant.koplugin setup for reading LLM-inference research papers on a
Pixel 9 Pro Fold (KOReader v2026.07.1, `org.koreader.launcher`, data dir `/sdcard/koreader`).
It lives on the `inference-reader` branch of this fork, on top of upstream
[omer-faruq/assistant.koplugin](https://github.com/omer-faruq/assistant.koplugin) at `9703af3`.

The plugin itself is changed in exactly two places so upstream merges stay easy:

- `feature/inference_reader.lua` (new): `ai_explain_page` and `ai_cycle_provider` actions.
- `main.lua`: one `require`, action registration, two event handlers.

Everything else (KOReader patch, prompts, settings, library, tools) is in this directory.

## Features

- **One-tap AI buttons** in the highlight popup: Explain | Simplify / Why it matters |
  Define terms / Ask AI... AI buttons are bold, the popup sits next to the selection, a
  single-word long-press opens it too, and it closes after an AI button fires. Wikipedia,
  Dictionary, Translate, View HTML and User dictionary are removed from the popup.
- **Prompts** written for a software engineer learning inference: plain words first, jargon
  defined inline, links to KV cache / prefill vs decode / vLLM / SGLang / FlashAttention /
  speculative decoding / MoE-MLA only when relevant, plain-text maths. `explain_page` gives
  TL;DR, key ideas, inference angle and a check-yourself question. All prompts send title,
  authors, position and +-1 page of paper text. Built-ins that don't help with papers (eli5,
  grammar, translate, vocabulary, historical_context, wikipedia) are hidden. The plugin's
  OTA updater is disabled so it can't overwrite the local edits.
- **Quick menu** (reader): tap the top-left corner (or two-finger tap there). Five groups:
  - AI: explain this page, ask a question, switch provider.
  - Zoom: Zoom in, Zoom out, Fit width (scroll), Fit page, One column at a time.
  - Find your way: Contents, Go to page, Search in document, Bookmark this page (on/off),
    Bookmarks & highlights (KOReader's annotation list: bookmarks, highlights and notes).
  - Display: night mode, figure colours, Brightness, More reader settings
    (KOReader's bottom bar: zoom/contrast/margins for PDF, font/size/spacing for EPUB).
    No rotation item: KOReader has no G-sensor access on Android (so no in-app rotation
    lock) and the inner screen ignores app orientation requests, so rotation is Android's
    own auto-rotate / rotation lock in quick settings.
  - Papers: previous / next paper, library.
- **Zoom**: spread two fingers = Zoom in, pinch = Zoom out (stock KOReader binds these to font
  size, which does nothing in a PDF). In a PDF the ladder is fit page -> fit width
  (continuous scroll) -> magnified x1.25 per step (up to 600%, a wider spread jumps further).
  Magnified switches to page view with a manual zoom factor, because continuous view cannot
  pan sideways: tap the right / left edge to move across and down the page. Zooming back out
  past 100% returns to fit width + scroll. In an EPUB / HTML file Zoom in / out change the
  font size instead.
- **Other gestures** (reader): tap bottom-left = night mode. Hold bottom-left = explain this
  page. Hold bottom-right = ask the AI. Draw →←→ / ←→← = next / previous paper. File
  browser: bottom-left corner = night mode.
- **Night mode** everywhere; "Figures: true colours / dark" flips the document inversion per
  paper so plots keep their colours.
- **Layouts**: default zoom to content width + continuous scroll (both arXiv columns readable
  on the 2076x2152 inner screen). Column view (2 columns, page mode) for the cover screen; the
  patch switches to it when the screen gets narrow (w < 0.62 h) and back when it gets wide.
  Fit width / Fit page / One column at a time are in the quick menu's zoom group.
- **Library**: home `Books/Inference`, resumes the last paper, cover list with clean titles
  from `custom_metadata.lua`, sorted by filename = reading order (01-10), DeepSeek papers
  (11-18) in `DeepSeek/`. Collections "Inference reading list" and "DeepSeek" are linked to
  those folders, so new PDFs show up on their own. `00 - Start here.html` is a cheat sheet.
- **Plugin settings**: streaming + auto-scroll, font 19, follow-up chips, reasoning hidden,
  no clipboard copy. Noisy stock plugins are disabled (re-enable in Tools > More tools >
  Plugin management). Footer: page, %, section, time left in section, clock, battery.

## Layout

| Path | Goes to (on the phone) | What |
|---|---|---|
| `koreader/patches/2-inference-reader.lua` | `koreader/patches/` | KOReader user patch (popup, fold layout) |
| `prompts/system_prompt.configuration.lua` | part of plugin `configuration.lua` | shared system prompt |
| `prompts/features.configuration.lua` | part of plugin `configuration.lua` | `features = {...}`: prompts, updater off |
| `configuration.example.lua` | - | full rendered config with `__PROXY_API_KEY__` |
| `overrides/settings.reader.lua` | merged into `koreader/settings.reader.lua` | global settings |
| `overrides/gestures.lua` | merged into `koreader/settings/gestures.lua` | gestures + quick menu |
| `overrides/assistant.lua` | merged into `koreader/settings/assistant.lua` | plugin settings |
| `overrides/collection.lua` | `koreader/settings/collection.lua` | collections |
| `overrides/bookinfo_cache.sql` | `koreader/settings/bookinfo_cache.sqlite3` | coverbrowser display (see below) |
| `library/Books/Inference/` | `/sdcard/Books/Inference/` | cheat sheet + `.sdr/custom_metadata.lua` |
| `tools/papers.tsv` | - | number, folder, file, title, authors, arXiv URL, sha256 |
| `tools/fetch-papers.sh` | - | downloads the 18 PDFs from arXiv |
| `tools/render-config.py` | - | builds `configuration.lua` (key injected, never printed) |
| `tools/kosettings.lua` | - | deep-merges overrides into KOReader settings files |
| `tools/make-metadata.py` | - | regenerates `custom_metadata.lua` from `papers.tsv` + `pdfinfo` |
| `tools/deploy.sh` | - | the whole thing end to end |

## Install / redeploy

Needs on the machine running it: `bash`, `curl`, `rsync`, `python3`, `luajit`; `pdfinfo`
(poppler) and `sqlite3` are optional. adb runs either locally (`--local`) or on an ssh host
(default `ubuntu@192.168.50.179` = VM117, adb `/opt/android-sdk/platform-tools/adb`).

- Clone the fork.
- `git switch inference-reader`
- `cp inference-reader/local.env.example inference-reader/local.env`
- Fill in `PROXY_API_KEY` there.
- `inference-reader/tools/deploy.sh --dry-run`
- `inference-reader/tools/deploy.sh --start`

`local.env` is gitignored. Instead of it you can export `PROXY_API_KEY` or
`PROXY_API_KEY_FILE`, or pass `--key-from-pi` to read the key from
`~/.pi/agent/extensions/proxycli.ts`. `PROXY_LAN_URL` (default
`http://192.168.50.31:8317/v1`), `PROXY_TS_URL` (default = LAN URL) and `PROXY_MODEL`
(default `hermes-default`) set the two providers. Transport: `--ssh HOST`, `--adb PATH`,
`--serial SERIAL` or `KR_SSH` / `KR_ADB` / `KR_SERIAL`.

What `deploy.sh` does, in order: fetches papers into `inference-reader/.cache/papers`
(skips ones already there with the right sha256), renders `configuration.lua`, stages the
plugin (this repo without `.git`, `test/`, `inference-reader/`), patch, library and
metadata, force-stops KOReader, backs up on the phone to
`/sdcard/koreader/backup-YYYY-MM-DD-HHMMSS/`, pulls the current settings files and merges the
overrides into them, pushes everything. `--dry-run` does all the local work and prints the
phone/ssh commands instead of running them (it renders with the placeholder and only reports
whether a key was found). Extra flags: `--install-koreader` (installs the v2026.07.1 arm64
APK first, for a fresh phone), `--bookinfo`, `--reset-history`, `--no-papers`, `--start`.

The script never pulls the phone's `configuration.lua`; the config is always rebuilt from
`prompts/` + env. Over ssh the staged files (including the rendered config) pass through a
0700 temp dir on the adb host that is deleted right after the push.

### Coverbrowser settings (`--bookinfo`)

The cover list density (8 items per page, file-size column hidden, list-with-covers display
for collections) is not in a settings `.lua` file: coverbrowser keeps it in the `config`
table of `koreader/settings/bookinfo_cache.sqlite3`, which only exists after the library has
been opened once. `--bookinfo` stops KOReader, pulls the DB with its `-wal`/`-shm`, applies
`overrides/bookinfo_cache.sql`, checkpoints and pushes it back. On the original setup this was
done by hand; the scripted path has not been run against the phone yet. `files_per_page = 8`
was tuned for the inner screen density; on the cover screen the rows end up much smaller, and
KOReader may need a restart before it picks up the new value.

## Rollback

- Force-stop KOReader.
- Copy the files from `/sdcard/koreader/backup-*/` back (settings, `plugin/main.lua`, `plugin/configuration.lua`).
- Delete `koreader/patches/2-inference-reader.lua`.
- Delete `plugins/assistant.koplugin/feature/inference_reader.lua`.

The first backup taken before any change is `/sdcard/koreader/backup-2026-11-02/` (pristine
plugin core/dialogs + original `configuration.lua`). For the plugin only, deploying upstream
`main` (or checking out `9703af3`) and removing `feature/inference_reader.lua` is a clean revert.

## Known gaps

- **Tailscale provider is a placeholder.** Both providers point at
  `http://192.168.50.31:8317/v1` because VM102 (the proxy) is not on Tailscale yet. Away from
  home it still works through the `homeassistant` node's subnet route for 192.168.50.0/24.
  Once VM102 has its own Tailscale address, set `PROXY_TS_URL` and redeploy.
- **Fold auto-layout is untested** on the physical fold: the narrow/wide switch was only
  checked by reasoning about the screen sizes, not by folding the phone.
- **Latency**: `hermes-default` runs with high reasoning effort on the proxy, so the first
  token takes ~5-10 s and whole-page explanations ~20-30 s.
- `--bookinfo` and `--install-koreader` are scripted but not yet run end to end against the phone.

## Upstream merges

    git fetch upstream
    git merge upstream/main     # conflicts, if any, are limited to the hooks in main.lua
