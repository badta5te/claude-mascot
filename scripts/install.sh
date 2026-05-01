#!/bin/sh
# Install Claude Mascot hooks into ~/.claude-helper/hooks and merge the
# hook entries into ~/.claude/settings.json. Idempotent.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/hooks"
DST_DIR="$HOME/.claude-helper/hooks"
SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$DST_DIR" "$(dirname "$SETTINGS")"
install -m 0755 "$SRC_DIR/set-working.sh"   "$DST_DIR/set-working.sh"
install -m 0755 "$SRC_DIR/set-attention.sh" "$DST_DIR/set-attention.sh"
install -m 0755 "$SRC_DIR/clear.sh"         "$DST_DIR/clear.sh"
echo "installed hooks → $DST_DIR"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
else
  echo '{}' >"$SETTINGS"
fi

WORKING_CMD="$DST_DIR/set-working.sh"
ATTENTION_CMD="$DST_DIR/set-attention.sh"
CLEAR_CMD="$DST_DIR/clear.sh"

# Idempotently merge all hook entries into settings.json in a single pass.
# Python is used because it ships with macOS (via Xcode CLT) — zero brew/dep cost.
TMP="$(mktemp)"
/usr/bin/env python3 - "$SETTINGS" "$WORKING_CMD" "$ATTENTION_CMD" "$CLEAR_CMD" >"$TMP" <<'PY'
import json, sys
path, working, attention, clear = sys.argv[1:5]
try:
    with open(path) as f: data = json.load(f)
except Exception:
    data = {}
hooks = data.setdefault("hooks", {})
mapping = [
    ("UserPromptSubmit", working),
    ("PreToolUse",       working),
    ("PostToolUse",      working),
    ("Notification",     attention),
    ("Stop",             clear),
]
for event, cmd in mapping:
    entries = hooks.setdefault(event, [])
    existing = {h.get("command") for entry in entries for h in entry.get("hooks", [])}
    if cmd not in existing:
        entries.append({"hooks": [{"type": "command", "command": cmd}]})
json.dump(data, sys.stdout, indent=2)
PY
mv "$TMP" "$SETTINGS"

echo "merged hook entries → $SETTINGS"
echo "done."
