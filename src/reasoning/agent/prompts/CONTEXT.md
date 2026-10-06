# System Assumptions

This is the shipped prompt root: the harness prompts, which ask about agent-sandbox itself, and the coding-agent prompts, which run the iteration, plan, milestone and record workflows.

## Runtime identity

| Field | Value |
|---|---|
| Source folders | `src/reasoning/agent/prompts/`, `workflow/coding-agent/prompts/` |
| Runtime path | `/opt/workflow/agent/prompts/` |
| Loaded when | the running provider's config lists `/opt/workflow/agent/prompts` as a prompt root, and the agent offers each Markdown file here as a command |

## Reachable

| Path | Holds | Condition |
|---|---|---|
| `/home/agentuser/sandbox/` | the project tree, and the working directory | always |
| `/home/agentuser/workspace/input/` | the operator's handover files, read-only | always |
| `/home/agentuser/workspace/output/` | where the agent writes its result | always |
| `/home/agentuser/workspace/session-diffs/` | the session diff output | always |
| `/opt/workflow/agent/prompts/` | this folder: both source folders, merged | always |
| `/opt/workflow/agent/skills/` | the harness skill root | always |
| `/opt/sandbox/docs/architecture/` | the harness architecture documents | always |
| `/opt/sandbox/docs/concepts/` | the harness concept documents | always |
| `/opt/sandbox/docs/operations/` | the operations policy corpus, bundled from `docs/operations/` | always |
| `/opt/sandbox/lib/` | the harness libraries | always |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts | always |
| `$AGENT_HOME/` | the running provider's config home, rewritten from its template at every start | always |
| `workflow/coding-agent/skills/` | the coding-agent skills a prompt reads | the reader has the repository tree |

## Not reachable

- `devlog/` at any image path. `/opt` does not hold it, and the project tree at `/home/agentuser/sandbox/` holds it only when the project under work is agent-sandbox. `docs/operations/` is the exception: it ships at `/opt/sandbox/docs/operations/`.
- A repository-relative link from a file in this folder into `docs/` or `devlog/`. Six levels up from `/opt/workflow/agent/prompts/` is `/`, so the link resolves to nothing. The link check reads a link in this folder in the image's path space and reports one.

## Assumptions

- The running provider loads this folder and resolves `$AGENT_HOME`. Nothing here depends on which provider that is.
- The coding-agent prompts assume the reader works in a git repository that carries the agent-sandbox record layer, and that the operator reviews the result at a gate.
- The reader is a coding agent, and the project under work is the mounted project, not the harness.
- Push is forbidden by policy in the provider's `AGENTS.md`. Nothing in the environment enforces it.
