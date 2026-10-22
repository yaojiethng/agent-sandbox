---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - File the correction-discipline principle

## Objective

State the judgement that governs what a correction may contain, and separate it from the rule that decides where a correction lands.

## Scope

One principle, `principle-minimal-corrections`: a correction restores the intended artifact and adds nothing beside it.

`git_policy.md` `## Amending` already decided where a correction lands, and it carried the content judgement only as an implication of its prose. This iteration splits the two. The policy keeps the routing cases, which are mechanical and answer to a session's liveness. The principle carries the content, which is a judgement and belongs where a judgement lives. The Amending section is shorter after the split than before it, which is the test the split had to pass.

Two cases replace the single clause "at the operator's direction". Case 1 grants the agent the fold for its own commit while the session is live, whichever actor raised the defect. Case 2 leaves the operator the rule once that session has ended. The clause could not separate a content direction from a landing direction, and a correction that landed as its own iteration was the result; the case split states the two as distinct decisions rather than reading one into the other.

A defect in the earlier iteration is recorded as `[A] 2026-10-18` in `devlog/AGENT_FEEDBACK.md`, naming `582af1eb` and `f82d1a0d`.

The assessment of `docs/adr/closed_record_corrections.md` is filed as an open roadmap row rather than run here. That document governs how a correction is recorded, carries six requirements, and is itself corrected by its own mechanic on its last line. The principle is the bar the assessment applies, so the row follows it.

The ADR is not left asserting a rule the tree drops. R5 stated that the agent applies a correction only at the operator's direction, which the case split replaced, so the record carries a `2026-10-18` entry that narrows R5 to a closed session and moves the content judgement to the principle. R1 to R4 and R6 stay open for the assessment.

Ruled out of scope. No decision on R1 to R4 or R6. The assessment owns them, and deciding them inside the iteration that states the bar would prejudge it. No change to the `record-correction` procedure, which the assessment may retire.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The principle states the judgement in one sentence | `principle-minimal-corrections` `SKILL.md` opening | Agent [x] |
| The principle pairs each artifact a correction adds with the one it should have been | the pattern table, six rows | Agent [x] |
| The principle carries a why and a test | `**Why.**` and `**The test.**` | Agent [x] |
| The test counts artifacts, not diff size | `**The test.**` asks how many artifacts the correction produces | Agent [x] |
| The policy routes and does not judge | `## Amending` names the two cases and points at the principle | Agent [x] |
| The policy is shorter than before the split | the closing paragraph lost its direction clause and gained two cases and a pointer | Agent [x] |
| Case 1 grants the fold without asking, for the agent's own commit in a live session | `## Amending`, case 1 | Agent [x] |
| Case 2 leaves the landing decision with the operator once the session has ended | `## Amending`, case 2 | Agent [x] |
| The repository source and the installed copy match | `diff -q` on both paths | Agent [x] |
| The defect that produced the principle is recorded with its two hashes | `[A] 2026-10-18` in `AGENT_FEEDBACK.md` | Agent [x] |
| The ADR assessment is filed and open | `devlog/roadmap.md`, `[ ]` row under M3.3.4 | Agent [x] |
| The ADR stops asserting the superseded R5 | `closed_record_corrections.md` `Current:` 2026-10-18, R5 narrowed, R1 to R4 and R6 left open | Agent [x] |
| Every gate passes | `bash scripts/lint.sh`, 10 gates | Agent [x] |
| The suite passes | `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The judgement gets its own skill and the policy keeps only routing | A judgement's only home is the principle that states it. A policy that states one violates the authority doctrine the milestone is built on, and the split shrinks the policy rather than growing it. | `git_policy.md` `## Amending`; the principle |
| The principle's subject is the artifact count, not the diff size | A one-line `[CORRECTION]` tag is light, concise and exactly scoped, and it is still a second artifact. Diff size is the weaker test, so the statement leads with the count and the scope check follows from it. | the principle's `**The test.**` |
| The two cases key on the session's liveness, not on who raised the defect | A content direction is not a landing direction. Keying on the actor left the policy unable to separate the two, which is the defect it produced. Liveness is a fact either party can check. | `git_policy.md` `## Amending` |
| The name is `principle-minimal-corrections` | It reads as a stance in the same form as `principle-subtract-before-you-add`, and the operator chose it from three candidates. | the directory name |
| The ADR assessment is a roadmap row, not part of this iteration | The principle is the bar, so filing the row beside it keeps the bar and the judgement that applies it in a known order. | `devlog/roadmap.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether R2's marker survives for a closed record | The ADR assessment | keep a marker, which is an artifact beside the corrected claim; or drop it and let the corrected claim stand alone |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A correction can be minimal in its diff and still compound in its artifacts | judgement | the principle's statement; a scope-only rule would have permitted every entry in the table |
| `closed_record_corrections.md` is the pattern it governs, applied to itself, and its own last line carries the `[CORRECTION]` tag its R2 requires | process | filed as the assessment row rather than raised as a defect, because the document's requirements are the question that row exists to answer |
| The `at the operator's direction` clause had two readers because it named one direction for two decisions | document defect | the two cases; the clause and its ambiguity are gone rather than annotated |
| The installed copy and the repository source can drift without a gate | process | verified by `diff -q` this time; no gate holds the pair, which the M3.3.3 skill-maintenance pipeline owns |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-minimal-corrections/SKILL.md` | the principle: statement, pattern table, why, test |
| `~/.pi/agent/skills/principle-minimal-corrections/SKILL.md` | the installed copy |
| `docs/policies/git_policy.md` | `## Amending` gains case 1 and case 2, drops the direction clause, and points at the principle for content |
| `devlog/AGENT_FEEDBACK.md` | `[A] 2026-10-18`, the correction that landed as a second commit, with both hashes and the compounding it caused |
| `docs/adr/closed_record_corrections.md` | `Current:` moves to 2026-10-18; new entry narrowing R5 to a closed session and moving the content judgement to the principle; R1 to R4 and R6 left to the assessment |
| `devlog/roadmap.md` | the principle row closed, the ADR assessment row open |
| `scripts/lint/norm-ownership.tsv` | regenerated |
| `devlog/handovers/archive/20261018-08-workflow-file_minimal_corrections_principle.md` | this record |
