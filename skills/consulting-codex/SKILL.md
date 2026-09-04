---
name: consulting-codex
description: Use when asked to review code, a diff, a PR, a plan, or a task result; to get a second opinion, sanity-check an approach, or cross-check work with another model; or to hand off a well-scoped implementation, refactor, migration, or batch edit to another agent — covers driving the codex CLI non-interactively as a reviewer or as an implementer.
---

# Consulting Codex

## Overview

The `codex` CLI (OpenAI Codex, `codex-cli`) is installed locally and runs a different model
family than you. That makes it useful in two distinct modes:

- **Reviewer** — an independent second opinion on code, diffs, and plans. Read-only.
- **Implementer** — a delegate that does well-scoped work in the workspace. Write-enabled.

**The modes have different sandboxes and are not interchangeable.** A reviewer that can write
will start "helpfully" fixing things you did not ask it to fix, and you lose the clean diff
that made the review checkable. Decide which mode you are in *before* you build the command.

| | Reviewer | Implementer |
|---|---|---|
| Sandbox | `-s read-only` **(mandatory)** | `-s workspace-write` |
| Model | `gpt-5.6-sol` | `gpt-5.6-luna` or `gpt-5.6-terra` |
| Output | Findings on stdout, back to you | Edits in the working tree |
| Writes files? | **No** — unless the user explicitly asked for a review file | Yes, that's the point |

## The Iron Rule: Always `codex exec`

**ALWAYS invoke codex as `codex exec` (or `codex exec review`). NEVER bare `codex`.**

Bare `codex` launches an interactive TUI. In an automated session that hangs forever and you
cannot recover it. No exceptions:

| Rationalization | Reality |
|---|---|
| "I'll just start it and type the prompt" | You cannot type. The TUI blocks and never returns. |
| "The prompt is short, bare codex is fine" | Length is irrelevant. Bare codex = TUI = hang. |
| "I need a back-and-forth conversation" | Use `codex exec resume --last`. Still non-interactive. |
| "I'll add a timeout as a safety net" | You still burn the timeout and get nothing back. |

## Deliver the Prompt on stdin

**Pass the prompt as a heredoc to `-`, not as a shell argument:**

```bash
codex exec -s read-only -m gpt-5.6-sol - <<'PROMPT'
Review src/auth/session.ts for correctness. Focus on `expiresAt` handling.
PROMPT
```

Review and implementation prompts are full of backticks, `$`, parentheses, and quotes. Inside
a double-quoted shell argument, backticks are **command substitution** — the shell silently
eats part of your prompt and codex acts on the mangled remainder. This is not hypothetical:
asking for `` `titlecase(text)` `` as a double-quoted argument produced a function named
`capitalize_words`, because the shell consumed the name before codex ever saw it.

Quoting the heredoc delimiter (`<<'PROMPT'`, with the quotes) turns off all expansion.

If you do pass a short prompt as an argument, single-quote it and redirect stdin:
`codex exec -s read-only 'short prompt with no backticks' < /dev/null`. Without a stdin
redirect codex waits on or absorbs stdin ("Reading additional input from stdin...").

## Shared Reference

| Flag | Purpose |
|---|---|
| `-s {read-only,workspace-write,danger-full-access}` | Sandbox policy. Set it explicitly, every time. |
| `-m <model>` | Model. See table below. |
| `-c model_reasoning_effort="..."` | Effort. **There is no `--effort` flag.** |
| `-C <dir>` | Working root, so codex reads/edits the right repo. |
| `--add-dir <dir>` | Extra writable directory alongside the workspace. |
| `--skip-git-repo-check` | Required when the target is not a git repo. |
| `--ephemeral` | Don't persist the session. Good for throwaway one-shots. |
| `-o <file>` | Write the final message to a file. **Opt-in only** — see Reviewer mode. |
| `--json` | JSONL event stream, for programmatic parsing. |

Progress streams to stdout; the final message is the last block. A bare `| tail -40` is
lossy: a thorough review's final message routinely runs longer than 40 lines, and the
truncation silently drops the *head* of the verdict (the "is it real" walkthrough) while
keeping the tail. Always capture the full stream to a scratch file and tail the file for
the immediate read, so the rest is still there when you need it:

```bash
codex exec ... - <<'PROMPT' 2>&1 | tee "$SCRATCHPAD/codex-<topic>.txt" | tail -40
...
PROMPT
```

The tee'd file is your working capture in the session scratchpad, not a review artifact
for the user — the "do not write files" reviewer rule below is about deliverables like
`REVIEW.md`, and does not apply to it. If the verdict looks clipped, read the file's tail
(`tail -150` of it) rather than re-running codex.

### Run It In The Background

**A codex call at `high` effort or above routinely runs past 10 minutes, and a foreground
Bash command is killed at that timeout — you lose the whole run.** Always start codex as a
background command (`run_in_background: true`), writing the full stream to the scratch file:

```bash
codex exec ... - <<'PROMPT' > "$SCRATCHPAD/codex-<topic>.txt" 2>&1
...
PROMPT
```

