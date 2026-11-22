---
name: delivering-hardened-features
description: Use when the user wants an agreed feature idea turned into a reviewed spec and then, on go-ahead, carried through to hardened PRs — "use the hardened feature skill", "spec this out and get it reviewed", "run the full feature pipeline", "I'm going to bed, keep going until the feature is done", "harden this before it gets to me". Not for single bugfixes, a one-off PR, or addressing comments on an existing PR.
---

# Delivering Hardened Features

## Overview

Takes a feature from an agreed idea to a PR or stack of PRs that could ship to beta
users as soon as the user finds no product or UX problems. Every artifact — spec,
plan, each PR — passes bounded rounds of independent review by at least two model families
(who reviews what is in Reviewer Slots) before the next stage starts. The user's
job at the end is product judgment, not bug hunting.

**Core rule: no stage advances on an unreviewed artifact, and no review loop runs
unbounded.** Every gate is mandatory. A gate is a review of a committed SHA, not a full test
run — the full test suites run at Finalization (see Checks). "It looks small" and "the reviewers will just
nit" are the rationalizations this skill exists to stop.

**REQUIRED SUB-SKILLS:** `superpowers:brainstorming`, `superpowers:writing-plans`,
`superpowers:subagent-driven-development`, `consulting-codex`, `consulting-gemini`; `gh-stack` when the
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

**Calibration** — part of the rubric: paste it with the table, and apply it yourself
when classifying.
- A P0/P1 needs a trace: the steps one user on one device takes, through code or
  text this change adds or modifies, to the wrong outcome. No trace → P2 at most.
- Behavior that predates the change and that the change does not make worse → P2,
  marked `pre-existing`.
- Needs two devices or two users acting at the same moment → P2.
- Affects only clients, app versions or deploy states that the acceptance brief's
  standing rulings put out of scope → P2.
- Layout or overflow that appears only at the largest text scale or on the smallest
  screen → P2.
- A missing test with no defect shown → P2. The P1 row's exception stands: untested
  migration, sync, persistence or concurrency logic.

You classify each finding after checking it against the code or document:
- **Refuted** — the claim is false (misread, wrong line, behavior already handled). Log a one-line reason. Only refuted findings may be dropped.
- **Confirmed** or **Unconfirmed** — keep it. Static reasoning and a concrete execution trace count as evidence; "I couldn't reproduce it" does not refute a plausible P0/P1.

You may downgrade a reviewer's severity only with a written reason. A reviewer's
P0/P1 that fails the calibration is downgraded, and the calibration line is the
written reason. An open
(confirmed or unconfirmed) P0/P1 is open, whether or not you intend to fix it.
An unconfirmed finding becomes refuted when every reviewer in the next round,
shown the finding and your analysis, independently rejects it with a stated reason
(cite each in `findings.md`).

## Reviewer Slots

Outside reviewers: **Sol** (codex `gpt-6.2-sol` at `high`) and **Neon**
(`gemini-4-neon-high` via `consulting-gemini`). The Claude reviewer is an Opus
subagent at `high`.

| Gate | Round 1 | Later rounds |
|---|---|---|
| Spec, Plan | Opus + Neon | Full review. Round 2: Opus + Sol. Round 3: Opus + Neon. |
| Per-PR | Sol + Neon | One delta round: Sol. |
| Ship-readiness | Sol + Neon | Full review: Sol + Neon. |

- **One-reviewer rounds** (Spec, Plan, Ship-readiness): when the previous round had
  no P0 and every P1 was a local fix with no design change, the next round runs one
  reviewer — the outside reviewer the table lists for that round at Spec/Plan, Sol
  at Ship-readiness. It reviews the full artifact with the previous round's fixes
  called out. A P0, or a P1 whose fix changed the design, keeps the round at full slots.
- **Per-PR delta round:** gets Sol + Neon instead of Sol alone when round 1 had a P0
  or a P1 whose fix changed the design.
