# Review Prompts

Both reviewers get the same prompt, written to `PROMPT.md` in the review package.

- **Codex:** `codex exec -s read-only --ephemeral --skip-git-repo-check -C "$S" -m gpt-6.1-sol -c model_reasoning_effort="high" - < "$S/PROMPT.md" > "$S/codex.md" 2> "$S/codex.err"`,
  run in the background (see `consulting-codex`). For spec/plan gates, `$S` is a
  snapshot of the repo at the frozen SHA, the same as for code.
- **Opus:** Agent call with `model: "opus"`, pointing at `$S/PROMPT.md` and `$S`.
- **Unconfirmed findings from last round:** list them with your analysis and ask
  each reviewer to independently confirm or reject them, with a reason.

## Package layout

Every prompt has these parts, in order:
1. **Shared header** with the severity rubric pasted verbatim from SKILL.md.
2. **Acceptance brief** — 5–15 lines: the user's request in their words (or a faithful
   paraphrase), settled decisions from `decision-log.md`, and the spec/plan paths. For
   a PR: which plan tasks this PR covers, and the verification evidence so far.
3. **Gate checklist** (below).
4. **Round context** (rounds 2–3 only): last round's findings with their resolution,
   and the delta (`ROUND_FIXES.patch`, or the spec/plan diff). Ask the reviewer to
   (a) confirm each fix, (b) hunt regressions the delta introduced, then (c) review
   the rest of the artifact with lighter weight. Keep effort `high`.

## Shared header

```
You are an adversarial reviewer for <feature> in <repo>. Find problems that would
hurt users or block shipping to beta; do not praise.
Do not spawn subagents. Do not edit any files.
This directory is a snapshot at <sha>. There is no .git; you cannot run tests — read.
Read the project's AGENTS.md/CLAUDE.md first; its rules are requirements.

Severity rubric:
<paste rubric>

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

## Ship-readiness gate

Shared header + acceptance brief + the full `ship-readiness.md` checklist + the
Unresolved-at-cap list from `findings.md`, asking the reviewer to re-assess each.
