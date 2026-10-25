---
date: 2026-10-20
milestone: M3.6.3 - Route and decide
type: Workflow
status: Closed
---

# Handover - the role table in the repository, and the dispatch procedure stated once

## Objective

Move the role table into the repository, replace every described path with a direct link, and state the dispatch procedure and its error cases where an agent reads them, so no dispatch depends on recall.

## Scope

The carrier set for the role table's location: the table itself, `src/libs/dispatch.sh` which reads it, both `AGENTS.md` layers, three dispatch skills, the skeleton, and the reference documents that named the old location.

Out of scope, with reason: the provider `setup.sh`, `onboard.sh` and `docker-compose.pi.yml`, which still create and mount the table at the retired agent-home path; the container cannot remove that bind mount, so those carriers keep working read-only until the host removes the mount. Written down under Findings.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The role table is committed in the repository and names one model per role | `test -f .agents/model-recommendations.md`; `grep -c "deepseek/deepseek-flash"` prints 4 | Agent [x] |
| The resolver reads the repository copy and still returns a pair | `source src/libs/dispatch.sh; dispatch_role_model _REVIEWER` prints `deepseek/deepseek-flash high` | Agent [x] |
| The dispatch tests express the pair through `DISPATCH_REC_FILE`, and both dispatch suites pass | `tests/test_dispatch.sh`, `tests/test_pi_model_recommendations.sh` | Agent [x] |
| No live instruction describes the retired path | `grep -rn "AGENT_HOME/model-recommendations" --include=*.md AGENTS.md docs workflow src/reasoning/providers/pi/config/agent` returns nothing | Agent [x] |
| The project layer states the four-step procedure and what to do when a step fails | read `## Model Recommendations` | Operator [x] |
| The provider layer states the same procedure and drops the two-family claim | read `**Which model.**` | Operator [x] |
| The installed provider copy is byte-identical to the repository source | `diff -q src/reasoning/providers/pi/config/agent/AGENTS.md ~/.pi/agent/AGENTS.md` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The role table lives at `.agents/model-recommendations.md` | it is an instruction the agent reads, not host configuration, and a model change is now a reviewable edit | the table, `AGENTS.md` |
| Every role names `deepseek/deepseek-flash` | the operator's direction: it is the only model we dispatch | the table |
| The resolver prefers the repository copy and reads the retired path only when that copy is absent | the retired file is a single-file bind mount the container cannot remove, so a hard switch would fail at runtime | `src/libs/dispatch.sh` |
| `DISPATCH_REC_FILE` is the explicit override | a fixture needs to express its own pair without depending on the live table | `src/libs/dispatch.sh`, `tests/test_dispatch.sh` |
| The startup-default fallback is removed from the project layer | two rules for one state is what let a dispatch leave the table for a preference | `AGENTS.md` |
| The procedure names `dispatch_role_model` and four steps, and states the four failure cases | the clause named a resolver whose call form was nowhere written, which is the recall gap the operator identified | both `AGENTS.md` layers |
| The two-family claim is dropped | one model is in use, so a second seat is a second run, not a second family | the provider layer, the reviewer skill |
| The skeleton carries no model slug | a template that names a model bakes a choice into every new table; the test enforcing that stays | the skeleton |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The retired `~/.pi/model-recommendations.md` is a bind mount; `rm` fails with `Device or resource busy` | environment | the host must remove the mount before the fallback in `dispatch_rec_file` can go | open work, below |
| `src/reasoning/providers/pi/setup.sh`, `onboard.sh` and `docker-compose.pi.yml` still create and mount the table at the retired path | propagation, deferred | the container still receives a stale table, which the repository copy now shadows | open work, below |
| `pi-reviewer-dispatch/dispatch.sh` pins its own pairs outside the table, recorded on 2026-10-20 as a designed exception | pre-existing | with one model in use the pin and the table agree only by luck | open work, below |
| The census report and handover still name three model families | record defect, closed records | two closed records misstate what ran | operator ruling, ruled out on 2026-10-20 |

## Completed

| File | Change |
|---|---|
| `.agents/model-recommendations.md` | new committed table; one role per line, all `deepseek/deepseek-flash` |
| `src/libs/dispatch.sh` | `dispatch_rec_file` reads the repository copy, with `DISPATCH_REC_FILE` and `DISPATCH_REPO_ROOT` overrides |
| `AGENTS.md` | `## Model Recommendations`: direct link, one model, the four-step procedure, the failure cases, no startup fallback |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | `**Which model.**` states the same procedure and drops the two-family claim |
| `~/.pi/agent/AGENTS.md` | installed copy, byte-identical to the source |
| `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/SKILL.md` | one-model seat note, replacing the two-family gap |
| `src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md` | points at the committed table; the bind-mount note is retired |
| `~/.pi/agent/skills/pi-reviewer-dispatch/SKILL.md`, `setup-model-recommendations/SKILL.md` | installed copies |
| `src/reasoning/providers/pi/model-recommendations.skeleton.md` | no model slug, no startup-default bullet, committed location |
| `docs/adr/single_source_model_recommendations.md`, `docs/reference/agent_workflow.md`, `docs/reference/provider_lifecycle.md`, `workflow/coding-agent/skills/eval/SKILL.md`, `workflow/coding-agent/prompts/document.md`, `src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md` | the retired path replaced with a direct link |
| `tests/test_dispatch.sh` | the fixture pair is expressed through `DISPATCH_REC_FILE` |
| `.agents/prompts/classifier-models.md` | the entry no longer counts model families |
| `devlog/handovers/20261020-05-workflow-role_table_in_repo.md` | this record |

## Open work

1. Remove the host bind mount for `~/.pi/model-recommendations.md`, then delete the fallback branch in `dispatch_rec_file`.
2. Move `src/reasoning/providers/pi/setup.sh`, `onboard.sh` and `docker-compose.pi.yml` to the repository table, or drop them if the table no longer needs provisioning.
3. Reconcile `pi-reviewer-dispatch/dispatch.sh`'s pinned pairs with the one-model table, or record the pin as obsolete.
