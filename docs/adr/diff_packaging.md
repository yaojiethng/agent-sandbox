# Diff Packaging

**Current:** 2026-09-19

## 2026-09-19 -- The autosave checkpoint is swapped in, never wiped first

**Decision:** The autosave loop builds each new checkpoint at a staging path outside the channel (`CHANGES_DIR/.autosave-staging-<SESSION_ID>`) and moves it into place only when the export succeeds. A failed cycle removes the staging directory and leaves the live checkpoint untouched.

**Rationale:** The earlier form removed the live checkpoint before writing the new one, so a failed cycle destroyed the last good checkpoint. That became reachable when the save decision gained its undeterminable status: an unreadable repository now proceeds to an attempted export, which then fails -- exactly the case where the previous checkpoint must survive. The staging path sits outside `CHANGES_DIR/autosave/` because every reader of that channel enumerates its direct children (`resolve_latest_dir_by_mtime`, `resolve_source_for_draft`, and the interactive pickers), so a staging directory inside it would be selected as a bundle after an interrupted cycle. `$CHANGES_DIR` and its `autosave/` child share a filesystem, so the move stays atomic.

**Edge cases / drivers:** An interrupted cycle leaves no partial bundle inside the channel. It can leave the staging path (outside the channel, cleared at the start of the next cycle) or, if it is killed between the two moves, the previous checkpoint at the aside path with no live path -- every cycle restores the aside path before it decides anything else, so even a skipped cycle cannot strand it. The baseline is still read before the swap, because the live checkpoint's `.export-status` holds the comparison point.

## 2026-09-19 -- The save decision is three-valued and callers do not switch on it

**Decision:** `session_save_needed SANDBOX_DIR BASELINE` returns three values, not two: `0` save, `1` skip, and `2` undeterminable when git cannot read the repository. A new `save_decision SANDBOX_DIR EXPORT_DIR LABEL` in the same module owns the dispatch: it resolves the baseline from EXPORT_DIR's own `.export-status` HEAD (falling back to the session baseline `init_sha`), maps `0` to "save", `1` to "skip" plus the diagnostic, and `2` to "save anyway" plus a distinct diagnostic, so callers see a boolean and never switch on the raw status.

**Rationale:** The two-valued form returned the same status for "the tree is clean at the baseline" and "git could not read the tree", so a sandbox with a broken `.git` produced the success message `nothing to save` and no artefact. The distinction is the point: an unknown state must not masquerade as a known-good one. Keeping the dispatch in one helper keeps the three-way mapping in a single place rather than repeated at each call site, and it is the shape [bash-coding-conventions.md](../../docs/development/bash-coding-conventions.md) section 3.2 prescribes.

**Edge cases / drivers:** Callers are the capability entrypoint's session export and its autosave loop; both now call `save_decision`. The policy functions live in `src/libs/session_save_policy.sh`, separate from the export pipeline, so the decision is testable without docker or packaging. A status of `2` leads to an attempted export, which fails loudly where it can report, rather than to a silent skip.

## 2026-09-19 -- The clean-tree guard returns a verdict and prints nothing

**Decision:** `require_clean_working_tree PROJECT_DIR` takes the directory only, returns a verdict, and prints nothing. The `LABEL` parameter is removed. Callers print their own first line and then call the shared hint for their case: `clean_tree_hint` for a dirty tree, `clean_tree_hint_unreadable` when git cannot read it. The verdict is three-valued, matching `session_save_needed`: `0` clean, `1` dirty, `2` unreadable. An unreadable tree fails closed at both callers.

**Rationale:** The previous form decided and printed, so `draft` suppressed the message and wrote its own variant while `apply --force` printed an error on a path it then continued. Separating the verdict from the presentation lets each caller state its own case -- `draft` refuses, `apply --force` warns and proceeds -- with one shared wording per case. The unreadable status exists because a corrupt or locked index is not a dirty tree: reporting it as dirty tells the operator to stash changes that do not exist, which is the error-versus-unknown collapse [bash-coding-conventions.md](../../docs/development/bash-coding-conventions.md) section 3.2 forbids. Replaces the `LABEL`-bearing signature recorded in the 2026-09-19 clean-tree entry below.

## 2026-09-19 -- Save only when there is a change to save

**Decision:** The save step -- the autosave loop and the session export -- runs only when the working tree is dirty (any uncommitted or untracked change) or when HEAD differs from the save baseline. It skips only when the tree is completely clean and HEAD equals the baseline. Previously both ran unconditionally on every cycle / container exit, writing an empty bundle even for a session that changed nothing.

