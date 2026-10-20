---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the approval-writes-the-artifact principle

## Objective

Bring the rule that this session broke into the repository as a principle, link it from both `AGENTS.md` copies, and check it against the five skills landed before it.

## Scope

The new skill `principle-approval-writes-the-artifact`, its two copies, and one paragraph in each `AGENTS.md`.

Out of scope: the pre-existing divergence between the two `AGENTS.md` copies, which is recorded under `## Findings` rather than repaired here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both skill copies are byte-identical | `diff -q` over the two `SKILL.md` files | Agent [x] |
| Both `AGENTS.md` copies carry the same new paragraph | `grep -c approval-writes-the-artifact` returns 1 in each | Agent [x] |
| The skill passes the five landed principles | the check is recorded under `## Findings`, with four fixes applied before approval | Agent [x] |
| The skill states its own assumption and its gap | read it: version control first, and the case without it | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule names the artifact's home file rather than a file that will ship | shipping implies delivery, and the operator's point is that writing a file and delivering it are separate acts | the skill, opening line |
| Writing is framed by what can be undone, not by delivery steps | push and merge are operator-directed, so a general rule must not depend on them; the reversible act versus the conversation that cannot be resumed is the distinction that holds everywhere | the skill, `## The pattern` |
| No parked copies and no staging documents | the operator's ruling: the drafts root collects committed files, and git already holds the undo. Churn is the accepted cost | the skill, `## The pattern` |
| The rule is filed in the repository, not only installed | the four principles it sums live only in the installed tree, which an image rebuild loses | both copies, and this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Checked against `communication-principle-hand-off-by-naming-the-boundary`: not applicable, since a rule skill has no steps that hand off | result | one of five checks found nothing, which is the right answer rather than a forced one | this record |
| Checked against `principle-own-the-scope-you-declare`: the cost of churn was justified by a green gate, which is another rule's stage | result | that clause was cut, leaving the cost stated | the skill |
| Checked against `principle-say-what-done-looks-like`: the test was a memory check | result | the test now points at the file and the diff that put the artifact in it | the skill |
| Checked against `principle-effective-skill-routing`: the description named one trigger situation twice | result | the trigger sentence names situations with no state word | the skill's description |
| Checked against `principle-match-precision-to-stakes`: the cheapness claim preceded the assumption that makes it true, and the case without version control was unnamed | result | the assumption is stated first, and the gap is named | the skill |
| The two `AGENTS.md` copies disagree in the subagent-dispatch sections, and the installed copy is the stale one | record defect, pre-existing | a reader of the installed layer follows advice the repository has replaced, so the running context and the shipped config differ | a new roadmap row |
| Every commit in this milestone needs a handover, and a one-file change follows the same rule | result | the rule this iteration files applies to the commit that files it | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-approval-writes-the-artifact/SKILL.md` | new: the pattern, what it does not cover, why, and the test |
| `~/.pi/agent/skills/principle-approval-writes-the-artifact/SKILL.md` | the installed copy, byte-identical |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | one paragraph in `## Write Discipline`, naming the skill |
| `~/.pi/agent/AGENTS.md` | the same paragraph |
| `devlog/handovers/20261020-19-workflow-approval_writes_artifact_principle.md` | this record |