- **Opus at code gates is the substitute, not a slot.** Claude models wrote the code,
  a same-family reviewer mostly repeats the outside reviewers there, and Claude quota
  runs out first.
- Sol traces code paths; Neon checks a document against many files. A user
  instruction naming reviewers overrides this table.

## Checks

Two levels. Take the commands from the project's agent instructions.

- **Affected checks** — format, analyze/lint/typecheck, the tests for the changed
  files and for the files that import them, the integration or emulator suites of
  any changed persistence, sync or backend area, and the project's guard tests that
  scan the source or test tree. Run them before every freeze and after every fix
  batch. Fix agents run them for their own batch and report the output.
- **Full gate** — every test suite of every codebase the stack changed, plus the
  opt-in suites the project requires for this kind of change (screenshot, rules,
  emulator shards). Run it at the first Ship-readiness freeze, then on the final top
  SHA for each codebase changed since its last full run. Not per PR, not per round.
  A single-PR feature follows the project's per-branch rule when it has one: run the
  full gate before that PR's first push, and count it as the first full run.

Run the full gate in the background alongside the reviewers, in a spare checkout
detached at the SHA when the project has one. Re-run a failing test on its own
before treating it as real: full runs under load produce flakes. A real failure is
fixed on the finalization branch.

## The Review Loop (every gate)

Cap: **3 rounds per gate; 2 for a Per-PR gate** (one full round, one delta round). Each round:

1. **Freeze the input.** Run the affected checks (Checks),
   commit everything, and require a clean tree. Record the head SHA (and base SHA
   for code). Reviewers only ever see a committed SHA — never the working tree.
2. **Build the review package** (`references/review-prompts.md`): acceptance brief,
   artifact, and for later rounds the prior findings with resolutions and the delta
   (the Per-PR delta round uses its own prompt).
3. **Dispatch the round's reviewers in parallel** (Reviewer Slots) under the Worker
   Contract below. Record each in `run-log.md` (output paths, SHA) before waiting.
4. **Wait, bounded.** A reviewer counts only when it returns a usable findings list.
   Each reviewer slot gets at most three attempts of 45 minutes each: the original,
   one retry (SendMessage nudge for Opus, re-run for the outside reviewer), then a
   substitute with the same package: an outside reviewer not already in this round,
   else a fresh Opus. A usage-limit error skips straight to the
   substitute — limit resets are hours away. After three failures the slot is
   **unavailable** for this round: proceed with the reviews you have, and log it.
   Log every substitution.
5. **Append every finding to `findings.md`** before changing anything. Classify.
6. **Decide:**
   - **No open P0/P1 → the gate passes at this SHA.** No further round. What happens
     to remaining P2s/nits depends on the gate: **Spec/Plan** — apply cheap ones now
     (the next gate reads the edited file). **Per-PR** — do not edit the PR; P2s and
     nits stay in `findings.md` for the Finalization triage. **Ship-readiness** — do
     not edit; list them in the handoff. The SHA that passed is the SHA that ships.
   - **Open P0/P1 and rounds remain →** fix them and only them — P2s and nits wait
     for the Finalization triage (at Spec/Plan, cheap P2 text edits may ride along) —
     and start the next round.
   - **Open P0/P1 after the gate's last round →** fix what you can, run the affected
     checks, and mark each as **Unresolved at cap** — "unfixed" or "fixed,
     unconfirmed by review". Do not run another round. What happens next depends on
     the gate (below).

**Per-PR delta round.** Round 2 of a Per-PR gate reviews the fix batch, not the PR.
The reviewer gets `ROUND_FIXES.patch`, round 1's findings with their resolutions,
and the head tree, and answers two questions: is each P0/P1 fixed, and did the fix
batch break anything it touched? The gate passes when every fix is confirmed and no
regression is P0/P1. Otherwise fix, run the affected checks, mark the items
Unresolved at cap ("fixed, unconfirmed by review") and open the PR. If the delta
reviewer reports a new P0/P1 in code the fix batch did not touch, classify it: a P0
is fixed now and marked "fixed, unconfirmed"; a P1 becomes a Ship-readiness
carry-over. Neither starts a third round.

