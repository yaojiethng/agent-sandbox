---
date: 2026-11-18
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The reply names the principle and the choice it changed

## Objective

Adopt `poteto-mode`'s wording for the naming rule in the provider layer surface, and re-scope the routing-miss row to the check that is actually missing rather than to a record that already exists.

## Scope

The operator read the row and asked whether a rule to name a principle and navigate to its leaf had been lost in the rewrite. It had not. The check ran over three carriers.

| Question | Answer |
|---|---|
| Did the rewrite remove the clause? | No. `git show 64434b1d:` reads "Read the leaf skill in full for any principle you apply. The agent names each entry when it applies." The rewrite merged the two sentences and kept the substance. The clause entered at `68f845b2` and no commit removes it. |
| What does the derivative skill say? | `poteto-mode/SKILL.md:15`: "In your reply, name each principle that shaped a decision and the specific choice it changed. Cite only principles whose leaf SKILL.md you read this session." `git log -S"specific choice"` over the provider file returns nothing, so those two clauses never landed rather than being removed. |
| Does the method work with pi? | Navigation does: each skill's name, description and absolute path is injected, so a leaf is one `read` away, and `/skill:name` forces a load. The naming is unenforced, since nothing reads a reply. |

The row's premise failed the same read. It said nothing holds a hit, and the naming rule puts every hit in the reply, which the session log holds. The gap is the check, so the row now names a `gate` over the naming rather than a new record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The surface carries the operator's chosen wording, verbatim. | Compare against `poteto-mode/SKILL.md:15`. | Accepted. Both sentences match word for word. |
| The row states the check and not the record. | Read the row against the three-carrier table above. | Accepted. |
| The gates and the surface check pass, and the installed copy matches. | `scripts/lint.sh`, `scripts/check_instruction_surfaces.sh`, `diff` against `$AGENT_HOME/agent/AGENTS.md`. | Accepted. The suite is green at `TEST_PARALLEL=2`, 1642 of 1642. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The wording is `poteto-mode`'s, verbatim, rather than a paraphrase. | The operator asked for it, and a paraphrase of a rule already reviewed elsewhere is a second version with no reader. | This record; the surface. |
| The same words now stand in two files. | The personal skill and the provider surface are read by different loads and neither links the other, so the duplication is a cost the operator accepted when choosing the wording. | This record. |
| The row keeps its identity and changes its statement. | The defect is one subject, a hit that leaves no trace; the statement was wrong about where the trace goes. | `devlog/roadmap.md`. |
| The check is not added in this iteration. | The row states the intent and leaves the method to its doer, and the surface change was the operator's ask. | This record; the row. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row asserted that a hit leaves no record while the surface required a record in the reply. | Record | A row whose premise is false scopes the work at the wrong size, and this one would have built a store beside the reply that already existed. | Fixed in this iteration: the row is re-scoped. |
| The suite at its default job count trips a per-file deadline, and the failing file is green on its own. | Gate | `test_doc_wrap_legacy_gate.sh` takes 27s alone and exceeds its own 45s budget under eight parallel jobs, so a red suite says nothing about this iteration's change, which is Markdown. | The existing row on the parallel runner's per-file deadlines, M3.1.2. |
| `AGENTS.md` and `poteto-mode` state the naming rule differently, and only the derivative carried the checkable half. | Carrier | A rule that names the choice changed can be checked by asking which choice; one that names only the principle cannot. | Fixed in this iteration, by adopting the wording. |

## Completed

| File | One-line change summary |
|---|---|
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The preamble adopts the two sentences: name the principle and the choice it changed, cite only leaves read this session. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | The routing-miss row becomes the check on the naming rule. |
| `devlog/handovers/M3.3.7/20261118-05-workflow-naming_rule_wording.md` | This record. |