Then do other work, or poll the file (`tail -40 "$SCRATCHPAD/codex-<topic>.txt"`) until the
final message lands. Do not "just try it in the foreground first" — a timeout kill wastes the
entire run and you have to start over.

### Models

All three are GPT-5.6 variants and all accept every effort level.

| Model | Use it for |
|---|---|
| `gpt-5.6-sol` | **Reviews, and hard implementation.** Complex, open-ended, ambiguous work; architecture critique; intricate multi-file changes. Start here when unsure. |
| `gpt-5.6-terra` | **Default implementer.** Everyday work balancing reasoning with tool use: features against a clear spec, refactors, test writing, debugging with a known repro. |
| `gpt-5.6-luna` | **Mechanical implementer.** Clear, repeatable tasks with defined success criteria: renames, codemods, boilerplate, extraction, classification, structured summaries. Cheapest and fastest. |

### Effort Levels

Set with `-c model_reasoning_effort="<level>"`.

| Level | When |
|---|---|
| `minimal` / `low` | Quick, well-defined tasks. Mechanical edits, style checks, obvious bugs. |
| `medium` | Balanced default — routine diff review, a feature against a clear spec. |
| `high` | **Default for a real code review.** Multi-step problems with tradeoffs; cross-file correctness reasoning. |
| `xhigh` | Subtle correctness — concurrency, protocol/state machines, security-sensitive paths. |
| `max` | Hardest problems, depth over speed. Slow and expensive; reserve it. |
| `ultra` | Divisible complex tasks — codex fans out to parallel subagents. Whole-feature or whole-PR sweeps, not a single file. |

`none` and `minimal` also exist at the API level; treat `low` as the practical floor.

---

# Mode 1: Reviewer

**Core principle: a reviewer with fresh eyes beats a reviewer with a stake in the answer.**
When you review your own work you check whether it matches your intent. Codex checks whether
it matches reality.

Consult codex as a reviewer when the user asks for a review or a second opinion, when you
just finished a non-trivial implementation and are about to declare it done, when you are
stuck and out of hypotheses, or before an expensive-to-reverse design decision.

Skip it for trivial changes, when tests haven't been run yet (run them first — codex is not
verification), or when the user asked *you* to do the review.

## Reviewer Rules

**1. `-s read-only`. Always.** A reviewer must not touch the working tree. Without it codex
will start editing the very code you asked it to assess, and you can no longer tell its
changes from yours.

**2. Return the findings to yourself — do not write files.** The review is an answer to the
question you asked, delivered on stdout for you to read, evaluate, and relay. Do **not** pass
`-o`, and do **not** instruct codex to write `REVIEW.md` or similar, unless the user
explicitly asked for a review file. Use `-o <path>` only in that case, at the path they asked
for. Default to leaving no artifacts behind.

**3. Answer the question that was asked.** If the user asked about the retry logic, report on
the retry logic. Don't return a general audit because codex volunteered one — mention extras
briefly, but lead with what was asked.

| Rationalization | Reality |
|---|---|
| "I'll write it to a file so it's easier to read" | The user asked for a review, not a file. Read stdout. |
| "A scratch file isn't really an artifact" | Files you didn't announce are files the user has to find and clean up. |
| "workspace-write lets it fix what it finds" | Then the review and the fix arrive tangled together and neither is checkable. |
| "It found other problems, I'll report those instead" | Lead with the answer to the question asked. Extras go after. |

## Reviewing a Diff: the `review` subcommand

`codex exec review` is purpose-built — it assembles the diff, file contents, tree, and git log
for you, and returns prioritized findings. It is read-only by nature.

```bash
codex exec review --uncommitted -m gpt-5.6-sol -c model_reasoning_effort="high" < /dev/null
codex exec review --base main   -m gpt-5.6-sol -c model_reasoning_effort="high" < /dev/null
codex exec review --commit <sha> < /dev/null
```

**The diff-selector flags (`--base`, `--uncommitted`, `--commit`) cannot be combined with a
custom PROMPT** — `codex exec review --base main - <<'PROMPT'` fails with "the argument
'--base <BRANCH>' cannot be used with '[PROMPT]'". To focus a review of a specific diff range,
use plain `codex exec` and name the range in the prompt (codex runs git itself):

```bash
codex exec -s read-only -m gpt-5.6-sol -c model_reasoning_effort="high" - <<'PROMPT'
Review the diff `git diff main..HEAD` (run it yourself).
Focus on error handling and resource cleanup.
PROMPT
```

Findings come back tagged with priority and a `file:line` anchor:

```
- [P2] Average the two middle values for even inputs — .../math.py:9-9
  When `nums` has an even number of elements, this returns only the upper middle value
  rather than the conventional median, so `median([1,2,3,4])` returns 3 instead of 2.5.
```

Use `codex exec review` for anything diff-shaped. Use plain `codex exec` for questions that
aren't a diff — design critique, "is this approach sound", checking a debugging hypothesis.

## Writing the Review Prompt

The prompt is a brief for a reviewer who has never seen this codebase and doesn't know what
you were trying to do. In this order:

