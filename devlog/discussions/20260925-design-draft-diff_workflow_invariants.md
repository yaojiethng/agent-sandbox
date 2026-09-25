# Diff Workflow Invariants

**Status:** draft - first write, not yet reviewed. Awaits the operator's decision.

**Scope:** the state contract and the operator-facing guarantees of the diff components - the export pipeline that produces a bundle, the bundle's artifact contract, and the four host-side workflows that consume it (`apply`, `draft`, `confirm`, `reject`). What each component promises about the states it accepts, the states it leaves behind, and what is recoverable when it fails. Out: how the pipeline is implemented (the sibling unification note), the flag and `.env` declaration surface (the resolver note), the dispatcher boundary (the CLI-to-workflow note), and the other capability branches (the session registry, the execution lifecycle, the record formats, host setup, provider context), which take their own notes in this series.

## Context

The read-through reached the four workflows and found that none of them declares its incoming state. `scripts/prune.sh` is the only file in the tree with an `INVARIANT` block (its partition rule), and it is the form this note proposes to follow.

**The chain, as the code enforces it today.** `apply` requires a clean tree and tolerates a dirty one under `--force` with a warning about `.rej` collateral. `draft` requires a clean tree and its comment states that `--force` never bypasses it ("force only tolerates apply conflicts, never an unclean fork base"). `draft` then *produces* a dirty tree by design: `draft_apply_uncommitted` applies `uncommitted.diff` "working tree only -- not committed". So a dirty tree is not a violation for `confirm` and `reject`; it is the normal state they are handed.

| state | what it is | recoverable from |
|---|---|---|
| S1 | clean tree, on the draft branch | n/a |
| S2 | dirty tree, residue applied from the bundle's `uncommitted.diff` | the bundle, by re-applying the diff |
| S3 | dirty tree, edits the bundle does not hold (operator edits after the draft) | nothing |
| S4 | not on a draft branch | n/a - both workflows refuse |

**What the two consumers do with it.** `confirm` declares nothing: on a dirty tree its `.draft-state` drop rebase refuses, and the failure handler runs `git reset --hard "$SAVEPOINT_COMMIT"`, which restores the branch and destroys the working tree. The step-3 path's message is worse, because it says the draft branch is "restored to the savepoint (unchanged)" - true of the branch, false of the tree - and then sends the operator to `make reject`. `reject` declares nothing either: its discard lives inside the `if ! git checkout` fallback, so it runs only when some unrelated tracked path happened to collide with the switch. On that path `git clean -fd` takes no pathspec and removes every untracked, non-ignored file in the project; on the other path the residue is carried to the source branch untouched.

**The composition rule nobody states.** `apply`'s postcondition (a dirty worktree, left unstaged for review) contradicts `draft`'s precondition (clean). The two are alternative consumers of one bundle, never a sequence, yet the Makefile presents them as neighbours with no statement of that.

**The guarantees around the bundle.** `docs/adr/diff_packaging.md` and the unification note fix the artifact internals, but the promises the operator can rely on are neither collected nor pinned: an export reports SUCCESS for a `package_branch` that failed internally (row 68), the artifact writers cannot carry binary content while the per-commit patches can (row 65), and the primitives alias "git could not run" to "no changes" (row 60). A recovery instruction that names the bundle is only as trustworthy as those verdicts.

**The interface guarantees.** `docs/architecture/tool_interface.md` documents each command's flags but not what each command guarantees about the repository afterwards. Two workflows advertise behaviour no flag selects (rows 218, 221), one requires a flag it never reads (row 219), and every leaf's help path exits 2 because the conversion meant to make it a success is dead under `set -e` (rows 130, 136, 174).

**Evidence.** Rows 241, 253, 255 (the force and clean-tree surface), 216, 231 (its plumbing coverage), 213, 215, 224, 250, 252 (entry points no unit drives), 57 through 71 (the pipeline), 200 through 208 (the dispatcher), 38 and 242 (the record read that both leaves perform), and 137 through 151 (`prune.sh`'s partition, the form's source). Probes: the reject pass's P3, P7, and P8 (the three residue outcomes) and P9 and P10 (confirm's WIP loss and its untracked carry-over), plus the R1 through R14 bite sweep.

