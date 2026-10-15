---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Eval Hillclimb Playbook

## Objective

Give the eval skill the loop that turns one measurement into sustained improvement, so the next wording change is climbed rather than argued.

## Scope

The eval skill answers one case. The hillclimb loop improves a metric across iterations. This unit writes the second as a playbook beside the first, in the language of the hillclimb playbook it borrows from, with the mechanics this session's run established.

1. **The playbook carries nine steps and a harness section.** Ground the workload, fix the score tuple, build and freeze the harness, open the decision log, batch with a paired control, accept only past the noise band, prefer a deletion or a named shape, stop at the predicate, close cleanly.
2. **Its sources are linked, not copied.** The hillclimb playbook owns the loop and the log, the eval playbook owns blinding, and the agentskills guide owns the case shape. Both repository URLs were checked and answer 200.
3. **The measured lessons are stated as rules.** The paired control is not optional, because batch-to-batch drift on identical text has exceeded most single-edit wins. A cross-batch figure is a story rather than a measurement, and the close says which figures are paired.
4. **It is reference material, not a second skill.** A skill is loaded by name and invoked; this file is read on demand by an eval run. It ships in the module payload with the skill that owns the case shape, and the skill's own body points at it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The playbook exists under the eval skill and the skill points at it | read `workflow/coding-agent/skills/eval/SKILL.md` and its `playbooks/` directory | Agent [x] |
| Both external sources resolve | `curl -o /dev/null -w '%{http_code}'` on each | Agent [x] -- 200 for both |
| `bash scripts/check_prompt_frontmatter.sh` is clean | the command | Agent [x] -- 44 files |
| `bash scripts/lint.sh` is clean | the command | Agent [x] |
| `bash scripts/run_tests.sh` is clean | the command | Agent [x] |
| The handover closes | this handover | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/eval/playbooks/hillclimb.md` | new: the loop |
| `workflow/coding-agent/skills/eval/SKILL.md` | one paragraph pointing at the loop |
| `devlog/handovers/20261005-13-workflow-the_eval_hillclimb_playbook.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A playbook file under the skill, not a second skill | the loop is read while running an eval rather than invoked on its own, and a second skill would compete for the same trigger | this handover |
| The score tuple order is correctness, consistency, target, size | the operator's own criterion, which prefers the smaller instruction set only when the earlier axes are equal | this handover |
| The paired control is a rule rather than advice | the run measured a 38 character drift on identical text, larger than three of the four accepted edits | `decision.tsv` of the hillclimb |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The frontmatter gate counts a reference document under a skill directory but does not require a frontmatter block in it. The count moved from 43 to 44 files with no finding. | evidence | current iteration | Triaged to: no change |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/eval/playbooks/hillclimb.md` | new: nine steps, the harness requirements, and the reply shape |
| `workflow/coding-agent/skills/eval/SKILL.md` | a paragraph naming the loop and linking it |
