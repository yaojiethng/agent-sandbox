# Sandbox and Host Correspondence Model

The sandbox and host repository are never the same git repository — they have divergent
histories, different baselines, and no shared object store. Yet they must stay in
correspondence: the sandbox must know what the host looks like, the host must be able to
receive what the sandbox produced, and across multiple sessions these two states must
remain coherent.

This document describes the model that keeps them in correspondence across three distinct
cases: live sandbox, stopped sandbox, and newly started sandbox.

Implementation detail and command shapes: [`apply_workflow.md`](../architecture/apply_workflow.md).
Reasoning record: [`design_diff_and_branch_packaging_workflow.md`](../discussions/design_diff_and_branch_packaging_workflow.md).

---

## Core Principle

Git is a tool used independently inside each repo. It is not the correspondence mechanism
between sandbox and host. The correspondence mechanism is the diff file — a git-agnostic
unified diff that applies cleanly when the target files are in the expected state.

This separation means the harness does not depend on git history, commit SHAs, or object
stores being shared or compatible across the boundary. Any tool that produces or consumes
unified diffs participates in the model.

---

## Primitives

| Primitive | Definition |
|---|---|
| **`INIT_SHA`** | SHA of the root (baseline) commit in the sandbox. Written once at container init, never updated. Defines the lower boundary for `package-branch` — all committed work after this commit belongs to the agent session. |
| **`package-diff` output** | Single unified diff of uncommitted working tree changes. No git metadata. Applied with `git apply`. |
| **`package-branch` output** | Numbered series of unified diffs (`0001.diff`, `0002.diff`, ...), one per agent commit since `INIT_SHA`. Manual invocation writes to `OUTPUT_DIR/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`; `diff_on_exit` writes to `CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/`. Overwrites on each run — always reflects full branch history since `INIT_SHA`. |
| **Draft branch** | `draft/<branch-name>` — temporary branch on the host. Populated by sequential diff application, ready for `git rebase -i`. |
| **`draft-state`** | File committed as the first commit on a `draft/` branch. Records source branch, from hash, session identity, and diff count. Dropped automatically by `make confirm` before merge — never lands on the target branch. |
| **`WORKTREE_ID`** | Short hash of `PROJECT_DIR` absolute path. Namespaces container names per worktree instance. |
| **Session artefact directory** | `SANDBOX_DIR/.workspace/session-diffs/<EXPORT_TIME>-<branch>-<SESSION_TS>/` — holds the numbered diff series produced by `diff_on_exit`. Overwritten on each exit. Manual `package-branch` invocations write to `OUTPUT_DIR/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`. |
| **Container labels** | Docker labels set on the capability layer container at session start. Ground truth for session identity. Labels: `agent-sandbox.project-dir`, `agent-sandbox.session-name`. |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow via diff files through the bind-mounted workspace.
- No `docker exec` is used for correspondence operations. All state transfer happens via bind-mounted files.
- No unreviewed changes become commits. `make apply` lands changes uncommitted; `make draft` lands changes on an explicitly-named `draft/` branch requiring operator review before merge.
- One draft is active per repo at a time. `draft-state` records which branch is staged; `make draft` guards against starting a second draft while one is in progress.
- The harness does not track which diffs have been applied. The operator selects what to apply via explicit arguments. Defaults cover the common case.
- Session artefact directories are non-colliding across concurrent worktree sessions. Branch name is the folder differentiator; git enforces branch uniqueness across worktrees.

---

## Correspondence Cycle

The full lifecycle — init, running, stopped, restart — as a single sequence. Loop
checkpoints mark where the cycle repeats.

```
[Host]                               [Sandbox]
HEAD = A                             (not yet started)
  │                                    │
  │        [INIT]                      │
  ├─ git archive HEAD ─────────────────►│
  │  rsync working tree                ├─ unpack baseline.tar → baseline commit
  │                                    ├─ INIT_SHA written (root commit SHA)
  │                                    ├─ rsync overlay (working tree state)
  │                                    │  INIT_SHA = A
  │                                    │
  │        [RUNNING — loop start]      │
  │                                    ├─ agent works, commits accumulate
  │                                    │
  │  ◄── package-diff ─────────────────┤  sandbox → host (uncommitted, mid-session)
  │      changes.diff                  │
  │                                    │
  ├─ make apply DIFF=<path> ──────────►│  host → sandbox (amendment, fix)
  │                                    ├─ agent reviews, commits
  │                                    │
  │  ◄── package-branch ───────────────┤  sandbox → host (on demand, or on exit)
  │      bundles/<timestamped>/        │  0001.diff .. 000n.diff
  │                                    │
  │        [STOPPED]                   │
  │                                    X  container exits; artefacts persisted
  │
  ├─ make draft [FROM=<hash>]
  │             [DIFFS=<start>..<end>]
  │    └─ draft/<branch> created
  │       diffs applied in order via git apply
  │
  ├─ git rebase -i / review
  ├─ make confirm
  ▼
HEAD = B
  │
  │        [RESTART — loop back to INIT]
  └─ (new container snapshots HEAD = B; new INIT_SHA established)
```

**INIT — establishing correspondence**

Before the container starts, the harness snapshots the host: `git archive HEAD` produces a
tar of the committed state; rsync copies the operator's working tree alongside it. Inside
the container, `snapshot_init_git` unpacks the tar, commits as the baseline, writes
`INIT_SHA`, then overlays the rsync copy so the working tree matches the operator's
on-disk state. At this point sandbox file content exactly matches the host. `INIT_SHA` is
the fixed reference for all diff packaging in this container lifetime.

**RUNNING — bidirectional flow**

