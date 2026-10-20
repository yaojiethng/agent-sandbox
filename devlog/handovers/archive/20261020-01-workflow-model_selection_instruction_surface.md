---
date: 2026-10-20
milestone: M3.6.3 - Route and decide
type: Workflow
status: Closed
---

# Handover - bind the model-selection instruction surface

## Objective

Remove the instructions that let a dispatch reach a model the operator never named, and bind every dispatch to the role table, without restricting the `pi -p` invocation.

## Scope

The instruction half of the M3.6.3 row **A mechanism constrains which models an agent can reach**, whose premise changes here on operator direction: the capability the row proposes to restrict stays, and the fix moves into the resolution rules the dispatcher reads. The row keeps its remainder.

Seven clauses, agreed with the operator before this iteration: a dispatch names a role; a dispatch that fits no role uses `_IMPLEMENTER`; the role table wins over a preference; a task needing something the table cannot give stops; the pair comes from `dispatch_role_model`, never from a hand read; the resolution runs before initialisation; the brief records the role or `startup default` beside the pair.

Out of scope, with reason: the capability restriction the row's title states, because the operator ruled it out; and the correction of the census handover and report model rows, because a closed record takes a correction only at the operator's direction and that direction is not given.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The untagged exemption is gone and a roleless dispatch uses `_IMPLEMENTER` | `grep -c "not tied to a role tag" AGENTS.md` prints 0; `grep -c "Every subagent dispatch names a role"` prints 1 | Agent [x] |
| Precedence is stated once and names the role table | `grep -c "The role table wins" AGENTS.md` prints 1; the restated "never leave the table" sentence is absent | Agent [x] |
| The provider layer names the resolver and the order, and resolves before it initialises | `grep -c "dispatch_role_model"` on the provider layer prints 1; `grep -c "does not initialise the file before resolving"` prints 1 | Agent [x] |
| The installed provider copy is byte-identical to the repository source | `diff -q src/reasoning/providers/pi/config/agent/AGENTS.md ~/.pi/agent/AGENTS.md` exits 0 | Agent [x] |
| The reviewer contract resolves the pair from the role and records its provenance | `grep -c "The caller chooses both"` prints 0 in both copies; `grep -c "dispatch_role_model"` prints 1; the copies are identical | Agent [x] |
| Arm B names role lines, not model families, and the settled design carries its correction tag | `grep -c "Three coders on three model families"` prints 0; `grep -c "CORRECTION -- 2026-10-20"` prints 1 | Agent [x] |
| The ADR moves its `Current:` line and states resolution before initialisation | `head -3` on the ADR shows `**Current:** 2026-10-20`; `grep -c "^## 2026-10-20"` prints 1 | Agent [x] |
| The owning row carries its amended premise and landing note, and its remainder stays open | `grep -c "Landed on 2026-10-20, the instruction half" devlog/roadmap.md` prints 1 | Agent [x] |
| Every decision this iteration records is realized in the files | read this record's `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The seven clauses are the design, and the ADR entry is its record; no separate design document | `adr_policy.md` owns a change to a standing principle, and this ADR already stated the resolution behaviour the clauses change | `docs/adr/single_source_model_recommendations.md`, `## 2026-10-20` |
| The capability restriction is not taken | the operator ruled it out and kept the free `pi -p` invocation | this record; the owning row's amendment |
| The reviewer pair stays pinned in its script and is named a designed exception | one role line names one pair, and the reviewer contract needs two model families | the ADR entry, the provider `**Which model.**`, the skill contract |
| An untagged dispatch uses `_IMPLEMENTER` rather than the startup default | a role keeps the table in the path, and an unattended run keeps moving | `AGENTS.md`; the ADR entry |
| Resolution runs before initialisation, and `test -f` decides a missing file | the old ordering turned one wrong path into a blocked resolution | `AGENTS.md`; the provider `**Which model.**` |
| The owning row's out-of-scope clause about the reviewer pin is amended, not left standing | it contradicted the rule this iteration lands | the roadmap row |
| The iteration type is Workflow | every changed file is an instruction, a skill contract, or a record | this record |
| The owning row closes on its instruction half, with its remainder transferred to the two rows it names | the operator directed the fix, and an open row whose own text declines its work is a false task | the row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The reviewer script pins `openrouter/z-ai/glm-5.3-flash` and `opencode-go/step-5-preview-free` outside the role table | design gap, resolved in scope | recorded as a designed exception in the ADR, the provider layer and the skill contract; no code change | this record's Decisions, `## 2026-10-20` |
| The owning row's "Out of scope" clause defended that pin as legitimate, and this iteration contradicts it | record defect | the row argued against its own rule | fixed in the row; clause and retraction removed |
| The census handover and report still carry the three off-table pairs as "the enabled model families" | record defect, closed records | two closed records misstate what ran | operator ruling; ruled out of scope in `## Scope` |
| `opencode-dispatch` keeps its own default model, which shadows the table on that path | pre-existing | a role's value never reaches that path | roadmap row `The dispatch-rule surface` |
| The role table is gitignored, so a model change appears in no diff and no handover | pre-existing | a value change is invisible to review | roadmap row `The role table moves into version control` |
| The 2026-10-20 roadmap-maintenance pass found this iteration's row keeping a retired exclusion beside its retraction (3.2) | record defect, this surface | the row contradicted the handover's own claim | fixed in the row; one statement remains |
| The same pass found the promoted M3.6.3 section carrying no objective and no scope paragraph (3.11) | record defect, this surface | the summary table claimed a state the section did not support | fixed; the section gains an objective and a scope paragraph |
| The same pass found two all-closed parents still expanded (2.4) | record defect, pre-existing | compaction is milestone grain | `/milestone-close` |
| The same pass found 28 closed rows carrying narrative, 4 of them with no handover link (3.6) | record defect, pre-existing | closed rows restate what the handover owns | roadmap row `Roadmap decision-row format drift` |
| The same pass found stale line references, version literals, a renamed-away script, and two redundant ordering blocks (3.13, 3.4) | record defect, pre-existing | rows carry facts the tree can falsify | new T8 row `The roadmap row carries no stale fact and no repeated ordering block` |
| The owning row's subject is a capability restriction the row itself records as declined, while its remainder sits under two other rows (3.2 escalation) | task set | an open row whose stated work will not happen | resolved on operator direction: the row closes on its instruction half, and its remainder transfers to the two rows it names |

