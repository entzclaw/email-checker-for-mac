# LinkedIn Post

---

I built a small tool that watches my email inbox while I work — and I haven't opened Mail.app in days.

It runs every 15 minutes, scores every unread email HIGH / MEDIUM / LOW, and for anything urgent it pulls the full thread history and drafts a reply using my local LLM.

I get a report in my personal inbox. I read it on my phone. If I like a draft, I tell my AI assistant to send it. Done.

No cloud. No subscriptions. Runs entirely on my Mac.

It's my first app published to ClawHub — the OpenClaw skill registry — and I wrote up the full story on Medium (link in comments).

A few things I learned building it:

→ AppleScript is underrated for Mac automation. Reliable, no dependencies, direct Mail.app access.
→ Thread history in the prompt makes a huge difference. Drafts without context are generic. Drafts with 10 prior messages are actually useful.
→ "No AI" mode is a real feature. A prioritised digest with zero LLM dependency is already valuable on its own.

If you're on macOS and tired of your inbox owning your attention — give it a try.

Install via ClawHub:
clawhub install email-checker-by-entzai

Or clone: github.com/entzclaw/email-checker-for-mac

#OpenClaw #MacOS #AITools #Automation #ProductivityTools #LocalAI #ClawHub

---

*[Post the Medium article link as the first comment to keep the post clean.]*
