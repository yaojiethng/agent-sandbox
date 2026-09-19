# Handover 20260917-04: workflow -- bootstrap prompt

## Status

Closed

## Type

Workflow

## Milestone

M2.6 (post-list close) -- operator-directed workflow-asset continuation

## Objective

Create the first-run prompt template that bootstraps the agent-sandbox content layer on a project of any completion state.

## Scope

One new prompt template in the deployed prompt surface, plus its registry row. The template encodes the setup procedure grounded in the operator's environment-check transcript from running agent-sandbox on an uninitialized project: investigate, classify, decide, materialize, verify.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| 1 | The prompt never assumes the project's completion state | Investigation section mandates classification into fresh / conventions-present / partial / initialized before any output; the initialized row says change nothing unless asked | done |
| 2 | The prompt always investigates | Probes for delivery and git, harness records, project conventions, and environment; expected-deviation list; gap-report step | done |
| 3 | The prompt materializes only what is missing | Record checklist per state class; dead-link repair limited to the partial class | done |
| 4 | The two operator decisions gate all file output | Decisions section places workflow intent and branch line first; the argument slot supports prefill | done |
| 5 | The four setup answers are requested during the iteration | Primer, goal and definition of done, verification contract, convention overrides | done |
| 6 | The setup ends verified | Verify-before-close section: link resolution, intended status, clean check-in inventory | done |
| 7 | The template meets documentation-policy writing rules | ASCII-only, STE wording, one paragraph per line, no change-history comments; policy copies precede AGENTS.md so its link targets exist | done |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | New first-run prompt template, deployed via the folder COPY of `workflow/coding-agent/prompts/` |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Registry row for the new template |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Policy copies precede AGENTS.md in the materialize order | AGENTS.md must follow `documentation_policy.md` wording rules and link to files that exist in the repo | `bootstrap.md` materialize section |
| The template deploys only at next image build | The provider dockerfiles COPY the prompts folder; the sandbox cannot update the baked copy | `project_index.md` row note |
| No roadmap row for this delivery | Operator-directed extension, same pattern as the `20260917-02/03` deliveries | This handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `scripts/macos_bootstrap.sh` carries a working-tree mode change `100644 -> 100755` from the prior session. Left uncommitted; the operator decides whether the script should ship executable. | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/bootstrap.md` | New template: mandate, state investigation, classification table, gap report, decisions, materialize order, verification, close |
| `docs/development/project_index.md` | Added the `prompts/bootstrap.md` registry row |

## Deferred items

None.

## What's Next

M2.6.6 continuation, or the portable-call-sites port offered from `20260917-02` when the operator returns to mount-model work.

Operator-owned follow-ups for the bootstrap prompt, outside the sandbox: copy it to `/opt/workflow/agent/prompts/` (or rebuild the images), and optionally wire a `/bootstrap` settings key.

Watch-outs: the mode change on `scripts/macos_bootstrap.sh` remains uncommitted until the operator rules on it.

**Conclusions from this iteration:** the setup procedure is stable and encoded: investigate first, classify the state, two gating decisions before any output, materialize the policy copies before AGENTS.md, verify links before close. The prompt reuses the vocabulary of the check-in and iteration policies so a bootstrapped project reads exactly like this one.
