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

### `make start PROVIDER=<provider> [SERVE=1] [REFRESH=1] [REBUILD=1] [INTERACTIVE=1]`

Stops any running session for this project, builds missing images if needed, snapshots the project, and starts a NEW agent session. The terminal attaches to the agent TUI.

**Default behaviour:** always starts a new session with fresh identity. To resume a previous session, use `make resume` (see below) — `start` carries no resume path.

`PROVIDER` is required (unless `INTERACTIVE=1`). Fast path supplies it explicitly. Optional flags:
- `SERVE=1` — start the agent in serve mode instead of attaching a TUI: the terminal returns to the shell immediately, the agent runs in the background and is accessible via browser at `http://127.0.0.1:SERVE_PORT`. Stop with `make stop`. Serve is provider-specific (see the serve-overlay table under Container Naming).
- `REFRESH=1` — rebuilds sandbox and provider images + starts a new session. Base image is reused if it exists.
- `REBUILD=1` — rebuilds everything from scratch including the base image + starts a new session. Supersedes `REFRESH=1` if both are set.
- `INTERACTIVE=1` — the interactive **config wizard** (flag `--interactive`, the explicit slow mode): pick a provider from the available providers (`pi`, `hermes`, `opencode`) and an image build policy (default / refresh / rebuild), review the settings, then confirm to start. `.env` values (`name`/`project`/`sandbox`/`env`) come from the Makefile automatically and are not entered in the wizard. Args already supplied override the wizard rather than being re-prompted — e.g. `make start PROVIDER=hermes INTERACTIVE=1` skips the provider picker. Aborting exits cleanly without starting a session.

**Leaves behind:** `session/` (per-export `<EXPORT_TIME>-<SESSION_ID>/`) and `autosave/` (single overwritten `<SESSION_ID>/`) subfolders in `.workspace/session-diffs/`; updated provider session state in `.<provider>/`.

---

### `make resume SESSION_ID=<id>`

Resumes a previously-started session. The session inventory is the `.compose/<session-id>.yml` registry; each `start`/`stop` records the session it created/stopped.

- `SESSION_ID=<id>` — resume that specific session silently (recommended).
- `LIST=1` — list resumable sessions as an enriched table (`SESSION_ID | PROVIDER | STARTED | BRANCH | LAST_USED`), newest first (by raw `session-ts`), capped at 10 rows per page (same cap as the draft picker; a footer reports any remainder). The `PROVIDER` cell shows the provider plus its loaded agent image's recorded content signature as a short-parenthetical, e.g. `pi (14f9c3a)`, read from the record's `agent-sandbox.image-sig` label (baked at start/resume by `compose_generate` via docker inspect; no docker needed at list time; absent/empty → `pi` with no parenthetical). `STARTED` and `LAST_USED` are relative times ("2 hours ago"; `LAST_USED` = time since the session was last stopped, read from its per-session `.compose/<session-id>.log`; `---` when running or never stopped). Staleness is shown exception-only as warning labels: `[SANDBOX_STALE]` when the session's recorded `host-head-sha` differs from the current project HEAD (registry-truth, D7), and `[IMAGE_STALE]` when a referenced image's baked `container-sig` label differs from a recomputation of the current source (image-truth, D9); no label when fresh or unknown. Accepts an optional `PROVIDER=<n>` filter.
- `INTERACTIVE=1` — interactive picker over the session inventory + confirmation before resuming; the deliberately slow mode. Picker marks `[SANDBOX_STALE]` (sandbox) and `[IMAGE_STALE]` (image) sessions and paginates at 10 rows. Accepts an optional `PROVIDER=<n>` filter.
- `PROVIDER=<n>` — filter the session inventory by provider; use with `LIST=1` or `INTERACTIVE=1`.

`--interactive` always shows the picker and asks for confirmation, even when only one session matches — explicit interactivity is deliberate, not a shortcut.

---

### `make dry-run PROVIDER=<provider>`

Starts both bearer containers (sandbox/capability + agent/reasoning); each runs its own full readiness self-checks (docker_image .. agent_runtime), writes a per-container diagnostics record to the output mount, and orchestration validates the correct container was started from those records, then tears down. No agent is started; no user input is accepted. Produces no diff output.

`PROVIDER` is required. Use after a build or onboard to verify the harness is functional.

The check set and the bearer/orchestration responsibility split are defined in [`devlog/discussions/20260828-design-settled-dry_run_phase_split.md`](../../devlog/discussions/20260828-design-settled-dry_run_phase_split.md).

---

### `make build [TARGETS=<target>[,<target>...]]`

Builds images. Safe to run at any time; does not start or stop any containers.

`TARGETS` is optional. Accepts comma-separated values: one or more provider names, `sandbox`, or `all`. Default: `all`. `TARGET` (singular) is also accepted as a legacy alias.

| TARGETS value | Builds |
|---|---|
| `all` (default) | Sandbox image + every discovered provider |
| `pi` | `pi` provider only |
| `pi,hermes` | `pi` and `hermes` providers |
| `sandbox` | Sandbox image only |
| `pi,sandbox` | `pi` provider + sandbox image |

