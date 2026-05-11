# M1.2 Discussion — Sandbox File Isolation & Diff Workflow

Design history and implementation notes for M1.2. This is a working reference document — not architecture documentation. Implementation decisions that stabilise should be reflected in [`../architecture/execution_model.md`](../architecture/execution_model.md)..

---

## The Two Core Operations

M1.2 establishes two git operations that together form the sandbox isolation and diff workflow:

1. **Snapshot** — replicate the host repo state into the container sandbox without touching the host
2. **Diff** — capture agent changes as a patch and apply it back to the host repo

---

## Operation 1 — Snapshot

### Approach: `git ls-files` copy

On container startup, `container-entrypoint.sh` enumerates files from the read-only `project/` mount using:

```bash
git ls-files --cached --others --exclude-standard
```

This covers tracked files (`--cached`) and untracked non-ignored files (`--others --exclude-standard`). The result is piped into `cp --parents` to replicate directory structure into `sandbox/`.

After copying, a git repository is initialised inside `sandbox/` and a baseline commit is recorded. This baseline is the reference point for diff generation on exit.

**Key properties:**
- Host repo is never modified
- `.gitignore` controls what enters the sandbox — gitignored files (secrets, `.env`) are excluded
- If no `.gitignore` is present, a warning is emitted and all untracked files are copied

**Known edge cases to validate:**
- Untracked-only repos (no commits yet) — `git ls-files` behaviour may differ
- Submodules — not handled; needs a decision to document or handle
- Symlinks — copy behaviour with `cp --parents` needs verification
- Dirty host working tree — unstaged modifications are visible to `git ls-files --cached` as the index state, not working tree state; untracked modifications to tracked files may not be captured. Needs explicit verification and documentation of intended behaviour.

### Rejected approach: git bundle

The git bundle approach was designed to create a portable snapshot of the repo state by bundling it on the host and cloning it inside the container.

**Why it was rejected:** The implementation required creating a temporary commit on the host repository during every agent run (`git add -A && git commit --no-verify`). This mutated the user's working tree — modifying HEAD, staging area, and commit history — and caused state parity failures between the container and host when the temporary commit was reset. The approach was fundamentally incompatible with the invariant that the host repo must not be modified by the harness.

The `git ls-files` volume mount approach achieves the same isolation and diff goals without touching the host repo at all.

---

## Operation 2 — Diff

### Approach: `git diff` on exit + `git apply --3way` on host

On container exit, an EXIT trap runs `stage_diffs`:

1. Any uncommitted changes in `sandbox/` are staged and committed
2. `git diff <baseline>..HEAD` is computed against the baseline commit recorded at startup
3. The result is written to `.workspace/session-diffs/patch.diff`

An autosave loop also runs `stage_diffs` on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s), providing incremental checkpoints during the session.

On the host, two scripts apply the patch:

- `apply_workspace_inplace.sh` — applies to the current branch, no commit
- `apply_workspace_to_branch.sh` — checks out a named branch and applies

Both use `git apply --3way` to handle conflicts gracefully. Both validate that `PROJECT_ROOT` is a git repo with at least one commit before applying.

**Key open questions:**
- Do `patch.diff` paths resolve correctly relative to `PROJECT_ROOT`? The diff is generated inside `sandbox/` with its own git root — path prefixes need to align with `git apply` expectations on the host.
- Behaviour when the host working tree is dirty at apply time needs testing. `--3way` should handle this but it has not been verified end-to-end.

---

## Modularization Design — Snapshot Pipeline Refactor

*Decided during M1.2 implementation discussion.*

### Motivation

The snapshot operation as implemented combines orchestration and logic inside `container-entrypoint.sh`. Extracting snapshot logic into a sourced lib enables:

- Testing snapshot behaviour in isolation without running the full entrypoint
- Reuse across `start_agent.sh`, `container-entrypoint.sh`, and future tooling
- A shorter entrypoint that reads as a sequence of named operations

### `.bootstrap/` — New Input Channel

A new host-side directory `.bootstrap/` is introduced alongside `.workspace/`. It carries the pre-built snapshot and the agent brief into the container as a read-only mount. This separates input from output at the mount level:

| Directory | Mount mode | Purpose |
|---|---|---|
| `.bootstrap/` | read-only | Input channel: snapshot + brief |
| `.workspace/` | read-write | Output/communication channel: patch, logs |

**Brief migration:** `brief.md` currently flows in via `.workspace/brief.md`. It moves to `.bootstrap/brief.md`. This is a breaking change to the existing mount shape.

**`.bootstrap/` lifecycle:** Overwritten on each run, not cleaned up. Consistent with current `.workspace/` behaviour. No per-run archiving at this stage.

### Snapshot Pipeline — Function Boundaries

The snapshot operation is split across host and container:

**`start_agent.sh` (host side)**

- `snapshot_enumerate_files` — runs `git ls-files --cached --others --exclude-standard` in `PROJECT_ROOT`, writes file list to stdout. Emits warning if no `.gitignore` detected.
- `snapshot_copy_files` — reads file list from stdin, copies files to `.bootstrap/snapshot/` using `cp --parents`.
- `snapshot_validate` — **gate 1**: structural check on `.bootstrap/snapshot/` after copy. Confirms non-empty, expected structure, no gitignored files present. Non-zero exit on failure; aborts before container starts.

**`container-entrypoint.sh` (container side)**

- `snapshot_validate` — **gate 2**: same structural checks run against the mounted `.bootstrap/snapshot/`. Catches mount or transfer failures before the agent runs.
- `snapshot_copy_to_sandbox` — copies `.bootstrap/snapshot/` → `sandbox/` (container-local, read-write).
- `snapshot_init_git` — `git init` + baseline commit in `sandbox/`. Owns container readiness: an incomplete copy reaching `init_git` is an `init_git` failure. Non-zero exit halts the container before the agent starts.

**Validation gates — scope**

`snapshot_validate` is intentionally narrow: structural correctness only. It confirms presence and shape, not behavioural properties. Behavioural assertions (symlink handling, dirty working tree, untracked-only repos) belong in the test suite.

**`libs/snapshot.sh`**

All snapshot functions are extracted into `libs/snapshot.sh` and sourced by both `start_agent.sh` and `container-entrypoint.sh`. This enables test harnesses to source the lib directly and call functions against fixture inputs without running the full scripts.

### Test Structure

```
tests/
  test_snapshot_host.sh       ← enumerate + copy, no container required
  test_snapshot_container.sh  ← validate + copy_to_sandbox + init_git, fixture snapshot input
```

Test cases for open M1.2 checklist items are added here rather than in runtime validation:
- Symlink handling
- Untracked-only repo behaviour
- Dirty host working tree
- Gitignored file exclusion (also covered by gate 1 + gate 2)

### Updated Mount Shape

```
HOST                              CONTAINER
──────────────────────────────────────────────────────
PROJECT_ROOT/.bootstrap/       → /home/agentuser/.bootstrap:ro
  snapshot/                       pre-built project files
  brief.md                        agent task brief

PROJECT_ROOT/.workspace/       → /home/agentuser/.workspace:rw
  session-diffs/patch.diff        agent output
```

`PROJECT_ROOT` itself is no longer mounted into the container at runtime. The snapshot is complete before the container starts.
