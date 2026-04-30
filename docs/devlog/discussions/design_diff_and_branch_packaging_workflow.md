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
| **`package-branch` output** | Numbered series of unified diffs (`0001.diff`, `0002.diff`, ...), one per agent commit since `INIT_SHA`. Manual invocation writes to `OUTPUT_DIR/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`; `diff_on_exit` writes to `CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/`. Overwrites the folder on each run — always reflects the full branch history since `INIT_SHA`. Index lines stripped. |
| **Draft branch** | `draft/<branch-name>` — temporary branch on the host. Created by `make draft`, populated by sequential diff application, ready for `git rebase -i` onto the target branch. |
| **`.draft-state`** | File committed as the first commit on the draft branch. Fields: `source_branch`, `from_hash`, `author`, `session_ts`, `host_branch`, `diff_count`, `exported-at`, `drafted-at`. Dropped automatically by `make confirm` before merge — never lands on the target branch. All fields are host-derivable or read from the export folder name — no local paths, no container-internal variables. M2.7 adds `run_id:` as one new field. |
| **`EXPORT_TIME`** | Timestamp at which a packaging command ran (`date +%Y%m%d-%H%M%S`). Prefixes all output folder names, enabling lexicographic sort by export order. Distinct from `SESSION_TS` — a session may produce multiple exports. |
| **`SESSION_SUMMARY`** | Operator or agent provided title for `package_branch` and `package_diff` invocations. Describes the content of the export. |
| **`BRANCH_SUMMARY`** | Optional operator argument to `make draft`. Replaces `<sanitized-host-branch>` in the draft branch name when provided. |
| **`SESSION_TS`** | Single canonical timestamp derived once at the top of `start_agent.sh`: `SESSION_TS=$(date +%Y%m%d-%H%M%S)`. Exported and reused everywhere — no independent `date` calls downstream. Format `YYYYMMDD-HHMMSS` with delimiter, applied uniformly to container names and artifact folder names. M2.7 introduces `RUN_ID` as the primary session identity; `SESSION_TS` is retained for time-based ordering and timestamp tagging. |
| **`WORKTREE_ID`** | Short hash of `PROJECT_DIR` absolute path. Namespaces container names per worktree instance. Retained from prior design. |
| **Session artefact directory** | Output folder for `diff_on_exit`: `$CHANGES_DIR/<EXPORT_TIME>-<sanitized-host-branch>-<SESSION_TS>/`. Flat structure — no parent folder. Lexicographic sort on `EXPORT_TIME` prefix gives chronological order. M2.7 replaces `<SESSION_TS>` suffix with `<RUN_ID>`. |
| **Container labels** | Docker labels set at session start. Ground truth for session identity. Labels: `agent-sandbox.project-dir`, `agent-sandbox.session-name`. |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow via diff files through the bind-mounted workspace.
- No `docker exec` is used for correspondence operations. All state transfer happens via bind-mounted files.
- No unreviewed changes become commits. `make apply` lands changes uncommitted; `make draft` lands changes on an explicitly-named `draft/` branch requiring operator review before merge.
- One draft is active per repo at a time. The presence of a `draft/` branch is the guard; `make draft` checks for existing `draft/` branches before proceeding.
- `.draft-state` is committed metadata on the draft branch, not a file in the working directory. It is never present on the target branch after merge.
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

## Output Paths

All artifact locations use `EXPORT_TIME` as the leading sort key. `SESSION_TS` as the trailing session identifier will be replaced by `RUN_ID` in M2.7 — a clean suffix substitution with no structural change.

| Artifact | Path | Name pattern |
|---|---|---|
| `diff_on_exit` | `$CHANGES_DIR/` | `<EXPORT_TIME>-<sanitized-host-branch>-<SESSION_TS>/` |
| `package_branch` | `$OUTPUT_DIR/bundles/` | `<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` |
| `package_diff` | `$OUTPUT_DIR/diffs/` | `<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` |
| Draft branch | host git | `draft/<EXPORT_TIME>-<SESSION_TS>-<sanitized-host-branch or BRANCH_SUMMARY>-<sha6>` |

`EXPORT_TIME` is generated at packaging time (`date +%Y%m%d-%H%M%S`), not at session start. Multiple exports within a single session each get a distinct `EXPORT_TIME`, enabling lexicographic sort to select the latest export correctly.

---

## Packaging Commands

### `package-diff` — uncommitted changes

Produces a single unified diff of the current working tree against HEAD. Strips index lines.

