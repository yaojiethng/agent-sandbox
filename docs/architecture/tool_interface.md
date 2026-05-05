# Tool Interface

External contract between the agent-sandbox harness and onboarded projects: what the harness guarantees, what a project must provide, and the naming conventions that bind them.

Internal implementation is in [`execution_model.md`](execution_model.md).

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

**Leaves behind:** `session/` and `autosave/` subfolders in `.workspace/session-diffs/<SESSION_TS>-<BRANCH>/`; updated provider session state in `.<provider>/`.

---

### `make serve PROVIDER=<provider> [REBUILD=1]`

Same as `make start` but starts the agent in serve mode. The terminal is returned to the shell immediately; the agent runs in the background and is accessible via browser at `http://127.0.0.1:SERVE_PORT`. Stop with `make stop`.

`PROVIDER` is required. `REBUILD=1` behaves identically to `make start`.

---

### `make dry-run PROVIDER=<provider>`

Starts both containers, verifies the sandbox initialises correctly, then tears down. No agent is started; no user input is accepted. Produces no diff output.

`PROVIDER` is required. Use after a build or onboard to verify the harness is functional.

---

### `make build [TARGET=<provider>[,sandbox]]`

Builds images. Safe to run at any time; does not start or stop any containers.

`TARGET` is optional. Without it, all provider images and the sandbox image are built. `TARGET=<provider>` builds the named provider only. `TARGET=<provider>,sandbox` builds the named provider and the sandbox image.

---

### `make apply [CHANNEL=<channel>] [SESSION=<name>] [DIFF=<path>] [BRANCH=<branch>] [FORCE=1]`

Applies a diff file to `PROJECT_DIR` using `git apply` with index lines stripped. Does not commit — changes land unstaged for operator review.

The `--channel` flag (aliased as `CHANNEL=` in Makefile) controls which directory the router searches.
By default, resolves from the `diffs` channel (`output/diffs/`) using auto-resolve (newest session). `SESSION=<name>` pins to a named session. `DIFF=<path>` bypasses all channel resolution — applies the specified file directly.

**Channels:**
- `diffs` (default) — resolves `uncommitted.diff` from `output/diffs/`
- `session` — resolves `uncommitted.diff` from `session-diffs/session/`
- `autosave` — resolves `uncommitted.diff` from `session-diffs/autosave/` (shorthand: `AUTOSAVE=1`)

`BRANCH` is optional. If supplied, checks out or creates the named branch before applying. `FORCE=1` applies with `--reject`, creating `.rej` files for conflicts.

---

### `make draft [SESSION=<name>] [CHANNEL=<channel>] [BRANCH_SUMMARY=<slug>] [DIFFS=<start>..<end>]`

Creates a `draft/<SESSION_TS>-<slug>-<sha6>` branch on `PROJECT_DIR` and applies `patches/*.diff` sequentially, then `uncommitted.diff` if present.

The `--channel` flag (aliased as `CHANNEL=` in Makefile, with `AUTOSAVE=1` → `channel=autosave` and `BUNDLE=1` → `channel=bundles` shortcuts) controls which directory the router searches.
By default, resolves from the `session` channel (`session-diffs/session/`) using auto-resolve (newest session). `SESSION=<name>` pins to a named session (name-only — absolute paths rejected).

**Channels:**
- `session` (default) — resolves from `session-diffs/session/`
- `autosave` — resolves from `session-diffs/autosave/` (shorthand: `AUTOSAVE=1`)
- `bundles` — resolves from `output/bundles/` (shorthand: `BUNDLE=1`)

`DIFFS=<start>..<end>` selects a sub-range of patches. `BRANCH_SUMMARY=<slug>` overrides the branch name suffix.

---

### `make confirm [TARGET=<branch>]`

Rebases the current `draft/` branch onto `TARGET` (default: the source branch recorded in `.draft-state`), fast-forward merges, and deletes the draft branch.

---

### `make reject`

Discards the current `draft/` branch, returns to the source branch. Artefacts unchanged.

---

### `make package-diff [SESSION_SUMMARY=<text>] [ALL=1] [BASELINE=<sha>]`

Host-side export. Packages uncommitted changes from `PROJECT_DIR` as `uncommitted.diff` + `changed-files/`. Delegates to `agent-sandbox package-diff`, which reads `.env` and writes to `INPUT_DIR/diffs/<ts>-<summary>/`.

`ALL=1` packages all changes since session baseline (`all-changes.diff`). `BASELINE=<sha>` packages against an explicit SHA.

---

### `make package-branch [SESSION_SUMMARY=<text>] [BASELINE=<sha>]`

Host-side export. Packages committed branch history as numbered diffs + `uncommitted.diff` + `all-changes.diff` + `changed-files/`. Delegates to `agent-sandbox package-branch`, which reads `.env` and writes to `INPUT_DIR/bundles/<ts>-<summary>/`.

`BASELINE=<sha>` overrides the baseline SHA (default: reads from SESSION_STATE — only available during a live session).

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
| `SERVE_PORT` | Operator-supplied | Operator — host port for serve mode |
| `AUTOSAVE_INTERVAL` | `60` | Operator |

`SANDBOX_IMAGE_NAME` and `AGENT_IMAGE_NAME` are derived at run time via `libs/containers.sh` and are not stored in `.env`. Provider-specific variables are appended from `providers/<n>/.env.example` at onboard time.

### Runtime-derived paths (not stored in `.env`)

These paths are derived from `SANDBOX_DIR` at run time by `dirs_resolve` in `libs/dirs.sh`. They are not stored in `.env` because they are strict functions of `SANDBOX_DIR` — storing them would introduce drift risk without providing any configurable behaviour.

| Variable | Derivation |
|---|---|
| `SNAPSHOT_DIR` | `$SANDBOX_DIR/.snapshot` |
| `CHANGES_DIR` | `$SANDBOX_DIR/.workspace/session-diffs` |
| `INPUT_DIR` | `$SANDBOX_DIR/.workspace/input` |
| `OUTPUT_DIR` | `$SANDBOX_DIR/.workspace/output` |

Inside the container, the workspace directory is named `workspace/` (visible) instead of `.workspace/` (hidden). The `WORKSPACE_DIR_NAME` override (`workspace`) is set in `sandbox-entrypoint.sh` and `dry_run.sh` before calling `dirs_resolve`.

---

## Capability Layer Contract

Guarantees the capability layer makes to the reasoning layer. Enforced by the harness — a conforming provider does not need to re-verify them.

**Readiness signal:** When the capability layer reports healthy, `sandbox/` is fully initialised. The reasoning layer may treat a healthy status as the unconditional signal to proceed.

**Volume ownership:** `sandbox/` is a Docker anonymous volume owned by the capability layer. The reasoning layer accesses it via `--volumes-from`. Created fresh at session start; destroyed on teardown. Inaccessible if the capability layer is not running.

**Sandbox initialisation:** Before reporting healthy, the capability layer will have:
1. Copied `.snapshot/` into `sandbox/`
2. Initialised a git repository in `sandbox/`
3. Committed a baseline SHA — the diff pipeline computes artefacts against this on exit

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
- The diff pipeline runs and produces output in `.workspace/session-diffs/<SESSION_TS>-<BRANCH>/`

A dry-run does not prove agent correctness — it proves the harness infrastructure is functional.

---

## References

| Topic | Document |
|---|---|
| Internal implementation | [execution_model.md](execution_model.md) |
| Security model | [security.md](security.md) |
| Onboarding a project | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
| Adding a provider | [../operations/provider_onboarding_guide.md](../operations/provider_onboarding_guide.md) |
