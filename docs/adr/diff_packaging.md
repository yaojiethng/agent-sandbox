# Diff Packaging

**Current:** 2026-11-08

## 2026-11-08 -- The draft branch record is branch-local state, not a commit

**Decision:** A draft branch records `source_branch` and `fork_point` in local git config under `branch.<draft>.agent-sandbox-source` and `branch.<draft>.agent-sandbox-fork`; the committed `.draft-state` file and its commit are removed. `package_branch` owns the fork point; `draft` consumes it and has no `HEAD` default. The record is written before the branch and removed by `git branch -D`, so it exists for the whole life of the branch. `confirm` validates the branch and record, prechecks, rebases, fast-forwards, and deletes the draft without a metadata-drop step; `reject` returns to the recorded source and deletes the draft. The statechart and its invariants are in [`draft_branch_statechart.md`](../reference/draft_branch_statechart.md).

**Rationale:** `.draft-state` was a lifecycle variable with a `present -> dropped` transition; every hung confirm state lived in that transition (`CleanDropThenFailureHangs`, `SwitchFailureAfterDropHangs`, `MergeFailureAfterDropHangs`). A branch record is a branch-lifetime invariant instead (`RecordPresentDuringDraft`, `NoHungState`, `CanReturnToDraft`). Git owns branch creation, deletion, and rebase survival: config is keyed by branch name and removed with the branch. Of the old fields, only `source_branch` is not derivable; the package owns the fork point, and the rest is provenance or derivable from the branch, log, or bundle.

**Rejected alternatives:** *Keep `.draft-state` and make rollback more durable* -- the drop is the state transition that creates the failure class; a better rollback preserves the class. *Derive `source_branch` from the reflog* -- local, expiring, absent in a clone, and rewritten by later switches. *Encode `source_branch` in the draft branch name* -- slash and summary ambiguity, and a sanitised name is not reversible. *Store the record in git notes or a custom ref* -- extra machinery, stale refs, and no automatic branch-deletion cleanup. *Require `TARGET_BRANCH` everywhere and keep no source record* -- confirm works, but reject and the `NEW=1` hint lose their return direction. *Precheck and rollback only, keep the commit* -- covers detected failures, not the post-drop switch/merge window. *Make bundle transport the default* -- it fixes host-rewrite forkability, not mergeability, and reopens the plain-patch decision.

**Edge cases / drivers:** The config is written before the branch and unset if branch creation fails; a killed process can leave an inert config section with no branch. A pushed draft branch does not carry the record; remote draft branches are out of scope for this decision, and if they return the record must travel again. If the source branch is deleted or renamed, reject prints the manual return commands rather than guessing. An explicit `TARGET_BRANCH` wins over the recorded source; the record supplies the default and the reject direction. A draft branch is detected from `refs/heads/draft/` by its exact branch name (session identity, branch label, fork prefix), not from metadata; distinct names may coexist, so a bundle basename is not a second identity.

## 2026-10-02 -- The end-to-end apply flow is recorded here, not in the prompt that starts it

**Decision:** The sequence from a container export to a merged host worktree is owned by this ADR, and each step prints its own next hop:

| Step | Prints |
|---|---|
| `package_branch.sh` | the bundle path, a movement notice when the branch point moved from `init_sha`, then `make draft FROM=bundles BUNDLE=<b> BRANCH_SUMMARY=<slug> BRANCH_FROM=<sha>` |
| `make draft` | the draft worktree, then the linear direction when the source worktree is an ancestor of the draft tip, or the `NEW=1` direction when it is not; both branches name `make reject` and `make apply DIFF=<path>` |
| `make confirm ... NEW=1` | `git switch <source>` and `git reset --soft <new-branch>` |

The bundle summary is validated at entry against `^[a-z0-9]+(_[a-z0-9]+)*$`, 3 to 48 characters, by `package_branch_validate_summary`. The value names the bundle directory and the draft branch; git refuses a ref holding a space or a colon. `/package-branch` carries no apply instructions: it runs the export, relays the script's block verbatim, and prints the host-only verification. The single prompt that exported a rebased branch, `/package-rebase`, is folded into it: the branch point is computed the same way in both cases, so the case is a runtime fact, not a routing decision.

**Rationale:** Held in a prompt, the flow was a second copy of what three scripts print, and it drifted: it described only the fast-forward route while the soft-reset route was needed after every rebase. Routing on `merge-base --is-ancestor` moves the decision to the only place that can answer it, and covers a host that advanced independently of `init_sha`.

