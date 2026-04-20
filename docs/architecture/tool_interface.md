# Tool Interface

External contract between the agent-sandbox harness and onboarded projects: what the harness guarantees, what a project must provide, and the naming conventions that bind them.

Internal implementation is in [`execution_model.md`](execution_model.md). Operator workflow is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md).

---

## Image Naming

| Image | Name pattern | Purpose |
|---|---|---|
| Capability layer | `sandbox-<project>` | Sandbox, snapshot pipeline, diff pipeline |
| Reasoning layer base | `<provider>-base` | Stable install layers; not project-specific |
| Reasoning layer | `<provider>-agent-<project>` | Agent runtime (provider-specific) |

`<project>` is `PROJECT_NAME` from the project-side Makefile. `<provider>` is the provider name (e.g. `opencode`, `hermes`). Base images contain no project-specific content and are built once per provider; the reasoning layer image inherits from the base and is built per project.

---

## Container Naming

Container names match image names exactly — `container_name:` is set explicitly; Docker Compose does not append an index suffix. One session per project can run at a time. `docker inspect`, `docker logs`, and `docker stop` address containers by name directly.

| Container | Name |
|---|---|
| Capability layer | `sandbox-<project>` |
| Reasoning layer | `<provider>-agent-<project>` |

---

## Commands

### `make start PROVIDER=<provider> [REBUILD=1]`

Stops any running session for this project, builds missing images if needed, snapshots the project, and starts the agent. The terminal attaches to the agent TUI.

`PROVIDER` is required. `REBUILD=1` is optional — forces a full rebuild of all images from scratch before starting; without it, images are built only if missing.

**Leaves behind:** `staged.diff` in `.workspace/session-diffs/`; updated provider session state in `.<provider>/`.

---

### `make serve PROVIDER=<provider> [REBUILD=1]`

Same as `make start` but starts the agent in serve mode. The terminal is returned to the shell immediately; the agent runs in the background and is accessible via browser at `http://127.0.0.1:SERVE_PORT`. Stop with `make stop`.

`PROVIDER` is required. `REBUILD=1` behaves identically to `make start`.

---

### `make dry-run PROVIDER=<provider>`

Starts both containers, verifies the sandbox initialises correctly, then tears down. No agent is started; no user input is accepted. Produces no `staged.diff`.

`PROVIDER` is required. Use after a build or onboard to verify the harness is functional.

---

### `make build [TARGET=<provider>[,sandbox]]`

Builds images. Safe to run at any time; does not start or stop any containers.

`TARGET` is optional. Without it, all provider images and the sandbox image are built. `TARGET=<provider>` builds the named provider only. `TARGET=<provider>,sandbox` builds the named provider and the sandbox image.

---

### `make apply [BRANCH=<branch>]`

Applies `staged.diff` to `PROJECT_DIR`. Does not commit.

`BRANCH` is optional. If supplied, applies to a new branch checked out from current HEAD; otherwise applies to the current branch.

**Review `staged.diff` before applying.** If rejected, discard `.workspace/session-diffs/` — the host repository is unchanged.

---

## Execution Modes

| Mode | Make target | Effect |
|---|---|---|
| `standard` | `make start PROVIDER=<n>` | Normal execution; agent TUI attaches to terminal |
| `serve` | `make serve PROVIDER=<n>` | Provider-specific serve mode (see below) |
| `dry-run` | `make dry-run PROVIDER=<n>` | Liveness check only; no agent interaction |
| `headless` | — | Reserved; not yet implemented |

**Serve mode is provider-specific.** The serve overlay lives in `providers/<n>/docker-compose.serve.yml` in the repo — never copied to `SANDBOX_DIR`.

| Provider | Serve behaviour |
|---|---|
| `opencode` | OpenCode runs in server mode; port exposed at `SERVE_PORT` on `127.0.0.1`; `OPENCODE_SERVER_PASSWORD` controls authentication |
| `hermes` | Open WebUI launched as a companion service; port exposed at `SERVE_PORT` on `127.0.0.1` |

---

## Mount Shape Guarantees

| Host path | Capability layer path | Reasoning layer path | Mode | Owner |
|---|---|---|---|---|
| `$SNAPSHOT_DIR` | `/home/agentuser/.snapshot/` | — | RO | Harness — rebuilt before each run |
| `$CHANGES_DIR` | `/home/agentuser/workspace/session-diffs/` | — | RW | Harness — diff pipeline output |
| `$INPUT_DIR` | — | `/home/agentuser/workspace/input/` | RO | Operator — populated before a run |
| `$OUTPUT_DIR` | — | `/home/agentuser/workspace/output/` | RW | Agent — written during a run |
| `$SANDBOX_DIR/.<provider>/` | — | `/opt/provider-config/` | RW | Harness — provider config; seed and persist via entrypoint |
| Docker anonymous volume | `/home/agentuser/sandbox/` | `/home/agentuser/sandbox/` | RW | Docker — owned by capability layer; shared via `--volumes-from` |

`PROJECT_DIR` is never mounted. `sandbox/` is created by Docker at session start and destroyed on teardown (`down -v`). The reasoning layer can only access it while the capability layer is running.

---

## Onboarding

See [`../operations/project_onboarding_guide.md`](../operations/project_onboarding_guide.md) for the full onboarding procedure.