`REBUILD=1` forces a full rebuild from scratch (including base images). Without it, cached layers are reused when nothing has changed.

**Note:** `make start` also triggers builds implicitly via `REFRESH` or `REBUILD`, but with different semantics — it always builds the sandbox alongside the provider because a run session depends on both. `make build TARGETS=pi` leaves the sandbox image unchanged.

**Note on the dispatch model:** The `build` subcommand is dispatched to `scripts/build.sh` as an independent process (`exec`). The workflow subcommands (`apply`, `draft`, `confirm`, `reject`) are similarly dispatched to their own scripts in `scripts/workflows/`. Each receives its flags directly from the dispatcher and handles its own argument parsing and execution. This means each subcommand script can also be invoked directly for testing or debugging: `bash scripts/workflows/apply.sh --project=<path> --sandbox=<path> --diff=<file>`.

---

### `make prune [STALE=<sandbox|image|all>] [PROVIDER=<n>] [AGE_DAYS=<n>] [INTERACTIVE=1] [DRY_RUN=1]`

Registry-based prune (Rules 1+2) over the `.compose/<session-id>.yml` session registry. Prune is **always a complete pass** — Rule 1 removes stale records, Rule 2 removes resources whose session now has no record (orphaned); simulation is `DRY_RUN=1`, confirmation is `INTERACTIVE=1`. There is no partial/`SCORE` split.

