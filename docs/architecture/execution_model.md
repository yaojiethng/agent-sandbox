# Execution Model

This document describes how a single agent run executes: how project files enter the container, how the sandbox is prepared, how agent changes are captured, and how outputs are returned to the host. It covers the snapshot pipeline, mount shape, entrypoint sequence, and diff workflow.

Implementation decisions are recorded here alongside the design they produce. Operator-facing workflow is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md).

---

## CLI Wrapper

`scripts/agent-sandbox.sh` is a dispatch wrapper installed onto the host as the `agent-sandbox` CLI. It is the interface used by onboarded projects — they call `agent-sandbox <subcommand>` from their own Makefile without any knowledge of the agent-sandbox repo layout.

Installation is performed once from the agent-sandbox repo:

```
make install              # installs to /usr/local/bin/agent-sandbox
make install PREFIX=~/bin # installs to ~/bin/agent-sandbox
```

`make install` substitutes the repo path into the wrapper at install time, so the installed binary has `AGENT_SANDBOX_REPO` baked in. The source file in the repo (`scripts/agent-sandbox.sh`) contains a placeholder and is never executed directly.

| Subcommand | Delegates to |
|---|---|
| `start` | `providers/opencode/start_agent.sh standard` |
| `dry-run` | `providers/opencode/start_agent.sh dry-run` |
| `build` | `providers/opencode/build_agent.sh` |
| `apply` | `scripts/apply_workspace_inplace.sh` |
| `apply-branch` | `scripts/apply_workspace_to_branch.sh` |

For `start`, `dry-run`, and `serve` the wrapper checks whether the project image exists before invoking `start_agent.sh`. If the image is missing it calls `build_agent.sh` automatically and notifies the operator. Passing `--rebuild` forces a build regardless of image state.

---

## Invocation Model

`start_agent.sh` is invoked by the project-side `Makefile`. Project identity and paths are defined as variables in the Makefile and passed as named flags — there is no separate conf file.

```
start_agent.sh <mode> --name=<project_name> --root=<path> [--brief=<rel>] [--env=<rel>] [--serve]
```

| Flag | Required | Description |
|---|---|---|
| `--name` | Yes | Project display name; used for Docker image naming (`opencode-agent-<name>`) |
| `--root` | Yes | Absolute WSL/Linux path to the project root on the host |
| `--brief` | No | Path to agent brief, relative to `PROJECT_ROOT` |
| `--env` | No | Path to `.env` file, relative to `PROJECT_ROOT` |
| `--serve` | No | Start OpenCode in serve mode |

`--rebuild` is handled by the wrapper before `start_agent.sh` is called and is never passed through to it.

The `Makefile` defines `PROJECT_ROOT` as `$(CURDIR)` — the directory containing the Makefile — so the correct root is always resolved without manual configuration. `AGENT_BRIEF` and `ENV_FILE` are relative paths resolved against `PROJECT_ROOT` inside `start_agent.sh`.

Machine-specific variables (`SERVE_PORT`, `OPENCODE_SERVER_PASSWORD`) live in a `.env` file at the project root, gitignored on the host. They are never committed and never enter the snapshot.

---

## Mount Shape

Two host directories are mounted into the container. Neither gives the agent access to `PROJECT_ROOT` directly.

| Host path | Container path | Mode | Purpose |
|---|---|---|---|
| `PROJECT_ROOT/.bootstrap/` | `/home/agentuser/.bootstrap/` | read-only | Input channel: snapshot and brief |
| `PROJECT_ROOT/.workspace/` | `/home/agentuser/.workspace/` | read-write | Output channel: patch, logs |

`PROJECT_ROOT` itself is not mounted at container runtime. The snapshot is fully constructed on the host before the container starts.

### Why `.bootstrap/` is read-only

The snapshot and brief are inputs prepared by the host before the run. The container must not modify them — doing so would break the reproducibility guarantee and could mask the baseline state used for diff generation. The entrypoint copies `.bootstrap/snapshot/` into a container-local `sandbox/` before the agent runs; all agent writes go to `sandbox/`, not to the mount.

### Why `.workspace/` is the sole output channel

Restricting agent output to a single known directory enforces the staging invariant: no agent change reaches the host repository without passing through `.workspace/` and receiving human review. The read-write mount is intentionally narrow — only `.workspace/` is writable from the container.