**Rejected alternatives:** *Keep both prompts* -- the split made the rebased case a separate invocation for a difference the script already detects. *Keep apply instructions in the prompt as a fallback* -- a fallback nobody reads until the primary fails is a second source of truth. *Have the agent choose the route* -- the agent cannot test fast-forwardability; it would guess from a hash.

**Edge cases / drivers:** `merge apply` is recovery-only and takes an arbitrary diff path; both it and the draft route are named in the hint. A target that diverged for any reason other than a container rebase also fails `--is-ancestor` and receives the `NEW=1` direction.

**Reason superseded by 2026-11-08:** the draft command no longer requires or defaults `BRANCH_FROM`; it forks at the package branch point, and the hint is unconditional. The `NEW=1` route remains the explicit fallback.

## 2026-09-24 -- The export baseline is the branch point; a rewritten target applies by soft reset

**Decision:** `package_branch` resolves its diff baseline to `git merge-base init_sha HEAD`, so the baseline is `init_sha` without a rewrite and the branch point after one; `--baseline=<sha>` overrides it. The pipeline's lower boundary is the newest commit the host and container share, not `init_sha` literally. A rewritten target cannot fast-forward, so `make confirm TARGET_BRANCH=<branch> NEW=1` creates `<branch>` at the draft tip, leaves the source untouched, and prints the `git reset --soft` direction. `TARGET_BRANCH` without `NEW` remains fast-forward or conflict-free rebase only.

**Rationale:** A rebase orphans `init_sha`, so diffs against it no longer match the host checkout. The merge-base recovers the shared commit without editing `SESSION_STATE` or naming the baseline by hand. The operator owns moving a long-lived branch, so the tool prints the reset rather than performing it.

**Rejected alternatives:** *Edit `SESSION_STATE.init_sha`* -- an ad-hoc mutation of the seed record. *Auto-detect with `git merge-base main HEAD`* -- assumes a base branch the harness does not guarantee. *Have `confirm` reset the target automatically* -- removes the operator's decision.

**Edge cases / drivers:** A garbage-collected `init_sha` makes `merge-base` fail; the resolver falls back to `init_sha`. A host that advances during a session names the newer shared commit with `--baseline`.

## 2026-09-19 -- The autosave checkpoint is swapped in, never wiped first

**Decision:** The autosave loop builds each checkpoint at a staging path outside the channel (`CHANGES_DIR/.autosave-staging-<SESSION_ID>`) and moves it into place only when the export succeeds. A failed cycle removes the staging path and leaves the live checkpoint untouched.

**Rationale:** The earlier form removed the live checkpoint first, so a failed cycle destroyed the last good checkpoint. The staging path sits outside `CHANGES_DIR/autosave/` because every reader enumerates that channel's direct children; a staging directory inside it would be selected as a bundle after an interrupted cycle. The move stays atomic because both paths share a filesystem.

**Edge cases / drivers:** An interrupted cycle leaves no partial bundle inside the channel. It can leave the staging path, cleared at the next cycle, or the previous checkpoint at the aside path; every cycle restores the aside path before deciding anything. The baseline is read before the swap, because the live checkpoint's `.export-status` holds the comparison point.

## 2026-09-19 -- The save decision is three-valued and callers do not switch on it

**Decision:** `session_save_needed SANDBOX_DIR BASELINE` returns `0` save, `1` skip, and `2` undeterminable when git cannot read the repository. `save_decision SANDBOX_DIR EXPORT_DIR LABEL` owns the dispatch: it resolves the baseline from the export's `.export-status` HEAD, falling back to `init_sha`, maps `0` to save, `1` to skip plus the diagnostic, and `2` to save anyway plus a distinct diagnostic.

**Rationale:** The two-valued form returned the same status for "clean at the baseline" and "git could not read the tree", so a broken sandbox reported `nothing to save` and wrote no artefact. An unknown state must not masquerade as known-good. One helper keeps the three-way mapping in one place.

**Edge cases / drivers:** Callers are the session export and the autosave loop. A status of `2` attempts an export and fails loudly where it can report.

## 2026-09-19 -- The clean-tree guard returns a verdict and prints nothing

**Decision:** `require_clean_working_tree PROJECT_DIR` takes the directory only, prints nothing, and returns `0` clean, `1` dirty, `2` unreadable. Callers print their own case with `clean_tree_hint` or `clean_tree_hint_unreadable`.

**Rationale:** The previous form decided and printed, so `draft` suppressed the message while `apply --force` printed an error on a path it then continued. Separating verdict from presentation lets each caller state its own case. An unreadable tree is not a dirty tree: reporting it as dirty tells the operator to stash changes that do not exist.

