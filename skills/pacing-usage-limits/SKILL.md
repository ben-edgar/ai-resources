---
name: pacing-usage-limits
description: Use during long or overnight autonomous runs, or before dispatching subagents, codex calls or other parallel work, to check how much of the 5-hour (and 7-day) Claude usage limit is used and pace accordingly — "don't hit my 5 hour limit", "check usage before dispatching", "pause at 97% and resume after the reset", "run overnight without hitting the limit".
---

# Pacing Usage Limits

## Overview

An agent session cannot query its own usage limit directly. The status line can: Claude Code
passes `rate_limits` to the status-line command on every render. The owner's
`~/.claude/statusline-command.sh` snapshots that into `~/.claude/state/rate-limits.json`:

```json
{"ts":1792584679,"rate_limits":{"five_hour":{"used_percentage":58,"resets_at":1792587000},"seven_day":{"used_percentage":42,"resets_at":1793080800}}}
```

`scripts/usage.sh` (in this skill's directory) reads it and prints one line:

```
<five_hour_pct> <resets_at_epoch> <secs_until_reset> <snapshot_age_s> <mode> <seven_day_pct>
58 1792587000 2347 12 normal 42
```

## The pacing rule (owner's)

| 5-hour usage | Mode | What to do |
|---|---|---|
| under 90% | `normal` | Run whatever the work needs: parallel agents and fan-out are fine. |
| 90–96% | `single` | At most one subagent at a time. Finish or wait on running ones before starting another. Be thoughtful before dispatching a chunky Opus task here: it can push past 97% mid-task. Prefer a smaller or cheaper task, or wait for the reset if it is close. |
| 97%+ | `pause` | Dispatch nothing new. Let running agents finish, then wait for the reset and resume. |

Codex (`codex exec`) does not draw on the Claude limit and is not counted.

## How to use it

1. **Before every dispatch** (Agent call, workflow, fan-out), run:
   ```sh
   bash ~/.claude/skills/pacing-usage-limits/scripts/usage.sh
   ```
   and apply the mode. Record the reading in the run log when the run keeps one.
2. **Check freshness.** The snapshot is only as fresh as the last status-line render. If
   `snapshot_age_s` is over ~600, treat the percentage as a floor, not a fact, and be more
   conservative (assume `single` when the stale value is 80%+).
3. **Pausing at 97%+.** Foreground `sleep` is blocked. Start a background wait that ends just after
   the reset; its completion re-invokes the session:
   ```sh
   # run_in_background: true
   S=$(bash ~/.claude/skills/pacing-usage-limits/scripts/usage.sh | awk '{print $3}'); sleep $((S + 120))
   ```
   Inside `/loop` dynamic mode, use `ScheduleWakeup` with `delaySeconds` = seconds until reset + 120
   (the runtime clamps to 3600; re-check and re-arm if the reset is further out). Log the pause and
   what will resume. On wake, re-run the script and confirm the mode is back to `normal` before
   dispatching.
4. **Thresholds** can be changed per run with `USAGE_SINGLE_AT` / `USAGE_PAUSE_AT` environment
   variables if the owner asks for different cut-offs.

## Setup (only if the snapshot file is missing)

If `usage.sh` prints `unknown`, the status line is not writing the snapshot. Add this near the top
of the status-line command script (after it reads stdin into `$input`), and make sure
`~/.claude/state/` exists:

```sh
# Snapshot rate-limit data so long-running agent sessions can pace themselves.
echo "$input" | jq -c '{ts: (now|floor), rate_limits}' > "$HOME/.claude/state/rate-limits.json.tmp" 2>/dev/null \
  && mv "$HOME/.claude/state/rate-limits.json.tmp" "$HOME/.claude/state/rate-limits.json"
```

Changing the status line is a settings change: confirm with the user first (or use the
`update-config` / `statusline-setup` helpers).

## Common mistakes

| Mistake | Fix |
|---|---|
| Checking once at the start of a long run | Check before **every** dispatch; usage climbs during the run. |
| Trusting a stale snapshot | Look at `snapshot_age_s`; a quiet terminal stops refreshing it. |
| Polling with short sleeps while paused | One background wait until `resets_at` + 2 min. |
| Killing running subagents at 97% | Let them finish; only stop starting new work. |
