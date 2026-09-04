# GitHub CLI PR Review Workflow

Use these commands when following `addressing-pr-review-comments`.

## 1. Resolve The Current Branch To A PR

```bash
gh pr view --json number,title,url,headRefName,baseRefName,id
```

If this fails, stop. The skill only applies when the current branch has a PR.

## 2. Fetch Top-Level PR Comments

Top-level PR comments do not have a resolved state. Fetch them, then triage for actionability.

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      comments(first: 100) {
        nodes {
          id
          databaseId
          url
          body
          createdAt
          isMinimized
          author { login }
        }
      }
    }
  }
}' -F owner='{owner}' -F repo='{repo}' -F number="$(gh pr view --json number --jq '.number')"
```

## 3. Fetch PR Review Bodies

Review bodies also do not have a resolved state. Fetch them, then triage for actionability.

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviews(first: 100) {
        nodes {
          id
          databaseId
          url
          body
          state
          submittedAt
          author { login }
        }
      }
    }
  }
}' -F owner='{owner}' -F repo='{repo}' -F number="$(gh pr view --json number --jq '.number')"
```

Filter out empty praise-only reviews during triage, not fetch. The skill should still inspect what came back before deciding a review is non-actionable.

## 4. Fetch Unresolved Review Threads

Inline line comments live in review threads. These are the only comments GitHub can mark resolved/unresolved.

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 100) {
            nodes {
              id
              databaseId
              url
              body
              createdAt
              author { login }
            }
          }
        }
      }
    }
  }
}' -F owner='{owner}' -F repo='{repo}' -F number="$(gh pr view --json number --jq '.number')"
```

During triage, keep only `isResolved == false`.

## 5. Choose The Plan Filename

```bash
plan_path="pr_comment_plan.md"
index=1
while [ -e "$plan_path" ]; do
  plan_path="pr_comment_plan-$index.md"
  index=$((index + 1))
done
printf '%s\n' "$plan_path"
```

## 6. Reply To A Review Thread

Reply in-thread before resolving it.

```bash
gh api graphql -f query='
mutation($threadId:ID!, $body:String!) {
  addPullRequestReviewThreadReply(input:{
    pullRequestReviewThreadId:$threadId,
    body:$body
  }) {
    comment {
      url
    }
  }
}' -F threadId='PRRT_xxx' -F body='Fixed in abc123. Added a regression test and verified the targeted and full test runs.'
```

## 7. Resolve A Review Thread

Only resolve the thread after fresh verification and after posting the reply.

```bash
gh api graphql -f query='
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread {
      id
      isResolved
    }
  }
}' -F threadId='PRRT_xxx'
```

## 8. Acknowledge Top-Level PR Comments Or Review Bodies

GitHub does not support resolving these. Post a top-level PR comment that references the original review/comment URL and states the disposition.

```bash
gh pr comment --body "$(cat <<'EOF'
Addressed review feedback from https://github.com/OWNER/REPO/pull/123#issuecomment-1234567890

- Verdict: valid
- Fix: tightened null handling in `FooService`
- Tests: added targeted regression coverage and reran the relevant suite
EOF
)"
```

## 9. Resolution Policy

Use this policy consistently:

- `valid` or `partially valid` with code changes:
  - reply with what changed and what tests proved it
  - resolve the review thread
- `not valid` or `non-actionable`:
  - reply with technical reasoning
  - resolve only if the explanation fully closes the concern
  - otherwise leave the thread open and surface it to the user

## 10. Important GitHub Model Limits

- Top-level PR comments cannot be resolved.
- Review bodies cannot be resolved.
- Only review threads can be resolved.
- A top-level PR comment is not the same thing as an inline review thread reply.
- Use `gh api graphql`, not `gh pr` alone, for unresolved-thread workflows.