**Rule 1 — stale records.** A `.compose/<session-id>.yml` record is selected when it is stale by the active `STALE` criterion and older than `AGE_DAYS` (default 3). The default (`STALE=all`) selects records stale by **either** dimension: sandbox (its recorded `host-head-sha` differs from the current project HEAD — registry-truth, see `docs/concepts/terminology.md` `## staleness`) or image (a referenced image's baked `container-sig` differs from the recomputed source sig). `STALE=sandbox` / `STALE=image` select that dimension only. Removing a record does not touch its resources directly; those become orphaned and are cleaned by Rule 2.

- `STALE=<kind>` — staleness kind to target: `sandbox` (repo out of date — the session's `host-head-sha` ≠ current HEAD), `image` (image out of date — a referenced image's baked `agent-sandbox.container-sig` ≠ recomputed source sig, so even resume carries an incomplete feature set), or `all`/unset (either criterion — the "remove all stale" filter).
- `PROVIDER=<n>` — narrow Rule 1's selection to records of that provider (same filter as `make resume`).

**Rule 2 — orphaned resources.** Resources labeled `agent-sandbox.sandbox-dir` whose `session-id` has no matching `.compose` record are removed: containers (`docker stop`+`rm`), networks, and volumes. Delivery-scoped: copy → volume + containers; mount → registry resources only. Worktrees are **never** touched.

- `INTERACTIVE=1` (flag `--interactive`) — show the prune plan (records + orphaned resources), print the equivalent non-interactive command, then confirm with a y/N prompt before acting.
- `DRY_RUN=1` (flag `--dry-run`) — print the plan without acting.

---

### `make apply DIFF=<path> [BRANCH=<branch>] [FORCE=1]`

Applies an exact diff file to `PROJECT_DIR` using `git apply` with index lines stripped. Does not commit — changes land unstaged for operator review. An empty diff file (no `diff --git` headers) is skipped with a warning; nothing is applied and the command succeeds.

`DIFF=<path>` (flag `--diff=<path>`) is **required** and must be the full path to an exact diff file. `apply` performs no channel, bundle, or auto-resolution — it applies the specified file directly.

`BRANCH` is optional. If supplied, checks out or creates the named branch before applying. `FORCE=1` applies with `--reject`, creating `.rej` files for conflicts.

**Interactive mode:** `INTERACTIVE=1` (flag `--interactive`) prints a git-oneline-style preview of the changes (the files the diff touches and the total file count), then asks for confirmation with a single y/N prompt before applying.

---

### `make draft [BUNDLE=<name>] [CHANNEL=<channel>] [BRANCH_SUMMARY=<slug>] [DIFFS=<start>..<end>]`

Creates a `draft/<SESSION_TS>-<slug>-<sha6>` branch on `PROJECT_DIR` and applies `patches/*.diff` sequentially, then `uncommitted.diff` if present. Empty bundle members land as message-bearing empty commits (with a warning); an empty `uncommitted.diff` is skipped with a warning.

The `--channel` flag (aliased as `CHANNEL=` in Makefile; shorthand `FROM=<channel>`) controls which directory the router searches.
By default, resolves from the `session` channel (`session-diffs/session/`) using auto-resolve (newest bundle). `BUNDLE=<name>` pins to a named bundle (name-only — absolute paths rejected).

**Channels:**
- `session` (default) — resolves from `session-diffs/session/`
- `autosave` — resolves from `session-diffs/autosave/` (shorthand: `FROM=autosave`)
- `bundles` — resolves from `output/bundles/` (shorthand: `FROM=bundles`)

`DIFFS=<start>..<end>` selects a sub-range of patches. `BRANCH_SUMMARY=<slug>` overrides the branch name suffix.

**Interactive mode:** `INTERACTIVE=1` (flag `--interactive`) guides the operator through a two-step numbered picker: channel selection and bundle selection. When both `BUNDLE=<name>` and a channel (via `FROM=` or `CHANNEL=`) are supplied with `--interactive`, the picker is skipped — the resolved patch list is shown and confirmed with a single y/N prompt. After selections are made, the equivalent non-interactive `make` command is printed (e.g. `Running: make draft CHANNEL=session BUNDLE=<name>`) before execution. When `BUNDLE=<name>` is provided and the named bundle is not in the displayed list, it is injected as option 0 in the bundle picker and becomes the default. When more bundles exist than the display limit (10), `n` and `p` navigate between pages. Interactive mode is opt-in only; non-interactive behaviour is unchanged.

---

### `make confirm [TARGET=<branch>]`

Rebases the current `draft/` branch onto `TARGET` (default: the source branch recorded in `.draft-state`), fast-forward merges, and deletes the draft branch.

---

### `make reject`

Discards the current `draft/` branch, returns to the source branch. Artefacts unchanged.

---

### `make package-branch [BUNDLE_SUMMARY=<text>] [BASELINE=<sha>]`

Host-side export. Packages all project changes as `patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, and `changed-files/`. Delegates to `agent-sandbox package-branch`, which writes to `OUTPUT_DIR/bundles/<ts>[-<summary>]-<runid>/`.

`BASELINE=<sha>` diffs against an explicit SHA instead of the session baseline.

---

### `make package-branch [BUNDLE_SUMMARY=<text>] [BASELINE=<sha>]`

Host-side export. Packages committed branch history as numbered diffs + `uncommitted.diff` + `all-changes.diff` + `changed-files/`. Delegates to `agent-sandbox package-branch`, which reads `.env` and writes to `INPUT_DIR/bundles/<ts>-<summary>/`.

`BASELINE=<sha>` overrides the baseline SHA (default: reads from SESSION_STATE — only available during a live session).

---

## Execution Modes

| Mode | Make target | Effect |
|---|---|---|
| `standard` | `make start PROVIDER=<n>` | Normal execution; agent TUI attaches to terminal |
| `serve` | `make start PROVIDER=<n> SERVE=1` | Provider-specific serve mode (see below) |
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

`docker-compose.yml`, `docker-compose.copy.yml`, `docker-compose.mount.yml`,
`docker-compose.dry-run.yml`, and `docker-compose.serve.yml` are repo-owned
templates — never written to `SANDBOX_DIR`. The merged result of
`compose_generate` is written to `SANDBOX_DIR/.compose/<session-id>.yml` and
persists after the session (see [`execution_model.md` — Compose
Generation](execution_model.md#compose-generation)). The delivery overlays
(`docker-compose.copy.yml` / `docker-compose.mount.yml`) are selected by
`SANDBOX_TYPE` at generation time — see the delivery-overlay note in
[`execution_model.md`](execution_model.md#compose-generation).

---

## `.env` Runtime Variables

| Variable | Default | Owner |
|---|---|---|
| `PROJECT_DIR` | Operator-supplied at onboard | Operator |
| `SANDBOX_DIR` | Operator-supplied at onboard | Operator |
| `SERVE_PORT` | Operator-supplied | Operator — host port for serve mode |
| `AUTOSAVE_INTERVAL` | `60` | Operator |

`SANDBOX_IMAGE_NAME` and `AGENT_IMAGE_NAME` are derived at run time via `src/build/image.sh` and are not stored in `.env`. Provider-specific variables are appended from `providers/<n>/.env.example` at onboard time.

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
| `base.dockerfile` | Yes | Stable install layers (system packages, runtimes, agent source); tagged `<provider>-base` |
| `provider.dockerfile` | Yes | Provider layer inheriting from `<provider>-base`; tagged `<provider>-agent-<project>` |
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

- Both container images build and start without error
- Each bearer container (sandbox/capability + agent/reasoning) runs its own full readiness self-check across six layers (docker_image, workspace_mounts, session_state, session_data, container_network, agent_runtime) and records the result to the output mount
- The capability layer initialises `sandbox/` (git baseline + SESSION_STATE `init_sha` is a valid commit)
- Cross-component link-up is correct: the reasoning layer reads the capability layer's state and markers via the shared volume
- The diff pipeline runs
- Orchestration validates the per-container diagnostics records — correct container started (identity echo-back matches expected; every layer `PASS`)

A dry-run does not prove agent correctness — it proves the harness containers start to a ready state with correct link-up.

---

## References

| Topic | Document |
|---|---|
| Internal implementation | [execution_model.md](execution_model.md) |
| CLI interaction conventions | [../development/interface-conventions.md](../development/interface-conventions.md) |
| Security model | [security.md](security.md) |
| Onboarding a project | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
| Adding a provider | [../operations/provider_onboarding_guide.md](../operations/provider_onboarding_guide.md) |
