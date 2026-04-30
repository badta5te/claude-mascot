#!/bin/sh
# Claude Code hook: mark this session as "working".
# Reads JSON on stdin and atomically writes the state file.
set -eu

DIR="$HOME/.claude-helper/sessions"
mkdir -p "$DIR"

SID="$(jq -r '.session_id // empty')"
[ -z "$SID" ] && exit 0

TMP="$(mktemp "$DIR/.tmp.XXXXXX")"
printf 'working' >"$TMP"
mv "$TMP" "$DIR/$SID.state"
