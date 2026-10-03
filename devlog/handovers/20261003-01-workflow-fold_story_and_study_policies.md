---
date: 2026-10-03
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - Fold the story and study policies into the discussion policy

## Objective

Fold `story_policy.md` and `study_policy.md` into `discussion_policy.md`, so one document owns the section order and status of all four discussion types, and add the section-order-template rule to `documentation_policy.md`.

## Scope

The fold closes the last open row of the deconfliction campaign: the four `point` verdicts neither map could reach. Their home was the two standalone type policies, which restated rules `discussion_policy.md` and `documentation_policy.md` already own.

| In | Out |
|---|---|
| Fold story and study into `discussion_policy.md` | Sweeping the 35 existing story and study Status lines, grandfathered as historical |
| One status vocabulary, owned by `discussion_policy.md` | The four links to the deleted files inside historical discussion records, whose tree is exempt from `record-links` |
| Convert all four type sections to inline-purpose skeletons | Fixing the `handover_policy.md` format drift, which is filed |
| Add the section-order-template rule to `documentation_policy.md` | Any change to the four type names or their closing rules beyond section order |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `discussion_policy.md` is the only document that states a discussion type's section order and status | `ls docs/operations/story_policy.md docs/operations/study_policy.md` fails, and each of the four `###` type sections carries a fenced `markdown` block | Agent [x] -- both paths absent; four blocks present |
| No type-specific status vocabulary survives | `grep -rn "Investigation in progress" docs/operations/` returns nothing, and `discussion_policy.md` carries the only status table | Agent [x] -- no hits; one status table |
| `documentation_policy.md` states the section-order-template rule | `grep -n "Section-order templates" docs/operations/documentation_policy.md` | Agent [x] -- one hit |
| No live link to the deleted files remains outside historical records and ADRs | `grep -rn "story_policy\|study_policy" docs/operations/ docs/concepts/` returns nothing | Agent [x] -- no hits |

`make lint` clean and the test suite pass are preconditions, verified before close, not criteria.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/discussion_policy.md`](../../docs/operations/discussion_policy.md) | the fold target; owns all four type sections and the status table |
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | gains the section-order-template rule; its correction table now covers discussion records |
| [`docs/operations/story_policy.md`](../../docs/operations/story_policy.md) | deleted |
| [`docs/operations/study_policy.md`](../../docs/operations/study_policy.md) | deleted |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | inbound link repointed |
| [`docs/concepts/agent_workflow.md`](../../docs/concepts/agent_workflow.md) | policy-map rows merged |
| [`docs/concepts/documentation_taxonomy.md`](../../docs/concepts/documentation_taxonomy.md) | inbound link repointed |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | write-back for the four-point-verdicts row, and a new row for the format drift |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fold the two policies into `discussion_policy.md` rather than keep separate files | one owner for the status rule; design and report already live there | `discussion_policy.md` |
| Inline-purpose skeletons over section tables | the block is the template and the order is unambiguous | `documentation_policy.md` `### Section-order templates` |
| Convert all four types in one pass | a mixed shape would recreate the asymmetry the fold removes | `discussion_policy.md` |
| Grandfather the existing story and study Status lines | 35 records; a closed record is corrected only at operator direction | this handover |
| Leave the four historical discussion-record links in place | the record trees are exempt from `record-links` | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `handover_policy.md` `## Format` specifies `# Agent Handover` with bold fields (`**Date:**`, `**Milestone:**`), while handovers `20261002-20` through `-28` use YAML frontmatter (`date:`, `milestone:`). No gate checks handover format. This handover follows current practice; the policy is stale. | contradiction | filed: roadmap.md -- *Handover format drift* |
| Four discussion records link to the deleted policies (`20260506-story-*`, `20260506-study-*`). The record trees are exempt from `record-links`, so the links are historical, not live. | gap | left as historical, recorded here |
| The fold removes the home of the four `point` verdicts; roadmap row 109 no longer has a live rule to point. | analysis | recorded in this handover |

## Completed

| File | Change |
|---|---|
| `docs/operations/discussion_policy.md` | added the status-ownership sentence; replaced `## Document types` with four inline-purpose skeletons |
| `docs/operations/documentation_policy.md` | added `### Section-order templates`; the correction table now covers discussion records |
| `docs/operations/story_policy.md` | deleted -- folded into `discussion_policy.md` |
| `docs/operations/study_policy.md` | deleted -- folded into `discussion_policy.md` |
| `docs/operations/iteration_policy.md` | repointed the story link at `discussion_policy.md` |
| `docs/concepts/agent_workflow.md` | merged the story and study lifecycle rows into one discussion-record-types row |
| `docs/concepts/documentation_taxonomy.md` | dropped the two policy links from the discussion row |
