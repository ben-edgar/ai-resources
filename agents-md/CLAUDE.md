## Language

Always write copy in US English.

## When using fable

When you are fable as the main agent, always use a sub-agent for any code changes. Your main job is to come up with a solid plan and review sub-agent output, not to do the grunt work yourself.

## Delegating to sub-agents

Model tiers for ANY delegated work — Agent-tool calls and Workflow-script `agent()` calls alike. Set the `model` parameter explicitly on every call; never omit it (omission silently inherits the session model). The tiers are the 5.5 generation: Haiku 5.5 is about 1/20 the price of Sonnet 5.5 and is built to run as a sub-agent; Sonnet 5.5 is strong at multistep coding in a real repo; Opus 5.5 is best at long-horizon work and catches the most bugs in review with the fewest false alarms.
- `haiku` — any task whose brief fully specifies the result, up to about 6–10 files. That covers mechanical edits, renames, boilerplate, format conversion, docs edits from given copy, test-file splits and behavior-preserving file splits, plus log and test-output triage. It also covers multi-file plan tasks and fix batches when the brief carries the exact interfaces, rulings, copy and test cases. Read-heavy fan-out works too: searching or summarizing many files, or checking that citations still match. Chunk a long verify loop into one area per Haiku.
- Not `haiku`: layout or visual judgment without pinned geometry, framework-internals debugging, harness or test-rig debugging, and discovery-heavy work. Haiku production code is usually right. Its tests often cannot fail, or they assert the wiring it chose instead of the requirement. Every Haiku task gets a reviewer one tier up.
- `sonnet` — the default for real work: implementing a plan task across several files with TDD, fix rounds, task-scoped spec and quality reviews, docs reviews, driving a simulator or emulator smoke run, research that needs judgment.
- `opus` — work where a miss is costly or the path is unclear: concurrency, lifecycle and races; persistence, migrations and sync; subtle algorithms; debugging after a cheaper tier failed; per-PR or whole-branch gate reviews and spec or plan reviews; adversarial verify or judge panels.
- `fable` — rare; only when independence from your own context is the point (e.g. adversarial review of your own plan or a large diff). If you want to call a Fable sub-agent because the complexity of the task warrants it, ALWAYS check with me first — never spawn one unprompted.

Also set the `effort` parameter explicitly on every delegated call (Agent tool and Workflow `agent()` alike). Pick the model by tier first, then effort by how complex the task is:
- `low` — very rote or simple things.
  - Implementation: mechanical edits, renames, boilerplate, format conversion, docs edits from given copy.
  - Review: checking that citations or file paths still match, lint-style passes.
  - Other: lookups, log or test-output triage.
- `medium` — standard work with a clear brief.
  - Implementation: a plan task whose brief carries the exact interfaces, rulings and test cases; a bugfix with a clear repro; review-comment fixes.
  - Review: task-scoped spec or quality review of a small diff, docs reviews.
  - Planning: breaking an agreed spec into tasks, research summaries.
  - Testing: baselines, QA and smoke runs, device checks from a detailed brief, merge-train runs, dependency triage.
- `high` — anything that's pretty complex.
  - Implementation: open design questions, multi-file features, concurrency, persistence, migrations or sync, anything after a cheaper run failed.
  - Debugging: root-causing a failure that isn't obvious.
  - Review: per-PR and whole-branch gate reviews, spec and plan reviews, adversarial verification.
  - Planning: writing a spec or implementation plan.
- Never use `xhigh` or `max` unless I ask for it.

For implementation, when unsure between tiers, pick the cheaper and escalate on failure. Do not downgrade reviewers to save quota: reviews run on the tier above.

Haiku and Sonnet sometimes report code as done without running a real check, and can stop early in long briefs. Every implementation brief for them names the exact check to run (tests, analyze, build) and says to keep going until it passes, then report its output.

Haiku briefs also:
- Paste the exact interface signatures and rulings. Haiku does not go and read the plan.
- Require mapping every listed case to a named test, and saying so if one is dropped. On long briefs Haiku drops cases silently otherwise.
- Require one self-run mutation per load-bearing assertion, with the red line reported.
- Ask for the report inline. Haiku sometimes refuses to write a report file unless the file is called the deliverable.
- Forbid `pkill` and `killall` explicitly, and say to kill only PIDs it started.

Verify a Haiku claim about why it deviated before accepting it. It is candid about deviations, but it sometimes gives a wrong reason, often by over-trusting its test doubles.

When delegating work to a sub-agent, explicitly tell that sub-agent not to spawn other sub-agents.
