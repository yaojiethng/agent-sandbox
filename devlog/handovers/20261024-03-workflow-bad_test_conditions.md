---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Workflow
status: Closed
---

# Handover - Two bad-test conditions, and the gate the dispatch-rule row was missing

## Objective

Name the two conditions a test is judged against -- a tautology asserts nothing, and a derived case set is bound to an invariant before anything is asserted about its items -- and apply the second one to the test that failed it, closing the dispatch-rule row on a gate that reads the committed table's own lines.

## Scope

`.agents/skills/testing/SKILL.md` `## Judgements`, [`tests/test_pi_model_recommendations.sh`](../../tests/test_pi_model_recommendations.sh), the roadmap rows, and this record.

The row asks four questions, and the tree already answered three:

| Question | Answered at |
|---|---|
| where a dispatch rule lives | [`dispatch.md`](../../docs/reference/dispatch.md) `## The Resolution Path`: `DISPATCH_REC_FILE`, then the repository copy, then the agent home |
| who edits it | [`agent_workflow.md`](../../docs/reference/agent_workflow.md) `## Model recommendations`: the committed file makes the edit reviewable and the `setup-model-recommendations` skill populates the values; the skill's own opening states the operator owns them |
| how a stale rule is detected | `dispatch.md` `## Requirements`: a malformed line fails the resolution before a command, and an id that names nothing surfaces at the provider, which marks that route dead and the walk advances |
| how a rule change is tested | **half-answered**: grammar cases over fixtures in [`tests/dispatch/machine/table.test.ts`](../../tests/dispatch/machine/table.test.ts), and a shape case that only checked that other files do not name a table model. Nothing resolved the committed table's own lines |

That shape case is the bad test this unit deletes. It derived the ids it forbade from the live table, so a line that stopped yielding an id narrowed the forbidden set and left the case green: with `_ADVISOR_DOCS` broken, `opencode/glm-5.3-flash-free` left the set and nothing failed. Bounding the derivation would have repaired it; the operator's ruling is that the case is removed instead, and that the condition it failed is stated. The static check that no file binds a role to a model keeps the guard the case half-held, and now covers the dispatch skill itself, which is where the shadow it prevents has its one historical carrier.

Out of scope, each with its reason. A schema file or a loader, because [`table.ts`](../../src/libs/dispatch/table.ts) already holds the grammar and `dispatch.md` already states it as a requirement; a second declaration is the artifact the model-catalog row was retired for on 2026-10-24. A validation of an assignment against a runtime catalogue, because `dispatch.md` forbids it one bullet from where the staleness answer sits, and the ADR `single_source_model_recommendations.md` rejected it on two measured failures. Price data, because nothing in this tree prices a model -- cost is read from recorded sessions, which is M3.6.2's subject -- so "a price moving is a data edit" holds by there being no price to edit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both conditions are stated as judgements | `grep -c '\*\*A tautology asserts nothing' .agents/skills/testing/SKILL.md` and `grep -c '\*\*A derived case set is bound' .agents/skills/testing/SKILL.md` each print 1, inside `## Judgements`, each as one unwrapped line | Agent [x] Operator [ ] |
| The case that failed the second condition is gone | `grep -c 'test_the_dispatch_skill_names_no_table_model' tests/test_pi_model_recommendations.sh` prints 0, the file's `run_test` count is 10, and the suite is green | Agent [x] Operator [ ] |
| The guard it half-held survives, statically | `grep -c 'the dispatch skill binds no role to a model' tests/test_pi_model_recommendations.sh` prints 1, and the case carrying it derives nothing from live data | Agent [x] Operator [ ] |
| Every role line of the committed table resolves | the new case is green on the committed table, and a copy with one broken entry turns it red naming that role; both runs are below | Agent [x] Operator [ ] |
| The case finds the roles a listing would skip | on that copy `table roles` prints the other four roles, omits the broken one, and exits 0, while the new case fails on it | Agent [x] Operator [ ] |
| No schema artifact is added | `git show --stat HEAD` names the convention skill, the test file, this record and the roadmap; no file under `src/libs/dispatch/` and no new config file | Agent [x] Operator [ ] |
| Both roadmap rows close with evidence | the M3.6.3 row and the T1 row each read `- [x]` with a closed note naming this record | Agent [x] Operator [ ] |

### The gate's two runs

The new case, `test_every_committed_role_line_resolves`, on the committed table:

```text
[ test_every_committed_role_line_resolves ]
  ok: the committed table names at least one role
  ok: the committed table resolves '_ADVISOR_CODE' (rc=0)
  ok: the committed table gives '_ADVISOR_CODE' an assignment
  ... one resolve and one assignment per role, five roles ...
  PASS: test_every_committed_role_line_resolves
```