An onboarded project provides the following in `SANDBOX_DIR`:

| File | Source | Purpose |
|---|---|---|
| `Makefile` | Copied from template by onboard | Defines `PROJECT_NAME`; delegates to `agent-sandbox` subcommands |
| `.env` | Written by onboard | Machine-specific runtime variables; never committed |
| `AGENTS.md` | Stub written by onboard; operator-completed | Agent context brief |
| `.<provider>/` | Copied from `providers/<n>/config/` by onboard | Provider config; operator fills in secrets; never committed |

`docker-compose.yml`, `docker-compose.dry-run.yml`, and `docker-compose.serve.yml` are never written to `SANDBOX_DIR`. Compose files are generated as tmpfiles per run. The serve overlay and capability layer Dockerfile are repo-owned.

---

## `.env` Runtime Variables

| Variable | Default | Owner |
|---|---|---|
| `PROJECT_DIR` | Operator-supplied at onboard | Operator |
| `SANDBOX_DIR` | Operator-supplied at onboard | Operator |
| `SNAPSHOT_DIR` | `$SANDBOX_DIR/.snapshot` | Harness — rebuilt before each run |
| `CHANGES_DIR` | `$SANDBOX_DIR/.workspace/session-diffs` | Harness — diff pipeline output |
| `INPUT_DIR` | `$SANDBOX_DIR/.workspace/input` | Operator — populated before a run |
| `OUTPUT_DIR` | `$SANDBOX_DIR/.workspace/output` | Agent — written during a run |
| `SERVE_PORT` | Operator-supplied | Operator — host port for serve mode |
| `AUTOSAVE_INTERVAL` | `60` | Operator |

`SANDBOX_IMAGE_NAME` and `AGENT_IMAGE_NAME` are derived at run time via `libs/containers.sh` and are not stored in `.env`. Provider-specific variables are appended from `providers/<n>/.env.example` at onboard time.

---

## Capability Layer Contract

Guarantees the capability layer makes to the reasoning layer. Enforced by the harness — a conforming provider does not need to re-verify them.

**Readiness signal:** When the capability layer reports healthy, `sandbox/` is fully initialised. The reasoning layer may treat a healthy status as the unconditional signal to proceed.

**Volume ownership:** `sandbox/` is a Docker anonymous volume owned by the capability layer. The reasoning layer accesses it via `--volumes-from`. Created fresh at session start; destroyed on teardown. Inaccessible if the capability layer is not running.

**Sandbox initialisation:** Before reporting healthy, the capability layer will have:
1. Copied `.snapshot/` into `sandbox/`
2. Initialised a git repository in `sandbox/`
3. Committed a baseline SHA — the diff pipeline computes `staged.diff` against this on exit

---

## Provider Interface

A conforming provider supplies the following under `providers/<n>/` in the repo:

| File | Required | Purpose |
|---|---|---|
| `base.Dockerfile` | Yes | Stable install layers (system packages, runtimes, agent source); tagged `<provider>-base` |
| `provider.Dockerfile` | Yes | Provider layer inheriting from `<provider>-base`; tagged `<provider>-agent-<project>` |
| `docker-compose.serve.yml` | Yes | Static serve mode overlay; referenced directly by `run_agent.sh` |
| `.env.example` | Yes | Provider-specific `.env` stubs; appended to project `.env` at onboard time |
| `config/` | Optional | Onboarding template — copied to `$SANDBOX_DIR/.<provider>/` by `agent-sandbox onboard`; `env.stub` renamed to `.env`; operator fills in secrets; never baked into image |
| `docker-compose.<provider>.yml` | Recommended | Provider-level overlay applied in all modes; **required if provider needs API keys or env vars** |
| `setup.sh` | Optional | Sourced by `run_agent.sh` before compose generation; exports provider-specific vars |

**Important: API keys in `.env` are NOT automatically passed to containers.** Docker Compose only passes environment variables that are explicitly declared in a compose file's `environment:` block. If your provider requires API keys (e.g. `ANTHROPIC_API_KEY`, `OPENCODE_API_KEY`), you **must** create `docker-compose.<provider>.yml` and declare them there. See [`../operations/provider_onboarding_guide.md — Step 7`](../operations/provider_onboarding_guide.md#step-7-optional-but-usually-required---write-docker-compose-nyml).

Providers do not supply `build.sh` or `run.sh` — the harness manages all build and container lifecycle. `libs/provider-entrypoint.sh` is injected into every provider image by the harness via the build context — providers do not author it.

See [`../operations/provider_onboarding_guide.md`](../operations/provider_onboarding_guide.md) for the full provider contract and step-by-step implementation guide.

---

## Dry-Run Guarantees

A successful `make dry-run` proves:

- Both container images build without error
- Both containers start and the capability layer initialises `sandbox/`
- The reasoning layer can access and write to `sandbox/` via the shared volume
- Both containers terminate gracefully
- The diff pipeline runs and produces output in `.workspace/session-diffs/`

A dry-run does not prove agent correctness — it proves the harness infrastructure is functional.

---

## References

| Topic | Document |
|---|---|
| Internal implementation | [execution_model.md](execution_model.md) |
| Operator workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security model | [security.md](security.md) |
| Onboarding a project | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
| Adding a provider | [../operations/provider_onboarding_guide.md](../operations/provider_onboarding_guide.md) |
