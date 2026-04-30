#!/bin/sh
# Install Claude Mascot hooks into ~/.claude-helper/hooks and merge the
# hook entries into ~/.claude/settings.json. Idempotent.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/hooks"
DST_DIR="$HOME/.claude-helper/hooks"
SETTINGS="$HOME/.claude/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required (brew install jq)" >&2
  exit 1
fi

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

# Add a single hook command for an event, but only if no existing entry
# already runs the same command. Other hooks for the same event are kept.
ensure_hook() {
  event="$1"
  cmd="$2"
  TMP="$(mktemp)"
  jq --arg ev "$event" --arg cmd "$cmd" '
    .hooks //= {}
    | .hooks[$ev] //= []
    | if (.hooks[$ev] | map(.hooks // []) | flatten | map(.command) | index($cmd))
      then .
      else .hooks[$ev] += [{ "hooks": [{ "type": "command", "command": $cmd }] }]
      end
  ' "$SETTINGS" >"$TMP" && mv "$TMP" "$SETTINGS"
}

ensure_hook UserPromptSubmit "$WORKING_CMD"
ensure_hook PreToolUse       "$WORKING_CMD"
ensure_hook PostToolUse      "$WORKING_CMD"
ensure_hook Notification     "$ATTENTION_CMD"
ensure_hook Stop             "$CLEAR_CMD"

echo "merged hook entries → $SETTINGS"
echo "done."
