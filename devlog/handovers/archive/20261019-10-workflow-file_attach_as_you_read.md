---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the attach-as-you-read principle

## Objective

File the sentence-structure principle `communication-principle-attach-as-you-read`, and point the three `documentation_policy.md` lines at it.

## Scope

The filing half of the M3.3.4 plan row **Plan the `communication` standard into principle specs**, and the first entry of the row **The neutral census and the communication-surface filing**. It lands one principle, the one proven by [`20261019-design-settled-sentence_structure_principle.md`](../../discussions/20261019-design-settled-sentence_structure_principle.md) with its two-reader evidence.

Landed ahead of the four-arm neutral census on direct operator direction. The two blind readers on two models, which reproduced the failure on 17 of 18 corpus sentences and recovered the intended meaning on 6 of 6 control sentences, are this principle's census. The four-arm census remains for the other principles.

Out of scope: the other proposed principles, the `prompt-authoring-conventions.md` filing, and the `skill-scaffolder` duplicate.

[CORRECTION -- 2026-10-19: the discussion path now carries its settled name after the status correction in handover 20261019-11.]

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill exists in the repository source and the installed copy, identical | `diff -q` the two `SKILL.md` files | Agent [x] |
| The skill follows the exemplar's shape | read the skill; one sentence, a pattern table, a why, a test | Operator [ ] |
| The three lines resolve to one pointer | read `docs/policies/documentation_policy.md` `### Simplified Technical English` | Agent [x] |
| No second statement of the judgement survives | `grep -n "Active voice\|thin subjects\|defined noun phrase" docs/policies/documentation_policy.md` returns only the pointer | Agent [x] |
| The ledger is clean | `bash scripts/check_norm_ownership.sh --check`, 164 rows | Agent [x] |
| The gates and the suite are clean | `bash scripts/check_frontmatter.sh`, `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The principle lands ahead of the four-arm census | the operator directed it, and the study's two blind readers on two models already separate the failure from the control | this record |
| One combined pointer replaces the three lines | the three were one judgement; three identical pointers would restate the duplication the principle removes | `documentation_policy.md` |
| The principle is model-visible | a writer reaches for a judgement mid-draft, so a hidden skill could not steer the draft | the skill has no `disable-model-invocation` |
| The skill keeps a boundary paragraph | a passive, end-weight, a garden path and a verbatim quote each override the default, so the principle needs its limit stated | the skill, `**Where another rule wins.**` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The design's pattern table carries five moves; the three policy lines map to three of them, and two are general instances with no policy line to move. | result | the skill states more than the policy held, and no two-home overlap results |
| The `documentation_policy.md` section lost three judgement rows and gained one pointer, so the ledger moved from 80 to 77 judgement and 44 to 45 model. | result | the judgement now has one home |
| The four-arm census is still the method for the remaining principles. | scope | this filing does not displace it |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | new principle skill |
| `$AGENT_HOME/agent/skills/communication-principle-attach-as-you-read/SKILL.md` | installed copy, identical |
| `docs/policies/documentation_policy.md` | the three sentence-structure lines become one pointer |
| `scripts/lint/norm-ownership.tsv` | regenerated; 164 rows, 77 judgement, 45 model |
| `devlog/roadmap.md` | the plan row and the census row note the landing |