1. **The goal** — what the change is supposed to accomplish.
2. **The scope** — which files or which diff.
3. **The specific worry** — what you actually want checked, if you have one.
4. **The verdict format** — findings ranked by severity, each with `file:line` and a concrete
   failure scenario; and an explicit "nothing found" if there's nothing.

Ask for concrete failure scenarios, not opinions. "Give inputs and state that produce the
wrong output" yields verifiable claims; "what do you think of this code" yields prose.

```bash
codex exec -s read-only -m gpt-5.6-sol -c model_reasoning_effort="high" - <<'PROMPT'
Review src/auth/session.ts. Goal: sessions expire exactly 30 min after last activity,
across server restarts. I'm most worried about clock handling and the restart path.
Report findings ranked most-severe first; for each give file:line and a concrete
failure scenario (inputs/state -> wrong outcome). If you find nothing real, say so —
do not manufacture findings.
PROMPT
```

## After a Review

1. **Check every finding against the actual code yourself.** Codex hallucinates like any
   model. A finding that cites a line is not proof the line says what it claims.
2. **Report faithfully.** Relay what it found, including findings you disagree with and why.
   Don't silently drop inconvenient ones or adopt ones you can't verify.
3. **Don't rubber-stamp.** "Codex says it's fine" is not verification. Tests are.

See `superpowers:receiving-code-review` for evaluating feedback rather than obeying it.

---

# Mode 2: Implementer

Delegate to codex when the work is **well-scoped and independently verifiable**: a feature
with a clear spec, a mechanical refactor across many files, a codemod, filling in test
coverage, or a migration with a known target shape. Good candidates are ones where you can
state the success criteria up front and check them afterward.

Don't delegate exploratory work, anything where the requirements are still being discovered,
or changes tangled up with context that only exists in this conversation. Handing over a
vague task produces plausible code aimed at the wrong target.

## Implementer Rules

**1. `-s workspace-write`,** plus `-C <dir>` to pin the working root and `--add-dir` for any
extra writable path. `danger-full-access` and `--dangerously-bypass-approvals-and-sandbox`
disable the sandbox entirely — don't reach for them; ask the user first if you think you need
them.

**2. Pick the model by how much judgment the task needs:** `luna` for mechanical work with an
unambiguous target, `terra` for real features and refactors, `sol` only when the
implementation itself is genuinely hard.

**3. Work on a clean tree.** Commit or stash first, so codex's changes arrive as a reviewable
diff instead of mixed into yours.

**4. Give it the success criteria, not just the task.** State what "done" means — which tests
pass, which command exits zero, what the signature must be.

**5. Verify the diff yourself afterward.** `git diff`, then run the tests. Codex reporting
success is a claim, not evidence — and it may have touched files you didn't expect.

```bash
codex exec --sandbox workspace-write -C /path/to/repo -m gpt-5.6-terra \
  -c model_reasoning_effort="medium" - <<'PROMPT'
Add a `titlecase(text)` function to src/strings.py that capitalizes the first letter
of each word, leaving the rest of each word unchanged. Add tests in tests/test_strings.py
covering empty strings, single words, and multiple spaces.
Done means: `pytest tests/test_strings.py` passes. Edit only those two files.
PROMPT

git diff --stat && pytest tests/test_strings.py
```

Scoping the file set in the prompt ("edit only those two files") keeps the diff reviewable
and makes an out-of-scope change an obvious signal rather than a surprise.

## Follow-ups

Sessions persist, so you can push back or iterate without re-explaining context:

```bash
codex exec resume --last - <<'PROMPT'
Finding 2 assumes the caller holds the lock — it does, see caller.ts:88.
Does that change your assessment?
PROMPT
```

`--last` takes the most recent session for the current directory; `codex exec resume <id>`
targets a specific one. A resumed session keeps its original sandbox mode — resuming a review
will not let it start writing.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Running bare `codex` | Always `codex exec`. The TUI hangs forever. |
| Running codex in the foreground | The 10-minute Bash timeout kills long runs. Start it with `run_in_background: true` and poll the output file. |
| Prompt as a double-quoted argument | Backticks become command substitution. Use `- <<'PROMPT'`. |
| Argument prompt with no stdin redirect | Codex waits on or absorbs stdin. Add `< /dev/null`. |
| Omitting `-s read-only` on a review | Codex edits your tree mid-review and the diff stops being checkable. |
| Passing `-o` on a routine review | Leaves an artifact nobody asked for. Read stdout; use `-o` only when a review file was requested. |
| Using `--effort` or `--reasoning` | Neither exists. It's `-c model_reasoning_effort="..."`. |
| Piping a diff into plain `codex exec` | Use `codex exec review --base <branch>` — better context than you can assemble. |
| Defaulting to `max`/`ultra` | Slow and expensive. `high` handles nearly every review. |
| Delegating a vague task to an implementer | Plausible code aimed at the wrong target. Scope it and state success criteria. |
| Trusting the implementer's success report | Read `git diff` and run the tests. |
| Treating findings as verdicts | They're hypotheses. Verify each against the code. |
