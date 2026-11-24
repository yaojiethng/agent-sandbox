---
date: 2026-11-24
milestone: T4 - Library Migrations
type: Plan
status: Closed
---

# Handover - One question for the sandbox's invocation definition

## Objective

Turn the T4 make-evaluation row into an evaluation an iteration can run: one question, four evidence-backed criteria, and an open candidate class with Nix recorded.

## Scope

A plan session, not an iteration. This record and two roadmap edits are the whole change.

The row asked whether make still earns its place and named no substitute, so an evaluation had nothing to weigh and a candidate's value had nowhere to land. Nix arrived with four properties, one of which -- that it subsumes the install files -- is a provisioning claim that a make-survival question cannot weigh. Hence one question, "one definition per sandbox's invocations, not a second idiom beside the CLI", with make as incumbent, the direct CLI as the floor, and an open class defined by the criteria.

The evidence for the row's opening claim comes from the tree and the archive: `scripts/templates/Makefile.template` carries 13 targets, the root `Makefile` 8, and handover [`20260919-15`](../archive/20260919-15-feature-make_vs_cli_help_and_error_hint_consistency.md) records the seven `usage()` blocks that had to learn the make form plus its regression test. The platform criterion cites the hosts [`host_requirements.md`](../../../docs/development/host_requirements.md) already names.

Out of scope, with reasons: the flake, a lock file, any `install.sh` change (the evaluation's outcome owns them), and the removal decision, which the row keeps as its own follow-up.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row states one question, not two. | read the row's bold title and its opening clause | Agent [x] |
| Each of the four criteria carries the artefact that evidences it. | the four parentheticals in the row | Agent [x] |
| The candidate class is open, with Nix recorded as a candidate and no verdict. | `grep -n 'Candidates form an open class' devlog/roadmap.md` | Agent [x] |
| No claim in the row lacks a source in the tree or the archive. | each number and link in the row resolves: 13 targets, 8 targets, seven `usage()` blocks, `20260919-15`, `host_requirements.md` | Agent [x] |
| The work splits by phase into subtasks with one artefact each. | the three nested rows | Agent [x] |
| The `Self-contained install` row no longer asserts independence from this evaluation. | `grep -n 'depends on that evaluation' devlog/roadmap.md` | Agent [x] |
| The markdown gates pass. | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Reframe to one question about what defines a sandbox's invocations. | The provisioning property is only weighable against make's cost in one decision; a make-survival question leaves it outside the row. | This record; the roadmap row |
| Four criteria, each with its evidencing artefact. | "Earns its place" becomes a check a reviewer can make, and the candidate's properties become weighable rather than asserted. | This record; the roadmap row |
| Candidate class open, Nix named, make incumbent, CLI the floor. | The criteria define membership, so an unlisted substitute is judged by the same four checks rather than excluded by list. | This record |
| Each candidate property names its settling artefact and carries no verdict. | The properties have no evidence in the repository yet; only the incumbent's cost does. | This record; the roadmap row |
| A provenance mark only where the repository cannot produce the evidence. | WSL coverage rests on an operator's word; a lock file is its own proof, so marking it would weaken it. | This record; the roadmap row |
| Split by phase, not by criterion or candidate. | The criteria are only decidable side by side, so per-criterion rows yield four partial answers; an open class makes per-candidate rows unbounded. | This record; the three subtasks |
| Correct the `Self-contained install` row's independence clause, and leave the `AGENTS.md` target rule to be reported. | Provisioning is criterion three, so the contradiction is in the file now; the target rule keeps its subject until an outcome removes make. | This record; the install row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's question excluded the one property that motivated the request. | design | a substitute's provisioning and pinning value could not be weighed against the incumbent's cost | the reframed row |
| The install row asserted independence from the evaluation whose third criterion is provisioning. | record | two rows contradicted each other in one file | corrected in place |
| Two hand-kept target tables (13 and 8) and seven `usage()` blocks are the measurable cost of the second idiom. | measurement | the evaluation starts from counts, not from an impression | the row's opening clause; subtask 1 |
| `AGENTS.md` reserves Makefile targets to the operator, so removing make touches the instruction surface and not only the scripts. | record | the outcome carries an instruction-surface consequence the evaluation must report | the row |
| The operator reverted a nix flake handover written before this session, so no Nix artifact exists in the tree. | record | the row records a candidate, not a dependency | this record |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | the T4 make row reframed as one question with four criteria and three phase subtasks; the install row's independence clause corrected |
| `devlog/handovers/T4/20261124-04-plan-invocation_definition.md` | this record |