## Options Considered

### Option area 1 - where the invariants are stated

**Option A - in the durable docs only.** State the contracts in `tool_interface.md` and `sandbox_lifecycle.md`. Cost: the code keeps improvising per file, and the doc drifts from it, which is the failure row 134 records (a header describing the previous design).

**Option B - in the workflow header, in `prune.sh`'s form.** The states, which are legitimate, and what the workflow does with each. The durable docs then point at the header for the current statement. Cost: four headers to keep coherent, so the block's shape must be fixed by one worked example and reused verbatim.

**Option C - a shared declaration helper.** Cost: the invariants are statements about behaviour, not runtime checks. A helper can own detection (`require_clean_working_tree` already does) but it cannot own the statement, and hiding the prose behind a call site makes it less readable, not more.

### Option area 2 - the enforcement policy

**Option A - refuse a dirty tree everywhere.** Cost: it breaks the documented `draft` then `reject` flow, because `draft`'s postcondition is exactly the state that would be refused.

**Option B - tolerate everywhere under `--force`.** Cost: it makes the destructive path the expected one and contradicts `draft`'s deliberate never-bypassed rule.

**Option C - declare, and enforce per workflow according to whether the dirty state is legitimate.** `draft` refuses and never bypasses; `apply` refuses with `--force` tolerance; `reject` refuses unless acknowledged; `confirm` refuses. Three policies, each stated where it applies.

**Option D - declare but never enforce.** Cost: a declaration no unit pins is documentation, and the current behaviour is what the read-through found.

### Option area 3 - the acknowledgement mechanism for `reject`

**Option A - `--force`, spelled `FORCE=1` at the Make layer.** The spelling `apply` and `draft` already use, so the operator learns one convention. Cost: `--force` means "tolerate a dirty tree" in `apply` and "discard the residue" in `reject`; one spelling with two meanings, which each declaration must state.

**Option B - a distinct flag** (`--discard-residue` or similar). Cost: a second convention on the Make surface for a single workflow.

**Option C - an interactive confirmation.** `apply` and `draft` already carry `--interactive`. Cost: unusable from automation, and the non-interactive default must still be fail-closed, so the flag is needed either way.

### Option area 4 - what the warning says

**Option A - the shared hint.** `clean_tree_hint`'s two lines ("Stash them ... or commit them first"). Cost: the operator cannot tell S2 from S3, and that distinction is the whole reason the draft-produced state is legitimate.

**Option B - the hint plus the recovery source.** Name the bundle and its `uncommitted.diff`, read from the record's `session_id` and the `--sandbox` path the workflow already receives. Cost: `reject` starts reading the bundle it currently ignores, and the message degrades to the generic hint when the bundle has been removed.

### Option area 5 - the breadth of a forced discard

**Option A - worktree-wide.** `clean -fd` as it runs today on the blocking path: every untracked, non-ignored file. Cost: files unrelated to the draft go too; the acknowledgement covers that but does not scope it.

**Option B - scoped to the paths the bundle touched.** Derived from the applied patches plus `uncommitted.diff`, or from the changed-files manifest. Cost: needs the bundle present, and a mis-derived list deletes the wrong files silently.

**Option C - worktree-wide, declared.** Keep the breadth, state it in the warning and in the declaration, and rely on the per-file `Removing ...` lines git already prints. Cost: nothing asserts that output today, so the visibility is incidental.

### Option area 6 - `confirm`'s rescue

**Option A - refuse before the `.draft-state` drop step.** A clean-tree precondition, so the destructive reset can never see WIP, with `make reject` as the named escape hatch. Cost: it refuses the legitimate S2 state, forcing the operator to stash the draft's own uncommitted diff before confirming.

**Option B - rescue the worktree, then proceed.** Cost: it changes what the savepoint means and needs a container for the rescue; it is the richer option and the larger one.

**Option C - keep the reset and only fix the message.** Cost: the operator's work is still destroyed by a command they expected to succeed.

### Option area 7 - the shape of the document series

