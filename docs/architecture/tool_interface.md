# Tool Interface

External contract between the agent-sandbox harness and onboarded projects: what the harness guarantees, what a project must provide, and the naming conventions that bind them.

Internal implementation is in [`execution_model.md`](execution_model.md). Operator workflow is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md).

---

## Image Naming

| Image | Name pattern | Purpose |
|---|---|---|
| Capability layer | `sandbox-<project>` | Sandbox, snapshot pipeline, diff pipeline |
| Reasoning layer | `<provider>-agent-<project>` | Agent runtime (provider-specific) |

`<project>` is `PROJECT_NAME` from the project-side Makefile. `<provider>` is the provider name (e.g. `opencode`, `hermes`).

---

## Container Naming

Container names match image names exactly — `container_name:` is set explicitly; Docker Compose does not append an index suffix. One session per project can run at a time. `docker inspect`, `docker logs`, and `docker stop` address containers by name directly.

| Container | Name |
|---|---|
| Capability layer | `sandbox-<project>` |
| Reasoning layer | `<provider>-agent-<project>` |

---

## Command Shapes

| Command | Effect |
|---|---|
| `make build` | Build capability layer image + all provider images |
| `make build TARGET=<n>` | Build named provider image only |
| `make build TARGET=<n>,sandbox` | Build named provider image + capability layer image |
| `make start PROVIDER=<n>` | Check images exist; start in standard mode |
| `make serve PROVIDER=<n>` | Check images exist; start with provider serve overlay |
| `make dry-run PROVIDER=<n>` | Check images exist; liveness check; tear down |
| `make start PROVIDER=<n> REBUILD=1` | Rebuild capability layer + provider images, then start |
| `make apply` | Apply `staged.diff` to host repo; optional `BRANCH=<n>` |

`make start`, `make serve`, and `make dry-run` require `PROVIDER` and error clearly if absent. Builds are not triggered unless `REBUILD=1` is passed.

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

| Host path (`$VAR`) | Capability layer path | Reasoning layer path | Mode | Owner |
|---|---|---|---|---|
| `$SNAPSHOT_DIR` | `/home/agentuser/.snapshot/` | — | RO | Harness — rebuilt before each run |
| `$CHANGES_DIR` | `/home/agentuser/workspace/changes/` | — | RW | Harness — diff pipeline output |
| `$INPUT_DIR` | — | `/home/agentuser/workspace/input/` | RO | Operator — populated before a run |
| `$OUTPUT_DIR` | — | `/home/agentuser/workspace/output/` | RW | Agent — written during a run |
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
| `agents.md` | Stub written by onboard; operator-completed | Agent context brief |

`docker-compose.yml`, `docker-compose.dry-run.yml`, and `docker-compose.serve.yml` are never written to `SANDBOX_DIR`. Compose files are generated as tmpfiles per run. The serve overlay and capability layer Dockerfile are repo-owned.

---

## `.env` Runtime Variables

| Variable | Default | Owner |
|---|---|---|
| `PROJECT_DIR` | Operator-supplied at onboard | Operator |
| `SANDBOX_DIR` | Operator-supplied at onboard | Operator |
| `SNAPSHOT_DIR` | `$SANDBOX_DIR/.snapshot` | Harness — rebuilt before each run |
| `CHANGES_DIR` | `$SANDBOX_DIR/.workspace/changes` | Harness — diff pipeline output |
| `INPUT_DIR` | `$SANDBOX_DIR/.workspace/input` | Operator — populated before a run |
| `OUTPUT_DIR` | `$SANDBOX_DIR/.workspace/output` | Agent — written during a run |
| `SERVE_PORT` | Operator-supplied | Operator — host port for serve mode |
| `AUTOSAVE_INTERVAL` | `60` | Operator |

`SANDBOX_IMAGE_NAME` and `AGENT_IMAGE_NAME` are derived at run time via `libs/containers.sh` and are not stored in `.env`. Provider-specific variables are appended from `providers/<n>/.env.example` at onboard time.

---

## Capability Layer Contract

Guarantees the capability layer makes to the reasoning layer. Enforced by the harness — a conforming `run.sh` does not need to re-verify them.

**Readiness signal:** When the capability layer reports healthy, `sandbox/` is fully initialised. The reasoning layer may treat a healthy status as the unconditional signal to proceed.

**Volume ownership:** `sandbox/` is a Docker anonymous volume owned by the capability layer. The reasoning layer accesses it via `--volumes-from`. Created fresh at session start; destroyed on teardown. Inaccessible if the capability layer is not running.

**Sandbox initialisation:** Before reporting healthy, the capability layer will have:
1. Copied `.snapshot/` into `sandbox/`
2. Initialised a git repository in `sandbox/`
3. Committed a baseline SHA — the diff pipeline computes `staged.diff` against this on exit

---

## Provider Interface

A conforming provider supplies the following under `providers/<n>/` in the repo:

| File | Purpose |
|---|---|
| `build.sh` | Builds the reasoning layer Docker image |
| `run.sh` | Handles all container invocation for this provider |
| `Dockerfile` | Reasoning layer image definition |
| `docker-compose.serve.yml` | Static serve mode overlay; referenced directly by `run.sh` |
| `.env.example` | Provider-specific `.env` stubs; appended to project `.env` at onboard time |

See [`../operations/provider_onboarding_guide.md`](../operations/provider_onboarding_guide.md) for the full provider contract and step-by-step implementation guide.

---

## Dry-Run Guarantees

A successful `make dry-run` proves:

- Both container images build without error
- Both containers start and the capability layer initialises `sandbox/`
- The reasoning layer can access and write to `sandbox/` via the shared volume
- Both containers terminate gracefully
- The diff pipeline runs and produces output in `.workspace/changes/`

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
