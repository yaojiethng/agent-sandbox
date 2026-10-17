---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The dispatch script names its base revision

## Objective

Make the OpenCode dispatch script attribute its change set to a named base revision instead of to a clean working tree, so a later pass over one unit runs in place.

## Scope

The M3.6.1 row `A correction pass through the dispatch script needs its own commit`: the `opencode-dispatch` skill's script, its skill file, and a new check. The script carried no check of any kind before this iteration, so the check is new coverage rather than an edit. The role-resolution defect found in passing is out of scope and routed below. The scratch directory sitting inside the repository work tree is a second finding, likewise routed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The clean-tree precondition is gone | `grep -c 'the working tree is dirty'` over the script returns 0 | Agent [x] |
| A dirty tree is accepted | `bash tests/test_opencode_dispatch.sh`, case `test_a_dirty_tree_is_accepted`, rc 0 | Agent [x] |
| The change set is the unit's, not one pass's | case `test_change_set_is_the_units_set` names both the caller's uncommitted edit and the worker's edit | Agent [x] |
| The caller's uncommitted work survives a destructive worker | case `test_the_pre_state_survives_a_destructive_worker`, whose stub runs `git reset --hard`; the tree loses the edit and the pre-state still holds it | Agent [x] |
| An unresolvable base is refused by name | case `test_refuses_an_unresolvable_base` | Agent [x] |
| An unset base resolves to HEAD | case `test_the_base_defaults_to_head` | Agent [x] |
| The check discriminates | the final file run against the pre-change script scores 8 failed, 4 passed; the 8 are the unresolvable base, the accepted dirty tree, the unit change set, the named base, the base sha, the pre-state, the destructive worker and the default base; the 4 are the refusal cases the change did not touch | Agent [x] |
| The base override is observed, not assumed | a mutant script with `OPENCODE_DISPATCH_BASE` ignored scores 10 passed, 2 failed: the unresolvable base and the named base. The first was the only detector before the correction pass | Agent [x] |
| The change is proven in place, on this repository | the correction pass ran with `base: 70478f2f...` and a non-empty pre-state, and its change set was the unit's five files | Agent [x] |
| The installed skill copy matches the repository source | `diff -q` on both files, identical | Agent [x] |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates; `bash scripts/run_tests.sh` 1186 passed across 84 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The report's basis is a base revision, not a pre-state snapshot | the caller commits the unit, not one pass, so the base set equals the commit set. A snapshot reports a narrower set than the artifact the caller commits | this handover; the run brief |
| The base is an environment override, not a fourth positional argument | the three existing per-run knobs are already environment overrides, and a fourth positional would sit after the optional role argument, coupling two unrelated options | this handover; the script header |
| The clean-tree refusal is deleted rather than kept beside the base | it was a proxy for attribution, and the base is the direct form. Keeping both leaves the blocker in place | the script header |
| A pre-state stash commit is captured when the tree is dirty | a worker runs with `--auto` in the same tree, and one `git reset --hard` destroys work that exists nowhere else. `git stash create` writes the object without touching the tree or the index | this handover; the script comment |
| The change set adds `git diff --cached` to the working-tree diff | an index-only divergence is invisible to `git diff <base>` while `git commit` would still land it | the script comment |
| Untracked file content is not captured, and the residual is named in the skill file | `git stash create` omits untracked files, and capturing them needs a second mechanism for a case a correction pass intends to modify | the skill file failure-mode table |
| The role argument does not select the model, and the fix is not this row | a dispatch asked for `_ADVISOR` and ran the script's own default model. Correcting it changes what the role argument means, which is the dispatch-rule surface's question | a finding below |
| The pre-state capture refuses rather than reporting a best-effort value | a recovery point the caller believes in and does not have is worse than a blocked run. A mid-merge index makes `git stash create` fail while writing its message to stdout, so the value looked like a sha | a finding below |
| A worker that commits the caller's work is documented, not prevented | the script cannot stop a worker running `git commit` in a tree it owns, and the pre-state still holds the work, so the caller unwinds one commit | the skill file failure-mode table |
| The correction pass ran in place over pass 1 | it is the change's own use case, and running it any other way would leave the feature unproven on the artifact it exists for | this handover |
| Guarding a worker's writes per brief is a governance lapse, not a control | a read-only worker should not be able to write, and a write-enabled worker needs a write mechanism that several workers use safely at once. A line the caller must remember is neither. The problem is designed, not patched | T7 row `A worker's write capability is not a property of the worker` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Who owns the role-to-model resolution order | whether the skill's default model keeps shadowing the role table | the skill reads the table for the pair only; or the table supplies the model and the override is explicit; or the role argument is dropped from the skill's contract |

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The script's default model shadows the role table, so the role argument selects nothing but a name that must exist | defect | a dispatch for one role silently runs another model; the run this iteration used for a second opinion did not get the model it asked for | M3.6.3 row `The dispatch-rule surface`, amended |
| The run directory sits inside the repository work tree, so `git clean -fdx` destroys the log and the change set that are the run's only evidence | defect | a worker that cleans ignored files destroys its own evidence and the refusal then reports no output | T7 row `A worker's write capability is not a property of the worker`, named there as a symptom |
| The skill script carried no check at all, while its sibling `pi-reviewer-dispatch` had one | coverage gap | the script's refusals and its report were unverified | closed by this iteration's new check |
| The role table and the skill default disagree on the implementer's model | fact | a reader cannot tell which value a run used from the invocation alone | M3.6.3 row `The dispatch-rule surface`, amended |
| An independent review found seven defects: a masked pre-state capture failure, an underclaimed residual, a vacuous base-override path, a stale discrimination figure, an undisclosed exit shape, an overstated print claim, and an undocumented incorporation risk | defect | the first three were live; the third left the change's stated purpose unobserved by any test | all seven corrected in the same iteration |
| The review ran its experiments inside the repository and reset the branch to unwind them | process | two dangling commits remain in the reflog; no tracked file was lost, because the tree was clean when the review started; it also removed the repository's local git identity, which this iteration restores | T7 row `A worker's write capability is not a property of the worker`, recorded there as the measured instance |

## Completed

| File | One-line change summary |
|---|---|
| [`dispatch.sh`](../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh) | the dirty-tree refusal is replaced by `OPENCODE_DISPATCH_BASE` defaulting to `HEAD`; a pre-state stash commit is captured for a dirty tree; the change set is the base-relative working-tree diff, the cached diff and the untracked paths, deduplicated by path; the header reports the base and the pre-state |
| [`SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md) | the clean-tree contract becomes the base-revision contract; step 2 names the base; the failure-mode table carries the unresolvable base and the untracked-file residual |
| [`tests/test_opencode_dispatch.sh`](../../tests/test_opencode_dispatch.sh) | new: twelve cases covering the refusals, the accepted dirty tree, the unit change set, the change set measured from a named non-default base, the resolved base and pre-state, the recovery point after a destructive worker, and the failing worker |
