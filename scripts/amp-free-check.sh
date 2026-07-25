#!/usr/bin/env bash
#
# amp-free-check.sh — Check your Amp Free remaining percentage
#
# Decrypts Brave's ampcode.com cookies, launches headless Brave with your
# existing profile, renders the /settings page, and extracts the "Amp Free"
# remaining value via Chrome DevTools Protocol.
#
# Requirements:
#   - Brave Browser installed at /Applications/Brave Browser.app
#   - Python 3 with: cryptography, websocket-client, requests
#   - macOS Keychain access (for "Brave Safe Storage" password)
#
# Usage:
#   ./scripts/amp-free-check.sh              # verbose: "Amp Free: 4% remaining"
#   ./scripts/amp-free-check.sh --percent-only  # machine-readable: prints "4" and exits 0
#                                               # exits 1 if the percentage cannot be parsed
#
set -euo pipefail

PERCENT_ONLY=false
for _arg in "$@"; do
  case "$_arg" in
    --percent-only) PERCENT_ONLY=true ;;
    *) ;;
  esac
done
export PERCENT_ONLY

BRAVE_APP="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
COOKIE_DB="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies"
TMP_PROFILE="/tmp/brave_headless_$$"
DEBUG_PORT=9222
TARGET_URL="https://ampcode.com/settings"

# ─── sanity checks ───────────────────────────────────────────────
[ -f "$BRAVE_APP" ] || { echo "ERROR: Brave Browser not found at $BRAVE_APP" >&2; exit 1; }
[ -f "$COOKIE_DB" ] || { echo "ERROR: Brave cookie DB not found at $COOKIE_DB" >&2; exit 1; }
python3 -c 'import cryptography, websocket, requests' 2>/dev/null || {
  echo "ERROR: Missing Python deps. Install with:" >&2
  echo "  pip3 install cryptography websocket-client requests" >&2
  exit 1
}

# ─── cleanup on exit ─────────────────────────────────────────────
cleanup() {
  if [ -n "${BRAVE_PID:-}" ]; then
    kill "$BRAVE_PID" 2>/dev/null || true
    wait "$BRAVE_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_PROFILE" 2>/dev/null || true
}
trap cleanup EXIT

# ─── copy Brave profile (cookies + Local State for decryption) ───
echo "Copying Brave profile to temp location..." >&2
mkdir -p "$TMP_PROFILE"
cp -r "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default" "$TMP_PROFILE/Default" 2>/dev/null || true
cp "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Local State" "$TMP_PROFILE/" 2>/dev/null || true

# ─── launch headless Brave ───────────────────────────────────────
echo "Launching headless Brave (port $DEBUG_PORT)..." >&2
"$BRAVE_APP" \
  --headless=new \
  --remote-debugging-port="$DEBUG_PORT" \
  --remote-allow-origins=* \
  --user-data-dir="$TMP_PROFILE" \
  --no-first-run \
  --disable-gpu \
  about:blank >/dev/null 2>&1 &
BRAVE_PID=$!

# wait for DevTools to be ready
for _ in $(seq 1 10); do
  if curl -sf http://localhost:"$DEBUG_PORT"/json/version >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
curl -sf http://localhost:"$DEBUG_PORT"/json/version >/dev/null 2>&1 || {
  echo "ERROR: Brave DevTools port not responding" >&2
  exit 1
}

# ─── CDP: navigate, wait, extract text ───────────────────────────
python3 - << 'PYEOF'
import json, time, websocket, requests, sys, re, os

PERCENT_ONLY = os.environ.get("PERCENT_ONLY", "false") == "true"

DEBUG_PORT = 9222
TARGET_URL = "https://ampcode.com/settings"

# find a non-extension tab
tabs = requests.get(f"http://localhost:{DEBUG_PORT}/json/list").json()
target = next(
    (t for t in tabs if not t.get("url", "").startswith("chrome-extension")),
    None,
)
if not target:
    print("ERROR: no usable tab in headless Brave", file=sys.stderr)
    sys.exit(1)

ws = websocket.create_connection(target["webSocketDebuggerUrl"], timeout=30)
_msg_id = 0

def cdp(method, params=None):
    global _msg_id
    _msg_id += 1
    msg = {"id": _msg_id, "method": method}
    if params:
        msg["params"] = params
    ws.send(json.dumps(msg))
    while True:
        resp = json.loads(ws.recv())
        if resp.get("id") == _msg_id:
            return resp

# navigate
cdp("Page.navigate", {"url": TARGET_URL})

# wait for SPA to render (network + JS hydration)
time.sleep(8)

# extract rendered body text
result = cdp("Runtime.evaluate", {
    "expression": "document.body.innerText",
    "returnByValue": True,
})
text = result.get("result", {}).get("result", {}).get("value", "")
ws.close()

# ── parse "Amp Free" section ──────────────────────────────────────
# Expected format on the page:
#   Amp Free
#   4%
#   remaining
#   Resets daily at 7:00 AM GMT+7

lines = [l.strip() for l in text.splitlines() if l.strip()]
amp_free_idx = next((i for i, l in enumerate(lines) if l == "Amp Free"), None)

if amp_free_idx is not None:
    # the percentage and "remaining" follow on the next lines
    section = lines[amp_free_idx:amp_free_idx+6]
    pct = next((l for l in section if l.endswith("%")), "?")
    reset = next((l for l in section if "Reset" in l), "")

    if PERCENT_ONLY:
        pct_match = re.match(r"(\d+)", pct)
        if pct_match:
            print(pct_match.group(1))
            sys.exit(0)
        else:
            sys.exit(1)

    print(f"Amp Free: {pct} remaining")
    if reset:
        print(f"  {reset}")
else:
    if PERCENT_ONLY:
        sys.exit(1)

    # fallback: just search for lines with "free" or "remaining"
    print("Could not find 'Amp Free' section — dumping relevant lines:")
    for line in lines:
        if any(w in line.lower() for w in ["free", "remaining", "credit", "balance"]):
            print(f"  {line}")

# also extract balance if present (verbose mode only)
if not PERCENT_ONLY:
    balance_match = re.search(r"\$([\d.]+)\s*USD", text)
    if balance_match:
        print(f"Balance: ${balance_match.group(1)} USD")
PYEOF

echo "" >&2
echo "Done." >&2
