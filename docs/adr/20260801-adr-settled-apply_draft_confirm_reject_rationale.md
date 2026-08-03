# ADR — Diff Packaging and Apply/Draft Workflow Design Decisions

**Summary:** Keep all four host-side workflow commands. Use `package-branch` as the single export mechanism (drop `package-diff`). Use local savepoint tags for rollback safety in draft/confirm. Keep `.draft-state` for draft branch metadata.

## Context

The harness exports agent changes from the capability container as diff artefacts (`patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, `changed-files/`). The operator needs to review, shape, and merge these changes into the host repository. Four commands form the review loop:

| Command | Purpose |
|---|---|
| `make apply` | Direct apply of a single diff for recovery and mid-session sync |
| `make draft` | Create a review branch, apply patches sequentially, leave for operator shaping |
| `make confirm` | Rebase draft onto target branch and fast-forward merge |
| `make reject` | Discard draft branch and return to source branch |

## Options Considered

### Option A: Remove `make apply`

Channel-mode application of `uncommitted.diff` could be handled by `make draft` directly. Rejected: `make apply` serves recovery use cases where creating a full draft branch is unnecessary overhead. Direct apply is faster and leaves no branch clutter. It also accepts `DIFF=<path>` for arbitrary diff files — a capability draft doesn't provide.

### Option B: Remove `make confirm` and `make reject`

These are 3-4 git commands each. An operator could type them manually. Rejected: the guard logic is valuable. `confirm` validates the current branch is a draft, reads `.draft-state` for source branch and target, and drops the metadata commit before merge. `reject` validates and returns cleanly. Removing them loses these guards and shifts the burden of correctness to the operator's memory.

### Option C: Merge draft/apply into a single command

Considered in [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md) — deferred. They solve different problems (branch review vs direct recovery) and merging would force one behavior to accommodate the other, making both worse.

### Option D: Remove `.draft-state` commit, use tags

Considered in handover `20260801-05`. Rejected: `.draft-state` stores structured metadata (source branch, from_hash, session identity, diff count) that `confirm` and `reject` read. Replacing it with tags would require tag annotations for metadata storage — less ergonomic than a committed file. `.draft-state` is dropped before merge and never lands on the target branch.

### Option E: Keep `package-diff` alongside `package-branch`

`package-branch` is a strict superset of `package-diff` — both produce `uncommitted.diff`, `all-changes.diff`, and `changed-files/`; `package-branch` also produces `patches/*.diff`. Maintaining two scripts with overlapping output from the same underlying primitives is pure duplication. Rejected: removed `package-diff` entirely.

## Decision

**Single export mechanism: `package-branch`.** All diff packaging — session export, autosave, agent-initiated, operator-initiated — uses the same pipeline (`diff_export` → `package_branch`). There is no `package-diff`. The `diffs` channel is removed from routing. The agent has one export tool (`/package-branch`).

**Keep all four workflow commands.** Each serves a distinct purpose:

- `apply` — direct recovery sync, no branch overhead, accepts arbitrary diff paths
- `draft` — creates review branch with full patch series, enables `git rebase -i` shaping
- `confirm` — guarded rebase + fast-forward merge with savepoint rollback on failure
- `reject` — guarded discard with atomic checkout+delete

**Use local savepoint tags for rollback safety** in `draft` and `confirm`. Pattern: `git tag <name>-savepoint` before risky operations; on failure, `git reset --hard <tag>` and `git tag -d <tag>`; on success, `git tag -d <tag>`. Local tags are never pushed by default — no remote pollution.

**Make `reject` atomic** by chaining checkout and branch delete: failure at checkout returns error with draft branch intact. No partial state possible.

## Consequences

### What this enables

- Single mental model for exports: everything is `package-branch`, triggered different ways
- Operator can safely retry `make confirm` after a rebase conflict — the savepoint resets to pre-confirm state
- Operator can retry `make reject` after a checkout failure — draft branch is still intact
- Patch application failures in `make draft` leave the repo in its pre-draft state via the same savepoint pattern
- All four commands have clear, non-overlapping purposes

### What this forecloses

- `package-diff` as a separate concept — the agent has one export tool, the operator has one host-side export
- The `diffs` channel — removed from routing; `make apply` defaults to `session` channel
- Combining `draft` and `apply` into one command — they serve different use cases
- Stateless confirm/reject — the `.draft-state` metadata file remains necessary for source branch resolution

### Migration

No migration needed. Existing workflow behavior is unchanged. Savepoint tags and atomic reject add safety without changing the command interface.

## Supersedes

- [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md) — unified design doc describing the current system
- `design_apply_workflow_and_baseline_advancement.md` — original M2.3 design (deleted, superseded by this ADR)
- `design_diff_and_branch_packaging_workflow.md` — earlier packaging workflow design (deleted, superseded)
- `design_remove_package_diff.md` — package-diff removal design (deleted, absorbed into this ADR)