**Edge cases / drivers:** An unreadable tree fails closed at both callers.

## 2026-09-19 -- Save only when there is a change to save

**Decision:** The autosave loop and the session export run only when the tree is dirty or HEAD differs from the save baseline. They skip only when the tree is clean and HEAD equals the baseline. A helper, `session_save_needed SANDBOX_DIR BASELINE`, makes the decision; the baseline is the previous SUCCESS save's `.export-status` HEAD, falling back to `init_sha` for the first save.

**Rationale:** One comparison covers two rules: `init_sha` skips a session that never changed, and the last-saved HEAD skips re-saving an unchanged committed state. The baseline is read from the previous save's own record, so the path is self-describing and needs no tracker file. Dirty-first precedence means an in-progress edit is never dropped.

**Rejected alternatives:** *Save every cycle or exit* -- writes empty bundles and rebuilds an unchanged tree. *`init_sha`-only baseline* -- recreates empty bundles after a committed state stalls. *A separate last-save tracker* -- an extra record the previous `.export-status` already supplies.

**Edge cases / drivers:** The baseline is read before the autosave swap, because the swap replaces the `.export-status` holding it. A FAILed export is not a baseline; the resolver falls back to `init_sha`.

**Reason superseded by 2026-09-19:** the status set is three-valued and `save_decision` owns the dispatch; see the entry above.

**Reason superseded by 2026-09-24:** the pipeline's lower boundary is the branch point, not `init_sha` literally.

## 2026-09-19 -- Host workflows require a clean tree; reject discards residue

**Decision:** `make draft` and `make apply` refuse a dirty tree and print a stash-or-commit hint. `make draft` never bypasses the guard, not with `--force`; `make apply --force` tolerates a dirty tree as an apply conflict and warns about `.rej` files. `make reject` returns to the source branch with `checkout -f` and `clean -fd` when a checkout is blocked, discarding draft residue. The shared helper is `require_clean_working_tree`.

**Rationale:** Draft and apply run on the operator's real project repo. A dirty tree is carried onto the draft branch by `checkout -b`, and `git add -A` sweeps it into draft commits; reject then cannot return cleanly and rollback can destroy it. The guard resolves all three at the fork point: nothing is carried in, nothing is swept, and reject discards only draft-introduced residue.

**Rejected alternatives:** *Allow draft on a dirty tree* -- the leak being fixed. *Draft `--force` bypasses the guard* -- folds operator WIP into a branch that confirm would merge. *Reject leaves residue* -- strands the draft. *Reject prompts before discarding* -- adds a confirm surface to a command whose purpose is discard.

**Edge cases / drivers:** The guard runs before any working-tree mutation, so a refused command leaves the tree untouched. `make apply --force` may leave `.rej` files; the warning names them.

## 2026-08-01 -- Single export mechanism, four guarded workflow commands

**Decision:** All diff packaging uses one pipeline (`diff_export` -> `package_branch`), exposed as `/package-branch` on the agent side and `package-branch` on the host. There is no `package-diff`; `make apply` defaults to the `session` channel. The four host commands have distinct purposes: `apply` for direct recovery, `draft` for a review branch, `confirm` for guarded rebase and fast-forward, and `reject` for discard. `draft` rolls back to the fork point recorded on the branch; `confirm` restores a tip captured in a local variable; no tag is written. `reject` is atomic by chaining checkout and branch delete. `.draft-state` was the draft metadata store and was dropped by `confirm` before merge.

**Rationale:** One pipeline gives one mental model; `package-branch` is a strict superset of `package-diff`. The guards move correctness from operator memory to the tooling, and a recorded or captured restore point makes draft and confirm failures retryable. Reasoning record: [`20260803-design-settled-apply_draft_workflow.md`](../../devlog/discussions/archive/20260803-design-settled-apply_draft_workflow.md).

**Rejected alternatives:** *Remove `make apply`* -- recovery needs direct apply without branch clutter. *Remove `confirm` and `reject`* -- loses branch validation and metadata resolution. *Merge draft and apply* -- they solve different problems. *Replace `.draft-state` with tags* -- structured metadata needs tag annotations. *Keep `package-diff`* -- duplicate output from the same primitives.

**Edge cases / drivers:** A confirm rebase conflict must leave the repo restorable; a reject checkout failure must leave the draft intact; a draft apply failure must leave the repo pre-draft. The host repo is never modified by the container directly; the commands are the host half of the [interface contract](../reference/sandbox_host_interface.md).

**Reason superseded by 2026-11-08:** the `.draft-state` and savepoint-tag clauses are replaced by the branch-local draft record; the rest of this entry stands.
