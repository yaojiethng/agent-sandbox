---
date: 2026-10-17
milestone: M3.3.4 - The prose standards as principles
type: Implementation
status: Active
---

# Handover - the judgement kind in the authority doctrine

## Objective

Retire the requirement that a judgement have a policy home, by deriving rule, model and judgement from the observer that detects a violation and holding that classification in a gated ledger.

## Scope

The M3.3.4 row *Retire the authority doctrine where a principle must be its own home*, continuing the split recorded at handover `20261016-18`. The design is [`20261017-design-settled-the_judgement_kind.md`](../../discussions/20261017-design-settled-the_judgement_kind.md).

On operator direction the iteration ran as an instrumented audit rather than a text reconciliation. A census of both source documents precedes any edit, the classification is keyed to what observes a violation, and the doctrine text changes only as far as the census reaches. The authority claim turned out to have an observer after all, the `doc-maintenance` register, which names "a rule in a skill or a prompt with no home in a policy". It is a reviewed rule, not an unenforced one, so the doctrine stays and the judgement kind is what it lacked.

The carry-over matrix over the two closed retirements was not produced. It is pushed to the split-criterion row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A norm's kind follows its observer, stated once | `sed -n '/## Rule authority/,/## Folder/p' docs/policies/documentation_policy.md`; `prompt-authoring-conventions.md` defers in one clause | Agent [x] |
| No carrier applies the policy-home requirement to a judgement | `grep -n "constraint that exists only in a skill\|judgement rules" docs/development/prompt-authoring-conventions.md` returns nothing | Agent [x] |
| The pi advisor prompt needs no edit | `git diff --stat` lists no change to `src/reasoning/providers/pi/config/agent/prompts/doc-advisor-policy.md` | Agent [x] |
| Every prose line of both sources carries a kind and an observer | `bash scripts/check_norm_ownership.sh --check` reports 167 rows, 23 gated, 20 reviewed, 85 judgement, 39 model | Agent [x] |
| The ledger is held both ways as a gate | `bash scripts/lint.sh` runs `check_norm_ownership.sh`; an edited sentence loses its kind and fails | Agent [x] |
| The ADR records the change and demotes the superseded entry | `grep -n "^\*\*Current:\*\*\|Reason superseded by 2026-10-17" docs/adr/policy_declarative_framing.md` | Agent [x] |
| Two independent classifiers agree on a 20-row sample | round two, `.scratchpad/rater_C.tsv` against `.scratchpad/rater_D.tsv`, 18 of 20 = 90 percent; round one was 12 of 20 | Agent [x] |
| Every decision recorded this iteration is realized in the files | the Decisions table read against the tree | Agent [x] |
| The two closed retirements reconcile with no unexplained drop | section-by-section carry-over matrix over `handover_policy` and `roadmap_policy` | pushed to the split-criterion row |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The kind is derived from the observer, not from the sentence's mood | It is the only test two readers apply and get the same answer, and the ledger makes the answer checkable | design doc, Decision; ADR 2026-10-17 |
| The ledger is generated from the sources and keyed on the line's hash | An edited sentence must lose its kind, or the census silently describes a tree that no longer exists | design doc; `check_norm_ownership.sh` |
| The criterion's home is `documentation_policy.md` `## Rule authority`, and the authoring bar defers to it | One home for the classification, and the section keeps its anchor, so three inbound pointers survive | design doc, Decision |
| The carriers narrow in place: `constraint` becomes `rule`, and "judgement rules" becomes "judgements" | The bars keep their force over rules and stop reaching a judgement | design doc, Decision |
| Two tie-breakers were added after the first reliability round failed | The criterion was not operational at 60 percent agreement, and prose cannot fix that; a main-clause rule and a named-check rule did | design doc, Evidence |

## Decisions pending

None. The roadmap row was reworded at close, from *retire the authority doctrine* to *derive the kind from the observer*, which is what the evidence supports.

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The authority claim has a reviewer observer, the `doc-maintenance` register's "a rule in a skill or a prompt with no home in a policy" | measured | it is a reviewed rule, not an unenforced sentence, so deleting it would have removed a working check | recorded in the doctrine and the ADR |
| 85 of 167 prose lines in the two standards are judgements with no observer | measured | the standards are mostly steering, so the split the sub-milestone needs is judgement against rule, and structure is a third axis | the split-criterion row |
| The classification is not reliable as first written, 12 of 20 agreement | measured | a taxonomy prose cannot make two readers apply is not a taxonomy | the tie-breakers, and the design's Evidence section |
| A rule can be observed by a reading procedure without a gate | measured | "unenforced" and "unobserved" are not the same, and the doctrine had been conflating them | ADR 2026-10-17 |
| The carry-over matrix over the two closed retirements was not produced | gap | a rule lost in either slice is not excluded | pushed to the split-criterion row |
| `prompt-authoring-conventions.md` owns the authoring bar without being a `*_policy.md` member | record defect | policy membership as written does not describe the tree | raised only; M3.3.2's membership row owns it |
| The authority claim still has two homes until M3.3.2 runs, `documentation_policy.md` and `docs/reference/agent_workflow.md:101` | known cost | a reference document carries a rule | M3.3.2's opening row |

## Completed

| File | One-line change summary |
|---|---|
| [`scripts/check_norm_ownership.sh`](../../../scripts/check_norm_ownership.sh) | the census generator and the two-way gate |
| [`scripts/lint/norm-ownership.tsv`](../../../scripts/lint/norm-ownership.tsv) | 167 rows, one per prose line, each with a kind and an observer |
| [`scripts/lint.sh`](../../../scripts/lint.sh) | the gate joins the umbrella |
| [`docs/policies/documentation_policy.md`](../../../docs/policies/documentation_policy.md) | `## Rule authority` states the observer criterion and names the ledger; the rule-versus-model paragraph retires |
| [`docs/development/prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) | a judgement may live in a principle skill; `constraint` becomes `rule`; "judgement rules" becomes "judgements" |
| [`docs/adr/policy_declarative_framing.md`](../../../docs/adr/policy_declarative_framing.md) | a 2026-10-17 current entry, and the 2026-09-30 authority entry demoted with its rejection line |
| [`devlog/discussions/20261017-design-settled-the_judgement_kind.md`](../../discussions/20261017-design-settled-the_judgement_kind.md) | the design and its measured evidence |
| [`devlog/roadmap.md`](../../roadmap.md) | the row reworded and marked; the matrix filed under the split criterion |
