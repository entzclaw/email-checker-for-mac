#!/bin/bash
# setup.sh — OpenClaw Email Checker setup wizard
# Run from anywhere: bash /path/to/cron/setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/settings.json"

echo "================================================"
echo "  OpenClaw Email Checker — Setup"
echo "================================================"
echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
echo "Checking prerequisites..."
errors=0
if ! command -v python3 &>/dev/null; then
    echo "  ✗ python3 not found — install via Homebrew: brew install python"
    errors=$((errors + 1))
else
    echo "  ✓ python3 $(python3 --version 2>&1 | awk '{print $2}')"
fi
if ! command -v osascript &>/dev/null; then
    echo "  ✗ osascript not found — macOS only"
    errors=$((errors + 1))
else
    echo "  ✓ osascript"
fi
if [ $errors -gt 0 ]; then
    echo ""
    echo "Fix the above and re-run setup."
    exit 1
fi
echo ""

# ── Existing settings? ────────────────────────────────────────────────────────
if [ -f "$CONFIG_FILE" ]; then
    echo "Existing settings.json found."
    read -r -p "Reconfigure from scratch? [y/N] " reconfigure
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo "Skipped. Using existing settings."
        exit 0
    fi
    echo ""
fi

# ── Discover Mail.app accounts ────────────────────────────────────────────────
echo "Discovering Mail.app accounts..."
accounts_raw=$(osascript << 'APPLESCRIPT' 2>/dev/null
tell application "Mail"
    set output to {}
    repeat with acct in accounts
        set end of output to ((id of acct) & ":::" & (name of acct))
    end repeat
    set AppleScript's text item delimiters to linefeed
    set resultText to output as text
    set AppleScript's text item delimiters to ""
    return resultText
end tell
APPLESCRIPT
)

declare -a accounts
if [ -n "$accounts_raw" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && accounts+=("$line")
    done <<< "$accounts_raw"
fi

if [ ${#accounts[@]} -eq 0 ]; then
    echo "  Could not auto-discover accounts. Check Mail.app is set up."
    echo "  You can find your account ID in Mail → Preferences → Accounts."
    echo ""
    read -r -p "  Enter Mail.app account ID manually: " MAIL_ACCOUNT_ID
else
    echo ""
    echo "Available Mail.app accounts:"
    for i in "${!accounts[@]}"; do
        id_part="${accounts[$i]%%:::*}"
        name_part="${accounts[$i]##*:::}"
        echo "  [$((i + 1))] $name_part  ($id_part)"
    done
    echo ""
    while true; do
        read -r -p "Select account [1-${#accounts[@]}]: " acct_num
        if [[ "$acct_num" =~ ^[0-9]+$ ]] && \
           [ "$acct_num" -ge 1 ] && [ "$acct_num" -le "${#accounts[@]}" ]; then
            chosen="${accounts[$((acct_num - 1))]}"
            MAIL_ACCOUNT_ID="${chosen%%:::*}"
            break
        fi
        echo "  Invalid selection."
    done
fi
echo ""

# ── User info ─────────────────────────────────────────────────────────────────
read -r -p "Your full name (for LLM context): " USER_NAME

read -r -p "Bot name [EntzClawBot]: " BOT_NAME
BOT_NAME="${BOT_NAME:-EntzClawBot}"

read -r -p "Report recipient email: " REPORT_EMAIL

echo "Trusted senders get a priority boost. Each entry is matched as a substring"
echo "of the sender's From: field (name + address). Examples:"
echo "  'Angelo'           — matches anyone named Angelo"
echo "  '@company.com'     — matches everyone from that domain"
echo "  'alice@example.com'— matches that exact address"
read -r -p "Trusted senders (comma-separated): " TRUSTED_SENDERS_RAW
echo ""

# ── LLM provider ─────────────────────────────────────────────────────────────
echo "LLM provider:"
echo "  [1] LM Studio  (local or remote vLLM)"
echo "  [2] Ollama     (local)"
echo "  [3] OpenAI"
echo "  [4] Skip       (no AI drafts)"
echo ""
while true; do
    read -r -p "Select provider [1-4]: " llm_choice
    case "$llm_choice" in
        1)
            LLM_PROVIDER="lm_studio"
            read -r -p "  Base URL [http://localhost:1234/v1]: " LLM_BASE_URL
            LLM_BASE_URL="${LLM_BASE_URL:-http://localhost:1234/v1}"
            read -r -p "  API key [local]: " LLM_API_KEY
            LLM_API_KEY="${LLM_API_KEY:-local}"
            while true; do
                read -r -p "  Model ID: " LLM_MODEL
                [ -n "$LLM_MODEL" ] && break
                echo "  Model ID is required."
            done
            break ;;
        2)
            LLM_PROVIDER="ollama"
            LLM_BASE_URL="http://localhost:11434/v1"
            LLM_API_KEY="ollama"
            read -r -p "  Model ID [llama3]: " LLM_MODEL
            LLM_MODEL="${LLM_MODEL:-llama3}"
            break ;;
        3)
            LLM_PROVIDER="openai"
            LLM_BASE_URL="https://api.openai.com/v1"
            read -r -p "  OpenAI API key: " LLM_API_KEY
            read -r -p "  Model ID [gpt-4o-mini]: " LLM_MODEL
            LLM_MODEL="${LLM_MODEL:-gpt-4o-mini}"
            break ;;
        4)
            LLM_PROVIDER="none"
            LLM_BASE_URL=""
            LLM_API_KEY=""
            LLM_MODEL=""
            break ;;
        *) echo "  Invalid selection." ;;
    esac
