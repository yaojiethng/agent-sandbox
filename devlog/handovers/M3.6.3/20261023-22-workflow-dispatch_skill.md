---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Workflow
status: Closed
---

# Handover - The dispatch skill states the contract

## Objective

Retire `opencode-dispatch` into a `dispatch` skill that names a role and no model, so the one instruction every worker dispatch reads stops telling the reader which model runs.

## Scope

The skill at `src/reasoning/providers/pi/config/agent/skills/`, its carriers, and the test that holds the rule it now states.

The row closes one defect the previous iteration filed. The skill's launcher retired into `scripts/dispatch.sh --worker` at handover `20261022-19`, and its prose did not follow: it still said the default is the free model `opencode/deepseek-v4.1-flash-free` at `high`, its description still said the run happens on a tier pi cannot reach, and its invocation example already passed `--role`. The dispatch-ownership iteration made a contract layer that names a model a defect, in [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md), and filed this as the standing cost of that rule having no gate.

Out of scope: the rest of the **dispatch-rule surface** row, which is the config schema, the validation and the staleness check, and which stays open. The skill's loadability is out of scope as well, because `~/.pi/agent/skills/` is an installed copy and the image rebuild is blocked; this iteration proves the content, the pointers and the gates, and it cannot prove the skill loads.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill is named `dispatch` and the old directory is gone | `ls src/reasoning/providers/pi/config/agent/skills/ \| grep -c '^dispatch$'` prints 1, and `ls .../opencode-dispatch` fails | Agent [x] |
| The skill names no model id and no tier | `grep -nE '[a-z]+/[a-z0-9.-]+(-free)?\|free tier\|FreeTierError'` over the skill returns nothing | Agent [x] |
| A test rejects a model id planted in the skill | `bash tests/test_pi_model_recommendations.sh` passes clean, and its new case fails when `opencode/deepseek-v4.1-flash-free` is appended to the skill | Agent [x] |
| The documented invocation resolves against the tree | the print form of the skill's command prints `/usr/local/bin/opencode run --auto ... -m opencode/deepseek-v4.1-flash-free --variant high` for `_IMPLEMENTER` | Agent [x] |
| No live pointer names the retired directory | `bash scripts/check_markdown.sh` clean, and the remaining mentions are closed rows, settled records and this row's own history clause | Agent [x] |
| Every decision this iteration recorded is realized in the files | the five rows below, each against its named file | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill stays in pi's provider config, not in `src/reasoning/agent/skills/` | its neighbours are `setup-model-recommendations` and the reviewer's runner, and the ADR scopes the problem to a caller inside pi, so an agent-sandbox root would offer the skill to an image that does not have the tree | this record |
| The retired name keeps no stub | nothing live names it, and a stub would be a second door for a caller that should use this one | this record |
| The skill documents no `--model` | a pin documented in the skill restores the shadow this unit removes; the entrypoint keeps the flag for a fixed run, which is not dispatch | the skill, `## The fallback` |
| The skill points at `dispatch.md` by its image path instead of restating resolution and the walk | one source of truth for the mechanism, and the image path is how a sibling skill in the same root cites a reference document | the skill, `## The form` |
| The rule is pinned by a test that derives its ids from the role table | the operator's rule forbids a test that hardcodes a model, and a derived check follows a table edit with no second edit | [`tests/test_pi_model_recommendations.sh`](../../tests/test_pi_model_recommendations.sh) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The rename is not verifiable as loadability here: `~/.pi/agent/skills/` holds a copy installed at container start, so the running container keeps loading the retired directory | environment | an agent in this container reads the old skill while the tree holds the new one, and only an image rebuild closes the gap | the blocked `make build` item, unchanged by this iteration |
| Two closed carriers still name the retired directory: the M3.6.1 blurb's changelog anchor is the changelog's own heading, and the closed row **The dispatch path ships on the free tier** names the skill in a code span | record | a reader following the closed row finds a name that has moved | no edit: the closed-entry rule keeps a closed row's text, and the successor row above already records the rename |
| The shape test catches a model the table carries, and it does not catch an id the table has never held | test | a skill naming a retired model id would pass the case | the roadmap's **The dispatch-rule surface** row, which owns the validation and the staleness check |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md) | renamed from `opencode-dispatch`; rewritten so it names a role, no model and no tier, points the mechanism at `dispatch.md`, and omits `--model` |
| [`tests/test_pi_model_recommendations.sh`](../../tests/test_pi_model_recommendations.sh) | one case: the dispatch skill pins no role and names no model the role table carries |
| [`devlog/roadmap.md`](../roadmap.md) | a row for this unit, closed here; the model-catalog row's link and the instruction-transport row's cell list retargeted; the dispatch-rule row's shadow recorded as retired |
| [`devlog/discussions/20261016-design-settled-dispatch_ownership.md`](../discussions/20261016-design-settled-dispatch_ownership.md) | its Consequences sentence records that the worker skill now names no model |
