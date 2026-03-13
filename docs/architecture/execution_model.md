# Execution Model

This document describes how a single agent run executes: how project files enter the container, how the sandbox is prepared, how agent changes are captured, and how outputs are returned to the host. It covers the snapshot pipeline, mount shape, entrypoint sequence, and diff workflow.

Implementation decisions are recorded here alongside the design they produce. Operator-facing workflow is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md).

---

## CLI Wrapper

`scripts/agent-sandbox.sh` is a dispatch wrapper installed onto the host as the `agent-sandbox` CLI. It is the interface used by onboarded projects — they call `agent-sandbox <subcommand>` from their own Makefile without any knowledge of the agent-sandbox repo layout.

Installation is performed once from the agent-sandbox repo:

```
make install                       # installs to /usr/local/bin/agent-sandbox
make install INSTALL_DIR=~/bin     # installs to ~/bin/agent-sandbox
```

The install directory is resolved in order: `INSTALL_DIR` argument to `make install`, then `INSTALL_DIR` in the repo's `.env` file, then `/usr/local/bin` as the default. This allows machine-specific install paths to be set once in `.env` without repeating them on every `make install` invocation.

`make install` substitutes the repo path into the wrapper at install time, so the installed binary has `AGENT_SANDBOX_REPO` baked in. The source file in the repo (`scripts/agent-sandbox.sh`) contains a placeholder and is never executed directly.

| Subcommand | Delegates to |
|---|---|
| `start` | `providers/opencode/start_agent.sh standard` — staleness check before invocation |
| `dry-run` | `providers/opencode/start_agent.sh dry-run` — staleness check before invocation |
| `build` | `providers/opencode/build_agent.sh` |
| `apply` | `scripts/apply_workspace.sh --project=<n> --sandbox=<n> [--branch=<n>]` |
| `rebuild` | `build_agent.sh` then re-execs wrapper with remaining args |