done
echo ""

# ── Test LLM connection ───────────────────────────────────────────────────────
if [ "$LLM_PROVIDER" != "none" ]; then
    echo "Testing LLM connection..."
    test_result=$(BASE_URL="$LLM_BASE_URL" API_KEY="$LLM_API_KEY" MODEL="$LLM_MODEL" \
        python3 << 'PYEOF' 2>/dev/null
import urllib.request, json, os, sys
url = os.environ['BASE_URL'] + '/chat/completions'
payload = json.dumps({
    'model': os.environ['MODEL'],
    'messages': [{'role': 'user', 'content': 'ping'}],
    'max_tokens': 5
}).encode()
req = urllib.request.Request(
    url, data=payload,
    headers={
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + os.environ['API_KEY']
    },
    method='POST'
)
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        print('OK')
except Exception as e:
    print(f'FAIL: {e}')
PYEOF
    )
    if [ "$test_result" = "OK" ]; then
        echo "  ✓ LLM connection OK"
    else
        echo "  ✗ LLM connection failed: $test_result"
        echo "    (Continuing — fix the URL/key in settings.json later)"
    fi
    echo ""
fi

# ── Write settings.json ───────────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR"

USER_NAME="$USER_NAME" \
BOT_NAME="$BOT_NAME" \
REPORT_EMAIL="$REPORT_EMAIL" \
TRUSTED_SENDERS_RAW="$TRUSTED_SENDERS_RAW" \
MAIL_ACCOUNT_ID="$MAIL_ACCOUNT_ID" \
LLM_PROVIDER="$LLM_PROVIDER" \
LLM_BASE_URL="$LLM_BASE_URL" \
LLM_API_KEY="$LLM_API_KEY" \
LLM_MODEL="$LLM_MODEL" \
python3 << 'PYEOF' > "$CONFIG_FILE"
import json, os

trusted_raw = os.environ.get('TRUSTED_SENDERS_RAW', '')
trusted = [s.strip() for s in trusted_raw.split(',') if s.strip()]

config = {
    "user": {
        "name":            os.environ['USER_NAME'],
        "bot_name":        os.environ['BOT_NAME'],
        "report_email":    os.environ['REPORT_EMAIL'],
        "trusted_senders": trusted
    },
    "mail": {
        "account_id":  os.environ['MAIL_ACCOUNT_ID'],
        "inbox_name":  "INBOX"
    },
    "llm": {
        "provider":   os.environ['LLM_PROVIDER'],
        "base_url":   os.environ['LLM_BASE_URL'],
        "api_key":    os.environ['LLM_API_KEY'],
        "model":      os.environ['LLM_MODEL'],
        "max_tokens": 800,
        "timeout":    45
    }
}
print(json.dumps(config, indent=2))
PYEOF

echo "  ✓ settings.json written"

# ── Install crontab ───────────────────────────────────────────────────────────
WRAPPER="$SCRIPT_DIR/scripts/email/checker_wrapper.sh"
echo ""
echo "Cron schedule:"
echo "  @reboot       — on system startup"
echo "  0 * * * *     — every hour"
echo ""
read -r -p "Install crontab? [y/N]: " install_cron
if [[ "$install_cron" =~ ^[Yy]$ ]]; then
    ( crontab -l 2>/dev/null | grep -v checker_wrapper || true
      echo "@reboot $WRAPPER"
      echo "0 * * * * $WRAPPER"
    ) | crontab -
    echo "  ✓ Crontab installed"

    # Update reference copy
    cat > "$CONFIG_DIR/email_check_crontab.txt" << EOF
# Email checker - runs at startup and every hour
@reboot $WRAPPER
0 * * * * $WRAPPER
EOF
    echo "  ✓ config/email_check_crontab.txt updated"
fi

# ── Permissions reminder ──────────────────────────────────────────────────────
echo ""
echo "================================================"
echo "  PERMISSIONS REQUIRED"
echo "================================================"
echo ""
echo "  System Settings → Privacy & Security → Automation"
echo "  → Allow Terminal to control Mail"
echo ""
echo "  If cron jobs fail, also add:"
echo "  → Full Disk Access → Terminal"
echo ""

# ── Optional test run ─────────────────────────────────────────────────────────
read -r -p "Run a test check now? [y/N]: " run_test
if [[ "$run_test" =~ ^[Yy]$ ]]; then
    echo ""
    python3 "$SCRIPT_DIR/scripts/email/checker.py"
fi

echo ""
echo "================================================"
echo "  Setup complete!"
echo "================================================"
