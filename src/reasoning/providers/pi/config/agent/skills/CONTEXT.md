# System Assumptions

This folder holds pi's own skills: the ones whose subject is pi or the harness's pi pin, which the provider-neutral skill root must not carry.

## Runtime identity

| Field | Value |
|---|---|
| Source folders | `src/reasoning/providers/pi/config/agent/skills/` |
| Runtime path | `$AGENT_HOME/skills/`, which is `/home/agentuser/.pi/agent/skills/` |
| Loaded when | pi scans its user skills directory at startup, and that directory is a host bind mount seeded from `/opt/workflow/agent/config/` at every container start |

## Reachable

| Path | Holds | Condition |
|---|---|---|
| `/home/agentuser/sandbox/` | the project tree, and the working directory | always |
| `/home/agentuser/workspace/input/` | the operator's handover files, read-only | always |
| `/home/agentuser/workspace/output/` | where the agent writes its result | always |
| `/home/agentuser/workspace/session-diffs/` | the session diff output | always |
| `/opt/workflow/agent/prompts/` | the merged prompt root | always |
| `/opt/workflow/agent/skills/` | the provider-neutral skill root | always |
| `/opt/sandbox/docs/architecture/` | the harness architecture documents | always |
| `/opt/sandbox/docs/concepts/` | the harness concept documents | always |
| `/opt/sandbox/docs/operations/` | the operations policy corpus, bundled from `docs/operations/` | always |
| `/opt/sandbox/lib/` | the harness libraries | always |
| `/opt/sandbox/bin/` | the entrypoint and preflight scripts | always |
| `$AGENT_HOME/` | pi's config home, including this folder's runtime path | always |
| `/opt/workflow/agent/config/` | the config template this folder is provisioned from at every start | pi delivery |
| `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/` | the pi install, its changelog and its documentation | pi delivery |
| `src/reasoning/providers/pi/` | the harness's pi provider sources, which the bump skill edits | the reader has the repository tree |

## Not reachable

- The harness's `devlog/` and `workflow/` trees at any image path; the operations policy is the exception and ships at `/opt/sandbox/docs/operations/`. The project tree at `/home/agentuser/sandbox/` carries them only when the project under work is agent-sandbox.
- The other two providers' config trees. This folder is pi's, and the hermes and opencode images do not carry it.
- `/opt/provider-config/`. The compose path table documents it as the provider config mount, and no running container has the directory.

## Assumptions

- The delivery is pi, and pi discovers this folder without a settings entry, because it is the user skills directory.
- The skills here are pi-specific by design. A skill with no provider in its subject belongs in `src/reasoning/agent/skills/` instead.
- The bump skill names the harness's own provider sources and the pinned version record, so it assumes the project under work is agent-sandbox.
- The folder's runtime path is a host bind mount written from the image template at every start. An operator edit under `$AGENT_HOME/skills/` lands on the host, and the next start writes the image copy over it.
