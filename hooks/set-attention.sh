#!/bin/sh
# Claude Code Notification hook. Only marks the session as "attention" when
# Claude is actually blocked on the user (permission / approval prompt).
# Generic "waiting for input" notifications clear the state file instead.
set -eu

DIR="$HOME/.claude-helper/sessions"
mkdir -p "$DIR"

PAYLOAD="$(cat)"
SID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty')"
[ -z "$SID" ] && exit 0

MSG="$(printf '%s' "$PAYLOAD" | jq -r '.message // empty')"

case "$MSG" in
    *permission*|*Permission*|*approve*|*Approve*|*allow*|*Allow*)
        TMP="$(mktemp "$DIR/.tmp.XXXXXX")"
        printf 'attention' >"$TMP"
        mv "$TMP" "$DIR/$SID.state"
        ;;
    *)
        rm -f "$DIR/$SID.state"
        ;;
esac