```bash
EXPORT_TIME=$(date +%Y%m%d-%H%M%S)
OUTPUT="$OUTPUT_DIR/diffs/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}/changes.diff"
git diff HEAD | grep -v '^index ' > "$OUTPUT"
```

Requires `SESSION_SUMMARY` argument — a short description of the content being packaged. `SESSION_TS` is injected into the container environment at session start; on the host it is read from the environment or passed explicitly.

Invoked as `/package-diff <summary>` inside the container (agent-facing skill) and `git package-diff <summary>` alias on the host (operator-facing). Both call the same underlying script in `libs/`.

### `package-branch` — committed branch history

Produces one numbered `.diff` file per commit from `INIT_SHA..HEAD` on the current branch.

```bash
EXPORT_TIME=$(date +%Y%m%d-%H%M%S)
OUT_DIR="$OUTPUT_DIR/bundles/${EXPORT_TIME}-${SESSION_SUMMARY}-${SESSION_TS}"
mkdir -p "$OUT_DIR"
git log --reverse --format="%H" INIT_SHA..HEAD | while read sha; do
  git show "$sha" | grep -v '^index ' > "$OUT_DIR/$(printf '%04d' $n).diff"
  n=$((n + 1))
done
```

Requires `SESSION_SUMMARY` argument. Overwrites nothing — each invocation produces a new timestamped folder. Multiple exports within a session are all preserved.

**On exit:** `diff_on_exit` runs automatically in the EXIT trap. It uses the same diff format but writes to `$CHANGES_DIR/` with an automated name (no `SESSION_SUMMARY` required):

```bash
EXPORT_TIME=$(date +%Y%m%d-%H%M%S)
OUT_DIR="$CHANGES_DIR/${EXPORT_TIME}-${SANITIZED_HOST_BRANCH}-${SESSION_TS}"
mkdir -p "$OUT_DIR"
```

`SANITIZED_HOST_BRANCH` is the host branch name captured at session start and injected into the container environment alongside `SESSION_TS`. The autosave loop also writes to `$CHANGES_DIR/` using the same pattern.

**Nonlinear history:** The sandbox is a linear workspace. Nonlinear cases are the operator's responsibility; the harness provides the tools but does not validate linearity.

---

## Apply Workflow

### `make apply [DIFF=<path>]` — single diff, uncommitted

Reads a single `.diff` file (default: latest entry under `$OUTPUT_DIR/diffs/` by lexicographic sort; override with `DIFF=<path>`). Applies with index lines stripped:

```bash
grep -v '^index ' "$DIFF" | git -C "$TARGET_DIR" apply
```

Result lands uncommitted in the working tree. Operator reviews and commits manually. No draft branch, no `draft-state` update.

Symmetric: works on host (applies to `PROJECT_DIR`) and inside container (applies to `sandbox/`). This is the path for mid-session partial sync in either direction.

**Amendment workflow (host → container):** If the operator needs to push a fix into the running sandbox without restart, they package the change on the host with `package-diff` and apply it inside the container with `make apply`. The agent reviews and commits. The next `package-branch` will include this commit in the series alongside the agent's own work.

### `make draft [FROM=<hash>] [DIFFS=<start>..<end>] [BRANCH_SUMMARY=<slug>]` — diff series, branch review

Resolves the target export folder: latest entry under `$CHANGES_DIR/` by lexicographic sort (most recent `EXPORT_TIME`). Override with explicit `--session=<path>` to target a specific folder, including `$OUTPUT_DIR/bundles/` exports.

Parses `EXPORT_TIME`, `SANITIZED_HOST_BRANCH`, and `SESSION_TS` from the resolved folder name (`<EXPORT_TIME>-<sanitized-host-branch>-<SESSION_TS>`). These values are not shell variables on the host — they are read from the folder name.

Derives draft branch name:

```
draft/<EXPORT_TIME>-<SESSION_TS>-<BRANCH_SUMMARY or sanitized-host-branch>-<sha6>
```

Where `sha6` is the first 6 characters of `FROM` (default: current `HEAD`). `BRANCH_SUMMARY` replaces the auto-generated branch slug when provided.

Guards against a branch with the exact computed name already existing — refuses if `git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"` succeeds. Drafts from different sessions produce different branch names and are allowed to coexist. Tests must verify that a second `make draft` with identical parameters is rejected, and that a second `make draft` with different parameters (different `EXPORT_TIME`, different `FROM`, etc.) is allowed.

