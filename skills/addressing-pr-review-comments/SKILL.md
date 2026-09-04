---
name: addressing-pr-review-comments
description: Use when addressing GitHub pull request review feedback for the PR associated with the current branch, especially when the task requires fetching outstanding PR comments, review bodies, and unresolved review threads with gh, writing a skeptical action plan, implementing fixes with TDD, and replying to or resolving comments after verification.
---

# Addressing PR Review Comments

## Overview

This skill standardizes the full workflow for addressing GitHub PR feedback with `gh`: fetch all relevant review inputs, group and validate them skeptically, write a plan, implement approved fixes with TDD, verify the result, then reply to or resolve comments consistently.

Read [github-cli-pr-review-workflow.md](references/github-cli-pr-review-workflow.md) for the exact `gh api graphql` queries and mutations.

## Required Companion Skills

Use these skills together with this one:

- `receiving-code-review` before accepting reviewer claims or solutions
- `test-driven-development` before any production code change
- `verification-before-completion` before claiming success or posting GitHub close-out comments

This skill coordinates the workflow. The companion skills enforce the quality bars.

## Workflow

### 1. Identify The PR

Resolve the current branch to a PR with `gh pr view`.

If there is no PR for the current branch, stop and tell the user this skill does not apply yet.

### 2. Fetch Outstanding Feedback

Fetch three sources:

- top-level PR comments
- PR review bodies
- unresolved review threads for inline line comments

Use the exact commands in the reference file. Do not improvise the GraphQL shapes.

### 3. Respect GitHub’s Comment Model

GitHub does not expose one unified "unresolved comments" concept:

- inline review threads can be resolved and filtered by `isResolved`
- top-level PR comments cannot be resolved
- review bodies cannot be resolved

That means:

- unresolved filtering is exact only for review threads
- top-level PR comments and review bodies are fetched, then triaged for actionability
- only review threads can be auto-resolved at the end

Do not claim a top-level PR comment or review body was "resolved". It was only addressed.

### 4. Group Comments Skeptically

Group related feedback into comment groups. A group may combine:

- duplicate comments about the same issue
- a review body item plus one or more inline comments
- multiple inline threads pointing to the same root cause

For each group, explicitly record:

- source URLs and authors
- the technical claim being made
- the reviewer’s proposed fix, if any
- the relevant code paths

Then evaluate the group skeptically against the current codebase and PR context.

Each group must get one verdict:

- `valid`
- `partially valid`
- `not valid`
- `non-actionable`

Never implement a suggestion just because a reviewer proposed it. Validate the problem and validate the proposed solution separately.

### 5. Write The Plan Before Implementing

Create `pr_comment_plan.md` in the repo root. If it already exists, create `pr_comment_plan-1.md`, `pr_comment_plan-2.md`, and so on.

Each comment group in the plan must include:

- verdict
- reasoning
- implementation approach
- specific tests to add first
- verification steps
- GitHub follow-up plan

For valid or partially valid groups, choose the simplest maintainable fix that fits the full PR context, not the narrowest literal reading of the comment.

If no reasonable automated test can be added, say that explicitly and explain why.

### 6. Present The Plan To The User

In chat, give a concise high-level overview and point the user to the plan file for details.

The summary must explicitly say:

- which groups are valid
- which groups are partially valid
- which groups are not valid or non-actionable
- why each verdict was chosen

Reasoning matters more than politeness. Be technically explicit.

### 7. Wait For Approval Before Implementation

Do not implement until the user reviews the plan and tells you to proceed.

### 8. Implement With Red-Green-Refactor TDD

For each group that requires code changes:

1. Write the failing test first.
2. Run it and confirm it fails for the expected reason.
3. Write the minimal production change.
4. Re-run the targeted test and confirm it passes.
5. Refactor only while staying green.

No production code before a failing test first.

If multiple groups are approved, implement them one group at a time so the test evidence stays attributable.

### 9. Run Verification Before Close-Out

After implementation, run:

- targeted tests for each changed behavior
- broader tests needed to prove no regressions
- any other project verification commands required by the repo

Do not tell the user a fix is complete until the verification commands have actually run and you have read the results.

### 10. Reply To Comments And Resolve Threads

After fresh verification:

- for addressed inline review threads:
  - post an in-thread reply summarizing the fix and the verifying tests
  - resolve the thread if it is fully addressed
- for addressed top-level PR comments or review-body items:
  - post a top-level PR comment that references the original URL and states the disposition

If a comment group is `not valid` or `non-actionable`:

- reply with technical reasoning
- resolve only if the explanation fully closes the concern
- otherwise leave it open and surface the unresolved disagreement to the user

### 11. Final User Summary

When the workflow is complete, tell the user:

- what was fixed
- what tests were added
- what verification ran
- which GitHub comments were replied to
- which review threads were resolved
- whether any feedback remains open and why

## Quality Bar

This skill is successful only if it does all of the following:

- fetches the real PR feedback for the current branch
- distinguishes GitHub objects that can be resolved from those that cannot
- rejects invalid feedback when the codebase evidence says it should
- writes a plan before implementation
- uses TDD for code changes
- verifies before claiming success
- closes out GitHub feedback with accurate replies and thread resolution behavior