---

## Snapshot Pipeline

The snapshot pipeline replicates the host repository state into the container sandbox without touching the host. It runs in two stages: host-side preparation before the container starts, and container-side unpacking inside the entrypoint.

All snapshot functions are defined in `lib/snapshot.sh` and sourced by both `start_agent.sh` and `container-entrypoint.sh`.

### Stage 1 — Host side (`start_agent.sh`)

**`snapshot_enumerate_files`** runs `git ls-files --cached --others --exclude-standard` inside `PROJECT_ROOT`. This covers tracked files and untracked non-ignored files. Gitignored files — including secrets and `.env` — are excluded by definition. A warning is emitted if no `.gitignore` is present.

The `git ls-files` approach was chosen over alternatives (e.g. git bundle, rsync) because it respects `.gitignore` without requiring any mutation of the host repository. A git bundle approach was evaluated and rejected: it required a temporary commit on the host (`git add -A && git commit --no-verify`), which mutated HEAD, the staging area, and commit history, violating the invariant that the harness must not modify the host repo.

**`snapshot_copy_files`** reads the file list from stdin and copies files into `.bootstrap/snapshot/` using `cp --parents` to preserve directory structure.

**`snapshot_validate` (gate 1)** runs after copy, before the container starts. Checks that `.bootstrap/snapshot/` is non-empty and structurally sound. Non-zero exit aborts the run before Docker is invoked.

### Stage 2 — Container side (`container-entrypoint.sh`)

**`snapshot_validate` (gate 2)** runs first, against the mounted `.bootstrap/snapshot/`. Catches mount failures or transfer corruption before the sandbox is prepared.

**`snapshot_copy_to_sandbox`** copies `.bootstrap/snapshot/` into `sandbox/` inside the container. `sandbox/` is container-local and writable — this is where the agent works.

**`snapshot_init_git`** initialises a git repository in `sandbox/` and records a baseline commit. The baseline SHA is stored for diff generation on exit. `snapshot_init_git` owns container readiness: an incomplete or corrupt copy reaching this function produces a non-zero exit, halting the container before the agent starts. There is no separate error path for a bad snapshot — an unpacked sandbox that cannot be cleanly initialised is an init failure.

### `.bootstrap/` lifecycle

`.bootstrap/` is overwritten on each run. It is not archived or cleaned up. This matches the existing behaviour of `.workspace/` and keeps run management simple.

---

## Agent Brief

The agent brief (`brief.md`) is an optional task description passed to the agent at run time. It is resolved by `start_agent.sh` from the `AGENT_BRIEF` config key and mounted into `.bootstrap/brief.md` read-only.

The entrypoint copies `brief.md` from `.bootstrap/` into `sandbox/` so the agent can read it alongside the project files.

**Why the brief moved from `.workspace/` to `.bootstrap/`:** The brief is an input, not an output. Routing it through `.workspace/` conflated the input and output channels, which are now kept strictly separate by mount mode.

---

## Diff Pipeline

On container exit, an EXIT trap runs `stage_diffs`:

1. Any uncommitted changes in `sandbox/` are staged and committed.
2. `git diff <baseline>..HEAD` is computed against the baseline SHA recorded at startup.
3. The result is written to `.workspace/changes/patch.diff`.

An autosave loop runs `stage_diffs` on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s), providing incremental checkpoints during a session.

On the host, two scripts apply the patch:

- `apply_workspace_inplace.sh` — applies to the current branch without committing.
- `apply_workspace_to_branch.sh` — checks out a named branch and applies.

Both use `git apply --3way` to handle conflicts. Both validate that `PROJECT_ROOT` is a git repository with at least one commit before applying.

---

## Entrypoint Sequence

```
container-entrypoint.sh
  1. snapshot_validate (gate 2)         — confirm .bootstrap/snapshot/ is intact
  2. snapshot_copy_to_sandbox           — copy snapshot into container-local sandbox/
  3. snapshot_init_git                  — git init + baseline commit; container readiness gate
  4. copy brief.md into sandbox/        — if present in .bootstrap/
  5. register EXIT trap → stage_diffs   — ensures diff is captured on any exit
  6. start autosave loop                — if AUTOSAVE_INTERVAL > 0
  7. exec agent                         — hand off to OpenCode
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