First commit on the branch is `.draft-state`. It is the first commit after `from_hash` on the draft branch. Locate it with `git rev-list "${DRAFT_BRANCH}" ^"${FROM_HASH}" | tail -1`. Tests must use `git log "${FROM_HASH}..${DRAFT_BRANCH}" --reverse --format=%s | head -1` to verify — not `git log "${DRAFT_BRANCH}" --reverse`, which includes the full history of the source branch.

The `.draft-state` file contains:

```
source_branch: main
from_hash: abc1234
author: Jane Operator <jane@example.com>
session_ts: 20260423-081334
host_branch: main
diff_count: 6
exported-at: 20260423-081334
drafted-at: 20260423-143012
```

All fields are host-derivable or read from the export folder name. No local paths. No container-internal shell variables. M2.7 adds `run_id:` as one new field.

Subsequent commits apply the numbered diffs in sort order via `git apply` with index lines stripped, staging and committing each.

**Branch topology after `make draft`** (where `FROM` is older than `HEAD`):

```
---[from_hash]---[A]---[B]---(HEAD=main)
      \
       ---[.draft-state]---[0001]---[0002]---[0003]---(draft/<EXPORT_TIME>-<SESSION_TS>-<branch>-<sha6>)
```

**Diff selection:** `DIFFS=start..end` selects a sub-range. `2..` means from diff 2 onwards. Default is all diffs in the folder.

**On failure:** `make draft` stops at the failing diff, reports the file and hunk. Operator runs `make reject`, amends the failing diff, re-runs `make draft`.

**Amendment workflow:** Amend the relevant `.diff` file in the source folder, `make reject`, re-run `make draft`. The diff series is the source of truth.

**Operator hint printed on completion:**

```
Draft branch created: draft/<EXPORT_TIME>-<SESSION_TS>-<branch>-<sha6>
Export: <source-folder>
Diffs applied: <n>
Branch point: <from_hash>

Shape your commits, then confirm:

  git rebase -i <source_branch>
  make confirm [TARGET=<branch>]

To discard: make reject
```

### `make confirm [TARGET=<branch>]`

Validates the current branch is a proper draft branch via three checks: branch name starts
with `draft/`, `.draft-state` exists at the branch tip, and the first commit after `from_hash`
has message `.draft-state`. Reads `.draft-state` from the draft branch into shell variables.
Performs the following sequence:

**1. Drop `.draft-state` commit**

```bash
draft_state_commit=$(git rev-list "draft/$BRANCH" ^"$FROM_HASH" | tail -1)
git rebase --onto "${draft_state_commit}^" "$draft_state_commit" "draft/$BRANCH"
```

The `.draft-state` commit is always the first commit on the branch — the one immediately
after `from_hash`. Dropping it leaves only the operator's shaped commits. The `.draft-state`
file is never present on the target branch after merge.

**2. Rebase draft onto target**

```bash
git rebase "$TARGET" "draft/$BRANCH"
```

Brings the draft commits up to the tip of the target branch regardless of where `FROM`
was. This is always required — even when `FROM=HEAD` at draft creation time, the target
may have advanced since.

**Branch topology after rebase:**

```
---[from_hash]---[A]---[B]---[draft changes]---(HEAD=main)
```

The draft changes land at the tip of the target branch. `from_hash` is retained in history
as the original branch point but the draft commits are now on top of the latest work.

**3. Fast-forward merge**

```bash
git checkout "$TARGET"
git merge --ff-only "draft/$BRANCH"
```

Guaranteed to succeed after the rebase. If it fails (concurrent modification to target
between rebase and merge), repeat from step 2.

**4. Cleanup**

Delete draft branch. Done.

**On rebase conflict:** `make confirm` stops and prints the exact command the operator
needs to resolve:

```
Conflict rebasing draft/main onto main.

Resolve conflicts, then run:

  git rebase --continue          # after resolving each conflict
  make confirm                   # retry the merge once rebase is clean

To abort and return to the draft branch:

  git rebase --abort
  make confirm                   # retry from scratch once draft is ready

To discard the draft entirely:

  git rebase --abort
  make reject
```

### `make reject`

Validates the current branch is a proper draft branch (same three checks as `make confirm`).
Reads `source_branch` from `.draft-state` on the draft branch. Checks out the source branch.
Deletes the current draft branch only — other `draft/` branches are untouched. Done.

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

## Contract Amendments (Session A.1, A.2, A.3 & B)

This section records amendments agreed across design sessions `20260429-03-design-command_shape_and_contract.md` and `20260429-04-impl-command_contract_refactor.md`. The original contract above remains valid for the portions it covers; this section supersedes specific clauses where noted.

Refactor work is partitioned into three implementation chunks (A.1, A.2, A.3). A.2 depends on A.1; A.3 depends on both. Session B (interactive) depends on all three.

