#!/bin/sh
# PreToolUse hook (Agent|Workflow): the single enforcer of usage limits. It
# reads the snapshot the status line writes and BLOCKS (permissionDecision
# "deny") Agent and Workflow calls when a limit is reached:
#   - weekly (seven_day) usage >= USAGE_WEEKLY_STOP_AT (default 95)
#   - 5-hour usage >= USAGE_STOP_AT (default 95)
# Override: if the file ~/.claude/state/usage-override-<session_id> exists, the
# hook allows everything for that session. The deny message tells the model
# how to create it, only on an explicit instruction from the user.
#
# Fail open: this script always exits 0, and anything unexpected (missing or
# malformed file, no jq, a window that has already reset) prints nothing.
#
# Env overrides: USAGE_STATE_FILE, USAGE_STOP_AT, USAGE_WEEKLY_STOP_AT.
exec 2>/dev/null
input=$(cat)

command -v jq >/dev/null || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
ovr=""
if [ -n "$sid" ]; then
  ovr="$HOME/.claude/state/usage-override-$sid"
  [ -e "$ovr" ] && exit 0
fi

f="${USAGE_STATE_FILE:-$HOME/.claude/state/rate-limits.json}"
[ -r "$f" ] && [ -f "$f" ] || exit 0

out=$(jq -c \
  --argjson now "$(date +%s)" \
  --argjson stop "${USAGE_STOP_AT:-95}" \
  --argjson wstop "${USAGE_WEEKLY_STOP_AT:-95}" \
  --arg ovr "$ovr" '
  .ts as $ts
  | .rate_limits.five_hour as $h
  | .rate_limits.seven_day as $w
  | (if ($ts|type) == "number" and ($now - $ts) > 600
     then " Snapshot is \((($now - $ts) / 60) | floor) min old, so the real number is at least this."
     else "" end) as $stale
  | (if $ovr != ""
     then " Only if the user has explicitly told you in this session to override the limit: touch \($ovr) and retry."
     else "" end) as $note
  | (if ($w.used_percentage|type) == "number" and $w.used_percentage >= $wstop
        and (($w.resets_at|type) != "number" or $w.resets_at > $now)
     then "USAGE LIMIT: weekly usage is \($w.used_percentage | floor)% (limit \($wstop)%). Do not start Agent or Workflow work. Let in-flight work finish, then stop and tell the user you are waiting for instructions.\($stale)\($note)"
     elif ($h.used_percentage|type) == "number" and $h.used_percentage >= $stop
        and ($h.resets_at|type) == "number" and $h.resets_at > $now
     then "USAGE LIMIT: 5-hour usage is \($h.used_percentage | floor)% (limit \($stop)%), resets in \((($h.resets_at - $now) / 60) | ceil) min. Do not start Agent or Workflow work, and do not do the work yourself instead. Let in-flight work finish, then wait for the reset: run `sleep \($h.resets_at - $now + 120)` as a background Bash command (run_in_background: true) and continue the task when it completes.\($stale)\($note)"
     else empty end) as $msg
  | {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $msg}}
' "$f") || exit 0

[ -n "$out" ] && printf '%s\n' "$out"
exit 0
