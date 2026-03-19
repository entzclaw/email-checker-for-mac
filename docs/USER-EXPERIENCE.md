# User Experience — Email Checker by EntzAI

## Overview

Email Checker is a macOS tool that watches your Mail.app inbox on a schedule, scores emails by priority, drafts AI replies for urgent ones, and sends you a report — so you can manage your inbox from your phone without opening Mail.app.

---

## Installation

### Step 1 — Get the project

```bash
git clone https://github.com/entzclaw/email-checker-for-mac
cd email-checker-for-mac
```

### Step 2 — Run the setup wizard

```bash
bash setup.sh
```

The wizard walks through everything interactively. No manual config editing required.

---

## Setup Wizard Walkthrough

### Prerequisites check
The wizard verifies `python3` and `osascript` are available before continuing.

### Mail.app account selection
Your Mail.app accounts are auto-discovered and presented as a numbered list:
```
Available Mail.app accounts:
  [1] My Personal Gmail  (account-id)
  [2] Work Inbox         (account-id)

Select account [1-2]:
```
If auto-discovery fails, you can enter the account ID manually (found in Mail → Settings → Accounts).

### Your details
```
Your full name (for LLM context): John Smith
Bot name [EntzClawBot]:
Report recipient email: john@personal.com
Trusted senders (comma-separated): Alice, @mycompany.com, ceo@bigcorp.com
```

**Trusted senders** get a priority boost. Each entry is matched as a substring of the sender's From: field:

| Entry | Matches |
|---|---|
| `Alice` | Anyone with "Alice" in their name |
| `@company.com` | Everyone from that domain |
| `alice@example.com` | That exact address only |

### LLM provider
```
LLM provider:
  [1] LM Studio  (local or remote vLLM)
  [2] Ollama     (local)
  [3] OpenAI
  [4] Skip       (no AI drafts)
```
If you pick an LLM, the wizard tests the connection before saving. If it fails, you can fix the URL/key in `config/settings.json` later.

Choosing **Skip** puts the checker in low-tech mode — you still get email previews and priority scores, just no AI-generated drafts.

### Check interval
```
How often should the checker run?
  [1] Every 15 minutes
  [2] Every 30 minutes
  [3] Every hour (default)
  [4] Custom interval
```

### Crontab install
The wizard shows you the exact cron expression, then asks permission to install it:
```
Cron schedule: */30 * * * * (every 30 min) + @reboot

Install crontab? [y/N]:
```

### Permissions reminder
After setup, the wizard reminds you to grant Mail.app access:
> System Settings → Privacy & Security → Automation → Allow Terminal to control Mail

If cron jobs fail to send, also add Terminal to Full Disk Access.

### Optional test run
```
Run a test check now? [y/N]:
```
Runs `checker.py` immediately so you can verify everything works before the first scheduled run.

---

## What Happens Each Run

```
Cron fires
  → fetch unread emails from Mail.app (AppleScript)
  → score each email: HIGH / MEDIUM / LOW
        HIGH  → fetch thread history → generate AI draft reply
        MEDIUM → preview only, no draft
        LOW    → preview only, no draft
  → format report (sections by priority)
  → send report to your personal email
  → mark processed emails as read
```

See `WORKFLOW.md` for the full diagram.

---

## Reading Your Report

You receive an email like this:

```
EMAIL CHECK REPORT - 2026-03-19 14:00:01
============================================================

Total unread messages: 4

⚠️  HIGH PRIORITY EMAILS (Action Required)
----------------------------------------
From: Alice Smith <alice@company.com>
Subject: Urgent: contract approval needed
Impact Score: 7/15
Triggered keywords: urgent, approve

Email Preview:
Hi, we need your sign-off on the contract by EOD...

Draft Response:
--------------------
Hi Alice,

Happy to take a look — sending you my feedback by 4pm.
Let me know if you need anything else before then.

MyBot 🤖

⚠️  MEDIUM PRIORITY EMAILS
----------------------------------------
From: newsletter@somesite.com
Subject: Your weekly digest
Preview: Here's what happened this week...

✅ LOW PRIORITY EMAILS
----------------------------------------
From: noreply@github.com
Subject: [repo] New issue opened
Preview: A new issue was opened in your repository...
```

---

## Replying to Senders

After reading the report on your phone, you have three options:

**Option A — Send the AI draft as-is**
Tell OpenClaw via Telegram or WhatsApp:
> "Send the draft reply to Alice"

**Option B — Send your own reply**
> "Reply to Alice with: Sounds good, reviewing now"

**Option C — Send from a file (CLI)**
```bash
python3 scripts/email/send_reply.py \
    --to alice@company.com \
    --subject "Re: Urgent: contract approval needed" \
    --file /path/to/my-reply.txt
```

All options send via Mail.app and log to `logs/email_check.log`.

---

## Configuration Reference

All config lives in `config/settings.json` (created by setup.sh, gitignored):

```json
{
  "user": {
    "name": "John Smith",
    "bot_name": "MyBot",
    "report_email": "john@personal.com",
    "trusted_senders": ["Alice", "@company.com"]
  },
  "mail": {
    "account_id": "XXXX-...",
    "inbox_name": "INBOX"
  },
  "schedule": {
    "interval_minutes": 30
  },
  "llm": {
    "provider": "lm_studio",
    "base_url": "http://localhost:1234/v1",
    "api_key": "local",
    "model": "your-model-id",
    "max_tokens": 800,
    "timeout": 45
  }
}
```

To change the check interval after setup, either re-run `bash setup.sh` or edit `interval_minutes` in `settings.json` and update your crontab manually:
```bash
crontab -e
```

---

## Useful Commands

```bash
# Run a manual check right now
python3 scripts/email/checker.py

# Watch the live log
tail -f logs/email_check.log

# Send a reply manually
python3 scripts/email/send_reply.py \
    --to someone@example.com \
    --subject "Re: Something" \
    --content "Your reply here"

# Re-run setup (reconfigure from scratch)
bash setup.sh
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Config not found. Run setup.sh first.` | Run `bash setup.sh` |
| `Not authorized to send Apple events to Mail` | System Settings → Privacy & Security → Automation → Terminal → Mail |
| Cron runs but emails don't send | Add Terminal to Full Disk Access |
| LLM times out | Increase `"timeout"` in settings.json; check the server is running |
| Wrong account detected | Re-run `bash setup.sh` to pick a different account |
| Logs not writing | `chmod +x scripts/email/checker_wrapper.sh` |
