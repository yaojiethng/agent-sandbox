# Tool Interface

This document defines the external contract between the agent-sandbox harness and onboarded projects. It specifies what an onboarded project must provide, what the harness guarantees in return, and the naming and generation conventions that bind them together.

Operator-facing workflow is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md). Internal implementation is in [`execution_model.md`](execution_model.md).

---

## Image Naming

Each project produces two container images:

| Image | Name pattern | Purpose |
|---|---|---|
| Capability layer | `sandbox-<project>` | Sandbox, snapshot pipeline, diff pipeline |
| Reasoning layer | `<provider>-agent-<project>` | Agent runtime (provider-specific) |

`<project>` is the value of `PROJECT_NAME` defined in the project-side Makefile. `<provider>` is the reasoning layer provider name (e.g. `opencode`, `hermes`). Hyphens are used throughout — Docker Compose accepts them natively.

---

## Container Naming

Container names match image names exactly. `container_name:` is set explicitly in the compose template — Docker Compose does not append an index suffix.

| Container | Name |
|---|---|
| Capability layer | `sandbox-<project>` |
| Reasoning layer | `<provider>-agent-<project>` |

This means only one session per project can run at a time. `docker inspect`, `docker logs`, and `docker stop` address containers by name directly without going through Compose.

---

## Command Shapes

All commands are invoked via `make` targets in the project-side Makefile, which delegates to `agent-sandbox <subcommand>`. Provider and rebuild behaviour are passed as Make variables.

| Command | Effect |
|---|---|
| `make build` | Build capability layer image + all provider images |
| `make build PROVIDER=hermes` | Build capability layer image + hermes provider image only |
| `make build PROVIDER=hermes,sandbox` | Build hermes provider image + capability layer image only |
| `make start PROVIDER=<n>` | Check images exist; `docker compose up` (standard mode) |
| `make serve PROVIDER=<n>` | Check images exist; `docker compose up` with provider serve overlay |
| `make dry-run PROVIDER=<n>` | Check images exist; `docker compose up` with dry-run overlay; liveness check |
| `make start PROVIDER=<n> REBUILD=1` | Rebuild capability layer + provider images, then start |
| `make apply` | Apply `staged.diff` to host repo; optional `BRANCH=<n>` |

`make start`, `make serve`, and `make dry-run` require `PROVIDER` — they error clearly if it is absent. They do not trigger builds unless `REBUILD=1` is passed.

---

## Execution Modes

The harness supports the following execution modes. The mode is passed to the provider's `run.sh`, which validates that the mode is supported and dispatches accordingly.

| Mode | Make target | Effect |
|---|---|---|
| `standard` | `make start PROVIDER=<n>` | Normal execution; agent TUI attaches to terminal |
| `serve` | `make serve PROVIDER=<n>` | Provider-specific serve mode; behaviour varies by provider (see below) |
| `dry-run` | `make dry-run PROVIDER=<n>` | Liveness check only; both containers start, `dry_run.sh` executes inside the reasoning layer, containers tear down; no agent interaction |
| `headless` | — | Reserved; not yet implemented |

**Serve mode is provider-specific.** The serve overlay lives in `providers/<n>/docker-compose.serve.yml` in the agent-sandbox repo — it is not copied to `SANDBOX_DIR`. Each provider's `run.sh` references it directly.

| Provider | Serve behaviour |
|---|---|
| `opencode` | OpenCode runs in server mode; port exposed at `SERVE_PORT` on `127.0.0.1`; `OPENCODE_SERVER_PASSWORD` controls authentication |
| `hermes` | Open WebUI launched as a companion service; port exposed at `SERVE_PORT` on `127.0.0.1` |

`standard` and `serve` differ only in how the reasoning layer is invoked. `dry-run` uses `docker compose exec` to run `dry_run.sh` and does not start the agent.

---

## Mount Shape Guarantees

The harness guarantees the following mount shape for every run. Onboarded projects may depend on these paths and access modes — including when extending `Dockerfile.sandbox` with additional tooling that writes to or reads from the sandbox.

