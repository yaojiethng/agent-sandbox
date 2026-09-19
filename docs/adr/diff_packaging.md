# Diff Packaging

**Current:** 2026-09-19

## 2026-09-19 -- Save only when there is a change to save

**Decision:** The save step — the autosave loop and the session export — runs only when the working tree is dirty (any uncommitted or untracked change) or when HEAD differs from the save baseline. It skips only when the tree is completely clean and HEAD equals the baseline. Previously both ran unconditionally on every cycle / container exit, writing an empty bundle even for a session that changed nothing.

A helper, `session_save_needed SANDBOX_DIR BASELINE`, makes the decision: 0 (save) when dirty or HEAD != baseline, 1 (skip) only when clean and HEAD == baseline. The baseline is the HEAD the previous SUCCESS save recorded in its `.export-status` (a new `HEAD=<sha>` line stamped at export time), falling back to the session baseline `init_sha` from SESSION_STATE for the first save. `_save_baseline` resolves it from the previous `.export-status`, else `init_sha`. A skipped autosave cycle writes nothing and leaves the previous checkpoint untouched; a skipped session export creates no session directory at all.

**Rationale:** The baseline folds two rules into one comparison, so there is a single code path. Level 1 (baseline = `init_sha`) skips a session that never changed. Level 2 (baseline = last save's HEAD) skips re-saving an unchanged state after the first save — once HEAD has passed `init_sha`, comparing against `init_sha` alone would keep re-creating empty bundles every cycle. The baseline is always the last-saved HEAD, never a moving marker the harness must keep in sync: it is read from the previous save's own `.export-status`, so the save path stays self-describing. `init_sha` remains the immutable fixed lower boundary for the diff pipeline (`package_branch` diffs `init_sha..HEAD`); the save decision reuses it as the first-save baseline rather than introducing a new tracker file.

The dirty-first precedence is the contract: any uncommitted change forces a save regardless of HEAD. So an in-progress edit is never dropped — the guard never drops a change, it only avoids writing byte-identical empty bundles. `git status --porcelain` captures modified, staged, and untracked files alike.

**Rejected alternatives:**
- *Save every cycle / exit unconditionally* (prior behaviour) — costs a full `rm -rf` + `package_branch` rebuild and stamps a new `session/<ts>-<sid>/` directory even when nothing changed; the waste is systemic on idle sessions and long-running resumed ones. Rejected as the baseline for the no-op rule.
- *`init_sha`-only baseline (level 1 alone)* — skips the never-changed session but cannot skip re-saving an unchanged committed state after the first save; a session that committed once then stalled would re-create empty bundles every cycle. Rejected as insufficient: level 2 is the actual optimization.
- *A separate persisted last-save tracker file* — an extra file the harness must write, read, and keep consistent. Rejected as unnecessary: the previous save's `.export-status` already records what was captured; its `HEAD` line is the natural comparison point.

**Edge cases / drivers:** The autosave loop reads the baseline *before* its `rm -rf`, because the wipe destroys the very `.export-status` that holds the comparison point. A FAILed previous export is not a baseline — `_save_baseline` falls back to `init_sha` rather than trust an interrupted save. A busy agent with uncommitted edits always saves, so an export is never lost to the guard. The lifecycle and layout are documented in [sandbox_lifecycle.md](../architecture/sandbox_lifecycle.md).

## 2026-08-01 -- Single export mechanism, four guarded workflow commands

**Decision:** All diff packaging — session export, autosave, agent-initiated, operator-initiated — uses one pipeline (`diff_export` → `package_branch`) exposed as `/package-branch` on the agent side and `package-branch` on the host. There is no `package-diff`; the `diffs` channel is removed from routing (`make apply` defaults to the `session` channel). The four host-side review-loop commands are kept with distinct, non-overlapping purposes:
`apply` (direct recovery sync, no branch overhead, accepts arbitrary `DIFF=<path>`), `draft` (review branch with full patch series, enables `git rebase -i` shaping), `confirm` (guarded rebase + fast-forward merge), `reject` (guarded discard). `draft` and `confirm` use local savepoint tags for rollback safety (`git tag <name>-savepoint` before risky operations; on failure `git reset --hard <tag>`; delete the tag on either outcome; local tags are never pushed). `reject` is atomic by chaining checkout and branch delete — a checkout failure leaves the draft branch intact. `.draft-state` (committed as the first draft commit, records source branch, from_hash, session identity, diff count) is kept as the draft metadata store and is dropped by `confirm` before merge, never landing on the target branch.

**Rationale:** The harness exports agent changes as diff artefacts (`patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, `changed-files/`) that the operator reviews, shapes, and merges into the host repo. One export pipeline gives one mental model and removes pure duplication (`package-branch` is a strict superset of `package-diff`). The command guards shift the burden of correctness from the operator's memory to the tooling; savepoint tags make `confirm` and `draft` failures safely retryable. Reasoning record:
[`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md).

**Rejected alternatives:**
- *Remove `make apply`* (fold into `draft`) — recovery use cases need direct
  apply without branch clutter; `apply` accepts arbitrary diff paths, which draft does not.
- *Remove `make confirm`/`make reject`* (operator types the git commands) —
  loses the branch/guard validation and `.draft-state` resolution logic.
- *Merge draft and apply into one command* — they solve different problems
  (branch review vs direct recovery); merging forces one behavior to accommodate the other, making both worse.
- *Replace `.draft-state` with tags* — structured metadata storage would need
  tag annotations; a committed file is more ergonomic and is dropped before merge.
- *Keep `package-diff` alongside `package-branch`* — overlapping output from
  the same primitives is duplication.

**Edge cases / drivers:** Rebase conflict during `confirm` must leave the repo restorable (savepoint reset to pre-confirm state); checkout failure during `reject` must leave the draft intact (atomicity); patch application failure during `draft` must leave the repo in its pre-draft state. The host repo is never modified by the container directly — the command set is the host-side half of the [interface contract](../concepts/sandbox_host_interface.md).