---

### A.1 — Data Model: Output Format Unification

*Theme: "What gets written where" — no CLI changes, no user-visible behaviour change.*

#### Motivation

The current output format has drifted across callers: `diff_on_exit` writes `session/changes.diff` + `session/staged.diff` + `session/patches/`; `diff_on_autosave` writes `autosave/changes.diff` + `autosave/patches/`; `package_diff` writes `output/diffs/<tag>/changes.diff`; `package_branch` writes flat `.diff` files to `output/bundles/<tag>/`. The amendments below unify all output to a single format, eliminate the sweep commit, and consolidate session identity into `SESSION_STATE`.

#### Unified output format

Every packaging operation (whether triggered by EXIT trap, autosave, or direct CLI) produces:

```
<output-dir>/
  uncommitted.diff     — git diff HEAD (uncommitted working tree vs HEAD)
  all-changes.diff     — git diff INIT_SHA (all changes since session init)
  patches/
    0001-<sha>.diff
    0002-<sha>.diff
    ...
```

- `uncommitted.diff` replaces `changes.diff`
- `all-changes.diff` replaces `staged.diff`
- `patches/` replaces flat `.diff` output in bundles
- No sweep commit: `diff_on_exit` no longer calls `diff_commit_pending`; uncommitted changes are captured directly by `uncommitted.diff`

#### `package_branch` dispatcher

`package_branch` becomes a dispatcher function that orchestrates four operations:

1. `package_commits(SANDBOX_DIR, INIT_SHA, OUTPUT_DIR/patches/)` — old `package_branch` logic, writes numbered diffs
2. `write_uncommitted_diff(SANDBOX_DIR, OUTPUT_DIR/uncommitted.diff)` — git diff HEAD
3. `write_all_changes_diff(SANDBOX_DIR, OUTPUT_DIR/all-changes.diff)` — git diff INIT_SHA
4. `write_changed_files(SANDBOX_DIR, INIT_SHA, OUTPUT_DIR)` — copies all changed files since INIT_SHA into `changed-files/`, with `MANIFEST.txt`

Called by:
- `diff_on_exit` (EXIT trap)
- `diff_on_autosave` (autosave loop)
- `package_branch.sh` direct mode (CLI)

#### `package_diff` changes

- Rename output file from `changes.diff` to `uncommitted.diff`
- Extract reusable diff-writing helpers into `libs/diff.sh`
- Accept `OUTPUT_PATH` argument to override default output directory

#### `diff_on_exit` / `diff_on_autosave` changes

- Drop `BASELINE_SHA` parameter (replaced by `INIT_SHA` read from `SESSION_STATE`)
- Drop `diff_commit_pending` call (no sweep)
- Call `package_branch` dispatcher for unified output
- `diff_on_exit` sweeps nothing; `uncommitted.diff` captures pre-sweep state

#### `diff_generate` / `diff_format_patch`

- Rename `BASELINE_SHA` parameter to `since_sha` (generic commit boundary)
- Callers pass `INIT_SHA` as the `since` argument

#### SESSION_STATE consolidation

- `snapshot_init_git` writes `session_ts` and `init_sha` to `sandbox/.git/SESSION_STATE`
- `sandbox/.git/INIT_SHA` file is removed
- All `INIT_SHA` readers updated to read from `SESSION_STATE`
- `session_state_write` function added to `libs/session.sh`

#### `changed-files/` as separate operation

`write_changed_files(SANDBOX_DIR, SINCE_SHA, OUTPUT_DIR)` is an accessibility function that produces `OUTPUT_DIR/changed-files/` containing:

- `MANIFEST.txt` — sorted list of unique file paths changed since `SINCE_SHA`
- Working tree copies of each file, preserving directory structure relative to repo root

Two-source file list: `git diff --name-only SINCE_SHA` (committed + staged + unstaged) + `git ls-files --others` (untracked). Deleted files are skipped. Deduplicated via `sort -u`.

Called by:
- `package_branch` dispatcher (with `SINCE_SHA=INIT_SHA`)
- `package_diff.sh` (with `SINCE_SHA=HEAD`)

Defined separately in `libs/diff.sh` so it can be added/removed without affecting the core diff contract.

---

### A.2 — CLI Contract: `--channel` Flag and Routing

*Theme: "How the user invokes it" — assumes A.1 output format is in place.*

**Depends on: A.1**

#### `--session` becomes name-only; single `--channel` flag

`--session` accepts names only, resolved under channel-specific base directories. Absolute paths are removed. A single `--channel` flag selects the channel.

