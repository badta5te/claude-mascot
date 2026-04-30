#!/bin/sh
# Claude Code hook: session turn finished, drop the state file.
set -eu

DIR="$HOME/.claude-helper/sessions"
SID="$(jq -r '.session_id // empty')"
[ -z "$SID" ] && exit 0

rm -f "$DIR/$SID.state"
