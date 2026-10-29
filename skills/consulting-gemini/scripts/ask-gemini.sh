#!/usr/bin/env bash
# Run one headless Antigravity (agy) turn with the prompt read from stdin.
#
#   bash ask-gemini.sh [agy flags...] < prompt.txt
#
# Why a wrapper:
#   - stdin delivery: no shell-quoting of backticks/$, no 1 MB ARG_MAX limit on inline diffs.
#   - agy exits 0 even when a tool was auto-denied and the run produced nothing.
#     This script turns that into a nonzero exit with a clear message.
#
# stdout: the final response text.
# stderr: conversation id (for --conversation follow-ups) and any warnings/errors.
# If AGY_LOG is set, the raw stream-json event log is written there.
#
# Exit: 0 ok | 1 agy/CLI error | 3 a tool was denied or the response was empty.
set -uo pipefail

log="${AGY_LOG:-$(mktemp -t agy-stream.XXXXXX)}"

jq -Rsc '{event:"user",message:{role:"user",content:.}}' \
  | agy "$@" --input-format stream-json --output-format stream-json -p '' > "$log" 2>&1
agy_status=$?

result=$(grep '"event":"result"' "$log" | tail -1)
if [[ -z "$result" ]]; then
  echo "ask-gemini: no result event (agy exit $agy_status). Last log lines:" >&2
  tail -5 "$log" >&2
  exit 1
fi

jq -r '.result.response' <<<"$result"
echo "ask-gemini: conversation_id=$(jq -r '.result.conversation_id' <<<"$result")" >&2

status=$(jq -r '.result.status' <<<"$result")
if [[ "$status" != "SUCCESS" ]]; then
  echo "ask-gemini: status=$status error=$(jq -r '.result.error // ""' <<<"$result")" >&2
  exit 1
fi

denied=$(jq -r '[.result.denied_actions[]?.action] | join(",")' <<<"$result")
if [[ -n "$denied" ]]; then
  echo "ask-gemini: DENIED tool(s): $denied — the run stopped there; the response above is partial or empty." >&2
  exit 3
fi
if [[ -z "$(jq -r '.result.response' <<<"$result" | tr -d '[:space:]')" ]]; then
  echo "ask-gemini: empty response." >&2
  exit 3
fi