**Option A - one note per capability branch**, each settling into its own ADR, each indexed from a line in `system_overview.md`'s Core Invariants. This note is the diff branch's.

**Option B - one note for every branch.** Cost: the diff surface alone carries forty findings; the document becomes a second read-through and stops being reviewable.

## Decision

Proposed, not settled. The recommendation is option B in area 1, option C in area 2, option A in area 3, option B in area 4, option C in area 5, option A in area 6 with option B recorded as the follow-up, and option A in area 7.

1. Each diff workflow declares its incoming states in a header `INVARIANT` block in `prune.sh`'s form: the states, which are legitimate inputs, and what the workflow does with each.
2. `reject` becomes refuse-unless-acknowledged. The warning names the bundle as the recovery source for S2 and says plainly that S3 cannot be recovered, and the acknowledgement is `make reject FORCE=1` mapped to `--force`.
3. `confirm` gains a refusal before its drop step, so no failure path can destroy WIP. The message names `make reject` as the escape hatch, which is also the path where the acknowledgement applies.
4. The composition rule is stated where the commands are documented: `apply` and `draft` are alternative consumers of one bundle, not a sequence.
5. The bundle's operator-facing guarantees are stated and pinned in the same work: what a bundle always contains, what an empty artifact means, and what an export's SUCCESS verdict covers.
6. The ADR home is a new `docs/adr/diff_workflow_state_contract.md`, settled when the operator decides; `docs/adr/diff_packaging.md` keeps the artifact internals. The boundary with the sibling notes is: implementation shape in the unification note, flags and declaration in the resolver note, the dispatcher contract in the CLI-to-workflow note, and state and guarantees here.
7. Durable-doc updates when it settles: `tool_interface.md` gains a guarantees line per command, `sandbox_lifecycle.md`'s join phase gains the state contract, and `system_overview.md`'s Core Invariants gains the branch pointer.

## Consequences

What closes: rows 241, 253, and 255 get their declarations and their enforcement; 216 and 231 close with the same plumbing work, since a gate that is never forwarded is not a gate; 213, 215, 224, 250, and 252 close with the entry-point units, because a declaration that no unit drives end to end is not pinned.

What the work needs. The `reject` parse spec gains `--force`, `reject_run` gains a `FORCE` parameter, and `scripts/templates/Makefile.template`'s `reject:` stanza gains `$(if $(FORCE),--force,)` with its help comment. The warning's recovery sentence gives `--sandbox` and the record's `session_id` their first real use, which is also the honest resolution of row 219: the flag is not hollow if the workflow reads the bundle it names. Tests: on the reject side a refusal with tracked residue, a refusal with untracked residue (the fixture whose absence let bite R7 survive), the acknowledged proceed, and the clean path; on the confirm side the two WIP-loss paths.

What it forecloses. The unconditional discard stays broad, so `make reject FORCE=1` deletes untracked non-ignored files beyond the draft's own. That is a deliberate trade: the operator is told the breadth, sees the per-file removals, and has the bundle named as the recovery source. Area 5 option B is the refinement if that proves too blunt, and it is a smaller decision once the gate exists.

The risks. A declaration with no unit behind it is documentation, which is the pattern row 134 records; each declaration must carry at least one unit that fails when the behaviour changes. The `--force` spelling carries two meanings across the family, which every declaration must state. And the export verdicts named in Context are load-bearing for the recovery instruction: a bundle that reports SUCCESS when it failed makes the warning's promise false, so those verdicts belong to the same contract even though their code lives in the pipeline.

Out of scope, with the series in mind: how the pipeline is implemented, the declaration and parser surface, the dispatcher contract, and the other capability branches. The session registry and container correspondence, the session execution lifecycle including dry-run, the persisted record formats, host setup and onboarding, and provider context delivery each carry an invariant surface of their own and take their own note in this series.

Evidence and disposition live in [`20260924-design-active-test_suite_readthrough.md`](20260924-design-active-test_suite_readthrough.md): rows 241, 253, and 255 (the state surface), 216 and 231 (its coverage), 213 through 252 (the entry-point and guard coverage of the four workflows), 57 through 71 (the pipeline's verdicts), and 137 through 151 (the form's source).
