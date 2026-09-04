---
name: pr-review-convergence-loop
description: Use when asked to iterate on PR review feedback until it converges - runs the addressing-pr-review-comments workflow in a loop, consulting codex to validate each finding and again to review each fix before pushing, and stops when only nits remain. Triggers on "keep addressing PR comments until clean", "loop on the PR review", "converge the PR", "iterate until the PR is approved", "keep fixing review comments until the reviewer is happy", "babysit the PR review", "get this PR to green", "address comments, push, and re-check until done". For a single pass over the current comments, use addressing-pr-review-comments instead.
---

# PR Review Convergence Loop

## Overview

Runs `addressing-pr-review-comments` on a loop until the reviewer stops finding
things worth fixing. Each round is bounded and verified; the loop's job is to
converge, not to grind.

**The premise: review findings are usually real, but their suggested fixes
frequently are not.** A reviewer sees the symptom from outside the codebase. It
proposes the fix a reader would reach for, which routinely breaks an invariant
it could not see. Codex is consulted twice per round to close that gap — once on
the finding, once on your fix.

## Required Companion Skills

- `addressing-pr-review-comments` — the per-round workflow, **with two
  amendments in loop mode**: skip the `pr_comment_plan.md` file and skip the
  wait-for-approval gate (its steps 5–7). The escalation rules in
  "Decide, And Say Why" below replace that gate — they are narrower and fire
  only when a decision is genuinely the user's. Everything else in that skill
  applies as written, including its resolution policy. Writing a plan file per
  round would litter the repo root with five of them.
- `consulting-codex` — exact CLI invocation. **Always `codex exec`, never bare
  `codex`** (bare launches a TUI and hangs forever).
- `test-driven-development` — every code fix is red-green.
- `verification-before-completion` — no success claim without a command's output.

## Round Budget

**Default 5 rounds.** The user can override with any number ("do 3 rounds",
"up to 10"). Announce the budget in your first message.

Stop early — do not spend the remaining budget — when any of these is true:

- No unresolved threads and no new review since your last push.
- Every remaining finding is a nit you have judged not worth fixing.
- The same finding returns after you have already explained why you rejected it.
- You are about to make a change you cannot verify.

Stopping early is the success case, not a shortfall. Announce which condition
you hit.

## Per-Round Workflow

### 1. Get The Current Feedback

**Round 1: fetch directly and skip the poll.** The feedback the user is pointing
at already exists; polling for something newer would time out against comments
that predate your cutoff.

**From your first push onward: poll.** The reviewer runs on push, so its verdict
on your last round does not exist at the moment you push. Record a UTC cutoff at
push time:

