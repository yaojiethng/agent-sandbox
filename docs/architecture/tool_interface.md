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
| `make start` | Check images are built and not stale; write Compose files; `docker compose up` (standard mode) |
| `make serve` | Check images are built and not stale; write Compose files; `docker compose up` with serve mode override (ports exposed) |
| `make dry-run` | Check images are built and not stale; write Compose files; `docker compose up` with dry-run override; both containers start, reasoning writes to sandbox, graceful termination, diff written |
| `make stop` | `docker compose down`; triggers capability layer EXIT trap and diff pipeline |
| `make apply` | Apply `staged.diff` to host repo; optional `BRANCH=<n>` |
| `make build sandbox` | Build capability layer image only |
| `make build agent` | Build reasoning layer image only (`providers/opencode/build.sh`) |
| `make rebuild` | Force rebuild of both images |

`make start`, `make serve`, and `make dry-run` check that images exist and warn if stale. They do not trigger builds — the operator runs `make build` or `make rebuild` explicitly.

---

## Execution Modes

The harness supports the following execution modes. The mode is passed as an argument to `make` and forwarded to the provider's `run.sh`, which validates that the mode is supported and dispatches accordingly.

| Mode | Make target | Effect |
|---|---|---|
| `standard` | `make start` | Normal execution; network access allowed; OpenCode TUI attaches to terminal |
| `serve` | `make serve` | OpenCode runs in server mode; port exposed at `SERVE_PORT` on `127.0.0.1` |
| `dry-run` | `make dry-run` | Liveness check only; both containers start, `dry_run.sh` executes inside the reasoning layer, containers tear down; no agent interaction |
| `headless` | — | Reserved; not yet implemented |

`standard` and `serve` differ only in how the reasoning layer is invoked — `standard` uses `docker compose run` to attach a TTY; `serve` uses `docker compose up -d` and exposes a port. `dry-run` uses `docker compose exec` to run `dry_run.sh` and does not start OpenCode.

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

This copies all required template files, creates `.workspace/` subdirectories, writes `.env` with derived path variables and operator stubs, and produces an `agents.md` stub. The operator fills in `agents.md` and reviews `.env` before the first run.

An onboarded project provides the following in `SANDBOX_DIR`:

| File | Required | Source | Purpose |
|---|---|---|---|
| `Makefile` | Yes | Template (copied by onboard) | Defines `PROJECT_NAME`; delegates to `agent-sandbox` subcommands; reads `PROJECT_DIR` and `SANDBOX_DIR` from `.env` |
| `.env` | Yes | Written by onboard | Machine-specific runtime variables (gitignored, never committed) |
| `agents.md` | Yes | Stub written by onboard | Agent context brief; describes the project, conventions, and expected outputs |
| `Dockerfile.sandbox` | Yes | Template (copied by onboard) | Capability layer Dockerfile; customise to add project-specific dependencies |

`Dockerfile.sandbox` is operator-controlled. `agent-sandbox onboard` seeds it from `libs/_template/dockerfile-default.sandbox` as a working default. The operator amends it as needed. `scripts/build_sandbox.sh` always builds from the project's `Dockerfile.sandbox` in `SANDBOX_DIR` — the template is a seed, not a runtime fallback.

The harness generates `docker-compose.yml` and mode override files into `SANDBOX_DIR` from templates on each run. These generated files are not committed — they are recreated from templates on every invocation.

---

## Docker Compose Generation

`scripts/start_agent.sh` writes the Compose configuration into `SANDBOX_DIR` at each run, not at onboarding time. This ensures the Compose files always reflect the current harness version, even if the harness is updated between runs.

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

The `.env` file in `SANDBOX_DIR` is written once by `agent-sandbox onboard` and supplies machine-specific values to the generated Compose files. The harness reads these at run time; they are never baked into images. Path variables are derived from `PROJECT_DIR` and `SANDBOX_DIR`; the operator sets the remaining values manually.

| Variable | Default | Owner |
|---|---|---|
| `PROJECT_DIR` | Operator-supplied at onboard | Operator — the project git repository; never modified by the harness |
| `SANDBOX_DIR` | Operator-supplied at onboard | Operator — created by `agent-sandbox onboard` |
| `SNAPSHOT_DIR` | `$SANDBOX_DIR/.snapshot` | Harness — rebuilt by `scripts/start_agent.sh` before each run |
| `CHANGES_DIR` | `$SANDBOX_DIR/.workspace/changes` | Harness — written by the capability layer diff pipeline |
| `INPUT_DIR` | `$SANDBOX_DIR/.workspace/input` | Operator — populated before a run; harness places the brief here |
| `OUTPUT_DIR` | `$SANDBOX_DIR/.workspace/output` | Agent — written during a run; cleared by operator between runs |
| `SANDBOX_IMAGE_NAME` | `<project>-agent-sandbox` | Harness — derived from `PROJECT_NAME`; built by `scripts/build_sandbox.sh` |
| `AGENT_IMAGE_NAME` | `<project>-opencode-agent` | Harness — derived from `PROJECT_NAME`; built by `providers/opencode/build.sh` |
| `SERVE_PORT` | Operator-supplied | Operator — host port for serve mode |
| `OPENCODE_SERVER_PASSWORD` | Operator-supplied | Operator — authentication for serve mode |

---

## Capability Layer Dockerfile

The capability layer image is project-controlled. Each project provides a `Dockerfile.sandbox` in `SANDBOX_DIR` — seeded from the default template by `agent-sandbox onboard`. Projects customise it to install project-specific dependencies, tools, or runtimes.

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
