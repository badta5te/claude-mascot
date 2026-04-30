#!/bin/sh
# Claude Code hook: mark this session as "working".
# Refuses to overwrite a recent "attention" state — otherwise PreToolUse /
# PostToolUse, which fire as soon as the user approves a permission prompt,
# would erase the orange mascot before the user could see it.
set -eu

DIR="$HOME/.claude-helper/sessions"
mkdir -p "$DIR"

SID="$(jq -r '.session_id // empty')"
[ -z "$SID" ] && exit 0

STATE_FILE="$DIR/$SID.state"
ATTENTION_STICKY_SECS=2

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "attention" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$STATE_FILE") ))
    if [ "$AGE" -lt "$ATTENTION_STICKY_SECS" ]; then
        exit 0
    fi
fi

TMP="$(mktemp "$DIR/.tmp.XXXXXX")"
printf 'working' >"$TMP"
mv "$TMP" "$STATE_FILE"
