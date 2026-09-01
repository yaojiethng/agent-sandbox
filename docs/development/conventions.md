# Conventions

Index of coding and interface conventions for the agent-sandbox project. Each category maps to its canonical document.

| Category | Document | Scope |
|---|---|---|
| Interface (CLI, TUI, API) | [`interface-conventions.md`](interface-conventions.md) | CLI flags, output discipline, TUI surface, API contracts pointer, contextual-knowledge-light naming |
| Bash coding | [`bash-coding-conventions.md`](bash-coding-conventions.md) | Language rules, traps as positive rules, dependency management |
| Testing | [`testing-conventions.md`](testing-conventions.md) | Fixture patterns, anti-patterns, templates, checklists, debug steps |

Policy documents govern process, not code shape. Conventions govern code shape within their category.

| Category | Policy document |
|---|---|
| Testing policy | [`testing_policy.md`](testing_policy.md) |
| Skills (agent-facing) | `src/reasoning/agent/drafts/*.skill.md` |
| Gotchas (operator-recorded) | [`devlog/GOTCHAS.md`](../../devlog/GOTCHAS.md) |
| Agent feedback | [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) |
