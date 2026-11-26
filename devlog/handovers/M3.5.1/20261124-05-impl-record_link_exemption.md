---
date: 2026-11-24
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - the record trees' link exemption

## Objective

Decide how a handover's dead relative link is held: re-path the corpus, or name why a historical record is exempt and hold the record that is still active.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| An Active record with a dead relative link fails, naming the target. | `bash tests/test_linking.sh`, Active case | Accepted |
| A closed record with a dead link stays exempt. | `bash tests/test_linking.sh`, closed case | Accepted |
| The live tree passes under the narrowed exemption. | `bash scripts/lint.sh` | Accepted |
| The rule and `work-log` state why a historical record is exempt. | `grep` both | Accepted |
| Every decision this iteration recorded is realized in the files. | diff against the Decisions table | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Name the exemption and hold the Active record; leave the closed corpus as written. | 323 of the 1,064 dead links name a target the tree no longer holds, so a corpus-wide repair forces deleting or inventing content in closed records. | This record |
| The check lives in `linking.mjs`, not a second link walker in the format gate. | One link implementation; the rule already resolves relative targets against the file's directory. | This record |
| The exemption is the record's `status`, not a date window. | A record's state says whether a reader follows its links now, without a second cutover date. | This record |
| The closed corpus is not rewritten. | A record is a snapshot of the tree at the time it was written; its pointers are part of the record. | This record |
| The layout's archives are exempt whatever status a frozen record carries. | An archive is history; a frozen record can still read `Active`. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| 1,064 dead relative links across 164 live handover files; 741 resolve by adding one `../` or reading the target from the repo root, 323 name a path the tree no longer holds. | defect | The row's own end condition is unsatisfiable for the 323 without a content change. | Resolved: route B, this record's Decisions |
| `devlog/handovers/M3.4/` holds 23 records, every one naming `M3.4.2 - The resolution model and record primitives`, a Complete milestone; the folder reads `M3.4`. The folder-field gate fails on all 23, so the release gate is red. | defect | Outside this iteration's surface (links); blocks the tree-wide lint. | Resolved: folder renamed to `M3.4.2/`, roadmap link re-pathed |
