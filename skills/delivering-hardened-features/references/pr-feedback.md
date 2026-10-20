# PR Feedback Sweep

How to collect, triage and close PR-bot (and human) feedback across a stack without
stalling. Always address PRs by number with `--repo`/explicit owner — never by
checking a branch out.

```bash
OWNER=$(gh repo view --json owner --jq .owner.login)
REPO=$(gh repo view --json name --jq .name)
```

## 1. Know who should review

From recent PRs in the repo, list the logins that post reviews (GraphQL drops the
`[bot]` suffix; e.g. `claude`, `chatgpt-codex-connector`, `github-actions` — read the
real values, don't guess):

```bash
for n in $(gh pr list --state all --limit 5 --json number --jq '.[].number'); do
  gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){
    reviews(last:30){nodes{author{login}}} comments(last:30){nodes{author{login}}}}}}' \
    -F o=$OWNER -F r=$REPO -F n=$n --jq '.data.repository.pullRequest|[.reviews.nodes[].author.login,.comments.nodes[].author.login]|unique|.[]'
done | sort -u
```

Record the expected bot logins in `run-log.md`. Leave out humans and bots that
only post status (deploy previews, CI summaries) unless they leave findings.

## 2. Bounded poll

A bot's verdict on a push doesn't exist yet right after the push. Poll the PRs
pushed since the last poll — in one background command, 30 minutes total:

```bash
python3 ~/.claude/skills/delivering-hardened-features/scripts/poll_bots.py --bots <login,login,...> --minutes 30 <PR> [<PR> ...]
```

A (PR, bot) pair is DONE when that bot has a review attached to the PR's **current
head SHA**. `COMMENT_ONLY` means the bot answered with a top-level comment instead —
open it and decide whether it is a verdict on the current head or a "review
started" placeholder. `PENDING` at the deadline means the bot never reported: check
`gh run list --branch <branch>` for a failed or never-started workflow and record
the pair as **unavailable**. Never treat a missing review as clean.

## 3. Fetch all three feedback sources, per PR

Top-level comments and review bodies can't be resolved; only inline review threads
can. Bots often put their whole verdict in a top-level comment — fetch all three.

```bash
gh api graphql --paginate -f query='
query($owner:String!,$repo:String!,$number:Int!,$endCursor:String){
  repository(owner:$owner,name:$repo){pullRequest(number:$number){
    reviewThreads(first:100, after:$endCursor){
      pageInfo{hasNextPage endCursor}
      nodes{id isResolved isOutdated path line
        comments(first:50){nodes{url body createdAt author{login}}}}}}}}' \
  -F owner=$OWNER -F repo=$REPO -F number=<PR>
```

Repeat with `comments(first:100, after:$endCursor){… nodes{id url body createdAt updatedAt author{login}}}`
and `reviews(first:100, after:$endCursor){… nodes{id url body state submittedAt updatedAt commit{oid} author{login}}}`.
Keep threads with `isResolved == false`; keep comments/reviews created **or
updated** after the previous sweep (bots edit their verdicts in place). A thread
with more than 50 comments: page its `comments` separately. Empty and praise-only
bodies are not findings.

## 4. Triage

Each item becomes a `findings.md` entry (source = bot login + URL) and gets the
same Refuted / Confirmed / Unconfirmed classification and severity as reviewer
findings. Bots usually find real symptoms but propose fixes that break invariants
they can't see — design the fix yourself.

## 5. Close the loop

Reply when the fix is pushed in an open PR. **Resolve** only once the round that
included the fix has finished with no open P0/P1 (or, for an owning-PR fix, the
next Ship-Readiness round has). Until then, reply with the link and leave the
thread open.

Reply in-thread, then resolve:

```bash
gh api graphql -f query='mutation($t:ID!,$b:String!){
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t, body:$b}){comment{url}}}' \
  -F t='PRRT_xxx' -F b='Fixed in #<finalization PR> (<sha>): <what changed, what test proves it>.'
gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}' \
  -F t='PRRT_xxx'
```

| Disposition | Action |
|---|---|
| Fixed (finalization PR or owning PR) | Reply with PR/SHA and test, resolve. |
| Refuted | Reply with the technical reason. Resolve only if the reason fully closes it; otherwise leave open and list it in the handoff. |
| Deferred / disagreement on product behavior | Reply with the reasoning and a `needs sign-off` decision ID; leave open. |
| Top-level comment or review body | One `gh pr comment <PR> --repo $OWNER/$REPO` per PR summarizing the disposition of each item with its URL. |
