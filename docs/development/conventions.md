# Conventions

Index of coding and interface conventions for the agent-sandbox project. Each category maps to its canonical document.

| Category | Document | Scope |
|---|---|---|
| Interface (CLI, TUI, API) | [`interface-conventions.md`](interface-conventions.md) | CLI flags, output discipline, TUI surface, API contracts pointer, contextual-knowledge-light naming |
| Bash coding | [`code-review-bash`](../../workflow/coding-agent/skills/code-review/code-review-bash/SKILL.md) | Language rules as patterns beside the runbook, each carrying the wrong form it replaces, and the review that applies them |
| Module dependency direction | [`context_resolution.md#dependency-direction`](context_resolution.md#dependency-direction) | Which module may depend on which, in every language: the graph, the boundary rules, and what an edge is per language |
| Testing | [`testing/SKILL.md`](../../.agents/skills/testing/SKILL.md) | Judgements and patterns for writing a test |
| Prompt and skill authoring | [`prompt-authoring-conventions.md`](prompt-authoring-conventions.md) | Workflow-document structure, runbook vs advisor, subject scoping, document-type identification |
| Instruction surfaces | [`instruction-surface-conventions.md`](instruction-surface-conventions.md) | Declaring a prompt or skill surface in the interface manifest: fields, conditions, scope, layers, gates |

Policy documents govern process, not code shape. Conventions govern code shape within their category.

| Category | Policy document |
|---|---|
| Skills (agent-facing) | `src/reasoning/agent/drafts/*.skill.md` (procedures), `.agents/audits/*.skill.md` (audit family), `workflow/coding-agent/skills/*/SKILL.md` (record checks, shipped as the module payload) |
| Agent feedback and gotchas (recorded) | [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) (entries tagged `[A]` raised by the agent, `[O]` raised by the operator) |
