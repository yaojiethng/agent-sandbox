---
reader: [agent]
---

# Draft Branch Statechart

This is the model behind the 2026-11-08 entry in `docs/adr/diff_packaging.md`. It decides two things: whether an exported package can be put on a branch, and whether a draft can be accepted without losing its metadata.

Two axes carry the package. **Forkable** means the host can put the package's commits on a branch. **Mergeable** means a clean rebase or fast-forward to the target can finish. They are not independent: mergeable implies forkable, and forkable does not imply mergeable.

## The package

| Form | After the agent amends | After the host rewrites | Merge guarantee |
|---|---|---|---|
| Diff from `init_sha` | not forkable | not forkable | none |
| Diff from the branch point | forkable, if the consumer forks there | may become not forkable | decided by the rebase |
| Bundle | forkable | forkable | not guaranteed |

<!-- snippet: illustrative -->
```mermaid
---
title: "Export package: forkable and mergeable"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: unpackaged
    lg1: packaged
    lg2: drafted
    lg3: draft_failed
    lg4: confirm_failed
    lg5: confirmed
    lg6: rejected
    lg7: Breaks DiffBranchAlwaysForkable
    lg8: Breaks BundleAlwaysMergeable or DiffBranchAfterAmendDraftsAtHead or DiffInitAfterAmendForkable in some cases
    lg9: Path to the BundleAlwaysMergeable or DiffBranchAfterAmendDraftsAtHead or DiffBranchAlwaysForkable or DiffInitAfterAmendForkable bug
  }
  class lg0 tan
  class lg1 blue
  class lg2 purple
  class lg3 orange
  class lg4 orange
  class lg5 teal
  class lg6 pink
  class lg7 breaks
  class lg8 mayBreak
  class lg9 bugPath
  s0: No package
  s1: Bundle: forkable
  s2: Diff(branch): forkable
  s3: Diff(init): forkable
  s4: Drafted: mergeable
  s5: Diff(branch): not forkable
  s6: Diff(init): not forkable
  s7: Rejected
  s8: Confirmed
  s9: Diff(branch): draft failed, package forkable
  s10: Diff(init): draft failed, package forkable
  s11: Drafted: not mergeable
  s12: Confirm conflicted
  [*] --> s0
  s0 --> s1: you export Bundle
  s0 --> s2: you export Diff(branch)
  s0 --> s3: you export Diff(init)
  s0 --> s0: the agent amends past history
  s1 --> s4: you draft at HEAD
  s1 --> s7: you reject
  s2 --> s4: you draft at the branch point or you draft at HEAD
  s2 --> s5: the host rewrites history
  s2 --> s7: you reject
  s3 --> s4: you draft at the branch point or you draft at HEAD
  s3 --> s6: the host rewrites history
  s3 --> s7: you reject
  s0 --> s6: you export Diff(init)
  s4 --> s8: you confirm
  s4 --> s11: the rebase conflicts
  s4 --> s7: you reject
  s5 --> s7: you reject
  s2 --> s9: you draft at HEAD [the series came from another base]
  s6 --> s7: you reject
  s3 --> s10: you draft at HEAD [the series came from another base]
  s9 --> s7: you reject
  s10 --> s7: you reject
  s11 --> s4: you resolve the conflict by hand
  s11 --> s12: you confirm [the rebase conflicts]
  s11 --> s7: you reject
  s12 --> s7: you reject
  classDef breaks fill:#ffecee,stroke:#e72e3b,stroke-width:2.5px,color:#cd2834
  classDef mayBreak fill:#fff3e6,stroke:#e8730c,stroke-width:2.5px,color:#b85a06
  class s0 tan
  class s0 bugPath
  class s1 blue
  class s1 bugPath
  class s2 blue
  class s2 bugPath
  class s3 blue
  class s4 purple
  class s4 bugPath
  class s5 blue
  class s5 breaks
  class s5 bugPath
  class s6 blue
  class s6 mayBreak
  class s6 bugPath
  class s7 pink
  class s8 teal
  class s9 orange
  class s9 mayBreak
  class s9 bugPath
  class s10 orange
  class s11 purple
  class s11 mayBreak
  class s11 bugPath
  class s12 orange
```

