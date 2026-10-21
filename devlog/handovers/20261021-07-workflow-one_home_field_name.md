---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Name the field's law behind one home per rule

## Objective

State in `principle-one-home-per-rule` that the law it applies is the field's `do not repeat yourself`, and that the half carrying the load is knowledge rather than text, so a reader meets the field's name where the rule is.

## Scope

The row **State the field's name for the one-home rule**, filed one commit before this iteration opened. It carries the decision and the reason, so this iteration reads no design: the phrase goes into the description spelled out, the acronym stays out because it routes the skill to duplicated code, which this rule does not govern, and the body states which half carries the load.

Ruled out of scope with a destination each. The leading-word declaration for this skill belongs to **Populate the leading words across the corpus**, which decides whether a declared field earns its keep. The `docs/reference/agent_workflow.md` citation in this skill's first pattern step belongs to **Decide how a shipped skill cites a rule that lives in this repository**. The sibling principle's name is settled and nothing here reaches it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The description carries the law's name spelled out | `grep -c "do not repeat yourself"` returns 2, in the description and the body, and the acronym returns 0 | Agent [x] |
| The body states the half that carries the load | the `**Why.**` paragraph states the prohibition, the target and the load-bearing half, says when a repeated word is a defect, and hands the exception to the fast-path part | Agent [x] |
| The new sentence does not contradict the fast path | the new sentence states the relation to the fast-path part: an inline that names the home states no second knowledge, which the next part then qualifies | Agent [x] |
| Both copies of the skill are identical | `diff` printed nothing | Agent [x] |
| The umbrella and the suite are clean | `Lint: clean in 9s across 11 gates`; `1273 tests across 92 files, 1273 passed, 0 failed, 0 skipped` | Agent [x] |
| The ledger is unchanged | `--check` printed `clean across 143 row(s), 24 gated, 14 reviewed, 65 judgement, 40 description, 13 homed`, the same counts as before | Agent [x] |
| Every decision this iteration recorded is realized in the files | three decisions, each read against its file: the prohibition in the description, the target and the load-bearing half in the body, and `authoritative` in the opening line | Agent [x] |
| The body names both the field's phrases, once each | `grep -c "single source of truth"` returns 1, and the prohibition appears once in the body and once in the description | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The description carries the prohibition spelled out, and no acronym | a review and the operator both found the acronym routing the skill to duplicated code, which this rule does not govern | this table, and the row's own text |
| The body names the target as `single source of truth` as well as the prohibition | prohibition and target are two things, so naming each once is not repetition, and the target is what a writer aims at | the body's `**Why.**` paragraph |
| The opening line says `authoritative home` | the defect is two copies that both read as authoritative, so one word names the property the defect destroys | the body's first line |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `test_linking.sh` exceeded its 10 second deadline under the suite on three runs | result | the file passes alone in 5.0 seconds, and the suite runs eight files in parallel, so the default budget is tight for this file now that the tree is larger. The suite could not report clean, which one acceptance criterion needs | fixed in this iteration, beyond the released scope and stated at the release gate: `tests/test_linking.sh` gains `# TEST_DEADLINE: 30`, the mechanism the runner documents for exactly this case. The suite then reported 1273 passing |
| A review proposed replacing the skill's body with an SSOT rewrite | result | the rewrite carried `referential integrity`, an absolute-hyperlink instruction a shipped skill cannot follow, `**The Test.**` in a case the shape gate rejects, the `judgment` spelling, and it dropped the skill's own `**A policy file owns a rule.**` part, which is the labelled row for this repository that handover `20261020-13` set as the pattern for a landed skill. Its two good ideas, the target phrase and `authoritative`, landed | nothing filed, because every fault it names is a fault in the proposal rather than the tree |

## Completed

| File | Change |
|---|---|
| [`principle-one-home-per-rule/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-one-home-per-rule/SKILL.md) | the description carries the prohibition, the opening line says `authoritative`, and `**Why.**` gains the paragraph naming the prohibition, the target and the load-bearing half |
| `$AGENT_HOME/agent/skills/principle-one-home-per-rule/SKILL.md` | the installed copy |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes |
| [`tests/test_linking.sh`](../../tests/test_linking.sh) | one line, `# TEST_DEADLINE: 30`, because the file's default budget no longer covers it under the suite |
