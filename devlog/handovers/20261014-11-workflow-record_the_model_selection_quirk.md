---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - record the model-selection quirk

## Objective

Record the model-selection quirk where a dispatcher will meet it, not only where it was diagnosed.

## Scope

Sidequest. Continues the interrupted handover [`20261014-10`](20261014-10-impl-move_the_file_list_to_the_scope_gate.md).

The operator asked where the quirk is recorded. It is recorded in one place: the `devlog/AGENT_FEEDBACK.md` entry **A partial model name silently binds to a different model**. The `setup-model-recommendations` skill does not carry it, and that skill is where a model id is chosen and written.

The quirk: `--model` is a substring pattern over the provider's model list, not an id lookup. Where several ids match, the resolver takes the last one in the list. `glm-5.3-flash` bound to `z-ai/glm-5.3-flashx`; only the full id binds the intended model. pi warns only when nothing matches, so a near-match is silent.

The skill's steps 1 and 4 are the gap. Step 1 says to treat `pi --list-models` output as the dependable source, and step 4 says "Every real slug written must be in the detected set" - which catches an unavailable slug, not a partial one that binds to a different available model.

Out of scope: the `_REVIEWER` role, which stays uninitialized until the operator sets it; the near-match behaviour of pi itself, which is upstream.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states the full-id rule at the point a slug is chosen and validated | read `setup-model-recommendations/SKILL.md` | Operator [x] |
| The provider `AGENTS.md` states it where the dispatch command is assembled | read `## Running Review Subagents` | Operator [x] |
| For both files, the repo source and the installed copy agree | `diff` each pair | Operator [x] |
| Neither carrier names a model slug, per the rule the existing test enforces | grep the two carriers for a slug | Agent [x] |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | run both | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule lands in the two carriers a dispatcher reads: the skill where a slug is chosen, the provider layer where the command is assembled | the feedback entry is the diagnosis record, not a place a dispatcher looks | this handover |
| Neither carrier names a concrete slug | the skill is seeded slug-free so it asserts no environment's models, and a test enforces it; the worked example stays in the feedback entry | this handover; `tests/test_pi_model_recommendations.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The first draft wrote the concrete model ids into the skill, and `test_pi_model_recommendations.sh` failed on it: the skill is seeded slug-free so it names no environment's models. The example belongs in the feedback entry alone. | contradiction | current iteration |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md` | step 1 gains the full-id rule; step 4 validates the full id |
| `/home/agentuser/.pi/agent/skills/setup-model-recommendations/SKILL.md` | the same file, installed |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the dispatch section gains the full-id rule |
| `/home/agentuser/.pi/agent/AGENTS.md` | the same file, installed |
| `devlog/roadmap.md` | the write-back |