**At cap, by gate:**
- **Spec / Plan:** Autonomous — make an explicit ruling on each open item, log it as
  `needs sign-off`, proceed. Checkpoint — bring them to the user.
- **Per-PR:** open the PR anyway; list the items in the PR body.
- **Ship-readiness:** push and open the finalization PR anyway, list the items in
  its body; the handoff verdict is Blocked.
- **All gates:** carry every Unresolved-at-cap item, and every Ship-readiness
  carry-over (new P1s from delta rounds), into the Ship-Readiness Review
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
- **Fix batches:** Sonnet at `high`, one batch per area (server, app, docs) holding
  only that area's findings, so no agent carries the whole round. Opus at `high`
  only for a batch containing a finding about concurrency, lifecycle or races,
  persistence, migration or sync, or a fix that changes the design. Each brief lists
  its findings by ID, names the affected checks to run, and requires a test that
  fails without the fix. Batches running in parallel touch disjoint files, format
  only their own paths and commit with a pathspec.
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
  Per-task reviews run only for (a) tasks the plan tags `risk: high`, reviewed one
  tier above the implementer (Opus at most) at `medium` effort, and (b) every Haiku-implemented
  task, reviewed by Sonnet. For every other task, skip the task review: read the
  implementer's report and the diff stat, and confirm the named check ran and a
  mutation went red. The Per-PR gate reviews that code. Task-review P2s and nits go
  to `findings.md`; they do not get their own fix dispatch. Its final whole-branch
  review is replaced by the Per-PR Hardening Gate, and its finishing step
  (`finishing-a-development-branch`) by Phases 4–6 of this skill.
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
- Also record the **standing rulings** — what the user, the project's instructions
  or memory have already ruled out of scope or low priority (unsupported app
  versions, beta compatibility, multi-device races). They go into every acceptance
  brief. Record whether the project has a spare checkout for the full gate.
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
  - tasks each tagged `risk: high` or `risk: normal` — high means persistence,
    migration, sync, concurrency or lifecycle, or a non-trivial algorithm;
  - tests: TDD per task, integration tests for any schema/migration/sync change,
    coverage of every flavor/variant for flavor-sensitive behavior;
  - a **verification-target smoke** of this PR's user-visible flows;
  - the **Per-PR Hardening Gate** as its final task.
- The plan **must** end with the Finalization phase (Phase 5 below).
- **Gate:** Review Loop on the plan. Reviewers also judge: right number of PRs
  (none mixing unrelated concerns; ~4,000 changed non-generated lines, tests included, is a soft guide, not a cap — keeping related work together beats hitting a number, and splitting well below it just to stay small is its own smell),
  correct stack order (each PR builds, analyzes clean and passes its affected checks on its own base), gates present.

### 4. Implement and harden each PR — strictly one at a time, in stack order
PR N+1 starts only after PR N is open. For each PR:
1. Branch from the previous PR's branch (PR 1: already created).
2. Implement with `superpowers:subagent-driven-development` under the Worker Contract.
3. Affected checks green. Run the **verification-target smoke** for this PR's flows; fix
   what it finds. Save screenshots/evidence to `.reviews/<slug>/evidence/` named with
   the SHA they show. A PR with no user-visible flow (migration-only, backend-only):
   record "no UI flows" in `run-log.md` and skip the smoke.
