---
date: 2026-10-19
milestone: W2 - Communication Domain Taxonomy
type: Plan
status: Closed
---

# Handover - the communication-domain milestone and run brief

## Objective

File the deep communication-domain run as a draft, and scope it as milestone W2 with its dependencies.

## Scope

A planning edit driven by the operator's 2026-10-19 scoping request. It creates one draft, one future milestone, and one summary row. It completes no M3.3.4 task.

Out of scope: running the brief, and the reduced version discussed alongside it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The run brief exists under `.agents/drafts/` | `test -f .agents/drafts/communication-domain-taxonomy-run.md` | Agent [x] |
| W2 carries an objective, dependencies, and its single task | read `devlog/roadmap_future.md` `## W2` | Agent [x] |
| The summary row links the W2 anchor and resolves | `bash scripts/lint.sh` record-links gate; grep the anchor | Agent [x] |
| The gates are clean | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| W2 owns the deep communication work, and the run brief is its single task | the operator scoped it as one milestone with one task, so the milestone is the planning home and the brief is the execution record | `roadmap_future.md` `## W2` |
| W2 depends on the eval module and M3.3.4's principle cleanup | the signalling experiment needs the eval harness, and the taxonomy needs the duplicate declarations gone first | `roadmap_future.md` `## W2` |
| The brief stays a draft under `.agents/drafts/` | an unreviewed run prompt is structurally unreachable, per `prompt-authoring-conventions.md` `## Draft status and the switch-over gate` | `.agents/drafts/communication-domain-taxonomy-run.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The three surfaces declare the same rules. `skill-scaffolder` carries a SKILL.md body template (`## When to Use`, `## Step-by-Step Instructions`, `## Constraints & Rules`) and a `paths:` frontmatter that `prompt-authoring-conventions.md` owns. | duplicate declaration | the resolved scope names the canonical owner |
| `documentation_policy.md` `## Communication Standards` and `prompt-authoring-conventions.md` both carry prose-structure rules, at different grains. | duplicate declaration | the reduced version resolves them |
| The Milestone Summary table carried a blank line between the M7 and M9 rows, so M9 and the new W2 row parsed as prose rather than table rows. | record defect, pre-existing | corrected in place |

## Completed

| File | Change |
|---|---|
| `.agents/drafts/communication-domain-taxonomy-run.md` | new draft run brief for the deep communication-domain work |
| `devlog/roadmap_future.md` | new `## W2 -- Communication Domain Taxonomy` section with its dependencies and single task |
| `devlog/roadmap.md` | the W2 summary row; the stray table blank line removed |
