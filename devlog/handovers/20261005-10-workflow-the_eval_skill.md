---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Eval Skill

## Objective

Give the behaviour eval one home, so a claim that an instruction set changes what the agent does can be measured by a run instead of argued from the document.

## Scope

Two external sources settle the process. The agentskills guide owns the loop, the case-file shape, the assertion rules and the benchmark. The poteto-mode `eval` playbook owns the blinding discipline. Neither can know how a run is isolated in this harness, and that part is what this unit adds.

1. **The skill is a fast path, not a source.** `workflow/coding-agent/skills/eval/SKILL.md` carries the two source links, the harness mechanics and the invariants. It does not restate the guide, for the reason a maintenance skill does not restate the policy it checks.
2. **The harness supplies three things the guide assumes.** A fixture starts from a `/package-eval-snapshot` bundle, which freezes a real past state. `PI_CODING_AGENT_DIR` gives each configuration its own pi config directory, so the with-state and baseline runs differ by one entry. `pi -p` gives each run a fresh context.
3. **The case set is declared data.** A case file names its subject, the negative case it reproduces, the configuration variable, and its assertions. Two ship with the skill: the commit-body budget, which is the case the operator named, and the placement check, which is the regression case for the correction the next unit lands.
4. **The first case asks the operator's question.** `commit-body-budget.json` asks whether the budget paragraph in `git_policy.md`, and the pointer to that policy in the project `AGENTS.md`, hold an agent to the budget. The baseline fixture carries neither.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill's frontmatter parses and the gate scans it | `bash scripts/check_prompt_frontmatter.sh` | Agent [x] -- clean across 43 files, one more than before |
| Both case files are valid JSON and each assertion tests one thing | `jq empty` on both, then a read-through | Agent [x] -- three assertions across two cases in the commit-body set, three in the placement set |
| A run of the first case produces graded artefacts outside the repository | the iteration directory under `$HOME/workspace/output/evals/` | Agent [x] -- two iterations, four runs, `benchmark.json` in each, and no repository file written |
| The benchmark reports pass rate, wall clock and tokens per configuration, with the delta | `benchmark.json` | Agent [x] -- iteration 1: 3/3 against 2/3, +54 seconds, +1,520 tokens. Iteration 2: 3/3 against 3/3, -36 seconds, -6,810 tokens |
| `bash scripts/lint.sh` is clean | the command | Agent [x] -- 8 gates, clean in 6s |
| `bash scripts/run_tests.sh` is clean | the command | Agent [x] -- 1101 tests across 75 files, 0 failed |
| The row is written back and the handover closes | `devlog/roadmap.md`; this handover | |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/eval/SKILL.md` | new: the fast path and the harness mechanics |
| `workflow/coding-agent/skills/eval/evals/commit-body-budget.json` | new: the case the operator named |
| `workflow/coding-agent/skills/eval/evals/placement-check.json` | new: the regression case for the placement correction |
| `devlog/roadmap.md` | the T1 eval-infrastructure row |
| `devlog/handovers/20261005-10-workflow-the_eval_skill.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill links the guide instead of copying it | a skill is a fast path to a rule that lives elsewhere, and the guide is that source; a copy goes stale the moment the guide moves | `docs/development/prompt-authoring-conventions.md` `## Runbook versus advisor versus skill` |
| `disable-model-invocation: true` | one run costs a subagent fan-out and several minutes of wall clock, so the operator invokes it deliberately | this handover |
| Case sets live in the skill's own `evals/` directory | one home for the method and its data until a case root earns a place of its own | this handover |
| The skill ships in the module payload, not the harness payload | the module is the toggle unit, and an eval of workflow instructions is workflow work | `docs/adr/module_instruction_payload.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Neither case separates its two configurations on the assertion that matters. `commit-body-budget` passed the 280-character assertion in both configurations, and the baseline answered a two-typo task by writing no body at all rather than a long one. `delivery-commit-body` produced 261 characters with the budget paragraph present and 255 without. The recorded failure ran 324, 880 and 1248 characters on iteration-scale delivery commits, and both fixtures hold a change too small to induce it. | assertion, caught by the run | open | Triaged to: the case set, which needs an iteration-scale change next; recorded in `notes` in the case file |
| The first fixture build was wrong. A builder script was patched with a chain of unguarded `String.replace` calls, the patch applied partly, and the two configurations ended up differing in the wrong places: one had an extra uncommitted file, and the budget paragraph survived in the baseline. The eval would have reported that as a null result about the instruction set. The rebuild asserts the fixture's facts at the end of the build and fails loudly. | process, silent | current iteration | Triaged to: `devlog/AGENT_FEEDBACK.md`, a second occurrence on the mechanical-transform entry |
| The model honours the `### Body` budget rules with or without the policy. Both configurations produced a short body stating the reason and no path list. The budget paragraph is therefore not the binding constraint at this change scale, which is the substantive answer to the question the case was built for. | evidence | open | Triaged to: the case set's next iteration, and the T1 row |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/eval/SKILL.md` | new: the two source links, the harness mechanics, the run's seven steps and the invariants |
| `workflow/coding-agent/skills/eval/evals/commit-body-budget.json` | new: two cases, the operator's question first, with the observed result recorded per case |
| `workflow/coding-agent/skills/eval/evals/placement-check.json` | new: the regression case for the placement correction the next unit lands |
| `devlog/roadmap.md` | the T1 eval-infrastructure row names the skill and the open part |
| `devlog/AGENT_FEEDBACK.md` | a second occurrence on the mechanical-transform entry, with the builder-side guard |
| eval run artefacts, outside the tree | `$HOME/workspace/output/evals/skill-eval-commit-body/`: two iterations, four runs, two benchmarks, the fixture facts and the measured bodies |
