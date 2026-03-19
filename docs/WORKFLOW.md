# Email Checker — Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    CRON (every hour)                        │
│              checker_wrapper.sh                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    checker.py                               │
│              load config/settings.json                      │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              get_unread_emails()                            │
│         osascript → get_unread_emails.scpt                  │
│              (Mail.app → INBOX)                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
               ┌──────────┴──────────┐
               │ no unread emails?   │
               ▼                     ▼
        send empty report      for each email
        → done                       │
                                     ▼
                     ┌───────────────────────────────┐
                     │         analyze_email()        │
                     │  keyword scoring +             │
                     │  trusted sender boost          │
                     └───────────────┬───────────────┘
                                     │
               ┌─────────────────────┼─────────────────────┐
               ▼                     ▼                     ▼
            HIGH                  MEDIUM                  LOW
      (score ≥ 5)            (score 2–4)            (score 0–1)
               │                     │                     │
               ▼                     ▼                     ▼
   get_thread_history()        preview only          preview only
   (up to 10 prior msgs)       no draft              no draft
               │
               ▼
   generate_contextual_draft()
   → call_llm()
   → strip <think> tokens
   → fallback if LLM down
               │
               ▼
          draft reply
               │
               └──────────────────────┐
                                      ▼
                          ┌───────────────────────┐
                          │     format_report()    │
                          │  HIGH  → preview+draft │
                          │  MEDIUM → preview only │
                          │  LOW   → preview only  │
                          └───────────┬───────────┘
                                      │
                                      ▼
                          ┌───────────────────────┐
                          │   send_email_report()  │
                          │  Mail.app → your       │
                          │  personal email        │
                          └───────────┬───────────┘
                                      │
                                      ▼
                          ┌───────────────────────┐
                          │  mark_emails_as_read() │
                          │  osascript → Mail.app  │
                          └───────────────────────┘


── REPLYING TO SENDERS ──────────────────────────────────────

  You receive the report on your phone.
  For HIGH priority emails, a draft reply is included.

  Option A — Send the draft as-is:
    Tell OpenClaw via Telegram/WhatsApp:
    "Send the draft reply to Alice"
         │
         ▼
    OpenClaw runs:
    python3 send_reply.py \
        --to alice@example.com \
        --subject "Re: ..." \
        --content "<draft text>"

  Option B — Send a custom reply:
    Tell OpenClaw via Telegram/WhatsApp:
    "Reply to Alice with: Sounds good, let's meet at 3pm"
         │
         ▼
    OpenClaw runs:
    python3 send_reply.py \
        --to alice@example.com \
        --subject "Re: ..." \
        --content "Sounds good, let's meet at 3pm"

  Option C — Send from a saved file:
    python3 send_reply.py \
        --to alice@example.com \
        --subject "Re: ..." \
        --file /path/to/draft.txt

  In all cases, Mail.app sends the reply from the bot account
  and the action is logged to logs/email_check.log.
```
