# Ship-Readiness Checklist

The question this review answers: **if the user finds no product/UX problems, can
this stack merge and go to beta users right away?** Review ``<base-sha>...<finalization-head-sha>`` as
one change. Items marked (DadTrack) are examples from that repo; apply the
equivalent in other projects, and skip a section that does not apply — but say so.

## Backend and deploy order
- Does the client depend on a backend change (Cloud Functions, rules, indexes,
  config)? Can the backend deploy **first** without breaking currently shipped
  clients? Can the new client run against the **old** backend if a deploy lags?
- Changed request/response shapes, token ceilings, required fields — are old callers
  still accepted?
- Firestore/Storage rules: do they still admit writes from older clients that the
  product still supports?
- State the required deploy order in the handoff. (DadTrack: `npm run deploy` from
  `functions/` targets debug; production is `npm run deploy:prod` and is a hard stop —
  the user runs it.)

## Database and persistence
- Every schema change has a migration, the migration runs from every shipped version,
  and an integration test covers upgrading existing data.
- Backup/restore: do backups from before this change still import and merge? Do new
  backups import on an older app (or is that explicitly unsupported)?
- No destructive migration step without a test proving data survives.

## Cross-device and partner sync
- A partner or second device on the previous app version: does it ignore, preserve,
  or corrupt the new fields/entities? Does inbound ordering still hold?

## Testability
- Can someone reach this feature's states on the verification target quickly and
  reproducibly? If that needs seeded data, is there a fixture for it? (DadTrack:
  `test/support/fixtures/`, generated via the fixture test tag.)
- Does verification evidence exist for every changed flow, on the current top SHA?

## Flavors / variants
- Flavor-sensitive copy, assets, notification channels, backup naming verified for
  each flavor. (DadTrack: DadTrack and MomTrack via `AppBranding`.)

## Release hygiene
- Docs the project requires per change are updated (DadTrack: `docs/CHANGELOG.md`,
  `docs/features/APP_FEATURES.md`, affected `docs/architecture/` files per AGENTS.md).
- No debug flags, test-only hooks, or leftover logging in production paths.
- Analyzer, formatter and full test suite green on the stack top.

## Carry-overs
- Re-assess every "Unresolved at cap" item from earlier gates: still real? still
  P0/P1? fixed incidentally?

## PR bot sweep
- Done by the orchestrator in parallel with this review, per `pr-feedback.md`
  (threads, top-level comments and review bodies, after a bounded poll). Reviewers
  don't fetch PR comments themselves.