One entry broken in a copy -- `_REVIEWER: opencode/ at high`, the model empty -- and the same walk goes red naming the role:

```text
_ADVISOR_CODE    rc=0 opencode/deepseek-v4.1-flash-free high opencode
_ADVISOR_DOCS    rc=0 opencode/glm-5.3-flash-free high opencode
_IMPLEMENTER     rc=0 opencode/deepseek-v4.1-flash-free high opencode
_ORCHESTRATOR    rc=0 deepseek/deepseek-flash high pi
_REVIEWER        rc=1 dispatch: the runtime for 'opencode' needs the model as well
gate verdict: RED
```

On that same copy the listing is silent -- `table roles` prints the other four roles, omits `_REVIEWER`, and exits 0 -- which is why the case reads the tag lines from the file.

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The gate lives in `tests/test_pi_model_recommendations.sh`, the file that already vets the committed table, and reads the `_ROLE:` tag lines rather than `table roles` output | a role whose line does not resolve is absent from that listing and the listing exits 0, so a walk over it passes on the very defect the gate exists to catch | the case and this record's two runs |
| D2 | No schema, no loader and no price table is built | the grammar is `table.ts`'s and is already stated as a requirement; a second declaration is the artifact the model-catalog row was retired for; nothing in this tree prices a model, so a price move is already a data edit with no data to edit | this record's Scope; the decision block under M3.6.3 |
| D3 | A stale id is still detected at the provider and not by a static check | `dispatch.md` forbids validating an assignment against a runtime's catalogue one bullet from where the staleness answer sits, on evidence that a listing names what a runtime knows and not what it will serve | `dispatch.md` `## Requirements`; this record |
| D4 | The derived-id case is deleted rather than repaired, and the two conditions are stated in the `testing` convention | an absence assertion over a set the test derives from live data is green over no evidence, and the operator's ruling is that the instance goes and the rule is written; bounding the derivation would leave a test whose value is one shape grep the static check already makes | the convention's `## Judgements`; the finding below; the T1 row |
| D5 | The static binding check gains the dispatch skill | that file is the one historical carrier of the shadow the deleted case existed for, and the static form asserts it without a generator | `test_no_file_pins_a_role_to_a_model` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `tests/test_pi_model_recommendations.sh` checked that no other file names a table model and never resolved the table's own lines | defect | a committed rule edit that breaks a line is found at the first dispatch of that role, not at the commit | this record's scope: the new case |
| A malformed role is absent from `--list-roles` output, so the listing cannot be the gate's source | fact | a gate that walked the listing would pass on exactly the defect it exists to catch (measured on the mutation copy: `table roles` printed the other four roles, omitted `_REVIEWER`, and exited 0) | D1: the case greps the tag lines instead |
| The deleted case's derived id set narrowed silently when a line stopped yielding an id: with `_ADVISOR_DOCS` broken, `opencode/glm-5.3-flash-free` left the forbidden set and the case stayed green | defect, found at the pre-close review | an absence assertion over a narrowed derivation is a green build over no evidence | D4: the case is deleted and the condition is stated in the `testing` convention |
| An id the table has never held is not caught by the shape cases | record, inherited from handover `20261023-22` | an unknown id is not enumerable from the tree, and enumerating it is the catalogue validation `dispatch.md` refuses | D3: the provider's refusal is the detection, and no static check is built |
| [`opencode_runtime_dispatch.md`](../../docs/adr/opencode_runtime_dispatch.md) says a paid model needing the operator's authentication "stays a provider-image concern until the dispatch-rule surface names it", and the row has now closed without naming it | record | the sentence's `until` clause points at a closed row, so a reader cannot tell whether the question was answered or dropped | M3.6.5's provider-image row, which owns a paid model's credential; flagged, not edited, because the ADR is outside this unit's artifact |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/testing/SKILL.md`](../../.agents/skills/testing/SKILL.md) | two judgements: a tautology asserts nothing, and a derived case set is bound to an invariant before anything is asserted about its items |
| [`tests/test_pi_model_recommendations.sh`](../../tests/test_pi_model_recommendations.sh) | a case that resolves every role line of the committed table, and the derived-id case deleted with its guard moved onto the static binding check |
| [`devlog/roadmap.md`](../roadmap.md) | the dispatch-rule row closed with its four answers and the gate, and the T1 row that records the convention change |
| this record | the four questions, the case's red and green runs, and why the deleted case was a bad test |
