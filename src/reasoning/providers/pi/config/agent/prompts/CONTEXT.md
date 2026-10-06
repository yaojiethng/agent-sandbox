# System Assumptions

This folder holds one prompt, `pi-agent.md`, which asks about pi itself. It is the pi provider's own prompt folder, and it is the only folder here that names pi.

## Runtime identity

| Field | Value |
|---|---|
| Source folders | `src/reasoning/providers/pi/config/agent/prompts/` |
| Runtime path | `$AGENT_HOME/agent/prompts/`, which is `/home/agentuser/.pi/agent/prompts/` |
| Loaded when | pi's own prompt root is the agent home's `prompts` directory, provisioned from `/opt/workflow/agent/config/` at container start and listed in the pi settings record |

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
| `/opt/sandbox/docs/operations/` | the operations policy corpus, bundled from `docs/operations/` | always |
| `/opt/sandbox/lib/` | the harness libraries | always |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts | always |
| `$AGENT_HOME/` | pi's config home: this folder, the settings record and the auth record | always |
| `/opt/workflow/agent/config/` | the config template this folder is provisioned from at every start | pi delivery |
| `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/` | the pi install and its documentation, under npm's global prefix | pi delivery |

## Not reachable

- Every agent-sandbox record and policy tree except the operations policy, which ships at `/opt/sandbox/docs/operations/`. This folder belongs to the pi provider layer, which serves any mounted project.
- Anything left at `/opt/workflow/agent/config/` after startup. The provisioning copy runs at every start and overwrites the agent home.
- `/opt/provider-config/`. The compose path table documents it as the provider config mount, and no running container has the directory.

## Assumptions

- The delivery is pi. This folder is absent from the hermes and opencode images, whose own config folders carry their equivalent.
- The project under work is named by nothing here, and any project may be mounted.
- The pi install is global, and its documentation sits under npm's global prefix.