For `start` and `dry-run` the wrapper runs two pre-flight checks before invoking `start_agent.sh`. First, if the project image does not exist, it calls `build_agent.sh` automatically and notifies the operator. Second, if the image exists but is stale — detected by comparing the current source digest against the label embedded in the image — it warns the operator and continues. The staleness warning is always the last line emitted before the run proceeds, so it is not lost in build output. If a rebuild triggered by staleness fails, the staleness warning is re-emitted as the final line before exit. See [Image Digest & Staleness](#image-digest--staleness) for the digest mechanism. To force a rebuild before any subcommand, prefix with `rebuild`:

```
agent-sandbox rebuild start   --name=<n> --project=<path> ...
agent-sandbox rebuild dry-run --name=<n> --project=<path> ...
```

`rebuild` extracts `--name` and `--project` from the passthrough args, runs `build_agent.sh`, then re-execs the wrapper with the original subcommand and flags. The `--rebuild` flag is not supported; `rebuild` as a subcommand is the only force-build path.

---

## Image Digest & Staleness

The harness embeds a content digest in each built image and checks it at run time to detect when source files have changed since the image was last built.

### Digest computation

`lib/image.sh` defines `image_compute_digest`, which computes a SHA-256 digest over two sets of files:

- All files in `lib/` — shared across all providers by convention
- Provider-specific files listed in `providers/<provider>/image-files.txt`, one relative-path-from-root per line

Both sets are concatenated in a deterministic order before hashing. The file list in `image-files.txt` must cover every file copied into the image by the provider's Dockerfile — omissions produce a digest that does not reflect all image inputs.

### Build-time label

`build_agent.sh` sources `lib/image.sh`, calls `image_compute_digest`, and passes the result as a Docker build label:

```
--label agent-sandbox.digest=<sha>
```

The label is embedded in the image at build time and retrievable via `docker inspect`.

### Start-time staleness check

Before invoking `start_agent.sh` for `start` or `dry-run`, the wrapper:

1. Recomputes the digest from current source files using `image_compute_digest`
2. Reads the `agent-sandbox.digest` label from the existing image via `docker inspect`
3. If the digests differ, emits a staleness warning and continues

The staleness warning is always the last line emitted before the run proceeds. If a rebuild is triggered and fails, the warning is re-emitted as the final line before exit, ensuring it is visible regardless of build output volume.

### Shared-lib assumption

All providers share `lib/`. The digest always includes the full contents of `lib/` regardless of which provider is in use. Provider-specific inputs are additive via `image-files.txt`.

---

## Directory Layout

The harness separates the project repository from harness artefacts into sibling directories under a common working directory. This keeps the project's git tree clean — no harness files ever appear in the project repo.

```
WORKDIR/
├── project-dir/              ← PROJECT_DIR (git repo, clean)
└── project-dir-sandbox/      ← SANDBOX_DIR (harness workspace, not committed)
    ├── Makefile
    ├── .env
    ├── .agent-input/         ← input channel (built at run time)
    │   ├── snapshot/         ← project snapshot built by harness
    │   ├── brief.md          ← agent brief (copied from --brief path)
    │   └── input/            ← operator-placed task files and briefs
    └── .workspace/           ← output channel (agent output)
        └── changes/
            └── staged.diff
```

`SANDBOX_DIR` defaults to `<parent-of-PROJECT_DIR>/<project-dir-name>-sandbox`. It is set explicitly in the project Makefile and passed to all subcommands.

### Terminology

| Term | Meaning |
|---|---|
| `PROJECT_DIR` | The project git repository. Never mounted into the container at runtime. |
| `SANDBOX_DIR` | Harness-owned sibling directory. Contains all harness artefacts. |
| `.agent-input/` | Read-only input channel mounted into the container. Contains snapshot, brief, and operator input files. |
| `.workspace/` | Read-write output channel mounted into the container. Contains agent output. |

---

## Invocation Model

`start_agent.sh` is invoked by the project-side `Makefile`. Project identity and paths are defined as variables in the Makefile and passed as named flags — there is no separate conf file.

```
start_agent.sh <mode> --name=<project_name> --project=<path> [--sandbox=<path>] [--brief=<rel>] [--env=<rel>] [--serve]
```

| Flag | Required | Description |
|---|---|---|
| `--name` | Yes | Project display name; used for Docker image naming (`opencode-agent-<name>`) |
| `--project` | Yes | Absolute WSL/Linux path to the project directory on the host |
| `--sandbox` | No | Absolute WSL/Linux path to the sandbox directory; defaults to `<parent-of-PROJECT_DIR>/<project-dir-name>-sandbox` |
| `--brief` | No | Path to agent brief, relative to `SANDBOX_DIR` |
| `--env` | No | Path to `.env` file, relative to `SANDBOX_DIR` |
| `--serve` | No | Start OpenCode in serve mode |

The `Makefile` defines `PROJECT_DIR` and `SANDBOX_DIR` explicitly as absolute paths. `AGENT_BRIEF` and `ENV_FILE` are relative paths resolved against `SANDBOX_DIR` inside `start_agent.sh`.

Machine-specific variables (`SERVE_PORT`, `OPENCODE_SERVER_PASSWORD`) live in a `.env` file in `SANDBOX_DIR`, gitignored. They are never committed and never enter the snapshot.

### Directory name definitions

`start_agent.sh` defines two variables that control the names of the harness-managed directories:

```bash
AGENT_INPUT_DIR_NAME=".agent-input"
AGENT_WORKSPACE_DIR_NAME=".workspace"
```

These are passed to the container as environment variables (`-e AGENT_INPUT_DIR_NAME=...`, `-e AGENT_WORKSPACE_DIR_NAME=...`) so that `container-entrypoint.sh` and `dry_run.sh` derive all paths from the same definitions. The Dockerfile hardcodes these names for `mkdir` — if the names are changed in `start_agent.sh`, the Dockerfile must be updated to match and the image rebuilt.

---

## Mount Shape

Three host directories are mounted into the container. None gives the agent access to `PROJECT_DIR` directly.

| Host path | Container path | Mode | Purpose |
|---|---|---|---|
| `SANDBOX_DIR/.agent-input/` | `/home/agentuser/.agent-input/` | read-only | Input channel: snapshot, brief, operator files |
| `SANDBOX_DIR/.workspace/` | `/home/agentuser/.workspace/` | read-write | Output channel: patch, logs |

`PROJECT_DIR` itself is not mounted at container runtime. The snapshot is fully constructed on the host before the container starts.

### Why `.agent-input/` is read-only

The snapshot and operator input files are inputs prepared before the run. The container must not modify them — doing so would break the reproducibility guarantee and could mask the baseline state used for diff generation. The entrypoint copies `.agent-input/snapshot/` into a container-local `sandbox/` before the agent runs; all agent writes go to `sandbox/`, not to the mount.

### Why `.workspace/` is the sole output channel

Restricting agent output to a single known directory enforces the staging invariant: no agent change reaches the host repository without passing through `.workspace/` and receiving human review.

---

## Snapshot Pipeline

The snapshot pipeline replicates the host repository state into the container sandbox without touching the host. It runs in two stages: host-side preparation before the container starts, and container-side unpacking inside the entrypoint.

All snapshot functions are defined in `lib/snapshot.sh` and sourced by both `start_agent.sh` and `container-entrypoint.sh`.

### Stage 1 — Host side (`start_agent.sh`)

**`snapshot_enumerate_files`** runs `git ls-files --cached --others --exclude-standard` inside `PROJECT_DIR`. This covers tracked files and untracked non-ignored files. Gitignored files — including secrets and `.env` — are excluded by definition. A warning is emitted if no `.gitignore` is present.

The `git ls-files` approach was chosen over alternatives (e.g. git bundle, rsync) because it respects `.gitignore` without requiring any mutation of the host repository. A git bundle approach was evaluated and rejected: it required a temporary commit on the host (`git add -A && git commit --no-verify`), which mutated HEAD, the staging area, and commit history, violating the invariant that the harness must not modify the host repo.

**`snapshot_copy_files`** reads the file list from stdin and copies files into `.agent-input/snapshot/` using `cp --parents` to preserve directory structure.

**`snapshot_validate` (gate 1)** runs after copy, before the container starts. Checks that `.agent-input/snapshot/` is non-empty and structurally sound. Non-zero exit aborts the run before Docker is invoked.

### Stage 2 — Container side (`container-entrypoint.sh`)

**`snapshot_validate` (gate 2)** runs first, against the mounted `.agent-input/snapshot/`. Catches mount failures or transfer corruption before the sandbox is prepared.

**`snapshot_copy_to_sandbox`** copies `.agent-input/snapshot/` into `sandbox/` inside the container. `sandbox/` is container-local and writable — this is where the agent works.

**`snapshot_init_git`** initialises a git repository in `sandbox/` and records a baseline commit. The baseline SHA is stored for diff generation on exit.

---

## Agent Brief

The agent brief (`brief.md`) is an optional task description passed to the agent at run time. It is resolved by `start_agent.sh` from the `AGENT_BRIEF` config key relative to `SANDBOX_DIR`, and copied into `.agent-input/brief.md`.

The entrypoint copies `brief.md` from `.agent-input/` into `sandbox/AGENTS.md` so the agent can read it alongside the project files.

---

## Operator Input Channel

The operator input channel allows task files, path lists, and additional briefs to be passed to the agent before a run. Files placed in `SANDBOX_DIR/.agent-input/input/` are copied into `sandbox/` at container startup alongside the project snapshot. The agent reads them as ordinary files; it cannot write back to this channel.

**Lifecycle:**
- Written by operator before the run (placed in `SANDBOX_DIR/.agent-input/input/`)
- Read by agent during the run (available in `sandbox/`)
- Operator clears or overwrites `input/` before the next run

The input channel is part of the `.agent-input/` read-only mount. No additional mount is required.

---

## `.agent-input/` Lifecycle

`.agent-input/` is overwritten on each run: `snapshot/` is rebuilt from `PROJECT_DIR`, `brief.md` is re-copied from `--brief`, and the operator manages `input/` manually. `.agent-input/` is not archived or cleaned up between runs.

---

## Diff Pipeline

On container exit, an EXIT trap runs `stage_diffs`:

1. Any uncommitted changes in `sandbox/` are staged and committed.
2. `git diff <baseline>..HEAD` is computed against the baseline SHA recorded at startup.
3. The result is written to `.workspace/changes/staged.diff`.

An autosave loop runs `stage_diffs` on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s), providing incremental checkpoints during a session.

