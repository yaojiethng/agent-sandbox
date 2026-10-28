---
date: 2026-10-27
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Documentation
status: Closed
---

# Handover - the project documentation convention, narrowed and gated

## Objective

Make the convention that governs `docs/` say only what `docs/` needs, hold one readable standard for the code block inside a document, and put a gate under that standard so a copied block announces its source.

## Scope

Four moves on one subject, in two commits: the `docs` convention renamed to `project-documentation` and narrowed to `docs/` alone, its body trimmed to the rules it states, the code-snippet standard added as a reference, and a gate plus a baseline holding the blocks that were already there.

Out of scope, and filed: the supersession rule, which needs the operator's reading of the sentence before it lands, and the three remaining files in `.agents/audits/`, which `surface-area-report.md` disposes of in its own unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The convention's name names its subject | `docs` collided four ways: a folder, the act of writing, the commit type `docs:`, and the convention itself. `project-documentation` excludes work records and the roadmap by construction | Agent [x] |
| The convention covers `docs/` and nothing else | `## Folder tree` cedes `devlog/` to `work-log`, the roadmap and changelog to `task-list`, ADR entry structure to `decision-records` | Agent [x] |
| The body states rules, not their reasons | 78 lines to 66, with the status header template ceded to `work-log` and six explanations and one paragraph of history removed | Agent [x] |
| A negated rule is stated as the target it asks for | `## Structure for grep navigation`, rewritten on operator direction: the heading to give, rather than the fault of not giving it | Agent [x] |
| The code-snippet standard exists as one reference | `.agents/skills/project-documentation/references/code-snippets.md`, carrying the four patterns verbatim, the stopgap this repository holds, the three markers and the gate's findings | Agent [x] |
| The standard is enforced where it can be | `scripts/check_code_snippets.sh` and `scripts/lint/code-snippets.mjs`, the fifteenth gate: 68 blocks read, `STALE`, `NOSOURCE`, `UNDECLARED`, `UNKNOWN-KIND`, `PRUNABLE` | Agent [x] |
| Today's tree is grandfathered rather than relabelled | `scripts/lint/code-snippets.baseline` holds the 68 blocks that predate the gate; a block added from here declares itself | Agent [x] |
| The gate has behavioural tests | `tests/test_code_snippets.sh`, 12 tests | Agent [x] |
| Gates and suite | `bash scripts/lint.sh` clean across 15 gates; `bash scripts/run_tests.sh` 1349 passed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `docs` becomes `project-documentation` | One word carried four meanings, and the folder it governed was the smallest of them | this record, and the convention's description |
| `devlog/` is not this convention's | The work record has its own convention, which states the record's status line and its redirect. A convention that governs two folders states the same rule in two places | `project-documentation` `## Folder tree` |
| The status header template leaves the convention | It is a record's shape, and a reference document carries no status line at all, so the template taught a form no document under `docs/` uses | `work-log` owns it |
| The code-snippet standard is a reference, not a section | Four patterns, three markers and five findings do not belong in the convention's body: the body names the standard and the reference states it | `## Drafting`, and the reference |
| The stopgap is derivation, not detection | No extraction, execution or generation is built here, so the honest position is pattern 1 reached by hand. What the gate can do is hold a block that claims a source to it, and refuse a new block that claims nothing | `references/code-snippets.md` `## The stopgap this repository holds` |
| The baseline grandfathers rather than relabels | Marking 68 existing blocks from memory would have written 68 guesses into the tree as provenance. A hash baseline states the truth: these blocks have no declared source yet, and the gate holds the next one to a different bar | `scripts/lint/code-snippets.baseline` header |
| `docs/adr/archive/` is not read | A record describes the system as it stood when the record was taken, so holding one to today's source would correct the record | the gate's header |

## Decisions pending

None.

## Findings

- **The iterated workflow was not followed at the start of this unit.** Two commits landed on the branch before an iteration handover was opened, which inverts the protocol's handover-first rule. The correction is this record, written after the work, so the unit is traceable rather than orphaned; the next unit opens its handover before its first edit.
- **A negation was doing the work of an instruction.** "A document that must be read whole to extract one fact is structured wrong" put the fault in front of the agent on every read and left the fix implicit, which is the failure `writing-for-agents` names for steering by prohibition. The positive form costs two words less.
- **The code-example rule asked for something nothing checks.** "Every code block, variable name, path and function signature matches the implementation as built" is a completeness bar with no detector, and three of the six findings from the `reference-staleness` trial were exactly its violation. The rule now names a source and a marker, and the gate reads them.
- **A path-resolution gate over code spans is not worth building.** Measured before rejecting it: 594 code spans under `docs/` name something path-shaped and 184 do not resolve, but most of those are container-internal paths, folder fragments written from another root, or archived records naming paths that were real. A heuristic gate would open with 127 findings in the shipped docs alone and be switched off within the week.
- **One test file was silently green against a broken fixture path.** The first run of `tests/test_code_snippets.sh` reported 2 passed because `new_root` wrote into an empty variable, and an empty tree is a clean tree. Both were made to fail loudly by giving `new_root` a real parent, but the shape is worth keeping: a test whose fixture never lands passes.

## Completed

- [x] `refactor: rename the docs convention` -- 29 files, two directories, three near-misses reverted (frozen eval fixtures, the commit type `docs`, `measure_sessions.mjs`).
- [x] `docs: trim the project documentation convention` -- 78 lines to 66, the status template and six explanations out.
- [x] The positive rewrite of the section rule, and the redundant sentence beside it removed.
- [x] The code-snippet reference, the gate, the baseline and the twelve tests.
- [x] The `## Drafting` rule retargeted from a completeness bar to a source the reader can open.
