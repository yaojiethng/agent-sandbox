# Agent Handover

**Date:** 2026-09-27
**Milestone:** M3 - Autonomous Task Execution, Manual Review Workflow
**Type:** Workflow
**Status:** Closed

## Objective

Make the task-to-iteration mapping explicit and single-sourced across the policy files, and correct the `AGENTS.md` files where that mapping is wrong or restated. Touching more files means more chance of misalignment, so the mapping and both instruction files are one scope, not three.

## Scope

A unit is one roadmap task scoped as a vertical slice, landing as one commit with one handover. An iteration is one unit. A task that does not fit that shape takes one of two named handling methods: split, when every part is a working increment, or consolidate, when the parts are steps. A section-at-a-time review cadence is a proposal rule and sets no unit count.

A provisional result from an open exchange is written to a record before the next commit, and its decisions, actions and deferred items move into the handover and the Roadmap when the iteration closes.

| Site | Change | Status |
|---|---|---|
| `docs/operations/iteration_policy.md` | the unit rule and both handling methods in Step 2, where the boundary is set; the write-back rule in the minor loop | done |
| `docs/operations/git_policy.md` | a fourth `wip:` trigger for an open exchange, beside the three discretionary ones | done |
| `workflow/coding-agent/prompts/auto.md` | the unit rule resolves its contradiction, and links to the binding rule | done |
| `AGENTS.md` (project layer) | the scoping guidelines; the iteration lifecycle trimmed to links; the handover rules land here | done |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the handover rules move out, leaving a pointer to the project | done |
| `devlog/AGENT_FEEDBACK.md` | two `legacy:` recurrences: record discipline and the edit-tool anchor-row mode | done |
| `devlog/roadmap.md` | a dated amendment to the scope-to-unit row, which stays open | done |

## Carried forward

| Item | From handover |
|---|---|
| A correction crossing two iterations has no owner | `20260927-07-workflow-correction_principle_across_records` (routed to `roadmap.md`) |
| Marker ordering for two corrections to one roadmap row | `20260927-07-workflow-correction_principle_across_records` (routed to `roadmap.md`) |
| Measure the cost of the fold against a commit per correction | `20260927-07-workflow-correction_principle_across_records` |
| Define "left this container" as a checkable condition | `20260927-07-workflow-correction_principle_across_records` |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | The unit rule and both handling methods are stated once, in the policy that owns the boundary, and the other sites link to it rather than restate it | read Step 2, then check the three referencing sites for restatement | Agent [x] accepted: the rule is in `iteration_policy.md` Step 2; `AGENTS.md` carries the shape and the two method names with a link, `auto.md` links to the binding rule, and `git_policy.md` links for the trigger |
| AC2 | The project `AGENTS.md` no longer restates the iteration mechanics its policy files already state | read the iteration lifecycle section | Agent [x] accepted: the section is links, the operator's signal phrase, and the three handover rules; the one-commit paragraph, which restates `iteration_policy.md` and which the session broke, is gone |
| AC3 | The handover rules live in the project `AGENTS.md`, and the unique rule is preserved verbatim while the two that restate a policy become links to their owners | read both `AGENTS.md` files | Agent [x] accepted: the dominant-activity rule is verbatim, and the other two link to `iteration_policy.md` and `roadmap_policy.md` |
| AC4 | Every added link resolves from the file that carries it, including the seeded provider file | a link check over the five files | Agent [x] accepted: the first provider link was dead from both the repo and the seed location, and is now a named path |
| AC5 | An open exchange's result has a destination, and a commit type that is not delivery | read the write-back rule and the `wip:` list | Agent [x] accepted: `iteration_policy.md` gives the destination and the provisional status, `git_policy.md` gives the trigger beside the three discretionary ones |
| AC6 | The lesson is recorded in `AGENT_FEEDBACK.md` as a recurrence on the existing record-discipline entry, with no sibling entry on the same topic | read the entry | Agent [x] accepted: `legacy: 2026-09-27` added, `state: open` unchanged |
| AC7 | The fold itself is stated as the worked example in that entry, since it is the instance that made the divergence visible | read the entry | Agent [x] accepted: the entry names the ten-commit break and the reading taken |
| AC8 | This iteration lands as one commit, which is the practice the change is about | `git log` | Agent [x] accepted: the delivery commit carrying this handover is the iteration's only commit |
| AC9 | Lint gate clean and the suite green at 1001 units | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] accepted: lint clean across 3 gates, 1001 passed, 0 failed, 0 skipped |
| AC10 | Handover committed with the delivery commit, Status Closed | `git log` | Agent [x] accepted: the commit carries this handover with Status Closed |

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/iteration_policy.md` | owns the task-to-iteration mapping |
| `docs/operations/git_policy.md` | owns the commit trigger an open exchange fires |
| `AGENTS.md` (project layer) | always loaded; carried the restated mechanics and receives the handover rules |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | always loaded; carried the handover rules |
| `workflow/coding-agent/prompts/auto.md` | the dispatch-side unit rule, which contradicted itself |
| `devlog/AGENT_FEEDBACK.md` | the lesson's home |
| `devlog/roadmap.md` | the scope-to-unit row's amendment |
| `devlog/handovers/archive/20260927-08-workflow-unit_boundary_proposal_and_commit_granularity.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The fold is one commit, not one per section | operator direction, and the unit rule's own test: one subject writes the diff | the previous handover's Decisions, by correction |
| One scope, not three units | operator direction: the mapping and both instruction files move together, because touching more files means more chance of misalignment, and split into iterations they would touch the project `AGENTS.md` twice | this handover, Scope |
| The binding rule lives in `iteration_policy.md`, and the other sites link | the rule decides the boundary where the scope is confirmed, and a second full statement is a second thing to drift | `iteration_policy.md` Step 2 |
| The project `AGENTS.md` keeps the shape and the two method names, not the criteria | the always-loaded file needs the test to act on, and the criteria have one owner | `AGENTS.md`, scoping section |
| One handover rule moves verbatim, two become links | two of the three restate `iteration_policy.md` and `roadmap_policy.md`, and the dominant-activity rule appears in no policy file | this handover, AC3 |
| The provider file keeps a pointer, not a relative link | the seeded copy sits outside the repository, so a repo-relative path resolves nowhere | `src/reasoning/providers/pi/config/agent/AGENTS.md` |
| The scope-to-unit roadmap row stays open | its open question is whether an agent can derive a work-unit table at all, which a unit definition does not answer | `roadmap.md`, dated amendment |
| The edit-tool recurrence is recorded in the same iteration | the failure recurred this session and its mitigation already names the mode, so the record was the honest place for it. Beyond the original released scope, and separable | this handover, AC6 |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| `auto.md` contradicted itself on unit size: the lead test said "the smallest change that lands" and the paragraph below said "one feature end to end" | record defect | the fine-grained reading had the normative weight, since it was the bulleted test, and it is the reading taken | resolved by the rewrite: the lead test carries the roadmap task and the slice, and the fine-grained phrase is gone |
| The one-commit rule was already explicit in `iteration_policy.md` and the provider `AGENTS.md`, and was broken anyway | process defect | the gap was not a missing one-commit rule; it was a unit definition with no roadmap-task anchor, so a single task looked divisible | resolved by the unit definition and its single owner |
| An open exchange's result had two destinations and no rule, so a grill answer was either committed as delivery or lost | process defect | two mid-session results became delivery-typed commits with no `wip:` and no squash, a false delivery surface in a project `AGENTS.md` whose own text claimed the opposite discipline | resolved by the write-back rule and the fourth `wip:` trigger; recorded as a recurrence on the record-discipline entry |
| The project `AGENTS.md` restated the one-commit rule, and the provider file carried the handover rules | misplacement | a rule in two always-loaded files is two rules to drift, and the provider file is infrastructure the project does not own | resolved: the lifecycle section links, and the handover rules move to the project |
| The scope-to-unit row presupposed a unit definition no file stated, and its own AC claimed the vertical-slice language the template carried only as "split vertically" | record defect | the AC passed on a phrase in its own text; a bad grep for two words missed the real one and produced a wrong finding to the operator | resolved by the row's dated amendment; the AC's claim is not repeated |
| The anchor-row edit mode recurred while inserting a roadmap row, after its mitigation was already recorded | recurrence | the row's text was lost and restored from `HEAD`, and the byte-identical check passed while the neighbouring trial row's body stayed appended to the marker-ordering row; the close read-back caught it | routed to the edit-tool entry's `legacy:` |
| `surface` as a verb | vocabulary question | the operator ruled it means to raise in chat, and has seen no other use | closed by ruling; no edit |
| `lapse` | vocabulary question | the operator confirmed it is acceptable, with its definition one hop away in `documentation_policy.md` | closed by ruling; no edit |
| `seed` | vocabulary question | the operator ruled it means to implant a starting data set, and the use is consistent across files | closed by ruling; no edit |
| "the spec" names no document | loaded language | the operator ruled it out of scope for this iteration: the spec as a document has fallen out of use, and tight requirements lists and implementation plans carry the content now | triaged to Deferred items for the next iteration |

