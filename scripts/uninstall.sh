#!/bin/sh
# Surgically remove Claude Mascot from this machine without touching any other
# Claude Code state. Removes:
#   - the running app process
#   - this app's hook entries from ~/.claude/settings.json (others are kept)
#   - ~/.claude-helper/ (our namespace; not Claude Code's)
#   - /Applications/ClaudeMascot.app
# Leaves untouched:
#   - all other ~/.claude/* state (history, caches, file-history, MCP, etc.)
#   - any project-local .claude/ dirs
set -eu

SETTINGS="$HOME/.claude/settings.json"
HELPER_DIR="$HOME/.claude-helper"
APP="/Applications/ClaudeMascot.app"

echo "stopping app…"
pkill -x ClaudeMascot 2>/dev/null || true

if [ -f "$SETTINGS" ]; then
  echo "removing mascot hook entries from $SETTINGS (backup → $SETTINGS.bak.uninstall.$(date +%Y%m%d-%H%M%S))…"
  cp "$SETTINGS" "$SETTINGS.bak.uninstall.$(date +%Y%m%d-%H%M%S)"
  TMP="$(mktemp)"
  /usr/bin/env python3 - "$SETTINGS" "$HELPER_DIR/hooks" >"$TMP" <<'PY'
import json, os, sys
path, hooks_dir = sys.argv[1], os.path.realpath(sys.argv[2])
with open(path) as f:
    data = json.load(f)
hooks = data.get("hooks", {})
def is_ours(entry):
    for h in entry.get("hooks", []):
        cmd = h.get("command", "")
        if cmd.startswith(hooks_dir + "/") or cmd == hooks_dir:
            return True
    return False
for event in list(hooks.keys()):
    hooks[event] = [e for e in hooks[event] if not is_ours(e)]
    if not hooks[event]:
        del hooks[event]
if not hooks:
    data.pop("hooks", None)
json.dump(data, sys.stdout, indent=2)
PY
  mv "$TMP" "$SETTINGS"
fi

if [ -d "$HELPER_DIR" ]; then
  echo "removing $HELPER_DIR…"
  rm -rf "$HELPER_DIR"
fi

if [ -d "$APP" ]; then
  echo "removing $APP…"
  rm -rf "$APP"
fi

echo "done."