| Host path (`$VAR`) | Capability layer path | Reasoning layer path | Mode | Owner |
|---|---|---|---|---|
| `$SNAPSHOT_DIR` | `/home/agentuser/.snapshot/` | — | RO | Harness — rebuilt before each run |
| `$CHANGES_DIR` | `/home/agentuser/workspace/changes/` | — | RW | Harness — diff pipeline output |
| `$INPUT_DIR` | — | `/home/agentuser/workspace/input/` | RO | Operator — populated before a run |
| `$OUTPUT_DIR` | — | `/home/agentuser/workspace/output/` | RW | Agent — written during a run |
| Docker anonymous volume | `/home/agentuser/sandbox/` | `/home/agentuser/sandbox/` | RW | Docker — owned by capability layer; shared via `--volumes-from` |

`PROJECT_DIR` is never mounted into either container. The `sandbox/` volume is not a host path — it is created by Docker when the capability layer container starts and destroyed on teardown (`down -v`). The reasoning layer can only access it while the capability layer container is running.

---

## Onboarding

New projects are onboarded using the `agent-sandbox onboard` command, which creates and populates `SANDBOX_DIR` from templates:

```sh
agent-sandbox onboard --name=<project> --project=<path> --sandbox=<path>
```

This copies all required template files, creates `.workspace/` subdirectories, writes `.env` with derived path variables and shared operator stubs, appends provider-specific stubs from each `providers/<n>/.env.example`, and produces an `agents.md` stub. The operator fills in `agents.md` and reviews `.env` before the first run.

An onboarded project provides the following in `SANDBOX_DIR`:

| File | Required | Source | Purpose |
|---|---|---|---|
| `Makefile` | Yes | Template (copied by onboard) | Defines `PROJECT_NAME`; delegates to `agent-sandbox` subcommands; reads `PROJECT_DIR` and `SANDBOX_DIR` from `.env` |
| `.env` | Yes | Written by onboard | Machine-specific runtime variables (gitignored, never committed) |
| `agents.md` | Yes | Stub written by onboard | Agent context brief; describes the project, conventions, and expected outputs |
| `Dockerfile.sandbox` | Yes | Template (copied by onboard) | Capability layer Dockerfile; customise to add project-specific dependencies |

Note: `docker-compose.serve.yml` is **not** copied to `SANDBOX_DIR` at onboard time. The serve overlay for each provider lives in `providers/<n>/docker-compose.serve.yml` in the agent-sandbox repo and is referenced directly by the provider's `run.sh` at runtime.

---

## Docker Compose Generation

`scripts/start_agent.sh` writes the base Compose configuration into `SANDBOX_DIR` at each run. This ensures the Compose files always reflect the current harness version, even if the harness is updated between runs.

**Generated files:**

| File | Source template | Purpose |
|---|---|---|
| `docker-compose.yml` | `libs/_template/docker-compose.yml.template` | Base configuration: images, volumes, service dependencies, internal mounts |
| `docker-compose.dry-run.yml` | `libs/_template/docker-compose.dry-run.yml.template` | Dry-run mode override |

**Serve overlay:** `docker-compose.serve.yml` is **not** generated into `SANDBOX_DIR`. Each provider supplies a static serve overlay at `providers/<n>/docker-compose.serve.yml` in the agent-sandbox repo. The provider's `run.sh` references it directly via an absolute path — no copy to `SANDBOX_DIR` is needed, and the operator never manages this file.

**Baked vs `.env` split:** The base Compose file bakes stable project structure — image names, container names, service dependencies, volume definitions, internal mount paths. Machine-specific values — host paths, ports, credentials — are referenced as `${VARIABLE}` and resolved from `.env` at runtime.

**Mode composition:**

- `make start PROVIDER=<n>` → `docker compose -f docker-compose.yml up`
- `make serve PROVIDER=<n>` → `docker compose -f docker-compose.yml -f <repo>/providers/<n>/docker-compose.serve.yml up`
- `make dry-run PROVIDER=<n>` → `docker compose -f docker-compose.yml -f docker-compose.dry-run.yml up`

---

## `.env` Runtime Variables

