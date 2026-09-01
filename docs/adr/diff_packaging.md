# Diff Packaging

**Current:** 2026-08-01

## 2026-08-01 -- Single export mechanism, four guarded workflow commands

**Decision:** All diff packaging — session export, autosave, agent-initiated,
operator-initiated — uses one pipeline (`diff_export` → `package_branch`)
exposed as `/package-branch` on the agent side and `package-branch` on the
host. There is no `package-diff`; the `diffs` channel is removed from
routing (`make apply` defaults to the `session` channel). The four host-side
review-loop commands are kept with distinct, non-overlapping purposes:
`apply` (direct recovery sync, no branch overhead, accepts arbitrary
`DIFF=<path>`), `draft` (review branch with full patch series, enables
`git rebase -i` shaping), `confirm` (guarded rebase + fast-forward merge),
`reject` (guarded discard). `draft` and `confirm` use local savepoint tags
for rollback safety (`git tag <name>-savepoint` before risky operations; on
failure `git reset --hard <tag>`; delete the tag on either outcome; local
tags are never pushed). `reject` is atomic by chaining checkout and branch
delete — a checkout failure leaves the draft branch intact. `.draft-state`
(committed as the first draft commit, records source branch, from_hash,
session identity, diff count) is kept as the draft metadata store and is
dropped by `confirm` before merge, never landing on the target branch.

**Rationale:** The harness exports agent changes as diff artefacts
(`patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, `changed-files/`)
that the operator reviews, shapes, and merges into the host repo. One export
pipeline gives one mental model and removes pure duplication (`package-branch`
is a strict superset of `package-diff`). The command guards shift the burden
of correctness from the operator's memory to the tooling; savepoint tags make
`confirm` and `draft` failures safely retryable. Reasoning record:
[`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md).

**Rejected alternatives:**
- *Remove `make apply`* (fold into `draft`) — recovery use cases need direct
  apply without branch clutter; `apply` accepts arbitrary diff paths, which
  draft does not.
- *Remove `make confirm`/`make reject`* (operator types the git commands) —
  loses the branch/guard validation and `.draft-state` resolution logic.
- *Merge draft and apply into one command* — they solve different problems
  (branch review vs direct recovery); merging forces one behavior to
  accommodate the other, making both worse.
- *Replace `.draft-state` with tags* — structured metadata storage would need
  tag annotations; a committed file is more ergonomic and is dropped before
  merge.
- *Keep `package-diff` alongside `package-branch`* — overlapping output from
  the same primitives is duplication.

**Edge cases / drivers:** Rebase conflict during `confirm` must leave the
repo restorable (savepoint reset to pre-confirm state); checkout failure
during `reject` must leave the draft intact (atomicity); patch application
failure during `draft` must leave the repo in its pre-draft state. The host
repo is never modified by the container directly — the command set is the
host-side half of the
[correspondence model](../concepts/sandbox_host_correspondence_model.md).
