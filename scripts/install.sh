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

# Idempotently add a hook entry to settings.json. We use Python (built into
# macOS) so the installer has zero brew/dep requirements.
ensure_hook() {
  event="$1"
  cmd="$2"
  TMP="$(mktemp)"
  /usr/bin/env python3 - "$SETTINGS" "$event" "$cmd" >"$TMP" <<'PY'
import json, sys
path, event, cmd = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path) as f: data = json.load(f)
except Exception:
    data = {}
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault(event, [])
existing = {h.get("command") for entry in entries for h in entry.get("hooks", [])}
if cmd not in existing:
    entries.append({"hooks": [{"type": "command", "command": cmd}]})
json.dump(data, sys.stdout, indent=2)
PY
  mv "$TMP" "$SETTINGS"
}

ensure_hook UserPromptSubmit "$WORKING_CMD"
ensure_hook PreToolUse       "$WORKING_CMD"
ensure_hook PostToolUse      "$WORKING_CMD"
ensure_hook Notification     "$ATTENTION_CMD"
ensure_hook Stop             "$CLEAR_CMD"

echo "merged hook entries → $SETTINGS"
echo "done."
