#!/bin/sh
# Reads the usage-limit snapshot the status line writes and prints one line:
#   <five_hour_pct> <five_hour_resets_at> <secs_until_reset> <snapshot_age_s> <mode> <seven_day_pct>
# mode: normal (<90), single (90-96), pause (>=97). Thresholds can be
# overridden with USAGE_SINGLE_AT / USAGE_PAUSE_AT.
# Prints "unknown 0 0 0 normal unknown" when no snapshot exists yet.
f="${USAGE_STATE_FILE:-$HOME/.claude/state/rate-limits.json}"
single_at="${USAGE_SINGLE_AT:-90}"
pause_at="${USAGE_PAUSE_AT:-97}"
[ -f "$f" ] || { echo "unknown 0 0 0 normal unknown"; exit 0; }
now=$(date +%s)
jq -r --argjson now "$now" --argjson single "$single_at" --argjson pause "$pause_at" '
  .rate_limits.five_hour as $h
  | ($h.used_percentage // 0) as $p
  | [ $p, ($h.resets_at // 0), (($h.resets_at // $now) - $now), ($now - (.ts // $now)),
      (if $p >= $pause then "pause" elif $p >= $single then "single" else "normal" end),
      (.rate_limits.seven_day.used_percentage // "unknown") ]
  | map(tostring) | join(" ")' "$f"
