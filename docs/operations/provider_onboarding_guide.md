# Provider Onboarding Guide

Step-by-step guide to adding a new reasoning layer provider to agent-sandbox. A provider is a self-contained directory under `providers/<n>/` that supplies the build script, run script, serve overlay, and `.env` stubs for one reasoning layer agent.

The provider interface contract is defined in [`../architecture/tool_interface.md` — Provider Interface](../architecture/tool_interface.md#provider-interface). This guide walks through implementing that contract. Refer to [`../architecture/execution_model.md`](../architecture/execution_model.md) for implementation detail on how the harness calls provider scripts.

`opencode` and `hermes` are both conforming providers and are the reference implementations for this guide.

---

## What You Are Building

A conforming provider supplies five files:

```
providers/<n>/
├── Dockerfile                    ← reasoning layer image definition
├── build.sh                      ← builds the reasoning layer image
├── run.sh                        ← handles all container invocation
├── docker-compose.serve.yml      ← static serve mode overlay
└── .env.example                  ← provider-specific .env stubs
```

None of these files are copied to `SANDBOX_DIR`. They live in the agent-sandbox repo and are referenced directly at run time.

---

## Step 1 — Create the provider directory

```sh
mkdir providers/<n>
```

Use a short lowercase name with hyphens if needed (e.g. `opencode`, `hermes`, `claude-desktop`). This name becomes the `<provider>` component in image and container names (`<provider>-agent-<project>`).

---

## Step 2 — Write the Dockerfile

The Dockerfile defines the reasoning layer image. It must:

- Install the agent runtime and any dependencies it requires
- Set `ENTRYPOINT` to the agent launch command or a wrapper script
- Not include project-specific content — the image is shared across all projects using this provider

The agent brief and operator input files are available at `/home/agentuser/workspace/input/` via a read-only bind mount at runtime. `sandbox/` is available at `/home/agentuser/sandbox/` via `--volumes-from`. Neither path needs to be created in the Dockerfile.

**Reference:** `providers/opencode/Dockerfile`

---

## Step 3 — Write `build.sh`

`build.sh` builds the reasoning layer image. It is called by the operator via `make build TARGET=<n>` or `make build` (which iterates all providers). It is never called by `scripts/start_agent.sh`.

Required behaviour:
- Accept `--name=<project>` — the project name; used to construct the image name `<provider>-agent-<project>`
- Accept `--no-cache` — passed through to `docker build`
- Produce an image named `<provider>-agent-<project>`
- Exit non-zero with a clear message on failure

`scripts/build_sandbox.sh` handles the capability layer build separately — `build.sh` is only responsible for the reasoning layer image.

**Reference:** `providers/opencode/build.sh`

---

## Step 4 — Write `run.sh`

`run.sh` handles all container invocation for the provider. It is called by `scripts/start_agent.sh` after pre-flight completes.

**What `run.sh` receives:**

`scripts/start_agent.sh` exports all `.env` variables into the environment before calling `run.sh`. Key variables available without re-derivation:

| Variable | Value |
|---|---|
| `SANDBOX_IMAGE_NAME` | `sandbox-<project>` |
| `AGENT_IMAGE_NAME` | `<provider>-agent-<project>` |
| `PROJECT_NAME` | Project name |
| `SANDBOX_DIR` | Absolute path to harness workspace |
| `SNAPSHOT_DIR`, `CHANGES_DIR`, `INPUT_DIR`, `OUTPUT_DIR` | Absolute host paths |
| `SERVE_PORT` | Host port for serve mode |

`run.sh` also receives two arguments:
- `--mode=<mode>` — one of `standard`, `serve`, `dry-run`
- `--compose-file=<path>` — absolute path to the pre-generated merged compose tmpfile

**Required behaviour:**

- Validate that `--compose-file` exists and is readable; exit non-zero with a clear message if not
- Dispatch on `--mode`:
  - `standard` — `docker compose -f <compose-file> up`
  - `serve` — `docker compose -f <compose-file> -f <abs-path-to-docker-compose.serve.yml> up`
  - `dry-run` — use `compose_dry_run` from `libs/compose.sh` (handles exec, liveness check, teardown)
  - unsupported mode — exit non-zero with a message naming the unsupported mode
- Register a trap to delete the tmpfile on exit — `run.sh` owns cleanup of the compose tmpfile it receives
- Call `docker compose down -v` on exit to destroy the anonymous sandbox volume

Use the helper functions in `libs/compose.sh` where possible:

| Function | Purpose |
|---|---|
| `compose_args` | Builds the `-f` flag list for a given mode |
| `compose_dry_run` | Full dry-run sequence: up, exec, liveness check, down |
| `compose_teardown` | `docker compose down -v` |
| `compose_sandbox_wait` | Polls capability layer health before attaching agent (for `docker compose run` paths) |

**Reference:** `providers/opencode/run.sh`, `providers/hermes/run.sh`

---

## Step 5 — Write `docker-compose.serve.yml`

The serve overlay is a static Compose file that extends the base configuration for serve mode. It is referenced directly by `run.sh` using an absolute path into the repo — it is never copied to `SANDBOX_DIR`.

It should contain only provider-specific serve configuration: port bindings, additional services (e.g. a UI container), provider credentials. It must not redefine services or volumes already defined in the base compose template.

If the provider does not support serve mode, create the file anyway (it can be empty or contain a comment) and have `run.sh` exit with an unsupported-mode error when `--mode=serve` is passed.

**Reference:** `providers/opencode/docker-compose.serve.yml`, `providers/hermes/docker-compose.serve.yml`

---

## Step 6 — Write `.env.example`

`.env.example` documents and seeds the provider-specific variables the provider requires. It is appended to the project's `.env` by `agent-sandbox onboard` — once for each provider present in the repo at onboard time.

Format: one variable per line, with a comment explaining the expected value. Variables should be left empty or given a safe default.

```sh
# Provider-specific variables for <n>
SOME_API_KEY=
SOME_PORT=8080
```

Variables that are always derivable from other `.env` values (e.g. image names) should not appear here — they are exported by `scripts/start_agent.sh` at run time.

**Reference:** `providers/opencode/.env.example`, `providers/hermes/.env.example`

---

## Step 7 — Verify conformance

Run the dry-run sequence against a onboarded project to verify the provider integrates correctly:

```sh
make dry-run PROVIDER=<n>
```

A passing dry-run confirms:
- The reasoning layer image builds without error
- Both containers start and the capability layer initialises `sandbox/`
- The reasoning layer can access `sandbox/` via the shared volume
- Both containers terminate gracefully
- The diff pipeline produces output in `.workspace/changes/`

If `make dry-run` passes, the provider conforms to the harness interface.

Optionally verify serve mode if implemented:

```sh
make serve PROVIDER=<n>
```

Confirm the serve overlay is picked up from the repo (not from `SANDBOX_DIR`) and the provider-specific service starts correctly.

---

## Step 8 — Register the provider

No changes to `scripts/` or `libs/` are required. The harness discovers providers by glob (`providers/*/build.sh`). Once the five files exist under `providers/<n>/`, the provider is available to all onboarded projects.

Operators onboarding new projects after the provider is added will receive the provider's `.env.example` stubs automatically. Operators with existing projects should run `agent-sandbox onboard --refresh` to append the new provider's stubs to their `.env`.

---

## References

| Document | Purpose |
|---|---|
| [`../architecture/tool_interface.md`](../architecture/tool_interface.md) | Provider interface contract and execution mode definitions |
| [`../architecture/execution_model.md`](../architecture/execution_model.md) | How `start_agent.sh` calls `run.sh`; compose generation internals |
| [`libs/compose.sh`](../../libs/compose.sh) | Helper functions available to `run.sh` |
