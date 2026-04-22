# Design — Diff and Branch Packaging Workflow

**Target milestone:** M2.3 (Change 6 redesign)

**Supersedes:** The Baseline Advancement section and Diff Primitives section of [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md), and the original Change 6 specification.

---

## Core Principle

Git is a tool used independently inside each repo. It is not the correspondence mechanism between sandbox and host. The correspondence mechanism is the diff file — a git-agnostic unified diff that applies cleanly when the target files are in the expected state. Packaging and applying file changes must not be tied to git-specific primitives (commit objects, patch metadata, object store SHAs).

---

## Primitives

| Primitive | Definition |
|---|---|
| **`INIT_SHA`** | SHA of the root commit in the sandbox. Written once to `sandbox/.git/INIT_SHA` at container init. Never updated. Defines the lower boundary for `package-branch` — all committed work after this commit belongs to the agent session. |
| **`package-diff` output** | Single unified diff of uncommitted working tree changes. Produced by `git diff HEAD` with index lines stripped. No git metadata headers. |
| **`package-branch` output** | Numbered series of unified diffs (`0001.diff`, `0002.diff`, ...), one per agent commit since `INIT_SHA`, written to `workspace/session-diffs/<branch-name>/`. Overwrites the folder on each run — always reflects the full branch history since `INIT_SHA`. Index lines stripped. |
| **Draft branch** | `draft/<branch-name>` — temporary branch on the host. Created by `make draft`, populated by sequential diff application, ready for `git rebase -i` onto the target branch. |
| **`draft-state`** | File at `SANDBOX_DIR/.workspace/draft-state`. Records active draft: source branch, working branch, diff series location. One per `SANDBOX_DIR`. |
| **`WORKTREE_ID`** | Short hash of `PROJECT_DIR` absolute path. Namespaces container names per worktree instance. Retained from prior design. |
| **Session artefact directory** | `SANDBOX_DIR/.workspace/session-diffs/<branch-name>/` — holds the numbered diff series for one branch. Overwritten on each `package-branch` run. |
| **Container labels** | Docker labels set at session start. Ground truth for session identity. Labels: `agent-sandbox.project-dir`, `agent-sandbox.session-name`. |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow via diff files through the bind-mounted workspace.
- No `docker exec` is used for correspondence operations. All state transfer happens via bind-mounted files.
- No unreviewed changes become commits. `make apply` lands changes uncommitted; `make draft` lands changes on an explicitly-named `draft/` branch requiring operator review before merge.
- One draft is active per repo at a time. `draft-state` records which branch is staged; `make draft` guards against starting a second draft while one is in progress.
- The harness does not track which diffs have been applied to the host. The operator selects what to apply via explicit arguments. Defaults cover the common case.
- Session artefact directories are non-colliding across concurrent worktree sessions. Branch name is the folder differentiator; git enforces branch uniqueness across worktrees.
- Git is used as a tool inside each repo independently. It is not the correspondence mechanism between sandbox and host.

---

## Functional Requirements

**Packaging (both host and container):**
- Uncommitted working tree changes can be packaged as a single diff on demand
- Committed branch history since session start can be packaged as a numbered diff series on demand
- Both packaging commands are available on host and container via the same underlying script in `libs/`
- Packaging is always a full re-export — no incremental tracking, no applied-state bookkeeping

**Apply workflow:**
- A single diff can be applied to the working tree, uncommitted, on both host and container
- A numbered diff series can be applied to a draft branch for structured review via `git rebase -i`
- Both apply operations use `git apply` with index lines stripped — no `git am`, no `patch` dependency
- A failed or unwanted draft can be cleanly discarded with no lasting effect on the host repo

**No harness-side sync tracking:**
- The harness does not track which diffs have been applied to the host or container
- The operator selects which diffs to apply via explicit `DIFFS=<start>..<end>` argument
- Defaults (all diffs, latest packaged diff) cover the common case without bookkeeping

**Parallel sessions:**
- Two sessions against different worktrees of the same repo do not collide in artefacts, container names, or draft state
- Merging worktree output to the main repo branch is handled by standard git workflow

---

## Diff Format

One format. Two directions. Same tools.

**Unified diff, git-index-agnostic**

