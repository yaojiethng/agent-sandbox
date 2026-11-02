---
description: "Handoff - name the constraint kinds the gates should express, and consolidate the instruction-surface checks onto them: seven kinds across eighteen gate scripts, each kind proved load-bearing by a mutation row, with the conformance gates left alone."
argument-hint: "[scope note, e.g. one kind at a time, or a consolidation order - optional]"
---

> $ARGUMENTS

# Handoff - name the constraint kinds the gates should express

## What the next session is for

The gate list grew one script per injury. Eighteen scripts now run, and a survey of them shows they express seven kinds of constraint, not eighteen: the same judgement is restated over a different subject each time it bit. The task is to name the seven kinds, decide which of them the gates should express, and consolidate the instruction-surface checks onto that set so that adding a subject adds a row rather than a script.

This belongs to the gate-upkeep work, not to the instruction-pipeline work: retiring or replacing a gate is the procedure that milestone owns, and its own statement that "the gates themselves are not in question here" is about scope, not about this survey. Delete this file when the task lands.

## Where things stand

`scripts/lint.sh` line 30 registers eighteen gates. The list is a map of past injuries: each script was written at the seam where two statements of one fact disagreed, and nothing names the class of fact. Seven kinds account for all eighteen.

| Kind | What it asserts | Instances today |
|---|---|---|
| **Partition** | every item has exactly one owner, and none has two | `check_instruction_surfaces.sh`, the collision half of `check_skill_map.sh` |
| **Closure** | every reference lands inside a zone its own source may reach | none. `check_skill_map.sh` catches a name collision and a forbidden cross-layer link over the skill tree only; a shipped document naming a project-only path passes, and the row that owns that gap is filed under M3.1.2 as "A project-path citation check over the shipped documents" |
| **Resolution** | every declared path, record or source exists | `check_skill_sources.sh`, `check_skill_packages.sh`, `check_reach.sh` |
| **Agreement** | two statements of one fact agree | `check_container_layout.sh` (manifest against dockerfile, entrypoint and settings), and the taxonomy side of `check_reach.sh` |
| **Conformance** | a file matches its type's shape | `check_document_shape.sh`, `check_markdown.sh`, `check_numbering.sh`, `check_handover_format.sh`, `check_record_names.sh`, `check_doc_wrap_legacy.sh` |
| **Liveness** | every gate is load-bearing | `scripts/mutations_run.sh`, behind `MUTATION=1`, whose own corpus row is open under M3.1.2 |
| **Non-vacuity** | every declared zone, row or source is exercised by something | none. A declared reach zone no file references is invisible today |

The mutation tier already returns `PROVEN`, `SURVIVED` or `NO-OP` per row, so the instrument for proving a gate load-bearing exists and does not need building. The wall-clock figure the other row needs is already recorded: about 30 seconds before the parallel-shellcheck change, about 5 seconds now.

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Seven kinds, not eighteen scripts | a kind is named once, and a subject is one row through the kind's checker rather than a new script |
| R2 | One check per kind, co-located with the subject it reads | the checkpoint holds its own evidence; a central engine that reaches into every tree is the shape this rejects |
| R3 | Every kind is proved load-bearing | one mutation row per kind, and a kind no mutant can kill is a finding about the kind |
| R4 | The declaration is exercised, not asserted | because a closure check runs over every file in a zone, a zone nothing references is a finding. This is the property that stops a declaration only growing |
| R5 | Conformance is not consolidated | the shape gates are out of this handoff's scope: they serve different readers, they are cheap, and merging them moves their failures further from their subjects |
| R6 | A gate states what it cannot decide | placement is judgement and no gate settles it; a kind that would need to read intent says so and stops at the reference boundary |
| R7 | The set has a number | the count of files that may state a layer destination is the metric: one, plus the mechanisms that cannot derive their statement, each of which is gated |

## What this handoff does not own

- **The reach model's content.** Which scopes exist, what each may reach, and where the declaration lives belong to the instruction-pipeline work; this handoff consumes its reference edges as input.
- **Gate cost and the add/amend/retire procedure.** Both are already rows under this milestone.
- **The conformance gates.** Named here only to mark the boundary.

## Open questions

- Whether the model checker is one executable over the seven kinds or one per kind. R2 argues for one per kind, co-located; the counter-argument is that partition, closure and non-vacuity read the same declaration and splitting them re-reads it three times.
- Which of the eighteen are retired outright. The closure kind may absorb two of them, the agreement kind one.
- The declared bound. Enumeration is the argument for keeping the model small: scopes, references, zones. A model that starts describing file contents has become the thing it was meant to check.