## Completed

| File | Change |
|---|---|
| `AGENTS.md` | `## Model Recommendations`: the exemption is gone, a roleless dispatch uses `_IMPLEMENTER`, precedence stated once, resolution ordered before initialisation with `test -f` |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the dispatch bullet pins the role and its pair; `**Attribution.**` records the role or `startup default`; `**Which model.**` states the two rungs, the stop, the multi-seat exception, and the resolver |
| `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/SKILL.md` | the contract states a role-resolved pair, the designed exception, and its provenance |
| `~/.pi/agent/AGENTS.md` | installed copy, identical to the repository source |
| `~/.pi/agent/skills/pi-reviewer-dispatch/SKILL.md` | installed copy, identical to the repository source |
| `docs/adr/single_source_model_recommendations.md` | `Current:` moves to 2026-10-20 with the resolution entry, its rationale, rejected alternatives and edge cases |
| `devlog/discussions/20261019-design-settled-neutral_principle_census.md` | arm B corrected to one coder per role line, with its `[CORRECTION]` tag; the design was removed in handover `20261020-06` |
| `devlog/roadmap.md` | M3.6.3 promoted to `In progress`; the owning row amended with the landing note and its remainder |
| `devlog/discussions/20261019-report-settled-neutral_principle_census.md` | the model attribution gains its provenance paragraph and a `[CORRECTION]` tag; the pairs and results are unchanged; the report was removed in handover `20261020-06` |
| `devlog/handovers/archive/20261020-01-workflow-model_selection_instruction_surface.md` | this record |

[CORRECTION -- 2026-10-20: the neutral-census design and report named above were removed in handover 20261020-06; the paths no longer resolve.]