4. **Per-PR Hardening Gate:** Review Loop on `base...head`. Snapshot per round:
   ```sh
   S=<scratchpad>/<slug>/pr<N>-r<round>; mkdir -p "$S"
   git archive <head-sha> | tar -x -C "$S"
   git diff <base-sha>...<head-sha> > "$S/PR_DIFF.patch"
   git diff <prev-round-sha>..<head-sha> > "$S/ROUND_FIXES.patch"   # round 2 (delta)
   codex exec -s read-only --ephemeral --skip-git-repo-check -C "$S" \
     -m gpt-6.2-sol -c model_reasoning_effort="high" - < "$S/PROMPT.md"
   ```
   Round 1 runs Sol and Neon on the same snapshot (the Neon command is in
   `references/review-prompts.md`). Tell reviewers the snapshot has no `.git` and
   cannot run tests.
5. If a gate fix touched a user-visible flow, re-run that flow's smoke before the
   PR opens.
6. Push the SHA that passed (or the capped SHA) and open the PR (stacked via
   `gh-stack` when N > 1). The PR body lists any Unresolved-at-cap items and Ship-readiness carry-overs, and
   says the full test gate runs on the stack top. Record the
   pushed SHA in `run-log.md`. Do not wait for PR bots — move on.

### 5. Finalization (after the last feature PR is open)
All changes in this phase go on one **finalization branch** on top of the stack,
which becomes the "Ship-readiness fixes" PR. Never push new commits to an
already-reviewed PR, except under the Owning-PR Exception.

1. **Triage and cleanup:** create the finalization branch. Fix the Ship-readiness carry-over P1s from the
   Per-PR delta rounds first (fix-batch rule), so round 1 does not start with a known
   open P1. Triage the P2s and nits
   recorded in `findings.md`: fix those with a user-visible effect and those that
   break a project rule (doc currency, size limits, architecture constraints); list
   the rest in the handoff as not fixed, one line each. Dispatch the fixes under the
   fix-batch rule. If the project requires `/simplify`, commit everything, run it
   over `base...top`, then re-run the affected checks.
2. **Full verification pass** on the verification target, every changed flow, every
   flavor/variant if flavor-sensitive. Fix what it finds on the finalization branch.
3. **Ship-Readiness Review** — Review Loop over `base...finalization-head` using
   `references/ship-readiness.md`, which includes every Unresolved-at-cap item. This
   loop is also the finalization branch's hardening gate, and it reviews any
   Owning-PR Exception fixes (they are inside `base...finalization-head`). Each round:
   1. freeze (affected checks, commit, record SHA). If the finalization branch has
      commits, push it; open the finalization PR the first time it has any. Round 1
      also starts the full gate at this SHA (Checks);
   2. in parallel: the round's reviewers on the frozen SHA, and the **PR feedback sweep**
      per `references/pr-feedback.md` — poll only PRs pushed since the last poll
      (including the finalization PR), then fetch feedback for every open PR;
   3. triage everything into `findings.md`; apply **one** set of fix batches (fix-batch
      rule); affected checks; re-run any affected flow on the verification target. The next round reviews it.
   If the finalization branch never gets a commit, record "finalization PR not needed".
4. **Final evidence:** confirm the verification-target evidence covers the final top
   SHA for every changed flow; re-run any flow whose code changed since its evidence. Run the final full gate on
   the top SHA for each codebase changed since its last full run.

**Owning-PR Exception.** Fix in the earlier PR itself — not the finalization branch —
when the defect makes that PR unsafe or broken if merged alone: a P0, or a build or
analyze failure on that PR's own base. Then restack with `gh-stack`
(force-pushing your own branches is fine) and re-run the affected checks on every
descendant. The fix and its effect on descendants are reviewed by the next
Ship-Readiness round; if no round remains, they are "fixed, unconfirmed". Log why.
A test failure the full gate finds is fixed on the finalization branch.