The rules that hold are `MergeableRequiresForkable`, `BundleAlwaysForkable`, and `ForkableConflictRecoverable`. The last one is the manual-resolution assumption: a forkable draft that conflicts can always be resolved by hand into a mergeable state.

The rules that break name the cases the model is meant to expose:

| Rule | What it says | Why it breaks |
|---|---|---|
| `DiffInitAfterAmendForkable` | A diff from the recorded `init_sha` still forks after an amend. | The package base is no longer the branch point. |
| `DiffBranchAlwaysForkable` | A branch-point diff stays forkable after a host rewrite. | The host can remove the commit the package was taken at; a bundle carries it. |
| `DiffBranchAfterAmendDraftsAtHead` | A branch-point package drafts successfully after an amend. | The package is forkable, but drafting at `HEAD` uses the wrong base. |
| `BundleAlwaysMergeable` | A bundle is always mergeable. | A bundle carries the objects; it does not remove a textual conflict. |

## The draft and confirm

Without `.draft-state`, the record is branch-local config. It is present for the whole life of the branch, and it is removed only by branch deletion. There is no `Dropped .draft-state` transition.

<!-- snippet: illustrative -->
```mermaid
---
title: "Confirm without .draft-state: the record is invariant"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: drafted
    lg1: refused
    lg2: rebased
    lg3: switched
    lg4: merged
    lg5: rolled_back
    lg6: switch_failed
    lg7: merge_failed
    lg8: rejected
  }
  class lg0 blue
  class lg1 teal
  class lg2 yellow
  class lg3 yellow
  class lg4 teal
  class lg5 purple
  class lg6 orange
  class lg7 orange
  class lg8 pink
  s0: Draft ready#59; record present
  s1: Rebased#59; record present
  s2: Rejected
  s3: Rebase rolled back#59; record present
  s4: Target checked out#59; record present
  s5: Merged
  s6: Refused#59; record present
  s7: Switch failed#59; still on draft, record present
  s8: Fast-forward failed#59; draft exists, record present
  [*] --> s0
  s0 --> s1: the rebase runs
  s0 --> s2: you reject#59; the branch and record go
  s0 --> s3: the rebase runs or you confirm on a dirty tree#59; rebase refuses
  s1 --> s2: you reject#59; the branch and record go
  s1 --> s4: the target switch runs
  s0 --> s6: you confirm [precheck refuses#59; record stays]
  s1 --> s7: the target switch runs
  s3 --> s2: you reject#59; the branch and record go
  s4 --> s1: you switch back to the draft
  s4 --> s5: the fast-forward runs
  s6 --> s2: you reject#59; the branch and record go
  s7 --> s2: you reject#59; the branch and record go
  s4 --> s8: the fast-forward runs
  s8 --> s1: you switch back to the draft
  class s0 blue
  class s1 yellow
  class s2 pink
  class s3 purple
  class s4 yellow
  class s5 teal
  class s6 teal
  class s7 orange
  class s8 orange
```

The rules that hold are `RecordPresentDuringDraft`, `NoHungState`, `CanReturnToDraft`, and `NoDeadlock`. The confirm model with `.draft-state` broke `CleanDropThenFailureHangs`, `SwitchFailureAfterDropHangs`, and `MergeFailureAfterDropHangs`; each of those paths required the dropped record.

The chart hides the no-op steps that stay in one state, including `Done`, the precheck's self-loop, and the failure probes. It also assumes the config record is written before the branch, so a branch cannot exist without it.

## What the model leaves out

- The real content of a rebase conflict. A conflict is a nondeterministic step, not a merge result.
- Patch-equivalence and the commits a rebase drops.
- `uncommitted.diff` residue and the working tree outside the clean/dirty distinction.
- The exact target tip. Mergeability is decided against a target supplied at runtime, not derived from the branch point.
- Pushed draft branches. The record is local; a pushed branch does not carry it.
- The `NEW=1` route. It is a fallback surface, not a state in this model.