A helper, `session_save_needed SANDBOX_DIR BASELINE`, makes the decision: 0 (save) when dirty or HEAD != baseline, 1 (skip) only when clean and HEAD == baseline. The baseline is the HEAD the previous SUCCESS save recorded in its `.export-status` (a new `HEAD=<sha>` line stamped at export time), falling back to the session baseline `init_sha` from SESSION_STATE for the first save. `_save_baseline` resolves it from the previous `.export-status`, else `init_sha`. A skipped autosave cycle writes nothing and leaves the previous checkpoint untouched; a skipped session export creates no session directory at all.

**Reason superseded by 2026-09-19:** The status set is now three-valued (0 save, 1 skip, 2 undeterminable) and `save_decision` owns the dispatch; see the entry above.

**Rationale:** The baseline folds two rules into one comparison, so there is a single code path. Level 1 (baseline = `init_sha`) skips a session that never changed. Level 2 (baseline = last save's HEAD) skips re-saving an unchanged state after the first save -- once HEAD has passed `init_sha`, comparing against `init_sha` alone would keep re-creating empty bundles every cycle. The baseline is always the last-saved HEAD, never a moving marker the harness must keep in sync: it is read from the previous save's own `.export-status`, so the save path stays self-describing. `init_sha` remains the immutable fixed lower boundary for the diff pipeline (`package_branch` diffs `init_sha..HEAD`); the save decision reuses it as the first-save baseline rather than introducing a new tracker file.

The dirty-first precedence is the contract: any uncommitted change forces a save regardless of HEAD. So an in-progress edit is never dropped -- the guard never drops a change, it only avoids writing byte-identical empty bundles. `git status --porcelain` captures modified, staged, and untracked files alike.

**Rejected alternatives:**

- *Save every cycle / exit unconditionally* (prior behaviour) -- costs a full `rm -rf` + `package_branch` rebuild and stamps a new `session/<ts>-<sid>/` directory even when nothing changed; the waste is systemic on idle sessions and long-running resumed ones. Rejected as the baseline for the no-op rule.
- *`init_sha`-only baseline (level 1 alone)* -- skips the never-changed session but cannot skip re-saving an unchanged committed state after the first save; a session that committed once then stalled would re-create empty bundles every cycle. Rejected as insufficient: level 2 is the actual optimization.
- *A separate persisted last-save tracker file* -- an extra file the harness must write, read, and keep consistent. Rejected as unnecessary: the previous save's `.export-status` already records what was captured; its `HEAD` line is the natural comparison point.

**Edge cases / drivers:** The autosave loop reads the baseline *before* the swap, because replacing the checkpoint replaces the very `.export-status` that holds the comparison point. A FAILed previous export is not a baseline -- `_save_baseline` falls back to `init_sha` rather than trust an interrupted save. A busy agent with uncommitted edits always saves, so an export is never lost to the guard. The lifecycle and layout are documented in [sandbox_lifecycle.md](../architecture/sandbox_lifecycle.md).

## 2026-09-19 -- Host workflows require a clean tree; reject discards residue

**Decision:** The host-side review-loop commands that touch the project working tree guard on its cleanliness. `make draft` and `make apply` refuse to run when `git status --porcelain` is non-empty (uncommitted, staged, or untracked changes present), printing a stash-or-commit hint. `make draft` never bypasses the guard, not with `--force`; `make apply --force` tolerates a dirty tree as one form of apply conflict and warns that some hunks may fail. `make reject` returns to the source branch with `checkout -f` + `clean -fd` when an unguarded checkout is blocked, discarding draft residue from the working tree.

The shared helper `require_clean_working_tree PROJECT_DIR [LABEL]` in `guards.sh` implements the check; it returns 1 with a hint when the tree is dirty.

**Reason superseded by 2026-09-19:** `LABEL` is removed, the helper prints nothing so callers own the message, and the verdict is now three-valued (0 clean, 1 dirty, 2 unreadable); see the entry above.

**Rationale:** Draft and apply operate on the operator's real project repo (`PROJECT_DIR`), not the sandbox. Running them from a dirty tree leaks the operator's working state: `git checkout -b` carries uncommitted/staged/untracked changes onto the draft branch, and `apply_and_commit`'s `git add -A` sweeps them into the draft commits. The leak then propagates to the unwind path -- `make reject` could not check out the source branch over conflicting residue and aborted, leaving the draft behind; the failed-apply rollback's `reset --hard` would destroy the pre-existing working changes. A hard clean-tree guard at the fork point resolves all three at once: nothing is carried in, nothing is swept, and reject/rollback can safely discard because the only residue is draft-introduced. Once the draft commits are dropped, the final working-tree changes carry no information, so reject discarding them is lossless and returns the operator to a known-clean source state.

Rejecting lacks an operator-visible surface for the discard decision: revert discards a review branch whose whole purpose is temporary, so there is no separate confirm prompt. `make apply --force` keeps its conflict-tolerance meaning; a dirty tree is the same class of problem as an apply conflict. Draft does not extend force to the guard: folding operator WIP into a review branch that `make confirm` would then merge into the source is never what the operator wants from `--force`.

**Rejected alternatives:**

- *Allow draft on a dirty tree* (prior behaviour) -- carries WIP into the branch and sweeps it into commits; reject then cannot return cleanly and rollback can destroy the WIP. Rejected as the leak being fixed.
- *Draft --force bypasses the clean guard* -- force would silently fold operator WIP into the review branch, and `make confirm` would merge that WIP into the source. Rejected: --force means tolerating apply conflicts, not shipping local work.
- *Reject leaves residue; ask the operator to resolve by hand* (prior behaviour) -- could not check out and aborted, stranding the draft. Rejected as the state leak.
- *Reject prompts before discarding* -- adds a confirm surface to a command whose purpose is discard; the residue is information-free once the commits drop. Rejected as needless friction.

**Edge cases / drivers:** The guard runs before any working-tree mutation, so a refused draft/apply leaves the tree untouched. `make apply --force` may produce `.rej` files from failing hunks; the warning points the operator at them. The lifecycle and command behaviours are documented in [sandbox_lifecycle.md](../architecture/sandbox_lifecycle.md).

## 2026-08-01 -- Single export mechanism, four guarded workflow commands

**Decision:** All diff packaging -- session export, autosave, agent-initiated, operator-initiated -- uses one pipeline (`diff_export` -> `package_branch`) exposed as `/package-branch` on the agent side and `package-branch` on the host. There is no `package-diff`; the `diffs` channel is removed from routing (`make apply` defaults to the `session` channel). The four host-side review-loop commands are kept with distinct, non-overlapping purposes:
`apply` (direct recovery sync, no branch overhead, accepts arbitrary `DIFF=<path>`), `draft` (review branch with full patch series, enables `git rebase -i` shaping), `confirm` (guarded rebase + fast-forward merge), `reject` (guarded discard). `draft` and `confirm` use local savepoint tags for rollback safety (`git tag <name>-savepoint` before risky operations; on failure `git reset --hard <tag>`; delete the tag on either outcome; local tags are never pushed). `reject` is atomic by chaining checkout and branch delete -- a checkout failure leaves the draft branch intact. `.draft-state` (committed as the first draft commit, records source branch, from_hash, session identity, diff count) is kept as the draft metadata store and is dropped by `confirm` before merge, never landing on the target branch.

**Rationale:** The harness exports agent changes as diff artefacts (`patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, `changed-files/`) that the operator reviews, shapes, and merges into the host repo. One export pipeline gives one mental model and removes pure duplication (`package-branch` is a strict superset of `package-diff`). The command guards shift the burden of correctness from the operator's memory to the tooling; savepoint tags make `confirm` and `draft` failures safely retryable. Reasoning record:
[`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md).

**Rejected alternatives:**

- *Remove `make apply`* (fold into `draft`) -- recovery use cases need direct
  apply without branch clutter; `apply` accepts arbitrary diff paths, which draft does not.
- *Remove `make confirm`/`make reject`* (operator types the git commands) --
  loses the branch/guard validation and `.draft-state` resolution logic.
- *Merge draft and apply into one command* -- they solve different problems
  (branch review vs direct recovery); merging forces one behavior to accommodate the other, making both worse.
- *Replace `.draft-state` with tags* -- structured metadata storage would need
  tag annotations; a committed file is more ergonomic and is dropped before merge.
- *Keep `package-diff` alongside `package-branch`* -- overlapping output from
  the same primitives is duplication.

**Edge cases / drivers:** Rebase conflict during `confirm` must leave the repo restorable (savepoint reset to pre-confirm state); checkout failure during `reject` must leave the draft intact (atomicity); patch application failure during `draft` must leave the repo in its pre-draft state. The host repo is never modified by the container directly -- the command set is the host-side half of the [interface contract](../concepts/sandbox_host_interface.md).
