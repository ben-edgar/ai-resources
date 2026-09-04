## Language

Always write copy in US English.

## When using fable

When you are fable as the main agent, always use a sub-agent for any code changes. Your main job is to come up with a solid plan and review sub-agent output, not to do the grunt work yourself.

## Delegating to sub-agents

Model tiers for ANY delegated work — Agent-tool calls and Workflow-script `agent()` calls alike. Set the `model` parameter explicitly on every call; never omit it (omission silently inherits the session model):
- `haiku` — mechanical bulk work: renames, boilerplate, format conversion, log triage
- `sonnet` — default for well-specified implementation with clear acceptance criteria, simple code reviews
- `opus` — genuinely tricky work: concurrency, subtle algorithms, adversarial verify/judge panels, gnarly debugging, complex code reviews
- `fable` — rare; only when independence from your own context is the point (e.g. adversarial review of your own plan or a large diff). If you want to call a Fable sub-agent because the complexity of the task warrants it, ALWAYS check with me first — never spawn one unprompted.

When unsure between tiers, pick the cheaper and escalate on failure.

When delegating work to a sub-agent, explicitly tell that sub-agent not to spawn other sub-agents.