Produced by `git diff` with `index <sha>..<sha>` lines stripped via `grep -v '^index '`. Applied by `git apply` with the same stripping:

```bash
grep -v '^index ' "$DIFF" | git -C "$TARGET_DIR" apply
```

No `git am`, no `format-patch`, no git metadata headers. `git apply` is already installed in the container — no additional tool dependency.

Both `package-diff` (uncommitted) and `package-branch` (committed series) produce this format. `make apply` and `make draft` consume it. The format is identical in both directions (sandbox→host and host→sandbox).

---

## Packaging Commands

### `package-diff` — uncommitted changes

Produces a single unified diff of the current working tree against HEAD. Strips index lines. Output: `workspace/output/changes.diff` by default.

```bash
git diff HEAD | grep -v '^index ' > "$OUTPUT"
```

Stateless — no reference to `INIT_SHA` or any sync point. Works identically on host and container. Invoked as `/package-diff` inside the container (agent-facing skill) and `git package-diff` alias on the host (operator-facing). Both call the same underlying script in `libs/`.

### `package-branch` — committed branch history

Produces one numbered `.diff` file per commit from `INIT_SHA..HEAD` on the current branch. Output directory: `workspace/session-diffs/<branch-name>/`. Overwrites the directory on each run — the series always reflects the current full branch history.

```bash
git log --reverse --format="%H" INIT_SHA..HEAD | while read sha; do
  git show "$sha" | grep -v '^index ' > "$OUTPUT_DIR/$(printf '%04d' $n).diff"
  n=$((n + 1))
done
```

Branch name is derived from the current branch and used as the folder key. If the sandbox or host has multiple branches, each gets its own folder. `make draft` reads from the folder matching the branch name passed or the current branch.

**On exit:** `package-branch` runs automatically in the EXIT trap alongside `staged.diff` generation. The autosave loop runs `package-diff` on a configurable interval (`AUTOSAVE_INTERVAL`, default 60s).

**Nonlinear history:** The sandbox is a linear workspace. If the operator introduces nonlinear history, the series reflects whatever `git log INIT_SHA..HEAD` produces on the current branch. Nonlinear cases are the operator's responsibility; the harness provides the tools but does not validate linearity.

---

## Apply Workflow

### `make apply [DIFF=<path>]` — single diff, uncommitted

Reads a single `.diff` file (default: latest in `workspace/output/` by timestamp; override with `DIFF=<path>`). Applies with index lines stripped:

```bash
grep -v '^index ' "$DIFF" | git -C "$TARGET_DIR" apply
```

Result lands uncommitted in the working tree. Operator reviews and commits manually. No draft branch, no `draft-state` update.

Symmetric: works on host (applies to `PROJECT_DIR`) and inside container (applies to `sandbox/`). This is the path for mid-session partial sync in either direction.

**Amendment workflow (host → container):** If the operator needs to push a fix into the running sandbox without restart, they package the change on the host with `package-diff` and apply it inside the container with `make apply`. The agent reviews and commits. The next `package-branch` will include this commit in the series alongside the agent's own work.

### `make draft [FROM=<hash>] [DIFFS=<start>..<end>]` — diff series, branch review

Creates a `draft/<branch>` branch from `FROM` (default: current host `HEAD`; accepts any commit hash or partial hash for cases where the host has advanced since session start). Reads numbered diffs from `session-diffs/<branch-name>/` in sort order. Applies each sequentially:

```bash
for diff in $(ls "$SERIES_DIR"/*.diff | sort); do
  grep -v '^index ' "$diff" | git apply
  git commit -m "$(basename $diff)"
done
```

The result is a branch with one commit per diff, ready for:

```bash
git rebase -i main   # operator squashes, rewords, reorders
                     # --continue, --skip, --abort all available
```

After rebase and merge, operator runs `make confirm` to clean up.

**Diff selection:** `DIFFS=start..end` selects a sub-range. `2..` means from diff 2 onwards. `..4` means up to and including diff 4. Default is all diffs in the folder. This is the operator's mechanism for applying only diffs not yet confirmed — no harness-side tracking required.

