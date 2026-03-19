# Dev Log — Email Checker by EntzAI

## What This Is

An automated email assistant for Apple Mail on macOS. Runs on a schedule via cron, scores unread emails by priority (HIGH / MEDIUM / LOW), drafts AI replies using your LLM, and emails you a report — so you can manage your inbox from Telegram or WhatsApp without opening Mail.app.

Designed for the OpenClaw setup: a dedicated machine running OpenClaw watches a bot inbox, generates reports, and sends drafts to your phone.

---

## What Was Built

### Core script: `scripts/email/checker.py`

The main entry point. Three versions across development:

- **v1** — Basic email fetch + priority scoring. Used Ollama for LLM drafts.
- **v2** — Switched from Ollama to LM Studio (OpenAI-compatible `/v1/chat/completions`). Added thread history fetching (up to 10 prior messages). Increased content capture from 800 → 2000 chars.
- **v3** (current) — All hardcoded values moved to `config/settings.json`. LLM is provider-agnostic (`call_llm()` replaces `call_lm_studio()`). LLM can be disabled entirely (`"provider": "none"`). AppleScript now receives `account_id` as a CLI argument instead of having it baked in.

Key features in the current version:
- `get_unread_emails()` — uses AppleScript to fetch unread mail including body content
- `analyze_email()` — keyword scoring + trusted sender boost → HIGH / MEDIUM / LOW
- `get_thread_history()` — fetches prior messages in the same thread for LLM context
- `call_llm()` — OpenAI-compatible, strips `<think>` tokens, handles all failure modes gracefully
- `generate_contextual_draft()` — builds full prompt with thread context, falls back to placeholder if LLM unavailable
- `format_report()` — sections by priority; draft replies generated for HIGH only (MEDIUM and LOW show preview only)
- `send_email_report()` — sends formatted report to your personal email via Mail.app
- `mark_emails_as_read()` — marks processed emails as read after report is sent

### AppleScript: `scripts/email/get_unread_emails.scpt`

Fetches unread emails from Mail.app using `osascript`. Receives `account_id` as a CLI argument. Returns `sender|subject|||content` blocks delimited by `|||`.

### Reply sender: `scripts/email/send_reply.py`

CLI tool for sending replies via Mail.app. Accepts `--to`, `--subject`, and either `--content` (inline) or `--file` (path to draft text). Used by OpenClaw when you approve a draft from Telegram/WhatsApp.

Writes content to a temp file before passing to AppleScript to avoid injection issues with newlines and quotes in message bodies.

### Setup wizard: `setup.sh`

Interactive bash wizard that:
1. Checks prerequisites (`python3`, `osascript`)
2. Auto-discovers Mail.app accounts via AppleScript — presents numbered list for selection
3. Prompts for name, bot name, report email, trusted senders
4. Lets you pick LLM provider (LM Studio, Ollama, OpenAI, or none) and tests the connection
5. Writes `config/settings.json` (gitignored)
6. Optionally installs the crontab and runs a first test

### Cron wrapper: `scripts/email/checker_wrapper.sh`

Thin shell wrapper that owns log rotation and is the actual crontab entry. Calls `checker.py` and appends stdout/stderr to `logs/email_check.log`.

### Config: `config/settings.json`

Gitignored. Created by `setup.sh`. Contains:
- `user.name`, `user.bot_name`, `user.report_email`, `user.trusted_senders`
- `mail.account_id`, `mail.inbox_name`
- `llm.provider`, `llm.base_url`, `llm.api_key`, `llm.model`, `llm.max_tokens`, `llm.timeout`

Template at `config/settings.example.json` (committed).

### ClawHub metadata

- `_meta.json` — slug, version, OS/binary requirements for the ClawHub registry
- `SKILL.md` — ClawHub skill descriptor (name, description, install/usage instructions)

---

## LLM Providers Supported

| Provider | `provider` value | Notes |
|---|---|---|
| LM Studio / vLLM | `lm_studio` | OpenAI-compatible, local or remote |
| Ollama | `ollama` | Local, `http://localhost:11434/v1` |
| OpenAI | `openai` | Requires real API key |
| Disabled | `none` | Reports without AI drafts |

---

## Key Design Decisions

- **stdlib only for HTTP** — `checker.py` uses `urllib.request` (no `pip install` needed to run the checker)
- **AppleScript for Mail.app** — more reliable than IMAP for detecting true unread status in Mail.app
- **`account_id` parameterised** — AppleScript receives it as a CLI arg so the script is not locked to one account
- **Thread history in prompt** — model gets up to 10 prior messages for context, making drafts significantly better
- **`<think>` token stripping** — reasoning models (like Qwen) emit thinking tokens before the reply; these are stripped before the draft is used
- **Graceful LLM failure** — if the LLM is unreachable or returns empty, a placeholder draft is inserted rather than crashing
- **Temp file for AppleScript content** — avoids shell injection from newlines/quotes in email body when passing to `osascript`

---

## Status

- All scripts written and tested on macOS Tahoe 26.3 (Apple Silicon)
- Repo: `https://github.com/entzclaw/email-checker-for-mac` (clean, up to date)
- ClawHub: logged in as `@entzclaw`, ready to publish
  - Slug: `email-checker-by-entzai`
  - Version: `1.0.0`
  - Publish command: `clawhub publish /Users/entzclaw/Documents/001-email-checker-for-mac --slug email-checker-by-entzai --name "Email Checker by EntzAI" --version 1.0.0`
