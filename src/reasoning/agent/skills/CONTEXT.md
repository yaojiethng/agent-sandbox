# System Assumptions

This is the harness skill root: the capabilities every reasoning image ships, from the review and state-machine skills to the harness's own maintenance skills.

## Runtime identity

| Field | Value |
|---|---|
| Source folders | `src/reasoning/agent/skills/` |
| Runtime path | `/opt/workflow/agent/skills/` |
| Loaded when | the running provider's config lists `/opt/workflow/agent/skills` as a skill root, and the agent loads a skill's `SKILL.md` description and any sibling file that skill names |

## Reachable

| Path | Holds | Condition |
|---|---|---|
| `/home/agentuser/sandbox/` | the project tree, and the working directory | always |
| `/home/agentuser/workspace/input/` | the operator's handover files, read-only | always |
| `/home/agentuser/workspace/output/` | where the agent writes its result | always |
| `/home/agentuser/workspace/session-diffs/` | the session diff output | always |
| `/opt/workflow/agent/prompts/` | the merged prompt root | always |
| `/opt/workflow/agent/skills/` | this folder: every skill, and every sibling file a skill names | always |
| `/opt/sandbox/docs/architecture/` | the harness architecture documents | always |
| `/opt/sandbox/docs/concepts/` | the harness concept documents | always |
| `/opt/sandbox/lib/` | the harness libraries | always |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts | always |
| `$AGENT_HOME/` | the running provider's config home, rewritten from its template at every start | always |
| `src/reasoning/providers/` | the harness's provider sources, one folder per provider | the reader has the repository tree |

## Not reachable

- `devlog/` and `docs/operations/` at any image path. `/opt` holds neither, and the project tree at `/home/agentuser/sandbox/` holds them only when the project under work is agent-sandbox.
- A relative link from a file in this folder into `docs/` or `devlog/`. Five levels up from `/opt/workflow/agent/skills/` is `/`, which holds neither tree.
- The harness's own source tree, except through `/home/agentuser/sandbox/` when the project under work is agent-sandbox.

## Assumptions

- Every skill here runs under whichever provider the session started, and the folder names no provider. A skill that needs one reports it itself.
- Skills whose subject is the harness itself, such as the provider bump skill, assume the project under work is agent-sandbox, because they name `src/reasoning/`.
- The other skills here, such as the interview and the domain-model skills, assume only a project tree and a git repository.
- `CONTEXT.md` in a project's root is that project's domain model, written by the domain-model skill. This file shares the name and describes the skill root instead.
- Push is forbidden by policy in the provider's `AGENTS.md`. Nothing in the environment enforces it.
