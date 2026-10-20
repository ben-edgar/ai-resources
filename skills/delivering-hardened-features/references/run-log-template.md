# Run State Templates

## run-log.md

```markdown
# <Feature name> — run log

- Mode: Checkpoint | Autonomous
- Started: <UTC timestamp>  Repo: <path>  Base: <default branch> @ <sha>
- Spec: <path>   Plan: <path>
- Project commands (from AGENTS.md): format=… analyze=… test=… fixtures=… deploy(non-prod)=…
- Verification target: <simulator via … | browser | CLI scenarios | service env>
- Expected PR bots: <logins>

## Stack
| # | Branch | Base | PR | Pushed at (UTC) | Reviewed SHA | Gate result | Evidence SHA |
|---|---|---|---|---|---|---|---|

## Phases
- [ ] 1 Intake
- [ ] 2 Spec (rounds: _ )
- [ ] 3 Plan (rounds: _ )
- [ ] 4 PRs (see Stack)
- [ ] 5 Finalization: cleanup / full verification / ship-readiness (rounds: _ ) / finalization PR / final evidence
- [ ] 6 Handoff

## Dispatch log
| UTC | Gate/round | Reviewer or worker | Model | SHA | Output path | Result |
|---|---|---|---|---|---|---|

## Current status
<one paragraph a fresh session can resume from>
```

## decision-log.md

One entry per judgment call. Flag anything the user might reasonably decide
differently as `needs sign-off`.

```markdown
### D<n> — <short title>   [needs sign-off | routine]
- Phase: <spec/plan/PR n/…>
- Question: <what had to be decided>
- Options: <A> / <B> (/ <C>)
- Chose: <option> — <why, one or two sentences>
- Reversal cost: <what changes if the user picks differently>
```

## findings.md

Append-only. Write before fixing. Later resolutions are appended as events, not
edits to the original row.

```markdown
## <Gate> — round <n> — <UTC timestamp>
Reviewers: codex gpt-6.1-sol high, opus  (or: opus ×2 — codex limit)

| ID | Src | Claimed | Final | Status | Location | Finding |
|---|---|---|---|---|---|---|
| S1-3 | codex | P1 | P1 | confirmed | spec §4 | … |

Resolution events:
- S1-3 — fixed in <sha> (verified by <test/command>) | refuted: <reason> | deferred: D<n>

Unresolved at cap: <IDs with "unfixed" or "fixed, unconfirmed", or "none">
```
