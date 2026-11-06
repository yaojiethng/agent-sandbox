---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Housekeeping
status: Closed
---

# Handover - rewrite the series without the census commit

## Objective

Drop `25ada818` from the series and rebuild the ten later commits on the pre-census base, so the branch carries no commit whose content a later commit removes.

## Scope

One history rewrite. The tree is held fixed: the census commit carried no content outside `devlog/` and `.agents/drafts/`, so the rewrite changes the record narration and nothing a reader acts on. The backup ref `pre-squash-20261020` holds the pre-rewrite tip and stays until the operator releases the package.

Out of scope, with reason: rewriting the ten replayed records so each is true at its own commit. The replay carries the records as they were written, and the tip's record state is restored from the backup ref; the deviation and its cost are recorded below.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The series starts at `824299e5` and carries no census commit | `git log --oneline 824299e5..HEAD` lists ten commits, none of them `docs: run the neutral principle census` | Agent [x] |
| No non-record content changed | `git diff --stat pre-squash-20261020 HEAD -- . ':!devlog' ':!.agents'` prints nothing | Agent [x] |
| The tip tree equals the pre-rewrite tree, apart from this record and the id correction | `git diff --stat pre-squash-20261020 HEAD` names only `20261020-02` and `20261020-07` | Agent [x] |
| Every record that cited a rewritten id now cites the new one | `grep -rn` for the ten old ids finds them only inside a correction tag or the map below | Agent [x] |
| The gates are clean on the rewritten series | `bash scripts/lint.sh`, `bash scripts/check_handover_format.sh`, `bash scripts/run_tests.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read this record's `## Decisions` against the tree | Operator [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The census commit is dropped, not collapsed into its successor | it carried no non-record content, so collapsing would move the same empty commit rather than remove it | this record |
| The ten later commits replay with `-X theirs` on record paths, and the tip's records are restored from the backup ref | every conflict was a record path, and the tip's record state is the one that was reviewed | this record |
| Intermediate records are the ones written at the time, so a reader of `git log -p` sees records citing a census commit the series no longer contains | rewriting ten records to be true at their commits is a second pass, and the tree they describe is unchanged | this record, `## Findings` |
| The old-to-new map is recorded here | a rewrite that changes ids and does not record the map leaves citations unresolvable | this record |
| The backup ref is retained | the rewrite is unrecoverable in practice once it is gone | `pre-squash-20261020` |

Old to new:

| Old | New |
|---|---|
| `e802f13c` | `bf4aa6b9` |
| `b40dd153` | `0f0e1075` |
| `bf4698ab` | `c5e5b80e` |
| `ed5a1827` | `32a5b33d` |
| `b3646e20` | `778bed8d` |
| `6cb0af6e` | `47f3ebf6` |
| `c61fe1ab` | `fa3213ca` |
| `5da06eac` | `ce39a72a` |
| `44711900` | `92516a26` |
| `ae69605a` | `6e5d34da` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The replay leaves ten records that cite a census commit the series no longer has, which is a deliberate deviation from "every record true at its commit" | process | a reader of `git log -p` meets a citation that does not resolve; the alternative is a second rewriting pass over ten records | this record |
| One closed record cited a rewritten id, and the class is general: any rewrite of a range invalidates the ids its records quote | process | the map above plus one correction tag; the check belongs in the rewrite, not in the reader's trust | `devlog/handovers/20261020-02` |
| The census commit held no non-record content at all | result | the whole branch after it was record and prompt work, so the rewrite could not change behaviour even in principle | this record |

## Completed

| File | Change |
|---|---|
| the series `824299e5..HEAD` | `25ada818` dropped; ten commits replayed and rewritten with new ids |
| `devlog/discussions/20261018-study-settled-numbering_scheme_census.md` | settled name and status restored |
| `devlog/discussions/20261019-design-settled-sentence_structure_principle.md` | settled name and status restored |
| `devlog/discussions/20261019-report-settled-sentence_structure_evidence.md` | settled name and status restored |
| `devlog/discussions/20261019-design-settled-neutral_principle_census.md` | [CORRECTION -- 2026-10-20] The design was deleted with the dead census plans in `20261020-06`, not restored. The row named the wrong file: the restored item is the design's blocker correction, and the file no longer exists. |
| `devlog/handovers/archive/20261019-05-design-sentence_structure_principle.md` | `[CORRECTION]` tag restored |
| `devlog/handovers/archive/20261019-07-plan-neutral_census_and_codemode.md` | `[CORRECTION]` tag restored |
| `devlog/handovers/archive/20261019-10-workflow-file_attach_as_you_read.md` | `[CORRECTION]` tag restored |
| `.agents/drafts/communication-domain-taxonomy-run.md` | link paths restored |
| `devlog/handovers/20261020-02-workflow-gate_owns_the_close_decisions.md` | the rewritten id, and its correction tag |
| `devlog/handovers/20261020-07-chore-rewrite_the_series_without_the_census.md` | this record |