Changes can flow in either direction at any time while the sandbox is live. All transfers
use the same diff format and the same `make apply` command regardless of direction.

- **Sandbox → host (mid-session partial):** `package-diff` exports uncommitted working
  tree changes as `changes.diff`. Operator runs `make apply` on the host, reviews, commits
  manually.
- **Host → sandbox (amendment):** Operator packages a host change with `package-diff` and
  applies it inside the container with `make apply`. Agent reviews and commits. The next
  `package-branch` includes this commit in the series.
- **Sandbox → host (committed work):** `package-branch` exports all commits since
  `INIT_SHA` as numbered diffs. `diff_on_exit` writes to `session-diffs/<timestamped>/`
  automatically on container exit; manual invocation writes to `bundles/<timestamped>/`.

**STOPPED — applying persisted artefacts**

The operator works entirely from the persisted session artefacts. No container interaction
is possible or required. `make draft` creates a `draft/<branch>` branch from `FROM`
(default: `HEAD`; supply an explicit hash if the host has advanced) and applies the
numbered diffs in order. `DIFFS=start..end` selects a sub-range — the operator's mechanism
for skipping already-confirmed diffs without harness tracking. After `git rebase -i` and
merge, `make confirm` cleans up the draft branch.

On failure: `make draft` stops at the failing diff and reports the file and hunk. Operator
runs `make reject`, amends the failing diff in the source export folder, and re-runs
`make draft`. The diff series is the source of truth; the draft branch is always derived
from it.

**RESTART — resetting correspondence**

On the next container start, the harness snapshots the current host HEAD — incorporating
all sessions confirmed since the last container — and establishes a new `INIT_SHA` from
that snapshot. What carries over: session artefacts in `session-diffs/` persist in
`SANDBOX_DIR` and remain available to the operator; provider config files are copied into
the new container at startup. What resets: `INIT_SHA` is recomputed from scratch; agent
session context (conversation history, in-progress work) is lost unless the provider
supports session resume (M2.6 scope).

---

## Diff Format

One format. Two directions. Same tools.

Produced by `git diff` with `index <sha>..<sha>` lines stripped. Applied by `git apply`
with the same stripping:

```bash
grep -v '^index ' "$DIFF" | git -C "$TARGET_DIR" apply
```

No `git am`, no `format-patch`, no git metadata headers. Works identically in both
directions and on both host and container.

---

## Command Map

| Command | Available on | What it does |
|---|---|---|
| `package-diff` | Both | Packages uncommitted working tree changes as a single `.diff`. Output: `workspace/output/changes.diff` by default. |
| `package-branch` | Both | Packages all commits since `INIT_SHA` as numbered `.diff` files. Manual: `OUTPUT_DIR/bundles/<timestamped>/`. On exit: `CHANGES_DIR/<timestamped>/`. Overwrites on each run. |
| `make apply [DIFF=<path>]` | Both | Applies a single `.diff` uncommitted. Default: latest in `workspace/output/` by timestamp. |
| `make draft [FROM=<hash>] [DIFFS=<start>..<end>]` | Host | Creates `draft/<branch>`, applies numbered diffs in order. `FROM` sets branch base (default: `HEAD`). `DIFFS` selects range (default: all). |
| `make confirm [TARGET=<branch>]` | Host | Cleans up draft branch after operator rebase and merge. |
| `make reject` | Host | Discards draft branch. Artefacts unchanged. |

---

## Correspondence Across Parallel Sessions

Two sessions against different worktrees maintain independent correspondence with their
respective host worktrees. Every token that could collide is scoped per worktree:

| Token | Scoped by | Collision possible? |
|---|---|---|
| Session artefact directory | Branch name | No — git enforces branch uniqueness across worktrees |
| Container names | Session identity | No — per-session name |
| Container labels | `project-dir` label scopes lookup | No — label lookup is project-scoped |
| `draft-state` | `SANDBOX_DIR` | No — separate file per worktree |

Each worktree session runs its correspondence cycle independently. Merging worktree output
to the main repo branch is standard git — the harness does not orchestrate cross-worktree
merges.

---

## Model Gaps

**Mixing `make apply` and `make draft` within a single session:** Resolved. Under the
prior design, both paths ultimately fed into `git am`, so double-application of content
was possible if `make apply` was used mid-session before `make draft` ran at exit. Under
the current model the two paths are structurally separate: `make apply` reads from
`workspace/output/` and lands changes uncommitted in the working tree; `make draft` reads
from `CHANGES_DIR/<timestamped-dir>/` or `OUTPUT_DIR/bundles/<timestamped-dir>/` and applies committed diffs to a branch.
The artefact locations do not overlap and there is no shared application mechanism. No
undefined behaviour remains.

**Mixed session types across sessions:** Closed as explicitly out of scope. A project
using both Claude Chat sessions (`package-diff` / `make apply`) and OpenCode sessions
(`package-branch` / `make draft`) against the same repo involves intentionally different
workflows targeting different artefact channels. The harness makes no claim to coordinate
across session types, and doing so is not intended behaviour. If cross-session-type
coordination becomes a real use case, it warrants a story at that time.

---

## References

| Document | Purpose |
|---|---|
| [`design_diff_and_branch_packaging_workflow.md`](../discussions/design_diff_and_branch_packaging_workflow.md) | Full design record — command shapes, implementation scope |
| [`design_apply_workflow_and_baseline_advancement.md`](../discussions/design_apply_workflow_and_baseline_advancement.md) | Prior design record — preserved with SUPERSEDED markers |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline; INIT_SHA initialisation; Phase 3 join |
| [`provider_lifecycle.md`](../architecture/provider_lifecycle.md) | Provider config copy-in at session start |
