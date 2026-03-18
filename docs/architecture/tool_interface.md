# Tool Interface

This document defines the external contract between the agent-sandbox harness and onboarded projects. It specifies what an onboarded project must provide, what the harness guarantees in return, and the naming and generation conventions that bind them together.

Operator-facing workflow is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md). Internal implementation is in [`execution_model.md`](execution_model.md).

---

## Image Naming

Each project produces two container images:

| Image | Name pattern | Purpose |
|---|---|---|
| Capability layer | `<project>-agent-sandbox` | Sandbox, snapshot pipeline, diff pipeline |
| Reasoning layer | `<project>-opencode-agent` | Agent runtime (provider-specific suffix) |

`<project>` is the value of `PROJECT_NAME` defined in the project-side Makefile. Hyphens are used throughout — Docker Compose accepts them natively. The reasoning layer suffix changes when the provider changes (e.g. `<project>-claude-agent` for a Claude Code provider).

---

## Container Naming

Containers follow the same pattern with a `-1` suffix appended by Docker Compose:

| Container | Name |
|---|---|
| Capability layer | `<project>-agent-sandbox-1` |
| Reasoning layer | `<project>-opencode-agent-1` |

---

## Command Shapes

All commands are invoked via `make` targets in the project-side Makefile, which delegates to `agent-sandbox <subcommand>`.

| Command | Effect |
|---|---|
| `make start` | Build both images, write Compose files, `docker compose up` (standard mode) |
| `make serve` | Build both images, write Compose files, `docker compose up` with serve mode override (ports exposed) |
| `make dry-run` | Build both images, write Compose files, `docker compose up` with dry-run override; both containers start, reasoning writes to sandbox, graceful termination, diff written |
| `make stop` | `docker compose down`; triggers capability layer EXIT trap and diff pipeline |
| `make apply` | Apply `staged.diff` to host repo; optional `BRANCH=<n>` |
| `make build sandbox` | Build capability layer image only |
| `make build agent` | Build reasoning layer image only |
| `make build all` | Build both images |
| `make rebuild start` | Force rebuild of both images, then start |
| `make rebuild serve` | Force rebuild of both images, then serve |
| `make rebuild dry-run` | Force rebuild of both images, then dry-run |

`make start`, `make serve`, and `make dry-run` always call `docker build` before compose up. Docker's content-addressed cache produces a cache hit in under 5 seconds when source files are unchanged — no separate staleness check is required.

---

## Mount Shape Guarantees

The harness guarantees the following mount shape for every run. Onboarded projects may depend on these paths being present and having the stated access modes.

| Host path | Capability layer | Reasoning layer | Mode | Purpose |
|---|---|---|---|---|
| `SANDBOX_DIR/.snapshot/` | `/home/agentuser/.snapshot/` | — | RO | Project snapshot input |
| `SANDBOX_DIR/.workspace/input/` | — | `/home/agentuser/.input/` | RO | Task briefs, operator addenda |
| `SANDBOX_DIR/.workspace/output/` | — | `/home/agentuser/project/.workspace/output/` | RW | Agent progress, serialised data (no binaries) |
| `SANDBOX_DIR/.workspace/changes/` | `/home/agentuser/workspace/changes/` | — | RW | Diff output |
| Shared Docker volume | `/home/agentuser/sandbox/` | `/home/agentuser/project/sandbox/` | RW | Working content |

`PROJECT_DIR` is never mounted into either container.

---

## Onboarding

New projects are onboarded using the `agent-sandbox onboard` command, which creates and populates `SANDBOX_DIR` from templates:

```sh
agent-sandbox onboard --name=<project> --project=<path> --sandbox=<path>
```

This copies all required template files, creates `.workspace/` subdirectories, writes `.env` with derived path variables and operator stubs, and produces an `agents.md` stub. The operator fills in `agents.md` and reviews `.env` before the first run.

An onboarded project provides the following in `SANDBOX_DIR`:

