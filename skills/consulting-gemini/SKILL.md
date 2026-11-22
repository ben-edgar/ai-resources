---
name: consulting-gemini
description: Use when asked to consult Gemini, Neon, Hydrogen, Argon, Antigravity, or agy — a Gemini code review, plan review, spec review, second opinion, or design critique — or to hand a well-scoped implementation, refactor, or batch edit to Gemini, including runs where Gemini executes commands itself (Auto mode); also when a second model family is wanted alongside or instead of codex. Covers driving the Antigravity CLI (agy) headlessly as a read-only reviewer, an edits-only implementer, or an Auto-mode agent.
---

# Consulting Gemini (Antigravity CLI)

## Overview

`agy` (Antigravity CLI, `~/.local/bin/agy`) runs Google's Gemini models, including
**Gemini 4 Neon**, the newest, **Gemini 4 Hydrogen**, and **Gemini 4 Argon**. These three
frontier models are the only ones to consult. It is a different model family from you, so it is useful as:

- **Reviewer** (read-only): an independent read on code, diffs, plans, and specs. It cannot
  change files or run commands.
- **Implementer** (`accept-edits`): a delegate that edits files in the workspace. It cannot run
  commands.
- **Auto agent** (`--mode auto`): edits files and runs commands in a sandbox, so it can run the
  tests itself and iterate.

Everything here was verified on **agy 1.5.7** (`agy --version`); Neon (added in 1.5.12) and
the denial check were re-verified on **1.5.12**. If the version has moved,
re-check any behavior you depend on, starting with the denial check under "Auto mode" below.

## What agy can and can't do headlessly

`agy -p` (print mode) runs one turn non-interactively and exits. **In Default mode, headless
runs can't show permission prompts, so any tool that would prompt is auto-denied.** A denial **ends the run**:
you get no output, and agy **still exits 0**. All the mode behavior below follows from that.

| Invocation | File reads (in workspace) | File edits | Shell commands | Use |
|---|---|---|---|---|
| no `--mode` (default) | yes | **denied** | **denied** (even `git status`) | **Reviewer** |
| `--mode accept-edits` | yes | yes | **denied** | **Implementer** |
| `--mode plan` | yes | no | no | Not usable: it writes a plan and waits for approval |
| `--mode auto` | yes | yes, workspace only | yes, in the terminal sandbox (no network) | **Auto agent** (Mode 3). Also what a bare `agy -p` gets on 1.5.7+; see below |
| `--sandbox` | adds no approvals on its own | | | |
| `--dangerously-skip-permissions` | everything | everything | everything | **Ask the user first.** Untested here. |

### Auto mode is the headless default since 1.5.7

