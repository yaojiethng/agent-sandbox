# Agent Handover

**Session date:** 2026-04-28
**Milestone:** M2.3 — Workflow Audit and Policy Refactor
**Session type:** Workflow
**Status:** Active

## Objective

Continue workflow audit: rewrite major loop with entry/exit conditions and gates; distil reflection session findings into policy; add knowledge persistence rules to handover_policy; produce story document on sequencing pain points.

## Scope

- iteration_policy.md: major loop rewrite with entry/exit conditions, three named gates, skip conditions for open milestone; Step 4 trimmed; grep rule moved to handover_policy; recovery check framing updated
- handover_policy.md: Mid-session findings section, three named write triggers, unit naming convention, carry-forward escalation rule, grep rule at scope confirmation, recovery check reframing
- roadmap_policy.md: carry-forward escalation rule at session close
- documentation_policy.md: code example propagation check; brevity pass
- new-session-v2.md: recovery check framing updated
- story_sequencing_and_knowledge_persistence.md: new story document

## Carried forward

| Item | From handover |
|---|---|
| All policy files produced in prior session | 20260427-01-workflow-policy_audit_and_refactor |

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](../operations/iteration_policy.md) | Major loop rewrite; three gates; skip conditions; Step 4 trim |
| [`docs/operations/handover_policy.md`](../operations/handover_policy.md) | Mid-session findings; write triggers; carry-forward escalation; grep rule; recovery check reframe |
| [`docs/operations/roadmap_policy.md`](../operations/roadmap_policy.md) | Carry-forward escalation rule |
| [`docs/operations/documentation_policy.md`](../operations/documentation_policy.md) | Code example propagation check; brevity pass |
| [`docs/concepts/agent_workflow.md`](../concepts/agent_workflow.md) | Full rescope as policy map (prior session) |
| [`docs/discussions/story_sequencing_and_knowledge_persistence.md`](../discussions/story_sequencing_and_knowledge_persistence.md) | New story document |
| `docs/skills/user/new-session/new-session-v2.md` | Recovery check framing updated |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Major loop converted to entry/exit condition table with three named gates | Gate 1 selects milestone, Gate 2 selects sub-milestone (also Trigger B entry point), Gate 3 confirms ready to session | iteration_policy.md |
| Step 1 and Gate 1 skipped when milestone already open | Major loop enters at Gate 2 for mid-milestone sub-milestone selection and Trigger B path | iteration_policy.md |
| Milestone promotion moved after Gate 1 | Prevents agent auto-promoting wrong milestone; operator decides what comes next | iteration_policy.md |
| Step 4 action cell trimmed; grep rule moved to handover_policy | Table cells describe what a step does, not how; spec production rules belong at scope confirmation | iteration_policy.md, handover_policy.md |
| Recovery check reframed: "does roadmap reflect prior handover's claimed state" | Broader than Trigger B check alone; catches any incomplete close sequence | handover_policy.md, new-session-v2.md |
| Mid-session findings section added to handover format | Append-only buffer for discoveries that change the plan; survives compaction; triaged at close | handover_policy.md |
| Three named write triggers: task completion, discovery, steering received | Scheduling issue — model does not know when to write; explicit triggers resolve ambiguity | handover_policy.md |
| Carry-forward escalation: one hop via Next session, roadmap after that | Findings deferred more than once fall through the handover chain; roadmap is the durable store | handover_policy.md, roadmap_policy.md |
| Grep rule added to scope confirmation | Code blocks written from memory are primary source of spec bugs; file must be read before spec is written | handover_policy.md |
| AC satisfiability check added to Gate 2 (minor loop) | A criterion that fails on correct implementation is a spec bug; catch at gate not at pre-close | iteration_policy.md |
| Story opened for sequencing and knowledge persistence pain points | Immediate fixes address symptoms; structural question requires a planning session | story_sequencing_and_knowledge_persistence.md |
| wrapup.md assessed — nothing to distil into policy | Prompt template faithfully mirrors handover_policy; no unique content | This handover |

## Completed this session

| File | Change summary |
|---|---|
| `iteration_policy.md` | Major loop rewritten with entry/exit conditions and three named gates; skip conditions for Step 1 and Gate 1; overview table updated; Step 4 trimmed; AC satisfiability check at Gate 2; recovery check framing updated |
| `handover_policy.md` | Mid-session findings section added; During the session rewritten with three named write triggers and unit naming convention; carry-forward escalation and findings triage at close; grep rule at scope confirmation; recovery check reframed |
| `roadmap_policy.md` | Carry-forward escalation rule added to session close Step 8 |
| `documentation_policy.md` | Code example propagation check under Enforcement Rules; brevity pass on agent-facing documents and concepts docs sections |
| `new-session-v2.md` | Recovery check framing updated to match handover_policy |
| `story_sequencing_and_knowledge_persistence.md` | New story: four pain points, five open questions, four candidate directions |

## Deferred items

None.

## Next session

**Milestone:** M2.3 — Workflow Audit and Policy Refactor
**Status:** Workflow audit complete. All policy changes produced as artifacts. Pending operator review and application to repository.

**Outstanding implementation thread:** M2.3 apply_workspace refactor (Changes 1–7) complete per `20260428-03-impl-apply_workspace_refactor.md`. Remaining M2.3 task groups in dependency order:
1. `SESSION_STATE` file / `$SESSION_TS` persistence bug
2. `package-branch` skill amendments (depends on SESSION_STATE)
3. Interactive confirmation flag
4. Test suite repair (partially depends on SESSION_STATE)

**Story opened this session:** `story_sequencing_and_knowledge_persistence.md` — requires a planning session before any implementation is scoped.

**Watch-outs:**
- New handover format includes `## Mid-session findings` — next implementation agent must populate or null-mark at session open
- Carry-forward escalation rule is new — first session to use it should verify the roadmap entry format for escalated findings is legible alongside planned task entries
- Major loop now has three named gates and skip conditions — next planning session agent should read the full major loop table before proceeding
