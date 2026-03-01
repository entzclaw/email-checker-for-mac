# OpenClaw Email Checker

Checks your Apple Mail INBOX on a schedule. For each unread email it scores
priority, generates an AI draft reply via a local or remote LLM, and emails
you a report. Marks emails as read after processing.

---

## Quick Start

### 1. Prerequisites

- macOS (Apple Silicon recommended)
- Python 3 — `brew install python` if missing
- Mail.app set up with at least one account

### 2. Clone / download

```bash
git clone <repo> && cd cron
# — or just copy this cron/ folder anywhere on your Mac
```

### 3. Run setup

```bash
bash setup.sh
```

The wizard will:
- Auto-discover your Mail.app accounts
- Ask for your name, bot name, report email, trusted senders
- Let you pick an LLM provider (LM Studio, Ollama, OpenAI, or skip)
- Test the LLM connection
- Write `config/settings.json`
- Optionally install the crontab and run a first test

### 4. Grant Mail.app permissions

**System Settings → Privacy & Security → Automation**
→ Allow **Terminal** to control **Mail**

If cron jobs fail with permission errors, also add Terminal under **Full Disk Access**.

### 5. Test manually

```bash
python3 scripts/email/checker.py
```

---

## For ClawBot

### Where config lives

`config/settings.json` — all user-specific values. Never committed to git.
`config/settings.example.json` — template committed to git.

### Re-run setup

```bash
bash setup.sh
```

Choose `y` when asked to reconfigure.

### Trigger a manual check

```bash
python3 scripts/email/checker.py
```

### Send a manual reply

```bash
python3 scripts/email/send_reply.py \
    --to recipient@example.com \
    --subject "Re: Something" \
    --content "Your reply here"

# Or from a file:
python3 scripts/email/send_reply.py \
    --to recipient@example.com \
    --subject "Re: Something" \
    --file /path/to/draft.txt
```

### Check logs

```bash
tail -f logs/email_check.log
```

### Update crontab path after moving the folder

Re-run `bash setup.sh` and choose `y` when asked to install crontab. It
writes absolute paths based on the current location.

---

## Directory Structure

```
cron/
├── README.md
├── setup.sh                           # Interactive setup wizard
├── config/
│   ├── settings.example.json          # Template (committed to git)
│   ├── settings.json                  # Your config (gitignored)
│   └── email_check_crontab.txt        # Reference copy of cron schedule
├── scripts/
│   └── email/
│       ├── checker.py                 # Main email checker (cron target)
│       ├── checker_wrapper.sh         # Cron entry point — owns logging
│       ├── get_unread_emails.scpt     # AppleScript: fetch unread emails
│       ├── send_reply.py              # Manual reply sender
│       ├── template.py                # Template for new Python scripts
│       └── template.sh                # Template for new Bash scripts
├── logs/                              # Runtime logs (gitignored)
│   └── email_check.log
└── temp/                              # Runtime temp files (gitignored)
    ├── email_report.txt
    └── recent_emails.json
```

---

## Scripts Reference

### `checker.py` — Email Checker

Runs on cron. Each run:
1. Fetches unread emails from Mail.app INBOX via AppleScript
2. Scores each email HIGH / MEDIUM / LOW (keywords + trusted senders)
3. Generates a draft reply for each email using the configured LLM
4. Sends a report to your `report_email`
5. Marks processed emails as read

All config comes from `config/settings.json`.

**LLM providers supported:**

| Provider  | `provider` value | Notes |
|-----------|-----------------|-------|
| LM Studio | `lm_studio`     | Local or remote vLLM endpoint |
| Ollama    | `ollama`        | Local; default URL set by setup.sh |
| OpenAI    | `openai`        | Requires API key |
| Disabled  | `none`          | Reports without draft replies |

### `checker_wrapper.sh` — Cron Entry Point

Called by cron (not `checker.py` directly). Uses relative paths — works
from any install location. Handles log directory creation and header lines.

### `get_unread_emails.scpt` — AppleScript Fetcher

Called internally by `checker.py`. Receives `account_id` as a CLI argument.
Returns emails in `sender|subject|||content` format.

### `send_reply.py` — Manual Reply Sender

Run manually to reply to a specific email. Logs to `logs/email_check.log`.

---

## Cron Schedule

```
@reboot       /abs/path/to/checker_wrapper.sh   # On system startup
0 * * * *     /abs/path/to/checker_wrapper.sh   # Every hour
```

See `config/email_check_crontab.txt` for the paths as installed on this machine.

---

## Troubleshooting

### LM Studio timeout

> `LLM connection failed` in the log

The LM Studio server may still be processing a previous request from a timed-out
call. Wait 1–2 minutes before retrying. The model is queued server-side.

### Mail.app permissions denied

```
osascript: OpenMail.app got an error: Not authorized to send Apple events to Mail.
```

Go to **System Settings → Privacy & Security → Automation** and allow Terminal
(or whichever app runs the script) to control Mail.

### Account ID not working

Run `bash setup.sh` again — it auto-discovers accounts from Mail.app. Pick yours
from the numbered list.

### Logs not being written

The wrapper creates `logs/` automatically. If it's missing, check that the
wrapper script is executable: `chmod +x scripts/email/checker_wrapper.sh`