On the host, `scripts/apply_workspace.sh` applies the patch to the current branch or a named branch via `--branch=<n>`. It uses `git apply --3way` to handle conflicts and validates that `PROJECT_DIR` is a git repository with at least one commit before applying.

---

## Entrypoint Sequence

```
container-entrypoint.sh
  1. snapshot_validate (gate 2)         — confirm .agent-input/snapshot/ is intact
  2. snapshot_copy_to_sandbox           — copy snapshot into container-local sandbox/
  3. snapshot_init_git                  — git init + baseline commit; container readiness gate
  4. copy brief.md into sandbox/        — if present in .agent-input/
  5. copy input/ contents into sandbox/ — if .agent-input/input/ is non-empty
  6. register EXIT trap → stage_diffs   — ensures diff is captured on any exit
  7. start autosave loop                — if AUTOSAVE_INTERVAL > 0
  8. exec agent                         — hand off to OpenCode
```

Steps 1–3 must succeed before the agent starts. Any failure exits the container without starting the agent.

---

## References

| Topic | Document |
|---|---|
| System invariants and component overview | [system_overview.md](system_overview.md) |
| Operator-facing workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security guarantees and trust boundaries | [security.md](security.md) |
| Standard operating procedures | [../operations/standard_operating_procedures.md](../operations/standard_operating_procedures.md) |
