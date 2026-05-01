#!/bin/sh
# Claude Code hook: session turn finished, drop the state file.
set -eu

DIR="$HOME/.claude-helper/sessions"
SID="$(sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$SID" ] && exit 0

rm -f "$DIR/$SID.state"