| File | Required | Source | Purpose |
|---|---|---|---|
| `Makefile` | Yes | Template (copied by onboard) | Defines `PROJECT_NAME`; delegates to `agent-sandbox` subcommands; reads `PROJECT_DIR` and `SANDBOX_DIR` from `.env` |
| `.env` | Yes | Written by onboard | Machine-specific runtime variables (gitignored, never committed) |
| `agents.md` | Yes | Stub written by onboard | Agent context brief; describes the project, conventions, and expected outputs |
| `Dockerfile.sandbox` | No | Template (copied by onboard) | Capability layer Dockerfile; customise to add project-specific dependencies |

The harness generates `docker-compose.yml` and mode override files into `SANDBOX_DIR` from templates on each run. These generated files are not committed — they are recreated from templates on every invocation.

---

## Docker Compose Generation

`start_agent.sh` writes the Compose configuration into `SANDBOX_DIR` at each run, not at onboarding time. This ensures the Compose files always reflect the current harness version, even if the harness is updated between runs.

**Generated files:**

| File | Source template | Purpose |
|---|---|---|
| `docker-compose.yml` | `libs/_template/docker-compose.yml.template` | Base configuration: images, volumes, service dependencies, internal mounts |
| `docker-compose.serve.yml` | `libs/_template/docker-compose.serve.yml.template` | Serve mode override: adds ports block |
| `docker-compose.dry-run.yml` | `libs/_template/docker-compose.dry-run.yml.template` | Dry-run mode override |

**Baked vs `.env` split:** The base Compose file bakes stable project structure — image names, container names, service dependencies, volume definitions, internal mount paths. Machine-specific values — host paths, ports, credentials — are referenced as `${VARIABLE}` and resolved from `.env` at runtime.

**Mode composition:** The base `docker-compose.yml` has no ports exposed. Mode overrides are applied via `-f` flags:

- `make start` → `docker compose -f docker-compose.yml up`
- `make serve` → `docker compose -f docker-compose.yml -f docker-compose.serve.yml up`
- `make dry-run` → `docker compose -f docker-compose.yml -f docker-compose.dry-run.yml up`

---

## `.env` Runtime Variables

The `.env` file in `SANDBOX_DIR` is written once by `agent-sandbox onboard` and supplies machine-specific values to the generated Compose files. The harness reads these at run time; they are never baked into images. The operator sets `SERVE_PORT` and `OPENCODE_SERVER_PASSWORD` manually; all path variables are derived from `PROJECT_DIR` and `SANDBOX_DIR` and written by onboard.

| Variable | Purpose | Example |
|---|---|---|
| `PROJECT_DIR` | Absolute path to the project git repository | `/home/user/myproject` |
| `SANDBOX_DIR` | Absolute path to the sandbox directory | `/home/user/myproject-sandbox` |
| `SNAPSHOT_DIR` | Host path to `.snapshot/` | `${SANDBOX_DIR}/.snapshot` |
| `CHANGES_DIR` | Host path to `.workspace/changes/` | `${SANDBOX_DIR}/.workspace/changes` |
| `AGENT_INPUT_DIR` | Host path to `.workspace/input/` | `${SANDBOX_DIR}/.workspace/input` |
| `AGENT_OUTPUT_DIR` | Host path to `.workspace/output/` | `${SANDBOX_DIR}/.workspace/output` |
| `SERVE_PORT` | Host port for serve mode | `46553` |
| `OPENCODE_SERVER_PASSWORD` | Authentication for serve mode | `<password>` |

---

## Capability Layer Dockerfile

The capability layer image is project-controlled. Each project provides a `Dockerfile.sandbox` in `SANDBOX_DIR` — seeded from the default template by `agent-sandbox onboard`. Projects customise it to install project-specific dependencies, tools, or runtimes.

If `Dockerfile.sandbox` is absent when `make build sandbox` runs, the harness copies `libs/_template/dockerfile-default.sandbox` into `SANDBOX_DIR` as a working default. The Compose file always references the project-level `Dockerfile.sandbox` — the template is a seed, not a fallback at runtime.

The reasoning layer Dockerfile is provider-specific and lives in `providers/<provider>/Dockerfile`. It is not project-controlled.

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