## Completed

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | the unit rule and both handling methods in Step 2; the write-back rule in the minor loop; the close paragraph restored to its original state |
| `docs/operations/git_policy.md` | a fourth `wip:` trigger for an open exchange |
| `workflow/coding-agent/prompts/auto.md` | the lead unit test restated as one roadmap task and one vertical slice; the fine-grained phrase replaced; the crossing distinction added; a link to the binding rule |
| `AGENTS.md` (project layer) | the scoping guidelines added; the iteration lifecycle trimmed to links; the handover rules received |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the handover rules replaced by a pointer to the project |
| `devlog/AGENT_FEEDBACK.md` | two `legacy:` recurrences: record discipline and the edit-tool anchor-row mode |
| `devlog/roadmap.md` | a dated amendment to the scope-to-unit row; the spec-language row opened for the next iteration; the trial row's body removed from the marker-ordering row, caught at the close read-back |
| `devlog/handovers/archive/20260927-08-workflow-unit_boundary_proposal_and_commit_granularity.md` | this handover |

## Deferred items

| Item | Why deferred | Where it goes |
|---|---|---|
| Whether an agent can derive a work-unit table at all, and who should | the definition is now stated, but derivation from a whole plan is a separate question the definition does not answer | `roadmap.md`, the scope-to-unit row, which stays open |
| Define where the spec lives, or retire the word | the operator ruled it out of scope for this iteration. The policy says "the confirmed spec" in Step 6, reads "spec" in the Step 4 order, and says "spec gaps" at close, but the spec as a document has fallen out of use; tight requirements lists and implementation plans carry the content | `roadmap.md`, the spec-language row, which opens as `20260927-09` |

## What's Next

The spec-language row in the T1 list opens as handover `20260927-09`: retire the dead word `spec` and name its surviving meanings -- an implementation plan, an agreed design, or a narrowed task requirement as recorded in the roadmap. Boundary: language only; mechanism changes to how roadmap entries are recorded belong to the Roadmap-mechanism rewrite study. The scope-to-unit row's Open half and the derivation deferred item stay carried.