### 6. Handoff
**Ready** means all of: no open P0/P1 anywhere (Unresolved-at-cap and "fixed,
unconfirmed" included); every gate's final round filled its reviewer slots
(substitutes count); verification-target evidence on the final top SHA; affected
checks green on every PR at its pushed SHA and the full gate green on the final top
SHA; every expected PR bot reviewed every PR's current head
with no open blocking item. If everything holds except that some bots never
reported, the verdict is **Ready pending bots** (name them). Otherwise **Blocked**,
with the reasons.

Report, in this order:
1. **Verdict:** Ready for product/UX review, Ready pending bots, or Blocked (on what).
2. PR stack with links, one line each, plus the final top SHA.
3. **Unresolved items** — every P0/P1 still open or unconfirmed, with current status.
4. **P2s and nits not fixed** — count, the ones the user may care about in one line
   each, and a link to `findings.md`.
5. **Decisions** — `needs sign-off` entries from the decision log, then a link to the full log.
6. Verification run: commands, results, SHAs; verification-target flows covered.
7. Ship-readiness notes: deploy order, migration notes, that the stack merges
   together (PRs below the top did not run the full suite on their own), anything the
   user must do before beta (e.g. deploy functions to production first).
8. Bot threads left open, and why.
9. What to look at on a real device — the 3–6 flows most worth the user's eyes, with screenshots.
10. Reviewer substitutions and any gate skipped, with reason.

## Quick Reference

| Gate | Input | Reviewers | Max rounds | Passes when | At cap |
|---|---|---|---|---|---|
| Spec | spec @ SHA | Opus + Neon/Sol | 3 | round with no open P0/P1 | ruling + `needs sign-off` (Autonomous) / ask (Checkpoint) |
| Plan | plan @ SHA | Opus + Neon/Sol | 3 | same | same |
| Per-PR | PR diff snapshot @ SHA | Sol + Neon; delta: Sol | 2 (full + delta) | full round with no open P0/P1, or delta round confirms every fix | open PR, list items in body |
| Ship-readiness | base...finalization @ SHA + PR bots | Sol + Neon | 3 | round with no open P0/P1 | open finalization PR, verdict Blocked |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Running another round after a clean round "to be safe" | A round with no open P0/P1 ends the gate. |
| Reviewing uncommitted code | Freeze: affected checks, commit, clean tree, record SHA — then review that SHA. |
| Starting PR N+1 while PR N is still in its gate | Strictly sequential. |
| Only one reviewer because the other is slow | Fill every slot the table lists for the round. Hung or limited → retry once, then substitute. |
| Adding an Opus reviewer to a PR or Ship-readiness round "for safety" | Opus is the substitute there, not a slot. |
| Running the full test suites before each PR or each review round | Affected checks per freeze; the full gate runs at the first Ship-readiness freeze and on the final SHA. |
| A third Per-PR round because the delta reviewer found something new | Fix it or carry it to Ship-readiness; open the PR. |
| Fixing P2s inside a P0/P1 fix batch "while we're there" | P2s wait for the Finalization triage. |
| Sending every fix batch to Opus | Sonnet `high` by default; Opus only for the finding types the Worker Contract lists. |
| Accepting a reviewer's P1 that has no single-device trace | Apply the calibration; downgrade with its line as the reason. |
| Reviewing every task | Only `risk: high` tasks and Haiku tasks get a task review. |
| Dropping a finding because you couldn't reproduce it | Only refuted findings drop. |
| Downgrading a P1 to P2 to pass the gate | Downgrades need a written reason; an unfixed P1 is still open. |
| Fixing findings before writing them down | Append to `findings.md` first. |
| Pushing fixes, `/simplify` output or "cheap nits" to an already-reviewed PR | Finalization branch, unless the Owning-PR Exception applies. |
| Sweeping bot comments right after pushing | Bounded poll first; report bots that never ran. |
| Skipping verification-target testing because tests pass | Required per PR and again on the final SHA. |
| Asking the user a question in Autonomous mode | Decide, log as `needs sign-off`, continue. |
| Calling the result Ready with Unresolved-at-cap items open | That's Blocked. Say what's blocking. |
