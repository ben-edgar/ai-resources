# Polling For The Reviewer's Verdict

The reviewer runs on push, so its verdict on your last round does not exist at
the moment you push. Record a cutoff, then poll in the background.

## Record the cutoff at push time

```bash
CUT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

## Confirm the reviewer's login first

The script filters reviews by `author.login`. Read the actual value off an
existing review before relying on it — a bot may be `claude`, `claude[bot]`,
`github-actions[bot]`, or something else, and a wrong login silently misses
body-only reviews:

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) { reviews(last: 5) { nodes { author { login } } } }
  }
}' -F owner=$OWNER -F repo=$REPO -F number=$PR
```

## Poll script

Run with `run_in_background: true`. It exits as soon as either a new unresolved
thread or a new review by `$REVIEWER` appears after `CUT`, and gives up after ~30 min.

```bash
CUT="<cutoff from above>"
OWNER=<owner>; REPO=<repo>; PR=<number>; REVIEWER=<reviewer login>
DEADLINE=$(( $(date +%s) + 1800 ))
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  OUT=$(gh api graphql -f query='
  query($owner:String!, $repo:String!, $number:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$number) {
        reviewThreads(last: 40) {
          nodes { isResolved comments(first:1){ nodes { createdAt author { login } } } }
        }
        reviews(last: 10) { nodes { submittedAt author { login } } }
      }
    }
  }' -F owner=$OWNER -F repo=$REPO -F number=$PR 2>/dev/null) || { sleep 45; continue; }
  HIT=$(printf '%s' "$OUT" | python3 -c "
import json,sys
cut='$CUT'; REVIEWER='$REVIEWER'
try: d=json.load(sys.stdin)['data']['repository']['pullRequest']
except Exception: print('0'); raise SystemExit
n=0
for t in d['reviewThreads']['nodes']:
    c=t['comments']['nodes']
    if not t['isResolved'] and c and c[0]['createdAt']>cut: n+=1
r=sum(1 for x in d['reviews']['nodes']
      if x['author'] and x['author']['login']==REVIEWER and x['submittedAt']>cut)
print(n if n else (-r if r else 0))
")
  if [ "$HIT" != "0" ]; then echo "NEW_FEEDBACK signal=$HIT at $(date -u +%H:%M:%SZ)"; exit 0; fi
  sleep 45
done
echo "TIMEOUT no new $REVIEWER review after $CUT"
```

`reviewThreads(last: 40)` truncates on a very comment-heavy PR. If the PR has
more threads than that, page with `after`/`endCursor` rather than assuming the
tail is the whole story.

A positive `signal` counts new unresolved threads; a negative one means a review
landed with no inline threads (often a body-only pass, sometimes an all-clear).
`TIMEOUT` means the workflow did not run or is stuck — check
`gh run list --branch <branch>` before assuming the PR is clean.

The `|| { sleep 45; continue; }` matters: one failed API call must not kill a
30-minute poll.

## Reading the result

Fetch the full bodies only after the poll fires:

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(last: 40) {
        nodes {
          id isResolved path line
          comments(first:20){ nodes { url body createdAt author { login } } }
        }
      }
      reviews(last: 4) { nodes { url body submittedAt author { login } } }
    }
  }
}' -F owner=$OWNER -F repo=$REPO -F number=$PR
```

Filter threads to `isResolved == false` and reviews to those after `CUT`. Review
bodies are frequently empty — an empty body is not a finding.