**On failure:** If a diff fails to apply, `make draft` stops at that diff, reports the failing file and hunk, and leaves the branch at the last successfully applied diff. Operator runs `make reject`, amends the failing diff, and re-runs `make draft`.

**Amendment workflow (review feedback):** If a diff doesn't pass review and needs changes:
1. Agent or operator amends the relevant `.diff` file in `session-diffs/<branch>/`
2. `make reject` discards the current draft branch
3. `make draft` re-applies the amended series from scratch

The diff series is the source of truth. The draft branch is always derived from it, never the other way around.

### `make confirm [TARGET=<branch>]`

Cleans up the draft branch after the operator has completed `git rebase -i` and merged. Deletes the draft branch. Clears `draft-state`. No rebase, no merge — those are operator actions via standard git.

### `make reject`

Discards the draft branch. Clears `draft-state`. Session artefacts unchanged.

---

## INIT_SHA

Set once at container init by `snapshot_init_git`, immediately after the baseline commit is created:

```bash
git rev-list --max-parents=0 HEAD > sandbox/.git/INIT_SHA
```

Never updated. Used only by `package-branch` as the lower boundary of the diff series. Not used by `make apply`, `make draft`, or any host-side command.

On container restart, a new container produces a new `INIT_SHA` from a fresh snapshot of the current host state. There is no carryover between container lifetimes.

---

## Parallel Sessions

### Collision properties

| Token | Scoped by | Collision possible? |
|---|---|---|
| Session artefact directory | Branch name | No — git enforces branch uniqueness across worktrees |
| Container names | Session identity via `container_name:` | No — per-session name |
| Container labels | Set at session start; `project-dir` label scopes lookup | No — label lookup is project-scoped |
| `draft-state` | `SANDBOX_DIR` | No — separate file per worktree |

### Worktree to main repo

Changes produced in a worktree session land on the worktree branch after `make confirm`.
Merging to the main repo branch is standard git — the operator merges or rebases the
worktree branch into the target. The harness does not orchestrate cross-worktree merges.

### Operator workflow

```bash
git worktree add ../project-feature feature-branch
mkdir ../project-feature-sandbox
agent-sandbox onboard --name=project \
  --project=../project-feature \
  --sandbox=../project-feature-sandbox
make start PROVIDER=<n>
```

Each worktree is an independent harness instance with its own `SANDBOX_DIR`. Sessions proceed independently. The worktree branch uniqueness constraint is the sole sequencing requirement.

---

## Implementation Scope (Change 6)

| File | Change |
|---|---|
| `libs/snapshot.sh` | In `snapshot_init_git`: write `git rev-list --max-parents=0 HEAD` to `sandbox/.git/INIT_SHA` after baseline commit. Remove any `BASELINE_SHA` write. |
| `libs/diff.sh` | Replace `diff_format_patch` with `package_branch` function. Update `diff_on_exit` to call `package_branch`. Add `package_diff` function (`git diff HEAD` with index lines stripped). Retain `staged.diff` generation. |
| `scripts/apply_workspace.sh` | Redesign `make draft`: remove checkpoint tag lookup; add `FROM=<hash>` and `DIFFS=<start>..<end>` arguments; replace `git am` loop with sequential `git apply` loop over numbered `.diff` files. Redesign `make confirm`: remove rebase — cleanup only. Update `make apply`: add `DIFF=<path>` argument; remove pre-staging block; use `grep -v '^index ' \| git apply`. Remove `make sync` and `SYNC=1` entirely. |
| `scripts/checkpoint.sh` | Remove checkpoint git tag creation, pruning, and lookup functions. Retain `WORKTREE_ID` derivation. Rename if scope no longer warrants the name. |
| `start_agent.sh` | Remove checkpoint tag creation call. Retain `WORKTREE_ID` and `SESSION_NAME` derivation. |
| `.skills/package-diff.md` | Add `package-branch` documentation. Update apply instructions for `make draft` redesign. |

---

## References

| Document | Purpose |
|---|---|
| [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md) | Superseded design — original reasoning record with inline SUPERSEDED markers |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline; INIT_SHA initialisation |
| [`sandbox_host_correspondence_model.md`](../concepts/sandbox_host_correspondence_model.md) | Correspondence model — how sandbox and host stay in sync |