The `.env` file in `SANDBOX_DIR` is written once by `agent-sandbox onboard` and supplies machine-specific values to the generated Compose files. The harness reads these at run time; they are never baked into images. Path variables are derived from `PROJECT_DIR` and `SANDBOX_DIR`; the operator sets the remaining values manually.

| Variable | Default | Owner |
|---|---|---|
| `PROJECT_DIR` | Operator-supplied at onboard | Operator — the project git repository; never modified by the harness |
| `SANDBOX_DIR` | Operator-supplied at onboard | Operator — created by `agent-sandbox onboard` |
| `SNAPSHOT_DIR` | `$SANDBOX_DIR/.snapshot` | Harness — rebuilt by `scripts/start_agent.sh` before each run |
| `CHANGES_DIR` | `$SANDBOX_DIR/.workspace/changes` | Harness — written by the capability layer diff pipeline |
| `INPUT_DIR` | `$SANDBOX_DIR/.workspace/input` | Operator — populated before a run; harness places the brief here |
| `OUTPUT_DIR` | `$SANDBOX_DIR/.workspace/output` | Agent — written during a run; cleared by operator between runs |
| `SERVE_PORT` | Operator-supplied | Operator — host port for serve mode |
| `AUTOSAVE_INTERVAL` | `60` | Operator — autosave interval in seconds |

**Provider-specific stubs** are appended to `.env` by `agent-sandbox onboard` from `providers/<n>/.env.example`. For example, the `opencode` provider appends `OPENCODE_SERVER_PASSWORD=` — used by the OpenCode serve overlay. Each provider documents its own variables in its `.env.example`.

---

## Capability Layer Dockerfile

The capability layer image is project-controlled. Each project provides a `Dockerfile.sandbox` in `SANDBOX_DIR` — seeded from the default template by `agent-sandbox onboard`. Projects customise it to install project-specific dependencies, tools, or runtimes.

The reasoning layer Dockerfile is provider-specific and lives in `providers/<provider>/Dockerfile`. It is not project-controlled.

---

## Capability Layer Contract

The capability layer makes the following guarantees to the reasoning layer. These must hold regardless of how `Dockerfile.sandbox` is customised — they are the interface the reasoning layer depends on.

### Readiness signal

The capability layer **must** declare a `HEALTHCHECK` in `Dockerfile.sandbox`. The check **must** verify that `sandbox/` is fully initialised — at minimum, that `sandbox/.git` exists, confirming the snapshot has been unpacked and the git baseline committed.

The reasoning layer treats a healthy status as the signal that `sandbox/` is ready to access. The harness enforces this in two ways:

- **`docker compose up`**: the `depends_on: condition: service_healthy` declaration on the agent service prevents the reasoning layer container from starting until the capability layer reports healthy.
- **`docker compose run`**: `depends_on` conditions are not applied. The harness polls `docker inspect` on the capability layer container by name until health status is `healthy` before attaching the agent.

A capability layer that does not declare a `HEALTHCHECK`, or whose check does not verify `sandbox/` initialisation, breaks the readiness contract and may cause the reasoning layer to attach before working content is available.

### Volume ownership

The capability layer **must** declare `sandbox/` as a `VOLUME` in `Dockerfile.sandbox`. This promotes `sandbox/` to a Docker anonymous volume, making it accessible to the reasoning layer via `--volumes-from`. Without this declaration, `sandbox/` exists only in the capability layer's writable layer and is invisible to other containers.

The anonymous volume is created fresh at each session start and destroyed on teardown (`docker compose down -v`). The reasoning layer can only access `sandbox/` while the capability layer container is running — if the capability layer exits, the volume becomes inaccessible.

### Sandbox initialisation

Before reporting healthy, the capability layer **must** have:

1. Copied `.snapshot/` into `sandbox/`
2. Initialised a git repository in `sandbox/`
3. Committed a baseline — the diff pipeline computes `staged.diff` against this SHA on exit

The reasoning layer may assume all three conditions hold when it attaches.

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
| Internal implementation details | [execution_model.md](execution_model.md) |
| Design principles and invariants | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security model and trust boundaries | [security.md](security.md) |
| Onboarding and running guide | [../operations/quickstart.md](../operations/quickstart.md) |