```bash
CUT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

Poll with `run_in_background: true` so the session stays responsive, at 45s
intervals with a ~30 min cap. Exit when either an unresolved thread or a review
by the reviewer account appears with a timestamp after `CUT`. See
`references/polling.md` for a ready-to-run script.

**Confirm the reviewer's actual `author.login` from an existing review on the PR
before the first poll**, and substitute it in the script. Do not assume
`claude` — a bot may appear as `claude[bot]`, `github-actions[bot]`, or
something else, and a wrong login silently misses body-only reviews and turns
every round into a 30-minute timeout.

Never claim a round found nothing until the poll has actually reported.

### 2. Fetch And Triage

Fetch unresolved review threads, top-level comments, and review bodies per
`addressing-pr-review-comments`. Only review threads can be resolved; top-level
comments and review bodies cannot.

**Read the code before forming an opinion.** Walk the exact sequence the finding
claims and decide for yourself whether it is reachable, so codex's answer is
checkable rather than authoritative.

### 3. Consult Codex On The Finding

One call per finding, or one per coherent group. Effort: `medium` for a
contained finding — narrower than a full diff review, hence below
`consulting-codex`'s `high` default — and `high` for concurrency, ordering,
caching, or anything touching a spec requirement.

Ask four things, in this order:

1. **Is the finding real?** Have it walk the exact code path and state the
   concrete triggering state or input, not a summary.
2. **Is the suggested fix correct *and* complete?** Ask separately about
   correctness and completeness — the usual failure is a fix that is correct in
   isolation and incomplete in context.
3. **What does the fix break?** Name candidates: unbounded recursion, a lost
   request, a dropped notification, a clock-domain mismatch, a spec requirement.
4. **What else is wrong here that neither of us named?**

Always close with: *"If you find nothing real, say so plainly — do not
manufacture findings."*

### 4. Decide, And Say Why

Verdict per finding: `valid`, `partially valid`, `not valid`, `non-actionable`.

You may accept the finding and reject its fix — that is the common case, not an
edge case. When you do, implement the fix that is actually right and explain the
divergence in the thread reply.

**Escalate to the user rather than deciding alone when the fix would:**

- add or change user-facing copy,
- trade off against a stated spec requirement,
- change behaviour the user has already made a call on,
- or expand well past the finding's own scope.

Give them the real options with the trade-off stated, and a recommendation. Do
not invent product decisions to keep the loop moving.

### 5. Fix With TDD

Red first, and confirm it is red *for the intended reason* — a compile error
because you added a constructor parameter is not a red test. If a test would
pass against the pre-fix code, say so plainly rather than presenting it as
proof. Some correct fixes (deleting a line, moving a declaration) have no honest
red test; name them.

One finding at a time, so test evidence stays attributable.

### 6. Verify, Then Commit

Run the project's full gate — formatter, analyzer, full test suite — and read
the output. Check the diff scope before staging: a repo-wide formatter run can
reformat files unrelated to your change, and those belong in their own commit,
not this PR.

Commit before the codex review, so its findings arrive as a separate diff.

### 7. Consult Codex On Your Fix — Before Pushing

This is the step that catches regressions you introduced. Same model and effort
rules as step 3. Point it at `git show HEAD` and ask:

1. Does the change introduce a regression — something that used to be caught,
   ordered, or bounded and now is not?
2. Are the new tests real regression tests, or would they pass against `HEAD^`?
3. Does it interact badly with anything downstream?

**Tell codex which decisions are settled.** If the user chose an approach it
argued against, say so and add *"Do not re-litigate that."* Otherwise it spends
the call re-arguing instead of reviewing.

Fix anything valid it finds as a separate follow-up commit (amend only if you
have not pushed), then verify again and push.

### 8. Reply And Resolve

Reply in-thread with: the verdict, every commit sha involved, what you did
*differently* from the suggestion and why, the tests, and anything you
deliberately left undone. A reply that says only "fixed in abc123" wastes the
reviewer's next pass.

Resolve the thread for `valid` and `partially valid` findings you fixed. For a
finding you rejected, resolve only if your reasoning fully closes the concern —
otherwise **leave it open and surface the disagreement to the user**. Resolving
a live disagreement hides it, and it also breaks the "same finding returns"
stop condition, since a resolved thread reappearing reads as a new finding.

Post top-level comments for review-body items, which cannot be resolved.

## Verifying Codex

Per `consulting-codex`, findings are hypotheses and citations need checking
against the actual code. The addition specific to this loop: **when codex
contradicts the reviewer, that is signal, not a tiebreak.** Both can be wrong.
You verify.

## Fallback When Codex Is Unavailable

If `codex exec` fails on usage limits or is not installed, spawn a fresh Opus
subagent as the reviewer with the same prompt, and **say in your summary that
codex was unavailable and which reviewer you used**. Never silently skip the
consultation — it is the step that makes this loop worth running.

## Final Summary

When the loop ends, report:

- Which stop condition you hit, and after how many rounds.
- Every commit, with one line on what it fixed.
- **Findings you rejected or deferred, and why.** This is the most valuable part
  of the summary — it is what the user cannot reconstruct from the diff.
- Where the suggested fix was wrong and what you did instead.
- Any thread left open, and the disagreement behind it.
- Whether codex was available throughout.
- Verification actually run, with counts.

## Red Flags

| Thought | Reality |
|---|---|
| "The reviewer suggested it, so I'll apply it" | The finding and the fix are separate claims. Validate both. |
| "Codex confirmed it, so it's real" | Check the cited lines yourself. |
| "I'll skip the post-fix review, the change is small" | That review is where introduced regressions surface. |
| "I'll write copy that seems reasonable" | User-facing copy is the user's call. Ask. |
| "The test passes, so the fix works" | Confirm it failed first, for the right reason. |
| "No new comments yet, so it's clean" | The review may not have run. Poll before concluding. |
| "I'll resolve it and note the disagreement in my summary" | Resolving hides it from the reviewer. Leave it open. |
| "I have budget left, so I should keep going" | Converged is done. Stop and summarize. |
| "I'll note the nits and fix them too" | Nits are why the loop ends, not more work to find. |
