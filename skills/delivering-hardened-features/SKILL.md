---
name: delivering-hardened-features
description: Use when the user wants an agreed feature idea turned into a reviewed spec and then, on go-ahead, carried through to hardened PRs — "use the hardened feature skill", "spec this out and get it reviewed", "run the full feature pipeline", "I'm going to bed, keep going until the feature is done", "harden this before it gets to me". Not for single bugfixes, a one-off PR, or addressing comments on an existing PR.
---

# Delivering Hardened Features

## Overview

Takes a feature from an agreed idea to a PR or stack of PRs that could ship to beta
users as soon as the user finds no product or UX problems. Every artifact — spec,
plan, each PR — passes bounded rounds of independent review by two model families
(codex `gpt-6.1-sol` and an Opus subagent) before the next stage starts. The user's
job at the end is product judgment, not bug hunting.

**Core rule: no stage advances on an unreviewed artifact, and no review loop runs
unbounded.** Every gate is mandatory. "It looks small" and "the reviewers will just
nit" are the rationalizations this skill exists to stop.

**REQUIRED SUB-SKILLS:** `superpowers:brainstorming`, `superpowers:writing-plans`,
`superpowers:subagent-driven-development`, `consulting-codex`; `gh-stack` when the
plan yields more than one PR. Their user-approval steps are overridden as described
in Dependency Adaptations.

## Modes

Pick the mode from the user's words. Record it in `run-log.md`.

| Mode | Trigger | Behavior |
|---|---|---|
| **Checkpoint** (default) | Anything not clearly autonomous | Run through the Spec gate, stop, present the spec and open product/UX questions. After the user's go-ahead, run every remaining phase as Autonomous. |
| **Autonomous** | "I'm going to bed", "keep going", "run it to the end", "don't wait for me" | Run end to end. Make judgment calls yourself; log each in `decision-log.md`. Never stop to ask; stop only for Hard Stops. |

