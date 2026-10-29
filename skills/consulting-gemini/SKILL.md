---
name: consulting-gemini
description: Use when asked to consult Gemini, Argon, Antigravity, or agy — a Gemini code review, plan review, spec review, second opinion, or design critique — or to hand a well-scoped implementation, refactor, or batch edit to Gemini; also when a second model family is wanted alongside or instead of codex. Covers driving the Antigravity CLI (agy) headlessly as a reviewer or an implementer.
---

# Consulting Gemini (Antigravity CLI)

## Overview

`agy` (Antigravity CLI, `~/.local/bin/agy`) runs Google's Gemini models, including
**Gemini 4 Argon**, the newest. It is a different model family from you, so it is useful as:

- **Reviewer:** an independent read on code, diffs, plans, and specs. It cannot change files.
- **Implementer:** a delegate that edits files in the workspace. It cannot run commands.

Everything here was verified on **agy 1.4.9** (`agy --version`). If the version has moved,
re-check any behavior you depend on.

## What agy can and can't do headlessly

`agy -p` (print mode) runs one turn non-interactively and exits. **Headless mode can't show
permission prompts, so any tool that would prompt is auto-denied.** A denial **ends the run**:
you get no output, and agy **still exits 0**. All the mode behavior below follows from that.

| Invocation | File reads (in workspace) | File edits | Shell commands | Use |
|---|---|---|---|---|
| no `--mode` (default) | yes | **denied** | **denied** (even `git status`) | **Reviewer** |
| `--mode accept-edits` | yes | yes | **denied** | **Implementer** |
| `--mode plan` | yes | no | no | Not usable: it writes a plan and waits for approval |
| `--mode auto` | | | | Not available on this account; it warns and falls back to default |
| `--sandbox` | adds no approvals on its own | | | |
| `--dangerously-skip-permissions` | everything | everything | everything | **Ask the user first.** Untested here. |

There is **no dedicated read-only flag.** Default headless mode works as one only while
`~/.gemini/antigravity-cli/settings.json` has no `permissions.allow` rules for `write_file` or
`command`. Check that file before you rely on it. The rule syntax is
`command(git diff)`, `write_file(src/)`, `read_file(/abs/path)`, with lists `allow`/`ask`/`deny`.
Never add rules yourself, because they apply globally, interactive use included. If a task
needs Gemini to run tests, ask the user whether to add a narrow rule like
`command(npm test)`.

Files outside the workspace are denied too (`read_file`). **The workspace is the current
directory,** so always `cd` into the repo first.

Practical consequence: **you run every command.** You run git, the tests, and builds, then put
the output (diffs, test failures) into the prompt. Gemini reads the source files itself.

## The wrapper: `scripts/ask-gemini.sh`

**Always call agy through the bundled wrapper.** It sends the prompt as stream-json on stdin,
which avoids shell quoting of backticks and `$` as well as the 1 MB argument limit on inlined
diffs. It also turns silent denials into real exit codes:

| Exit | Meaning |
|---|---|
| 0 | Response on stdout |
| 1 | CLI error (bad flag or model, auth). The error is on stderr |
| 3 | A tool was **denied** (stderr names it) or the response was empty. Re-prompt and tell Gemini not to use that tool |

The conversation id and any warnings go to stderr, so capture it in a separate `.err` file and
read both. `$SCRATCHPAD` means your session scratchpad directory. Set `AGY_LOG=<file>` to keep
the raw event stream.
All other arguments pass through to `agy`.

```bash
G=~/.claude/skills/consulting-gemini/scripts/ask-gemini.sh
cd /path/to/repo && bash "$G" --model gemini-4-argon-high --print-timeout 1200s \
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

`agy models` lists them. Choose effort either with a suffix (`gemini-4-argon-high`) or with
`--model gemini-4-argon --effort high`. **Don't combine a suffixed name with `--effort`.**
That's a hard error.

| Model | Use |
|---|---|
| `gemini-4-argon-high` | **Default reviewer:** code, plan, and spec review; design critique; hard implementation |
| `gemini-4-argon-medium` | **Default implementer:** features against a clear spec, refactors, tests. This is also the CLI default when `--model` is omitted |
| `gemini-4-argon-low` | Quick sanity checks, smoke tests |
| `gemini-3.8-flash-{low,medium,high}` | Cheap mechanical work: renames, boilerplate, summaries |

Argon supports **only `low`/`medium`/`high`**. `xhigh` and `max` fail with
`gemini-4-argon has no "xhigh" effort`. When `high` isn't enough, give it a sharper prompt or
use codex `xhigh`. `agy` also serves Claude models; don't use those here, since the point is a
different model family.

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
  --model gemini-4-argon-high --print-timeout 1200s > "$SCRATCHPAD/gemini-review.txt" 2> "$SCRATCHPAD/gemini-review.err"
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
  --mode accept-edits --model gemini-4-argon-medium --print-timeout 1800s \
  > "$SCRATCHPAD/gemini-impl.txt" 2> "$SCRATCHPAD/gemini-impl.err" <<'PROMPT'
Fix `median` in stats.py so even-length inputs return the average of the two middle
values and empty input raises ValueError. Add unittest cases to test_stats.py for both.
You cannot run shell commands in this session — any command attempt aborts the run. Use
only file read/edit tools; I will run `python3 -m unittest` myself. Edit only stats.py and
test_stats.py. Finish with a short summary of what you changed.
PROMPT
git status --short && git diff && python3 -m unittest
```

## Follow-ups

Use `--conversation <id>`, with the id from stderr, to continue a conversation. `-c` continues
the most recent one, but don't use it when other agy runs may have happened in between.
**Pass `--mode` and `--model` again on every call,** because mode is set per invocation.
A follow-up without `--mode accept-edits` is a reviewer again and can't edit.

```bash
bash "$G" --conversation <id> --model gemini-4-argon-high <<'PROMPT'
Finding 2 assumes the caller holds the lock — it does, see caller.ts:88. Does that change
your assessment?
PROMPT
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Raw `agy -p --model X "..."` | `-p` takes the next argument as its prompt, so this errors. Use the wrapper |
| `agy -p -` to read stdin | Sends the literal prompt `-`. Use the wrapper |
| Trusting exit 0 from raw `agy -p` | A denial exits 0 with no output. The wrapper exits 3 |
| Reviewer prompt that lets it run `git diff` | Commands are denied and the run dies. Inline the diff yourself and forbid commands |
| `--mode plan` for a review | It waits for plan approval that never comes. Use no `--mode` |
| Expecting the implementer to run tests | Commands are denied. You run them, or ask the user about a narrow allow rule |
| Adding `permissions.allow` rules yourself | They are global. Ask the user |
| `gemini-4-argon-high --effort high`, or `--effort xhigh` | A suffixed name can't take `--effort`, and Argon tops out at `high` |
| Running from the wrong directory | The workspace is the cwd. Files outside it are denied. `cd` first |
| Foreground run at `high` | Use `run_in_background: true` and set `--print-timeout` |
| Resuming without `--mode accept-edits` | The follow-up becomes read-only. Pass the mode every call |
| Treating findings or summaries as verdicts | Verify against the code, `git diff`, and the tests |
