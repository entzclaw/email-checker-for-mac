# I Built My First OpenClaw App — And I Haven't Opened My Inbox Since

## A tiny email assistant that runs while you sleep, scores your emails, and drafts replies before you even pick up your phone.

---

I have a problem with email.

Not the volume — I can handle volume. The problem is the *switching*. I'll be deep in work, and a notification pulls me into my inbox. Twenty minutes later I'm replying to a GitHub notification I didn't need to reply to, and whatever I was building is gone from my head.

I wanted something that watched my inbox *for* me, figured out what actually needed my attention, and had a draft reply ready to go when I got there.

I didn't want to pay for another SaaS tool. I didn't want to pipe my email through some company's servers. I just wanted a small, local thing that did exactly this and nothing else.

So I built it. It's called **Email Checker**, and it's my first app published to ClawHub — the OpenClaw skill registry.

---

## What It Does

Every 15 minutes (or whatever interval you set), it:

1. Checks your Mail.app inbox via AppleScript
2. Scores every unread email **HIGH / MEDIUM / LOW** based on keywords and senders you trust
3. For **HIGH priority** emails only — fetches the full thread history and generates a draft reply using your local LLM
4. Emails you a formatted report with previews and drafts
5. Marks everything as read

That's it. No cloud. No subscriptions. Runs entirely on your Mac.

---

## The Flow

Here's what actually happens under the hood:

```
Cron fires (every N minutes)
  │
  ▼
AppleScript fetches unread emails from Mail.app
  │
  ├── No emails? → send empty report → done
  │
  └── For each email:
        Score by keywords (urgent, approve, feedback...)
        + trusted sender boost
        │
        ├── HIGH  → fetch thread history → generate AI draft
        ├── MEDIUM → preview only
        └── LOW   → preview only
  │
  ▼
Format report → send to your personal email
Mark inbox as read
```

When a HIGH priority email comes in, the app fetches up to 10 prior messages in the same thread so the LLM has full context. The draft it generates isn't a generic "Thanks for reaching out" — it actually knows what the conversation has been about.

---

## The Report

You get an email that looks like this:

```
EMAIL CHECK REPORT - 2026-03-19 14:00

Total unread: 4

⚠️ HIGH PRIORITY
-----------------
From: Alice Smith <alice@company.com>
Subject: Urgent: contract approval needed
Keywords triggered: urgent, approve

Preview:
Hi, we need your sign-off on the contract by EOD...

Draft Reply:
Hi Alice,

Happy to take a look — sending you feedback by 4pm.
Let me know if you need anything else before then.

MyBot 🤖

⚠️ MEDIUM PRIORITY
-------------------
From: newsletter@somesite.com
Subject: Your weekly digest
Preview: Here's what happened this week...

✅ LOW PRIORITY
----------------
From: noreply@github.com
Subject: [repo] New issue opened
```

I read this on my phone. If I like a draft, I tell my OpenClaw agent via Telegram: *"Send the draft reply to Alice."* It fires `send_reply.py` and it's done. I never opened my inbox.

---

## Why OpenClaw?

I'd been running OpenClaw as my always-on assistant for a while — it handles Telegram messages, runs scheduled tasks, manages my agent workspace. When I built this email checker, I realised it fit naturally into that ecosystem.

The whole setup — AppleScript for Mail.app access, Python for logic, a cron wrapper for scheduling — is exactly the kind of small, focused tool OpenClaw is designed around. Publish it to ClawHub, and anyone else running OpenClaw can install it in one command.

That felt worth sharing.

---

## Setup in 3 Steps

**1. Clone and run the wizard**
```bash
git clone https://github.com/entzclaw/email-checker-for-mac
cd email-checker-for-mac
bash setup.sh
```

The wizard auto-discovers your Mail.app accounts, lets you pick an LLM provider (LM Studio, Ollama, OpenAI, or none), and asks how often you want it to run. It writes `config/settings.json` and installs the crontab. Takes about 2 minutes.

**2. Grant Mail.app permission**
```
System Settings → Privacy & Security → Automation
→ Allow Terminal to control Mail
```

**3. Done**

The next time cron fires, you'll get your first report.

---

## LLM Options

You're not locked into any provider:

| Provider | Notes |
|---|---|
| LM Studio | Local or remote — what I use |
| Ollama | Fully local |
| OpenAI | If you want GPT-4o drafts |
| None | Just scoring and previews, no AI |

If you don't have a local LLM running, **none** mode still gives you a prioritised inbox digest. The drafts are just blanked out.

---

## What's Next

A few things I'm thinking about adding:

- **Reply approval flow** — queue drafts for explicit approve/reject before sending
- **Digest mode** — one daily summary instead of every N minutes
- **More priority signals** — calendar events, CC patterns, sender history

If you try it and have ideas, I'd love to hear them.

---

## Try It

**Install via ClawHub:**
```bash
clawhub install email-checker-by-entzai
```

**Or clone directly:**
```bash
git clone https://github.com/entzclaw/email-checker-for-mac
```

Full docs in the `docs/` folder — setup walkthrough, workflow diagram, and config reference.

This is the first thing I've published to ClawHub. Building small, local tools that do one thing well and compose with the rest of your setup is something I want to keep doing. If you're using OpenClaw and building things too, I'd love to see what you're working on.

---

*Built with OpenClaw · Published on ClawHub · macOS only*
