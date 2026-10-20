#!/usr/bin/env python3
"""Wait until every expected PR bot has reviewed each PR's current head commit.

Usage:
  python3 poll_bots.py --bots claude,chatgpt-codex-connector --minutes 30 PR [PR ...]

A (PR, bot) pair counts as done when the bot has a review whose commit is the PR's
current head SHA. Bots that answer with a top-level comment instead of a review are
reported as COMMENT_ONLY with the comment's update time; read those bodies yourself
to decide whether they are a verdict or a "review started" placeholder.

Prints one line per PR when it completes, then a final summary. Exit code 0 when
every pair is done, 2 when the deadline passed with pairs still pending.
"""
import argparse
import json
import subprocess
import sys
import time

QUERY = """
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      headRefOid
      reviews(last:50) { nodes { author { login } submittedAt commit { oid } } }
      comments(last:50) { nodes { author { login } updatedAt url } }
    }
  }
}
"""


def gh_json(args):
    out = subprocess.run(["gh", *args], check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


def norm(login):
    return login.removesuffix("[bot]")


def check(owner, repo, number, bots):
    data = gh_json([
        "api", "graphql", "-f", f"query={QUERY}",
        "-F", f"owner={owner}", "-F", f"repo={repo}", "-F", f"number={number}",
    ])["data"]["repository"]["pullRequest"]
    head = data["headRefOid"]
    status = {}
    for bot in bots:
        reviewed = any(
            r["author"] and norm(r["author"]["login"]) == bot
            and r["commit"] and r["commit"]["oid"] == head
            for r in data["reviews"]["nodes"]
        )
        if reviewed:
            status[bot] = "DONE"
            continue
        comments = [
            c for c in data["comments"]["nodes"]
            if c["author"] and norm(c["author"]["login"]) == bot
        ]
        status[bot] = (
            f"COMMENT_ONLY last_update={comments[-1]['updatedAt']} {comments[-1]['url']}"
            if comments else "PENDING"
        )
    return head, status


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--bots", required=True, help="comma-separated logins, without [bot]")
    p.add_argument("--minutes", type=int, default=30)
    p.add_argument("--interval", type=int, default=60)
    p.add_argument("prs", nargs="+", type=int)
    a = p.parse_args()

    repo_info = gh_json(["repo", "view", "--json", "owner,name"])
    owner, repo = repo_info["owner"]["login"], repo_info["name"]
    bots = [norm(b.strip()) for b in a.bots.split(",") if b.strip()]
    deadline = time.time() + a.minutes * 60
    last = {}
    remaining = set(a.prs)

    while True:
        for pr in sorted(remaining):
            try:
                head, status = check(owner, repo, pr, bots)
            except (subprocess.CalledProcessError, KeyError, TypeError, json.JSONDecodeError) as e:
                print(f"PR #{pr}: query failed ({e.__class__.__name__}), retrying", flush=True)
                continue
            last[pr] = (head, status)
            if all(s == "DONE" for s in status.values()):
                print(f"PR #{pr} @ {head[:8]}: all bots reviewed this head", flush=True)
                remaining.discard(pr)
        if not remaining or time.time() >= deadline:
            break
        time.sleep(a.interval)

    print("SUMMARY")
    for pr in a.prs:
        head, status = last.get(pr, ("?", {b: "UNKNOWN (no successful query)" for b in bots}))
        for bot, s in status.items():
            print(f"  PR #{pr} @ {head[:8]} {bot}: {s}")
    sys.exit(0 if not remaining else 2)


if __name__ == "__main__":
    main()