| Command | `--channel` values | Resolves under |
|---|---|---|
| `draft` | `session` (default), `autosave`, `bundles` | `$CHANGES_DIR/<session>/session/` or `.../autosave/` or `$BUNDLES_DIR/<session>/` |
| `apply` | `diffs` (default), `autosave`, `session` | `$DIFFS_DIR/<tag>/` or `$CHANGES_DIR/<session>/autosave/` or `.../session/` |

Escape hatch for arbitrary files: `--diff=<path>` on `apply` bypasses all resolution.

#### Unified `SOURCE_DIR` contract

Every directory passed to `draft_run` conforms to:

```
SOURCE_DIR/
  patches/
    0001-*.diff
    ...
  uncommitted.diff    (optional)
```

`draft_run` applies `patches/*.diff` sequentially, then `uncommitted.diff` if present.

#### `apply_run` contract

`apply_run` receives a file path directly. It has no hardcoded filename — the caller (router) decides which file to pass. The default resolved path is `uncommitted.diff` for all channels, but `--diff=<path>` bypasses all resolution and passes an arbitrary file.

- `--channel=diffs` → router resolves `$DIFFS_DIR/<tag>/uncommitted.diff`, passes to `apply_run`
- `--channel=autosave` → router resolves `$CHANGES_DIR/<session>/autosave/uncommitted.diff`, passes to `apply_run`
- `--channel=session` → router resolves `$CHANGES_DIR/<session>/session/uncommitted.diff`, passes to `apply_run`
- `--diff=<path>` → bypasses router entirely; `<path>` passed directly to `apply_run`

#### Router functions

Channel resolution lives in `scripts/agent-sandbox.sh` (the CLI entry point), not in the workflow libraries:

- `resolve_source_for_draft SANDBOX_DIR CHANNEL SESSION_ARG` — returns tab-separated `SOURCE_DIR` and `SESSION_NAME`. Validates that `--session` is name-only (rejects absolute paths).
- `resolve_diff_for_apply SANDBOX_DIR CHANNEL SESSION_ARG` — returns file path to `uncommitted.diff`.

Both functions auto-resolve the latest directory when `--session` is omitted, and error clearly when no matching export is found.

#### Makefile flag mapping

| Flag | Maps to |
|---|---|
| `AUTOSAVE=1` | `--channel=autosave` |
| `BUNDLE=1` | `--channel=bundles` |

Mutually exclusive. No flag needed for default channel.

---

### A.3 — Documentation and Recovery

*Theme: "How the operator recovers" — assumes A.1 and A.2 are complete.*

**Depends on: A.1 + A.2**

#### Emergency recovery helpers

Thin wrapper snippets bypassing channel routing, documented in `docs/development/quickstart.md`:

```bash
# Draft from explicit path (bypass --session/--channel)
source "$AGENT_SANDBOX_REPO/libs/draft_workflow.sh"
draft_run "$PROJECT_DIR" "$EXPLICIT_SOURCE_DIR" ""

# Apply explicit diff (bypass --session/--channel)
source "$AGENT_SANDBOX_REPO/libs/diff_workflow.sh"
apply_run "$PROJECT_DIR" "$EXPLICIT_DIFF_FILE" "" false
```

These are escape hatches for manual recovery. The primary interface remains `make draft` / `make apply`.

#### Design document maintenance

Update `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` to remove superseded sections (old Packaging Commands, old Apply Workflow) and replace with the amended contract. Preserve the original in `design_apply_workflow_and_baseline_advancement.md` with SUPERSEDED markers.

---

### B — Interactive Mode

**Depends on: A.1 + A.2 + A.3**

- Add `interactive_select_sessions` utility
- Wire `--interactive` into `agent-sandbox.sh` for `draft` and `apply`
- Table rendering for `draft` (recent sessions with availability indicators)
- Default-on-empty-input, pre-filled from `SESSION=<name>`
- Abort on `q`/`n`
- For `apply`: show resolved `uncommitted.diff` path, prompt for confirmation

---

### Open questions

1. **Whether `package_diff` should cross-write into `session-diffs/<session>/session/uncommitted.diff`.** Currently `package_diff` (host CLI) writes to `output/diffs/` only. Cross-writing would make host-packaged uncommitted diffs available to `draft` via `--channel=session`. Channel-boundary decision; does not block A.1–A.3 or B.

2. **Exact CLI flag names for `--channel` values.** `bundles`, `autosave`, `session`, `diffs` are confirmed. May be revised if shorter alternatives emerge during implementation.

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