**Hard stops (both modes):** merging any PR; production deploys (`npm run deploy:prod`
or the project's equivalent); force-pushing a branch you did not create; deleting
data or remote branches; release signing. Log what you would have done and continue
with everything that does not depend on it. (A dirty working tree at Intake that
isn't yours is different: stop and ask — nothing can proceed without it.) Non-production deploys (debug/staging backends, local emulators) are
allowed when verification needs them.

## Severity Rubric

Paste this verbatim into every reviewer prompt. Every finding gets one level.

| Level | Meaning |
|---|---|
| **P0** | Data loss or corruption, crash, broken migration or sync, security/privacy hole, backwards-incompatible change that breaks existing users. |
| **P1** | Wrong behavior, missing or contradicted requirement, missing test for risky logic (migration, sync, persistence, concurrency), broken build/analyze/tests. |
| **P2** | Should fix: maintainability, unclear naming, missing edge-case test for low-risk logic. |
| **Nit** | Style, wording, preference. |

You classify each finding after checking it against the code or document:
- **Refuted** — the claim is false (misread, wrong line, behavior already handled). Log a one-line reason. Only refuted findings may be dropped.
- **Confirmed** or **Unconfirmed** — keep it. Static reasoning and a concrete execution trace count as evidence; "I couldn't reproduce it" does not refute a plausible P0/P1.

You may downgrade a reviewer's severity only with a written reason. An open
(confirmed or unconfirmed) P0/P1 is open, whether or not you intend to fix it.
An unconfirmed finding becomes refuted when both reviewers in the next round,
shown the finding and your analysis, independently reject it with a stated reason
(cite both in `findings.md`).

## The Review Loop (every gate)

Cap: **3 rounds per gate.** Each round:

1. **Freeze the input.** Run the project's local gates (format, analyze, tests),
   commit everything, and require a clean tree. Record the head SHA (and base SHA
   for code). Reviewers only ever see a committed SHA — never the working tree.
2. **Build the review package** (`references/review-prompts.md`): acceptance brief,
   artifact, and for rounds 2–3 the prior findings with resolutions and the delta.
3. **Dispatch both reviewers in parallel** under the Worker Contract below: codex
   `gpt-6.1-sol` at `high` and an Opus subagent. Record both in `run-log.md` (output
   paths, SHA) before waiting.
4. **Wait, bounded.** A reviewer counts only when it returns a usable findings list.
   Each reviewer slot gets at most three attempts of 45 minutes each: the original,
   one retry (SendMessage nudge for Opus, re-run for codex), then a fresh Opus
   substitute with the same package. A codex usage-limit error skips straight to the
   substitute — limit resets are hours away. After three failures the slot is
   **unavailable** for this round: proceed with the one review you have, and log it.
   Log every substitution.
5. **Append every finding to `findings.md`** before changing anything. Classify.
6. **Decide:**
   - **No open P0/P1 → the gate passes at this SHA.** No further round. What happens
     to remaining P2s/nits depends on the gate: **Spec/Plan** — apply cheap ones now
     (the next gate reads the edited file). **Per-PR** — do not edit the PR; record
     them as finalization-branch work. **Ship-readiness** — do not edit; list them in
     the handoff. The SHA that passed is the SHA that ships.
   - **Open P0/P1 and rounds remain →** fix them (plus cheap P2s in the same batch)
     and start the next round.
   - **Open P0/P1 after round 3 →** fix what you can, re-run local gates, and mark
     each as **Unresolved at cap** — "unfixed" or "fixed, unconfirmed by review". Do
     not run a 4th round. What happens next depends on the gate (below).

**At cap, by gate:**
- **Spec / Plan:** Autonomous — make an explicit ruling on each open item, log it as
  `needs sign-off`, proceed. Checkpoint — bring them to the user.
- **Per-PR:** open the PR anyway; list the items in the PR body.
- **Ship-readiness:** push and open the finalization PR anyway, list the items in
  its body; the handoff verdict is Blocked.
- **All gates:** carry every Unresolved-at-cap item into the Ship-Readiness Review
  and the final report. Code changed after a gate's last review round is
  "fixed, unconfirmed" — it counts as open.

**Deadlines for everything else.** Every build, test run and device/verification task
gets a deadline (60 minutes for builds and test suites, 90 for a verification-target
session) and one retry. When both fail, kill it, record the failure with its log
path, and treat the affected check as not passed.

## Worker Contract

Applies to every dispatched worker — reviewers, implementers, fixers, verifiers,
fallbacks, and workers a sub-skill dispatches for you.
- Every Agent call sets `model` explicitly (`haiku`/`sonnet`/`opus` per the user's
  tiers; never `fable` — it needs the user's say-so, which an unattended run
  can't get). Codex calls set `-m` and effort explicitly.
- Every brief, codex prompts included, says: "Do not spawn subagents."
- Reviewer briefs add: "Do not edit any files."
- Build/test/device briefs add: start long commands in the background and poll the
  log with foreground loops under 10 minutes each; never end the turn to wait for a
  notification; return only with the complete result.

## Dependency Adaptations

- **brainstorming:** in Autonomous mode, answer its questions yourself from the
  conversation and the codebase; each answer is a decision-log entry. Its "user
  reviews the spec" wait is replaced by the Spec gate (plus, in Checkpoint mode,
  the stop after it).
- **writing-plans:** its plan-review wait is replaced by the Plan gate. Skip its
  execution-choice prompt; always use subagent-driven-development.
- **subagent-driven-development:** work in the current checkout on the PR's branch —
  skip its worktree setup unless the project allows worktrees and the user asked.
  Keep its per-task reviews. Its final whole-branch review is replaced by the
  Per-PR Hardening Gate, and its finishing step (`finishing-a-development-branch`)
  by Phases 4–6 of this skill.
- **PR comments:** do not use `addressing-pr-review-comments` or
  `pr-review-convergence-loop` here — their plan-file and approval steps stall an
  unattended run. Use `references/pr-feedback.md`.

## Run State

At start (or on resume) use `.reviews/<feature-slug>/` in the repo root. Make sure
it is ignored: if `.gitignore` doesn't cover it, add `.reviews/` to the file at
`git rev-parse --git-path info/exclude`.

- `run-log.md` — mode, base branch + SHA, stack table, phase checklist, every
  dispatch (output path, SHA), current status. **Update after every dispatch,
  completed review, fix commit and verification**, not just at phase changes.
- `decision-log.md` and `findings.md` — templates in `references/run-log-template.md`.
- Review snapshots go in the scratchpad (they are regenerable from recorded SHAs).

**Resume:** if `.reviews/<slug>/run-log.md` exists, read it first. Reconcile with
reality — `git log`, existing branches, `gh pr list` — then continue from "Current
status". Background notifications from a previous session never arrive: check each
recorded output path; re-run any reviewer whose output is missing or incomplete.

## Phases

### 1. Intake
- Read the project's agent instructions (`AGENTS.md`/`CLAUDE.md`). Record in
  `run-log.md`: format/analyze/test commands, test conventions, doc-currency rules,
  backend deploy commands, fixture tooling, and the **verification target**:
  - mobile app → simulator/emulator via the project's documented run path (required);
  - web app → a real browser session; CLI → scripted scenarios against a built
    binary; service → its integration/emulator environment.
- Base branch = the repo's default branch (`gh repo view --json defaultBranchRef`)
  unless the user named one. Fetch it; record its SHA.
- Working tree must be clean. If it holds changes that aren't yours, stop and ask.
- Create PR 1's branch from the base. Spec and plan commits live on PR 1's branch;
  squash or reword their WIP commits before PR 1 opens.

### 2. Spec
- `superpowers:brainstorming`. The spec must state: user-visible behavior; data,
  schema and migration path; sync/backend changes; compatibility with existing
  installs and older app versions; how it will be verified on the verification
  target, including any fixture needed.
- **Gate:** Review Loop on the spec.
- **Checkpoint mode stops here.** Present: spec path, a 5-line summary, open
  product/UX questions, decisions made, any Unresolved-at-cap items.

### 3. Plan
- `superpowers:writing-plans`. Per PR, the plan **must** contain:
  - scope and tasks, sized for subagent-driven-development;
  - base branch and why the split falls where it does;
  - tests: TDD per task, integration tests for any schema/migration/sync change,
    coverage of every flavor/variant for flavor-sensitive behavior;
  - a **verification-target smoke** of this PR's user-visible flows;
  - the **Per-PR Hardening Gate** as its final task.
- The plan **must** end with the Finalization phase (Phase 5 below).
- **Gate:** Review Loop on the plan. Reviewers also judge: right number of PRs
  (none mixing unrelated concerns; ~4,000 changed non-generated lines, tests included, is a soft guide, not a cap — keeping related work together beats hitting a number, and splitting well below it just to stay small is its own smell),
  correct stack order (each PR builds and passes tests on its own base), gates present.

### 4. Implement and harden each PR — strictly one at a time, in stack order
PR N+1 starts only after PR N is open. For each PR:
1. Branch from the previous PR's branch (PR 1: already created).
2. Implement with `superpowers:subagent-driven-development` under the Worker Contract.
3. Local gates green. Run the **verification-target smoke** for this PR's flows; fix
   what it finds. Save screenshots/evidence to `.reviews/<slug>/evidence/` named with
   the SHA they show. A PR with no user-visible flow (migration-only, backend-only):
   record "no UI flows" in `run-log.md` and skip the smoke.
4. **Per-PR Hardening Gate:** Review Loop on `base...head`. Snapshot per round:
   ```sh
   S=<scratchpad>/<slug>/pr<N>-r<round>; mkdir -p "$S"
   git archive <head-sha> | tar -x -C "$S"
   git diff <base-sha>...<head-sha> > "$S/PR_DIFF.patch"
   git diff <prev-round-sha>..<head-sha> > "$S/ROUND_FIXES.patch"   # rounds 2-3
   codex exec -s read-only --ephemeral --skip-git-repo-check -C "$S" \
     -m gpt-6.1-sol -c model_reasoning_effort="high" - < "$S/PROMPT.md"
   ```
   Tell reviewers the snapshot has no `.git` and cannot run tests.
5. If a gate fix touched a user-visible flow, re-run that flow's smoke before the
   next round's freeze.
6. Push the SHA that passed (or the capped SHA) and open the PR (stacked via
   `gh-stack` when N > 1). The PR body lists any Unresolved-at-cap items. Record the
   pushed SHA in `run-log.md`. Do not wait for PR bots — move on.

### 5. Finalization (after the last feature PR is open)
All changes in this phase go on one **finalization branch** on top of the stack,
which becomes the "Ship-readiness fixes" PR. Never push new commits to an
already-reviewed PR, except under the Owning-PR Exception.

1. **Cleanup:** create the finalization branch. Apply the P2/nit work recorded at
   per-PR gates. If the project requires `/simplify`, commit everything, run it over
   `base...top`, then re-run local gates.
2. **Full verification pass** on the verification target, every changed flow, every
   flavor/variant if flavor-sensitive. Fix what it finds on the finalization branch.
3. **Ship-Readiness Review** — Review Loop over `base...finalization-head` using
   `references/ship-readiness.md`, which includes every Unresolved-at-cap item. This
   loop is also the finalization branch's hardening gate, and it reviews any
   Owning-PR Exception fixes (they are inside `base...finalization-head`). Each round:
   1. freeze (local gates, commit, record SHA). If the finalization branch has
      commits, push it; open the finalization PR the first time it has any;
   2. in parallel: both reviewers on the frozen SHA, and the **PR feedback sweep**
      per `references/pr-feedback.md` — poll only PRs pushed since the last poll
      (including the finalization PR), then fetch feedback for every open PR;
   3. triage everything into `findings.md`; apply **one** fix batch; local gates;
      re-run any affected flow on the verification target. The next round reviews it.
   If the finalization branch never gets a commit, record "finalization PR not needed".
4. **Final evidence:** confirm the verification-target evidence covers the final top
   SHA for every changed flow; re-run any flow whose code changed since its evidence.

**Owning-PR Exception.** Fix in the earlier PR itself — not the finalization branch —
when the defect makes that PR unsafe or broken if merged alone: a P0, or a failing
build/analyze/test on that PR's own base. Then restack with `gh-stack`
(force-pushing your own branches is fine) and re-run local gates on every
descendant. The fix and its effect on descendants are reviewed by the next
Ship-Readiness round; if no round remains, they are "fixed, unconfirmed". Log why.

### 6. Handoff
**Ready** means all of: no open P0/P1 anywhere (Unresolved-at-cap and "fixed,
unconfirmed" included); every gate's final round had two usable reviews
(substitutes count); verification-target evidence on the final top SHA; local
gates green on every PR; every expected PR bot reviewed every PR's current head
with no open blocking item. If everything holds except that some bots never
reported, the verdict is **Ready pending bots** (name them). Otherwise **Blocked**,
with the reasons.

Report, in this order:
1. **Verdict:** Ready for product/UX review, Ready pending bots, or Blocked (on what).
2. PR stack with links, one line each, plus the final top SHA.
3. **Unresolved items** — every P0/P1 still open or unconfirmed, with current status.
4. **Decisions** — `needs sign-off` entries from the decision log, then a link to the full log.
5. Verification run: commands, results, SHAs; verification-target flows covered.
6. Ship-readiness notes: deploy order, migration notes, anything the user must do
   before beta (e.g. deploy functions to production first).
7. Bot threads left open, and why.
8. What to look at on a real device — the 3–6 flows most worth the user's eyes, with screenshots.
9. Reviewer substitutions and any gate skipped, with reason.

## Quick Reference

| Gate | Input | Max rounds | Passes when | At cap |
|---|---|---|---|---|
| Spec | spec @ SHA | 3 | round with no open P0/P1 | ruling + `needs sign-off` (Autonomous) / ask (Checkpoint) |
| Plan | plan @ SHA | 3 | same | same |
| Per-PR | PR diff snapshot @ SHA | 3 per PR | same | open PR, list items in body |
| Ship-readiness | base...finalization @ SHA + PR bots | 3 | same | open finalization PR, verdict Blocked |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Running another round after a clean round "to be safe" | A round with no open P0/P1 ends the gate. |
| Reviewing uncommitted code | Freeze: local gates, commit, clean tree, record SHA — then review that SHA. |
| Starting PR N+1 while PR N is still in its gate | Strictly sequential. |
| Only one reviewer because the other is slow | Both, every round. Hung or limited → retry once, then a second Opus. |
| Dropping a finding because you couldn't reproduce it | Only refuted findings drop. |
| Downgrading a P1 to P2 to pass the gate | Downgrades need a written reason; an unfixed P1 is still open. |
| Fixing findings before writing them down | Append to `findings.md` first. |
| Pushing fixes, `/simplify` output or "cheap nits" to an already-reviewed PR | Finalization branch, unless the Owning-PR Exception applies. |
| Sweeping bot comments right after pushing | Bounded poll first; report bots that never ran. |
| Skipping verification-target testing because tests pass | Required per PR and again on the final SHA. |
| Asking the user a question in Autonomous mode | Decide, log as `needs sign-off`, continue. |
| Calling the result Ready with Unresolved-at-cap items open | That's Blocked. Say what's blocking. |
