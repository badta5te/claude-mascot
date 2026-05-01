#!/bin/sh
# Claude Code Notification hook. Default: assume the notification is
# something the user needs to act on (permission prompt, blocker) → attention.
# Only the explicit "waiting for input" idle notification clears state.
#
# Every payload is appended to ~/.claude-helper/notifications.log so the
# matching rules can be tuned to whatever messages Claude Code actually emits.
set -eu

DIR="$HOME/.claude-helper/sessions"
LOG="$HOME/.claude-helper/notifications.log"
mkdir -p "$DIR" "$(dirname "$LOG")"

PAYLOAD="$(cat)"
# NOT a real JSON parser — relies on Claude Code's payload shape (no escaped
# quotes in session_id or message). Avoids depending on jq.
SID="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$SID" ] && exit 0

MSG="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
printf '[%s] sid=%s msg=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$SID" "$MSG" >>"$LOG"

MSG_LC="$(printf '%s' "$MSG" | tr '[:upper:]' '[:lower:]')"

case "$MSG_LC" in
    *waiting\ for\ your\ input*|*waiting\ for\ input*|*awaiting\ input*|*idle*)
        rm -f "$DIR/$SID.state"
        ;;
    *)
        TMP="$(mktemp "$DIR/.tmp.XXXXXX")"
        printf 'attention' >"$TMP"
        mv "$TMP" "$DIR/$SID.state"
        ;;
esac
