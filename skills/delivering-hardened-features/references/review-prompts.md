# Review Prompts

Every reviewer in a round gets the same prompt, written to `PROMPT.md` in the review package.

- **Codex:** `codex exec -s read-only --ephemeral --skip-git-repo-check -C "$S" -m gpt-6.2-sol -c model_reasoning_effort="high" - < "$S/PROMPT.md" > "$S/codex.md" 2> "$S/codex.err"`,
  run in the background (see `consulting-codex`). For spec/plan gates, `$S` is a
  snapshot of the repo at the frozen SHA, the same as for code.
- **Opus:** Agent call with `model: "opus"`, pointing at `$S/PROMPT.md` and `$S`. It is
  the Spec/Plan slot and the substitute at every other gate.
- **Neon:** `cd "$S" && bash ~/.claude/skills/consulting-gemini/scripts/ask-gemini.sh --model gemini-4-neon-high --print-timeout 2400s < "$S/PROMPT.md" > "$S/neon.md" 2> "$S/neon.err"`,
  run in the background. Add "Do not run shell commands; use only your file-reading and
  search tools" to the header, or the run dies with exit 3.
- **Which outside reviewer:** Codex (Sol) or Neon, per Reviewer Slots in SKILL.md.
- **Unconfirmed findings from last round:** list them with your analysis and ask
  each reviewer to independently confirm or reject them, with a reason.

## Package layout

Every prompt has these parts, in order:
1. **Shared header** with the severity rubric **and its calibration** pasted verbatim
   from SKILL.md.
2. **Acceptance brief** — 5–15 lines: the user's request in their words (or a faithful
   paraphrase), settled decisions from `decision-log.md`, the **standing rulings** from `run-log.md`,
   and the spec/plan paths. For
   a PR: which plan tasks this PR covers, and the verification evidence so far.
3. **Gate checklist** (below).
4. **Round context** (Spec, Plan and Ship-readiness rounds 2–3: a full review with the
   fixes called out): last round's findings with their resolution, and the delta (the
   spec/plan diff or fix patch). Ask the reviewer to (a) confirm each fix, (b) hunt
   regressions the delta introduced, then (c) review the rest of the artifact with
   lighter weight. Keep effort `high`. The Per-PR round 2 uses the delta prompt below.

## Shared header

```
You are an adversarial reviewer for <feature> in <repo>. Find problems that would
hurt users or block shipping to beta; do not praise.
Do not spawn subagents. Do not edit any files.
This directory is a snapshot at <sha>. There is no .git; you cannot run tests — read.
Read the project's AGENTS.md/CLAUDE.md first; its rules are requirements.

Severity rubric:
<paste rubric and calibration>
Apply the calibration before rating anything P0 or P1; put the trace in Evidence.

Output: a list, most severe first. Per finding:
- Severity (P0/P1/P2/Nit)
- Location (file:line, or spec/plan section)
- The problem, in one or two sentences
- Evidence: the exact code/text, or an execution trace
- Suggested direction (not a full patch)
First line: "No P0/P1 findings." if that is true.
```

## Spec gate

```
Review the spec at <path> against the acceptance brief. Check:
- Does it solve the user's problem? Any requirement ambiguous enough that two
  implementers would build different things?
- Data model, schema, migration: is the upgrade path from every shipped version
  defined? What happens to existing user data?
- Sync / backend: what happens when another device or partner runs an older app
  version? Can the backend change deploy before the client ships?
- Edge cases: empty states, first run, offline, large data, multiple profiles,
  timezones — whatever applies.
- Is verification (tests + verification target + fixture) concrete enough to prove it works?
- Scope: anything to cut or defer?
```

## Plan gate

```
Review the plan at <path> against the spec at <spec path>. Check:
- Every spec requirement maps to a task; no task contradicts the spec.
- PR split: right count? Any PR mixing unrelated concerns, or too large to review in
  one sitting? Does each PR build and pass tests on its own base?
- Stack order: dependencies flow strictly downward.
- Each PR has a verification-target smoke and ends with the Per-PR Hardening Gate.
- Tests: TDD per task; integration tests for schema/migration/sync; every
  flavor/variant covered where behavior is flavor-sensitive.
- The plan ends with Finalization: cleanup, full verification pass naming the
  fixture, Ship-Readiness Review, finalization PR.
- File paths, symbols and commands are real — spot-check them.
```

## Per-PR gate

```
PR_DIFF.patch is this PR's full change against its base; the tree is the head.
Check:
- Correctness of changed logic, including error paths and lifecycle (dispose, async
  gaps, mounted checks, listener cleanup).
- Persistence: migrations, backup/restore, sync payloads — round-trip and upgrade safety.
- Tests: do they test behavior, would they fail without the change, are risky paths covered?
- Does the PR do what the plan says this PR does — no more, no less?
- Project rules (architecture constraints, file size limits, imports, doc-currency).
```

## Per-PR delta round (round 2)

Shared header and acceptance brief, then:

```
ROUND_FIXES.patch is the fix batch for round 1's P0/P1 findings, listed below with
their resolutions. The tree is the new head. Answer only:
1. For each finding: is it fixed? Quote the code that fixes it, or the path that
   still fails.
2. Did the fix batch break anything in the code it touched or in that code's
   direct callers?
Do not re-review the rest of the PR. If you trace into a P0 outside the fix batch,
report it under a separate heading "Outside the delta".
First line: "All fixes confirmed, no P0/P1 regressions." if that is true.
```

## Ship-readiness gate

Shared header + acceptance brief + the full `ship-readiness.md` checklist + the
Unresolved-at-cap list from `findings.md`, asking the reviewer to re-assess each.