agy 1.5.7 changed the default agent mode to **Auto** for every session with no saved mode,
headless `-p` runs included. A bare `agy -p` with no `--mode` now **runs shell commands and
writes files without asking** (verified with both Argon and Hydrogen, inside and outside the
repo; `--sandbox` doesn't stop it). The wrapper below pins the old Default mode per call with
`--settings '{"agentMode":""}'`, which is session-only and never saved. With it, the table above
holds: no `--mode` denies commands and writes (exit 3), and `--mode accept-edits` edits but
can't run commands. The pin also blocks Auto (commands are denied even with `--mode auto`), so
the wrapper drops it when you pass `--mode auto`. It also drops it when you pass your own
`--settings`, so include `"agentMode":""` in yours unless you want Auto. Never call raw
`agy -p` for a review.

To re-check after an upgrade, from an empty scratch directory: ask the wrapper (no `--mode`) to
run `ls -1` and expect exit 3 with `DENIED tool(s): command`.

There is **no dedicated read-only flag.** Default headless mode works as one only while
`~/.gemini/antigravity-cli/settings.json` has no `permissions.allow` rules for `write_file` or
`command`. Check that file before you rely on it. The rule syntax is
`command(git diff)`, `write_file(src/)`, `read_file(/abs/path)`, with lists `allow`/`ask`/`deny`.
Never add rules yourself, because they apply globally, interactive use included. If a task
needs Gemini to run tests, ask the user whether to add a narrow rule like
`command(npm test)`.

Files outside the workspace are denied too (`read_file`). **The workspace is the current
directory,** so always `cd` into the repo first.

Practical consequence in read-only and accept-edits modes: **you run every command.** You run
git, the tests, and builds, then put the output (diffs, test failures) into the prompt. Gemini
reads the source files itself. In Auto mode Gemini runs them (Mode 3).

## The wrapper: `scripts/ask-gemini.sh`

**Always call agy through the bundled wrapper.** It sends the prompt as stream-json on stdin,
which avoids shell quoting of backticks and `$` as well as the 1 MB argument limit on inlined
diffs. It also turns silent denials into real exit codes:

| Exit | Meaning |
|---|---|
| 0 | Response on stdout |
| 1 | CLI error (bad flag or model, auth). The error is on stderr |
| 3 | A tool was **denied** (stderr names it) or the response was empty. Re-prompt and tell Gemini not to use that tool |

It also pins Default mode (see "Auto mode" above).
The conversation id and any warnings go to stderr, so capture it in a separate `.err` file and
read both. `$SCRATCHPAD` means your session scratchpad directory. Set `AGY_LOG=<file>` to keep
the raw event stream.
All other arguments pass through to `agy`.

```bash
G=~/.claude/skills/consulting-gemini/scripts/ask-gemini.sh
cd /path/to/repo && bash "$G" --model gemini-4-neon-high --print-timeout 1200s \
  > "$SCRATCHPAD/gemini-<topic>.txt" 2> "$SCRATCHPAD/gemini-<topic>.err" <<'PROMPT'
...prompt...
PROMPT
```

To inline a diff, build the prompt with a command group so nothing is shell-escaped:
`{ cat <<'PROMPT' ... PROMPT; git diff main...HEAD; } | bash "$G" ...`

**Run it with `run_in_background: true`** for anything past a trivial prompt. `--print-timeout`
defaults to 0 (wait forever), and a foreground Bash call dies at 10 minutes. A small review
takes about 25s at `high`. A large diff can take many minutes.

## Models and effort

`agy models` lists them. Choose effort either with a suffix (`gemini-4-neon-high`) or with
`--model gemini-4-neon --effort high`. **Don't combine a suffixed name with `--effort`.**
That's a hard error.

| Model | Use |
|---|---|
| `gemini-4-neon-high` | **Default reviewer:** code, plan, and spec review; design critique |
| `gemini-4-neon-xhigh` | Subtle correctness (concurrency, state machines, security paths), or when a `high` review comes back thin |
| `gemini-4-neon-{low,medium}` | Quick review sanity checks. Use when the user asks for Neon outside review |
| `gemini-4-hydrogen-high` | Hard implementation; second reviewer or fallback if Neon is unavailable or out of quota |
| `gemini-4-hydrogen-xhigh` | Hardest implementation tasks; fallback for Neon `xhigh` reviews |
| `gemini-4-hydrogen-medium` | **Default implementer:** features against a clear spec, refactors, tests |
| `gemini-4-hydrogen-low` | Quick sanity checks, smoke tests |
| `gemini-4-argon-{low,medium,high}` | The older frontier model. Use when the user asks for Argon, or as a fallback if Neon and Hydrogen are unavailable or out of quota. `gemini-4-argon-medium` is still the CLI default when `--model` is omitted, so always pass `--model` |

Consult only Neon, Hydrogen, and Argon. `agy models` also lists Flash, orchestrators
(including `gemini-pro-orchestrator-neon`), Claude and GPT-OSS models; don't use them here.

Neon and Hydrogen support `low`/`medium`/`high`/`xhigh`; there is no `max`
(`gemini-4-neon-max` and `gemini-4-hydrogen-max` are rejected as unknown models). Argon supports **only
`low`/`medium`/`high`**; `xhigh` fails with `gemini-4-argon has no "xhigh" effort`. When
Neon `xhigh` isn't enough, give it a sharper prompt, get a second read from Hydrogen `xhigh`, or
use codex `xhigh`.

---

# Mode 1: Reviewer (no `--mode`)

Use this when the user asks Gemini for a review or a second opinion, before declaring a
non-trivial change done, before an expensive-to-reverse design decision, or when you're stuck.
Skip it for trivial changes, and run the tests first. Gemini is not verification.

**The review prompt has these parts, in order:**
1. **Role and tools:** "You are a read-only reviewer. Do not run shell commands or edit
   files. Read any files in this repo with your file tools." Without this line it often
   tries `git diff` and the run dies with exit 3.
2. **Goal:** what the change, plan, or spec is supposed to achieve.
3. **Scope:** for a diff, inline it (you ran `git diff`). For a plan or spec, give its
   workspace-relative path, or inline it if it lives outside the repo.
4. **The worry:** what you specifically want checked.
5. **Verdict format:** findings ranked most-severe first, each with `file:line` and a
   concrete failure scenario (inputs/state → wrong outcome). If nothing is real, say so
   instead of manufacturing findings.

```bash
cd /path/to/repo && { cat <<'PROMPT'
You are a read-only code reviewer. Do not run shell commands or edit files; use only your
file-reading and search tools. Read any other files in this repo you need.
Goal: sessions expire exactly 30 min after last activity, across server restarts.
Worry: clock handling and the restart path.
Report findings ranked most-severe first, each with file:line and a concrete failure
scenario. If you find nothing real, say so — do not manufacture findings.
The diff under review (`git diff main...HEAD`):
PROMPT
git diff main...HEAD; } | bash ~/.claude/skills/consulting-gemini/scripts/ask-gemini.sh \
  --model gemini-4-neon-high --print-timeout 1200s > "$SCRATCHPAD/gemini-review.txt" 2> "$SCRATCHPAD/gemini-review.err"
```

For a plan or spec review, swap the goal and scope: "Review docs/plan.md against
docs/spec.md. Find gaps, contradictions, unstated assumptions, and steps that can't be
verified." Gemini reads both files itself.

**After the review:**
1. Check every finding against the actual code yourself. Gemini hallucinates too, and a
   finding with a line number is still only a claim.
2. Report faithfully: lead with the answer to the question asked, include the findings you
   disagree with, and say why.
3. Don't write review files unless the user asked for one. The scratchpad capture is for
   you. See `superpowers:receiving-code-review`.

---

# Mode 2: Implementer (`--mode accept-edits`)

Delegate to Gemini when the work is well-scoped and independently checkable. Don't hand it
exploratory work, or work that depends on context that only exists in this conversation.

**Rules:**
1. **Start from a clean tree** (commit or stash) so Gemini's changes arrive as a reviewable diff.
   If the code being fixed is itself uncommitted and you may not commit, run
   `git diff > "$SCRATCHPAD/pre-gemini.diff"` first so you can separate its changes from what was already there.
2. **Tell it that it cannot run commands.** Say that "any command attempt aborts the run" and
   that you will run `<test command>` yourself. Without this it tries to run the tests and dies
   (exit 3). Edits made before the denial stay on disk, so check `git status` either way.
3. **Name the files it may edit** and state what "done" means: which tests must pass, the
   signatures, the behavior.
4. **Verify the result yourself:** run `git status`, `git diff`, and the tests. Its summary is
   a claim, not evidence.
5. **Iterate by resuming.** Paste the failing test output into a follow-up on the same
   conversation.

```bash
cd /path/to/repo && bash ~/.claude/skills/consulting-gemini/scripts/ask-gemini.sh \
  --mode accept-edits --model gemini-4-hydrogen-medium --print-timeout 1800s \
  > "$SCRATCHPAD/gemini-impl.txt" 2> "$SCRATCHPAD/gemini-impl.err" <<'PROMPT'
Fix `median` in stats.py so even-length inputs return the average of the two middle
values and empty input raises ValueError. Add unittest cases to test_stats.py for both.
You cannot run shell commands in this session — any command attempt aborts the run. Use
only file read/edit tools; I will run `python3 -m unittest` myself. Edit only stats.py and
test_stats.py. Finish with a short summary of what you changed.
PROMPT
git status --short && git diff && python3 -m unittest
```

---

# Mode 3: Auto agent (`--mode auto`)

Use this when Gemini should run the check itself and iterate: implement, run the tests, fix,
rerun. Verified on agy 1.5.7 through the wrapper:

- **Edits** inside the workspace are approved. A write outside it is denied (exit 3).
- **Commands** run in the terminal sandbox. It has **no network** (`curl` fails), so anything
  that downloads (`flutter pub get`, `npm install`, first-time Gradle) fails. Fetch dependencies
  yourself first.
- Auto mode's own review may still deny a command that would leave the sandbox. That ends the
  run with exit 3, like any other denial.

**Rules:**
1. Everything in Mode 2's rules still applies, except rule 2: name the exact check it must run
   (`flutter test test/foo_test.dart`) and tell it to keep going until it passes, then paste the
   output into its summary.
2. **Start from a clean tree** and verify with your own `git status`, `git diff` and rerun of
   the check. Its test output is a claim until you rerun it.
3. Tell it what it must **not** run: no `git commit`/`push`/`reset`/`stash`, no `pkill` or
   `killall`, no deploys. The sandbox limits where it writes, not what it does to the repo.
4. Pass `--mode auto` on every follow-up too. Without it, the wrapper pins Default mode again.
5. Don't use Auto for a review. A reviewer that can write starts fixing things, and you lose
   the clean diff.

```bash
cd /path/to/repo && bash ~/.claude/skills/consulting-gemini/scripts/ask-gemini.sh \
  --mode auto --model gemini-4-hydrogen-medium --print-timeout 1800s \
  > "$SCRATCHPAD/gemini-auto.txt" 2> "$SCRATCHPAD/gemini-auto.err" <<'PROMPT'
Fix `median` in stats.py so even-length inputs return the average of the two middle
values and empty input raises ValueError. Add unittest cases to test_stats.py for both.
Edit only stats.py and test_stats.py. Run `python3 -m unittest` and keep going until it
passes. Do not run git commands other than `git status`/`git diff`, and do not kill
processes. Finish with a short summary and the final test output.
PROMPT
git status --short && git diff && python3 -m unittest
```

## Follow-ups

Use `--conversation <id>`, with the id from stderr, to continue a conversation. `-c` continues
the most recent one, but don't use it when other agy runs may have happened in between.
**Pass `--mode` and `--model` again on every call,** because mode is set per invocation.
A follow-up without `--mode accept-edits` or `--mode auto` is a reviewer again and can't edit.

```bash
bash "$G" --conversation <id> --model gemini-4-neon-high <<'PROMPT'
Finding 2 assumes the caller holds the lock — it does, see caller.ts:88. Does that change
your assessment?
PROMPT
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Raw `agy -p --model X "..."` | `-p` takes the next argument as its prompt, so this errors. Use the wrapper |
| Raw `agy -p` on 1.5.7+ for a review | It starts in Auto mode and can run commands and edit files. The wrapper pins Default mode |
| Your own `--settings` without `"agentMode":""` | The wrapper drops its pin when you pass `--settings`; the run is in Auto mode again |
| `agy -p -` to read stdin | Sends the literal prompt `-`. Use the wrapper |
| Trusting exit 0 from raw `agy -p` | A denial exits 0 with no output. The wrapper exits 3 |
| Reviewer prompt that lets it run `git diff` | Commands are denied and the run dies. Inline the diff yourself and forbid commands |
| `--mode auto` for a review | It can edit and run commands. Use no `--mode` |
| Auto mode run that needs the network | The sandbox has none. Fetch dependencies first, or run that step yourself |
| `--mode plan` for a review | It waits for plan approval that never comes. Use no `--mode` |
| Expecting the `accept-edits` implementer to run tests | Commands are denied. You run them, or use Auto mode (Mode 3) |
| Adding `permissions.allow` rules yourself | They are global. Ask the user |
| `gemini-4-neon-high --effort high`, or Argon at `xhigh` | A suffixed name can't take `--effort`. Argon tops out at `high`, Neon and Hydrogen at `xhigh` |
| Running from the wrong directory | The workspace is the cwd. Files outside it are denied. `cd` first |
| Foreground run at `high` | Use `run_in_background: true` and set `--print-timeout` |
| Resuming without `--mode accept-edits` | The follow-up becomes read-only. Pass the mode every call |
| Treating findings or summaries as verdicts | Verify against the code, `git diff`, and the tests |
