# System Assumptions

This folder holds the coding-agent skills: the check-in dispatcher and the two record auditors.

## Runtime identity

| Field | Value |
|---|---|
| Source folders | `workflow/coding-agent/skills/` |
| Runtime path | none |
| Loaded when | a prompt names a file here by its repository-relative path, and the reader has the repository tree; no image path and no skill discovery reaches this folder |

## Reachable

| Path | Holds | Condition |
|---|---|---|
| `/home/agentuser/sandbox/` | the project tree, and the working directory | always |
| `/home/agentuser/workspace/input/` | the operator's handover files, read-only | always |
| `/home/agentuser/workspace/output/` | where the agent writes its result | always |
| `/home/agentuser/workspace/session-diffs/` | the session diff output | always |
| `/opt/workflow/agent/prompts/` | the merged prompt root | always |
| `/opt/workflow/agent/skills/` | the harness skill root | always |
| `/opt/sandbox/docs/architecture/` | the harness architecture documents | always |
| `/opt/sandbox/docs/concepts/` | the harness concept documents | always |
| `/opt/sandbox/lib/` | the harness libraries | always |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts | always |
| `$AGENT_HOME/` | the running provider's config home, rewritten from its template at every start | always |
| `devlog/` | the roadmap and the handover chain a check-in reads | the reader has the repository tree |

## Not reachable

- Any image path for this folder. `/opt/workflow/agent/skills/` holds the harness skills alone, and a link from a prompt there into this folder has no target.
- Skill discovery. The provider loads the roots in its config, and this folder is not one of them, so a session cannot see these skills from the command surface.
- `devlog/`, `docs/operations/` and `workflow/` through the image. The project tree at `/home/agentuser/sandbox/` carries them only when the project under work is agent-sandbox.

## Assumptions

- The reader has the repository, not only the image. That is the folder's whole load condition.
- The project under work carries the agent-sandbox record layer, which the auditors read.
- A dispatched auditor runs in the same container, sees the same tree, and is invoked through the running provider's own binary.
- Push is forbidden by policy in the provider's `AGENTS.md`. Nothing in the environment enforces it.
