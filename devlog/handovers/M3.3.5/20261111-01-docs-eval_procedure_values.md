---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Documentation
status: Closed
---

# Handover - The eval procedure states the rule, not a closed run's values

## Objective

Remove the measured values of closed runs from the eval skill and its methods reference, so each rule stands on its own statement and each number sits in the record that measured it.

## Scope

The roadmap row "The eval procedure states the rule, not a closed run's measured values". The files are `SKILL.md` steps 3 and 4 and `references/methods.md`, whose A/A, factorial, screen and minimum-detectable-effect sections each restate a result from the stored `gm-focus-milestone` work. The instrument, the gate and the case files are untouched: no behaviour changes, and the only claim that changes is which document owns a number.

The gate follow-up the operator named next is filed as a separate open row and is not this iteration's.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No token band, alignment granularity or per-cell count from a closed run appears in the prose files. | `grep -nE '25 percent\|one report at eight\|0 of 8\|1 of 8\|five read strategies'` over both files prints nothing | Agent [x] |
| Every sentence that reports what a run found names the record that holds it. | the same grep for `20261110-06`, `20261110-04` and `20261110-05` shows a citation at each remaining claim | Agent [x] |
| The minimum detectable effect is stated in terms of `n`, not a fixed run count. | `references/methods.md` reads `1/n` and `100/n`, and no fixed run count survives in that section | Agent [x] |
| Every rule has one owner, and no claim about a past run is frozen into the prose. | a grep for a percentage sign over the skill directory prints nothing, and each remaining claim cites the record that holds it | Agent [x] |
| Every pointer resolves to a heading the file carries. | `grep -n '^## '` beside the `](...#anchor)` targets in the skill directory | Agent [x] |
| Each file carries one mode: steps in the skill, facts in `references/`, the why in the ADR. | read each file's sections against `organization.md`'s four modes | Agent [x] |
| An experimental unit reads as a quantity rather than a record entity. | `bash tests/test_unit_vocabulary.sh`, whose new case writes "The experimental unit is one agent run on one fixture" and expects the gate to pass | Agent [x] |
| No durable instruction names a handover as the evidence for a rule. | `grep -n '202611' .agents/skills/evals/` prints nothing | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table read against the diff | Agent [x] |
| A hillclimb states the assumptions it rests on and the preconditions that hold before it starts. | `grep -n "^## The assumptions\|^## The preconditions" .agents/skills/evals/playbooks/hillclimb.md` prints both | Agent [x] |
| Every external source carries the repository's citation form and an adaptation record. | each `https://` in the skill and the ADR is preceded by an author, a title and a read date, and `.agents/registry/citations/` holds the record the sentence names | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The phase is scope alignment and the artefact is the experiment specification. | A contract in this repository is an interface between two parties, and these two are a scope and a description, so "contract" named neither. | recorded in `docs/adr/eval_harness_contract.md` |
| A worked result stays as a pointer, not as numbers. | the lesson survives without freezing another instrument's band, and the reader can open the record | this table |
| The rule text names the variable, never the case's value. | `n` and `1/n` hold for any run count; a fixed count holds only for one closed case | this table |
| A rule is stated in one file, and the rest point at it. | the skill's steps, the methods and the harness each carried the admission test, the measure split and the attrition rule, so a change needed an edit in each file and could miss one | the files in this diff |
| A claim about a past run is either a rule or a pointer to its record. | a sweep of the whole skill directory, not only the files the row named, found more of them | this diff |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None | - | - |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The read-cost roadmap row was closed while its text still said the row stays open for the artifact family. | record | A closed row promised future work, and the `roadmap-maintenance` pass reported it. | fixed in the roadmap diff this iteration |
| The stored `gm-focus-milestone` experiment still names the control `baseline` and a `min_effect` of zero. | record | A rerun decides on the wrong arm; the repair is outside this iteration's file set. | roadmap row "The stored gm experiment's decision block matches the repaired prompt" |
| `--case` never calls `check_case`, so a graded run can start on a declaration `--check` would reject. | harness | The gate is opt-in at the run path, which is a second hole beside the optional `design` and `checks`. | roadmap row "A run validates its declaration before it starts" |
| The grader's own agreement has no field in the declaration. | harness | The procedure asks for it and no record refuses a verdict that lacks it. | roadmap row "A verdict records the grader's own agreement" |
| `measure_gm_report.sh`'s score range was a second closed-run value beside the ones the row named. | record | Same defect class; it was in scope once the row was read as "a closed run's measured values". | fixed in the same edit |
| The rewrite's first wording used `unit` as a quantifier, which the `unit vocabulary` gate reports. | prose | A gate caught it before the close; the sentence names the measurement instead. | fixed in place |
| `specification.md` pointed at `## Purpose`, a heading `SKILL.md` does not carry. | record | A reader following the pointer found nothing, and no gate checks a heading anchor against its target. | fixed in place |
| `specification.md`'s A4 named `found` and `declared` as fields a measure emits, and no measure emits them; the antipattern file asserted the same gap separately. | record | Two documents disagreed about whether the harness fills the row, and the table read as a promise the code does not keep. | fixed in place, and the antipattern now points at the row |
| `harness.md` said `EVAL_CASE_SET` may name another case directory, without saying that the fixture gate is its reader. | record | The variable belongs to `scripts/check_eval_fixtures.sh`; a reader took it for a runner option. | fixed in place |
| `playbooks/hillclimb.md` made claims about past runs with no record behind them: "every accepted edit so far" and a drift magnitude for identical text. | record | A later reader cannot check either, and the drift claim also sat in `methods.md` as a second copy. | both restated as rules, and the methods copy states it once |
| `harness.md` explained that `design` and `checks` are declared together "so a frozen observation stays valid", which the case and experiment split has made stale. | record | The rationale survived the change that removed its reason. | rationale cut; the pairing rule stays |
| A durable skill now names transient handovers as the evidence for its rules: `SKILL.md` step 3 names `20261110-06`, and `methods.md` names `20261110-05` and `20261110-04`. | record | The dependency runs the wrong way: a record may cite the rule, and the rule may cite the ADR that cites the record. | fixed in place: the pointers are cut, and the rules stand alone |
| `methods.md` opens with a description of its own structure and a hidden actor, and `harness.md` opens by restating its own headings. | prose | A sentence about the document rather than about the work, and a tautology over the headings beneath it. | fixed in place |
| `specification.md` carries an explanation section, `## Why these seven and no others`, and pointers into a how-to. | structure | Explanation belongs to `docs/adr/`, and a reference document describes rather than routes to a procedure. | filed: `## Why` moves to the ADR; the row-admission rule stays as one clause |
| The A7 proof paragraph narrates what the test asserts instead of stating it. | prose | Reference prose describes; it does not recount. | fixed in place |
| `harness.md` links the ADR, inverting the authority: an ADR governs a skill, and a skill's execution does not read it. | structure | The dependency direction is the ADR's to state. | fixed in place: the link is cut |
| `SKILL.md` carries more than one mode: explanation in `## Two instruments` and the provenance paragraph, reference in `## The measure` and `## The stores`, and the how-to steps. | structure | `organization.md` puts one mode in one document; `body.md` puts the contract in a reference and the why in the ADR. | fixed in place: the stores and measure rules moved to `harness.md`, the instruments and provenance to the ADR |
| No route sent a session revising a skill to `instruction-authoring`, so the mode split, the sentence kinds and the review runbook were reachable only by search. | steering | A rule reachable only by search is a routing defect; `AGENTS.md`'s read-before table listed the record conventions and not this one. | roadmap row "A skill edit reads the instruction-authoring rules before it starts" (M3.3.5) |
| `linking` states the durable-to-ADR-to-record chain for a documentation or policy document, and `principle-guard-derived-state` states the record rule, and neither states the chain for an instruction, so a skill can cite a handover and satisfy both. | steering | The rules I applied were satisfied by the pointers I wrote, which is why the defect survived a pass that was looking for it. | roadmap row "A durable document cites through the ADR, never around it" (M3.3.6) |
| The skill's claim about `--check` was wider than the code: `check_case` reads only the `harness` block, so the case's instruction, rubric and expected output are unvalidated, and `runs_detail[].model` records the session's model rather than the requested one. | record | A limit stated wider than the mechanism is a claim a reader will design against, and the harness also keeps its callers to this skill. The skill now names the fields `--check` reads and says what it cannot settle. | fixed in place |
| The `unit vocabulary` gate rejected `experimental unit`, which `terminology.md` already allows as a quantifier. | harness | The gate was narrower than the rule it copies, so a correct use failed and the prose took the weaker word. | fixed in place: the allowlist and the rule now match, with a test case |
| `playbooks/hillclimb.md` stated its loop but not the assumptions the climb rests on, the terms it judges with, or the scope alignment the climb proceeds from, and it restated harness rules that `references/harness.md` and `patterns/isolation.md` own. | structure | A climber can start on a case that does not reproduce the complaint, or on a harness that cannot separate a contrast, and each failure reads as a result; "improvement", "noise" and "fix" carried the reader's meaning rather than the case's; and the restatement gave one rule two owners. | fixed in place: the contract, the order, the terms, and the pseudocode with a source tag per step |
| A precondition tagged `[OP]` read as "the operator writes it": the tag sat on the score tuple, the harness and the log, which are the agent's to build. | structure | An agreement step stated as an authorship step, so a reader could not tell which artefact the operator signs and which the agent makes. | fixed in place: the contract names the agent's mechanism per part, and `[OP]` is defined as a signature on the contract |
| The skill stated its stages as sections with no order between them, so nothing said the design is agreed before it runs, or that the run is the handoff. | structure | The run is implemented from a design, and a question list is not a contract: the invariant, its enforcement and the delivery format were all left to the run. | fixed in place: `## The workflow` states the five phases and the four-part agreement, and `## The run` names itself the handoff |
| The skill and the playbook had no scope gate: nothing asked whether the experiment was necessary, which method answered the claim, what the deliverables were or what the taboos were, so a run could start on a question nobody agreed to. | steering | Every procedure here is scoped and agreed before execution, and the experiment procedure began at the claim; the climb then inherited the gap and began at its loop. | fixed in place: `## Scoping the experiment` in the skill, and the playbook defers to it |
| The skill and the ADR cited three upstream sources as bare links to a moving branch, with no publisher, no read date and no adaptation record. | record | The revision a claim rests on was unpinned and the adaptation lived nowhere, so a later reader could not check what was taken or dropped. | fixed in place: the citation form, and three records under `.agents/registry/citations/` |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/SKILL.md` | Rewritten as the experimental process: the scope gate before the protocol, the domain mapping to the traditional frame, the inventory of the test case and the tools, each with its constituents and its limits, the protocol in declaration order with its invariants and what holds each one, and the run steps, non-goals at the end, and the close. Unchanged in length; one mode replaces the mixed body. |
| `.agents/skills/evals/references/methods.md` | The handover pointers are cut, and A/A, factorial, screen and minimum-detectable-effect state the rule in terms of `n`. |
| `.agents/skills/evals/references/harness.md` | Gains `## The stores` and `## Process and content measures`; the tautological opener, the ADR link and the repeated field list are cut. |
| `.agents/skills/evals/references/specification.md` | The explanation section moves to the ADR, the row-admission rule stays as one clause, A4 states that no field fills it, and the A7 proof states instead of narrating. |
| `docs/adr/eval_harness_contract.md` | The `## 2026-11-11` section now records the process-versus-measurement-system split, the domain mapping, why the honesty block and the co-location belong to the skill, the instruments, the measure split, the sources, and the rejected alternatives. |
| `.agents/skills/evals/references/specification.md`, `tests/test_eval_specification.sh` | The measurement contract is renamed the experiment specification, and the test that reads it follows the name. |
| `.agents/skills/evals/antipatterns/README.md` | Two isolation entries defer the rule to `patterns/isolation.md`, and the missing-denominator entry points at A4. |
| `.agents/skills/evals/playbooks/hillclimb.md` | Two unrecorded claims about past runs become rules, the paired-batch rule cites its owner, and the file now states the four assumptions a climb rests on, the preconditions that hold before the first attempt, and the loop, plateau and stop, with the harness rules left to their owners. |
| `.agents/registry/citations/pstack-hillclimb-playbook.json`, `pstack-eval-playbook.json`, `agentskills-evaluating-skills.json` | The three sources the eval skill adapts, each with its edition, its read date and what was kept, rewritten, added and dropped. |
| `scripts/lint/unit.mjs` | The allowlist admits an experimental unit and a unit of analysis or observation, which the terminology rule already permits. |
| `docs/reference/terminology.md` | The quantifier examples name the experimental unit. |
| `tests/test_unit_vocabulary.sh` | New case: an experimental unit passes the gate. |
| `devlog/roadmap.md` | Filed the open rows this iteration named, the steering gaps among them; closed this row, corrected the read-cost row's forward-looking clause and removed a stray blank line. |
| `devlog/handovers/M3.3.5/20261111-01-docs-eval_procedure_values.md` | This record. |
