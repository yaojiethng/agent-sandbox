# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Execute U3 of the M3.2.1 loop-to-workflow migration (redesigned repeatedly per operator steering 2026-09-28): author the `/plan` and `/milestone-start` prompts to match actual major-loop practice, strip the now-replaced major-loop procedure from `iteration_policy.md` Major Loop and `milestone_policy.md` (option B), park the close-prior content in a `/milestone-close` stub for U4, and add the `advisor` review prompt. Final forms: `/plan` is a plan-session-start procedure parallel to `/iter`; `/milestone-start` is a single general fractal protocol that factors the roadmap task pool into a named milestone.

## Scope

One unit, one commit, one handover. U3 redesigns the major-loop prompt pair to match actual practice (operator steering, 2026-09-28). This unit drafts **stubs**, not final prompts; refinement happens in the `Four per-prompt quality passes` roadmap tasks after the migration (U1-U4).

- **`/milestone-start`**: a single general fractal protocol at any nesting level: orient, audit the task pool via gm's decision axes, propose ONE reorganization decision (covers stale/overfull/split milestones and nesting), organize tasks into bins, promote and record. Points to `roadmap_policy.md` fractal-numbering rules.
- **`/plan`**: plan-session-start procedure parallel to `/iter` (orient, open session with handover, gather context, align scope, interview via grill-me, decide outcome, write back). Deliverable is always documents.
- **Option B**: strip the major-loop procedure from the policies (`iteration_policy.md` Major Loop, `milestone_policy.md`), leaving rules and links; the close-prior content is parked in a `/milestone-close` stub until U4.
- **`advisor` prompt**: new, formalizing the advisor-review workflow; four review-sharpening revisions landed.
- The ADR state diagram is unchanged.

Files in scope: `workflow/coding-agent/prompts/milestone-start.md`, `workflow/coding-agent/prompts/plan.md`, `docs/operations/milestone_policy.md`, `docs/operations/iteration_policy.md` Major Loop, `devlog/roadmap.md` (U3 row).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | `plan.md` is a plan-session-start procedure parallel to `/iter` (Orient, open session with handover, gather context, align scope, interview, decide outcome, write back), stating plan acceptance positively | head + section map of `plan.md` | Agent [x] accepted |
| AC2 | `milestone-start.md` is a single general fractal protocol (finish at any nesting level): orient, audit task pool via gm's axes, propose ONE reorganization decision (covers stale/overfull/split), organize into bins, promote and record; links the fractal-numbering rules | head + section map of `milestone-start.md` | Agent [x] accepted |
| AC3 | `iteration_policy.md` Major Loop keeps rules but carries no step-by-step procedure; links to the prompts | read of the Major Loop section; grep for prompt links | Agent [x] accepted |
| AC4 | `milestone_policy.md` keeps its rules and links to the prompts, carries no step-by-step procedure | read + grep for prompt links | Agent [x] accepted |
| AC5 | The prompts' policy links are root-relative per convention and the grill-me link resolves | grep the links; file existence | Agent [x] accepted |
| AC6 | `plan.md` reviewed as agent-context by a fresh `glm-5.3-flash` subagent; consensus that it has no philosophical discussion or irrelevant backlinks/context for in-the-moment execution | subagent conversation | Agent [x] accepted |
| AC7 | `advisor.md` exists in `src/reasoning/agent/prompts/`, formalizing the advisor-review workflow (invocation, brief construction, leader triage, consensus loop), and is reviewed to consensus by a fresh `glm-5.3-flash` subagent | head + section map of `advisor.md`; subagent conversation | Agent [x] accepted |
| AC8 | `milestone-close.md` carries a "Prior milestone close (parked for U4)" stub preserving the Step 1 close-prior content removed from `iteration_policy.md` Major Loop | grep for the parked section | Agent [x] accepted |

All eight criteria accepted. None pushed.

## Hot files

| File | Change |
|---|---|
| `devlog/roadmap.md` | roadmap maintenance (U1/U2/U3 checked) + U3 row reworded; T8 writing-conventions task added |
| `workflow/coding-agent/prompts/milestone-start.md` | rewritten as single fractal protocol; completed this unit |
| `workflow/coding-agent/prompts/milestone-close.md` | parked close-prior stub added; completed this unit, U4 formalizes |
| `workflow/coding-agent/prompts/plan.md` | rewritten as plan-session-start; completed this unit |
| `src/reasoning/agent/prompts/advisor.md` | new prompt + four revisions; completed this unit |
| `docs/operations/iteration_policy.md` Major Loop | option B strip; completed this unit |
| `docs/operations/milestone_policy.md` | option B strip (intro link); completed this unit |
| `devlog/AGENT_FEEDBACK.md` | added the handover-table / trailing-newline class entry |
| `devlog/handovers/archive/20260928-08-workflow-major_loop_into_plan_and_milestone_start.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Option B for U3: the major-loop procedure is stripped from `milestone_policy.md` and `iteration_policy.md` Major Loop, leaving rules + links; the redefined procedure lives in the prompts | operator confirmed option B is acceptable (2026-09-28) | this handover |
| `/milestone-start` opens the next major milestone (mechanical: an open milestone is required; M3 is the logical next progression) | operator's described practice; not a researched choice | this handover |
| `/plan` is a catch-all planning helper: far-sight scoping (reorganize tasks, drop stale, arrange tracks, choose sub-milestone), design refinement (grill-me interviews, implementation plans, ADRs); deliverable is always docs/prose records | operator's described practice; only commonality is deliverable type | this handover |
| `/plan`'s start gate is the grill-me "confirm the problem exists" preamble; its end gate is a write-back gate producing a propagation checklist (per `propagation-check.md`), not runnable acceptance criteria | operator resolved the gate-shape question (2026-09-28) | this handover |
| ADR state diagram is unchanged; `/plan` is a workflow helper, not a loop with invariant state | operator confirmed the diagram is fine (2026-09-28) | this handover |
| `/plan` may be skipped when the task is already well-scoped (power through with `/auto`) | operator noted the past practice | this handover |
| This unit drafts prompt stubs; the `Four per-prompt quality passes` refine `/plan` and `/milestone-start` to a final bar after the migration | operator set the stub scope (2026-09-28) | this handover |
| `/milestone-start` and `/plan` are decoupled and self-contained, flexible to invocation order; they do not chain into each other | operator review feedback: a prompt chain might leave the agent not knowing when to terminate (2026-09-28) | this handover |
| `/plan` carries a Goal section binding the session to a stated direction (operator or agent direction) | operator review feedback: a plan session must not roam the codebase (2026-09-28) | this handover |
| `/plan` delegates the interview to the `grill-me` skill instead of restating its preamble | operator review feedback: avoid duplicating grill-me content (2026-09-28) | this handover |
| `/plan` is the anchor layer with responsibilities grill-me cannot do: start the iteration and anchor the problem in writing in the handover; search related documents, devlog discussions, past handovers and roadmap tasks; get alignment/context from the operator; set scope and deliverables; then pass the anchored context to `grill-me` for the interview | operator control-thought: a core-responsibilities division between `/plan` and `grill-me` (2026-09-28) | this handover |
| `/plan` also decides the disposition of the grill-me response: what to do with the output -- write back to a report, design document, roadmap, or handover, or persist in chat. grill-me is scoped to the interview; plan owns the outcome routing | operator control-thought on grill-response disposition (2026-09-28) | this handover |
| A new `advisor` prompt is added in `src/reasoning/agent/prompts/` formalizing the advisor-review workflow used this session, self-reviewed to consensus by a fresh `glm-5.3-flash` subagent | operator requested the prompt mid-iteration (2026-09-28) | this handover |
| `plan.md` is rewritten as a plan-session-start procedure parallel to `/iter`, without the new "anchor" term, without a plan-enforced milestone gate, and stating plan acceptance positively (what it is, not what it is not) | operator inline comments on `plan.md` (2026-09-28) | this handover |
| U3 over-stripped: the `iteration_policy.md` Major Loop table removal dropped Step 1 "Close prior milestone", which belongs to `/milestone-close` (U4, not yet written). Correction: park the close-prior content in a `/milestone-close` stub now so it survives; U4 formalizes it. The shaping steps (Gate 2 select sub-milestone, Steps 3-5 stories/design/resolve, Gate 3 release) go into `milestone-start.md` | operator sequencing correction (2026-09-28) | this handover |
| `milestone-start.md` carries the shaping work the major-loop role subsumes: select sub-milestone, open/revise stories, investigate/design, resolve stories, release for execution -- its end state is a milestone-shaped bundle of work tasks to take on; it does not delegate the interior shaping to `plan` | operator correction on the milestone-start boundary (2026-09-28) | this handover |
| Operator feedback: the main agent invoked the advisor too often this iteration; from here on, the main agent alone is sufficient for the remaining work | steering on review cadence (2026-09-28) | this handover |
| Operator refined `milestone-start` further (2026-09-28): it must distinguish milestone-finish vs sub-milestone-finish; when no next sub-milestone exists, it does a gm-style audit of roadmap task categories to suggest candidate sub-milestones (possibly several, e.g. M3.2.1 and M3.2.2), waits for the operator to choose and title them, assigns tasks to each, and if several sub-milestones, promotes one as next active and updates all records. For end-of-milestone: if a next milestone exists but may be stale/subsumed/wrong, help rescope and renumber | operator steering (2026-09-28) | this handover |
| `milestone-finish` and `sub-milestone-finish` are the SAME protocol: the milestone numbering is fractal, so `milestone-start` draws from the task pool (all remaining roadmap tasks, scoped to the current lineage) and factors a milestone-shape; skipping a sub-level means the next milestone goes up one nesting level. `milestone-close` is the same single fractal protocol (U4). Copy gm's decision axes (Size/Progress/Impact; easiest/highest-leverage/most-urgent; landing order) but do not be gm: milestone-start factors/reorganizes tasks into a milestone, gm picks one task. A new sub-milestone is a new empty bin; fill it, move badly-filed tasks, supersede or split old bins -- all at operator command | operator unification of the milestone protocols (2026-09-28) | this handover |
| `milestone-start` reorganization sequencing: the milestone suggestion covers stale and overfull milestones, and the reorganization is a single presentation and single decision; after the milestones are chosen, organization is a subsequent step; after organization, promotion | operator rewrite feedback (2026-09-28) | this handover |
| After implementation, a fresh `glm-5.3-flash` subagent reviews `plan.md` as a prompt (agent-context authoring, no philosophical/irrelevant backlinks) until consensus | operator requested the review (2026-09-28) | this handover |

## Findings

| Finding | Type | Impact | Triage |
|---|---|---|---|
| The roadmap still shows the U1 and U2 sub-rows of "Move the major and minor loops out of policy into workflows" as unchecked, though handovers `20260928-05` and `20260928-07` landed and closed them | contradiction | a reader sees the migration as one unit behind; the roadmap does not reflect the state the prior handover claims | Triaged to: Completed (roadmap maintenance applied, U1/U2 checked) |
| Operator confirms `/plan`'s gates: start gate is a soft marker, end gate is the write-back release point. This unit drafts prompt stubs only; the `Four per-prompt quality passes` refine them. After implementation, a fresh `glm-5.3-flash` subagent reviews `plan.md` as a prompt (agent-context authoring, no philosophical/irrelevant backlinks) until consensus | steering | this iteration | Triaged to: Decisions + What's Next |
| The `write` tool drops the trailing newline on a full-file write, failing MD047; the recurring Table-column-count / trailing-newline handover defect class the prior handover (U2) asked to monitor in U3 recurred as this defect, fixed by appending a newline | recurring record defect | current iteration | Triaged to: AGENT_FEEDBACK [A] 2026-09-28 (handover-table stray-pipe and write-tool trailing-newline class) |
| Operator inline comments on `plan.md`: (1) drop the milestone-open gate - the handover assigned to a milestone is the only operational restriction; (2) drop the new term "anchor/anchoring" - it is not used elsewhere in the project; (3) make `/plan` parallel to `/iter` as a "plan session start" procedure (plan replaces iter for planning/design work), referencing iter's imperative form; (4) formalize Align/scope in the same imperative format; (5) state what plan acceptance is, not what it is not | steering / scope change | current iteration | Triaged to: Decisions + Completed (plan.md rewrite) |
| The documentation_policy writing-conventions section must be re-ingested repeatedly (the agent keeps needing this file); propose extracting it to its own file linked from AGENTS.md, or subsuming it into AGENTS.md | recurring burden | roadmap | Triaged to: roadmap task (T8 Writing-conventions section extraction or subsume) |
| The handover-table stray-pipe defect class (flagged for monitoring in U3) recurred: an edit merged two Decision-table rows into one line (MD056), caught by lint before pre-close | recurring record defect (recurrence 4) | current iteration | Triaged to: AGENT_FEEDBACK [A] 2026-09-28 (same class as above) |
| The handover-table stray-pipe defect class recurred a third time: a Decision-table row was written with a Findings-style fourth cell (MD056), caught by lint | recurring record defect (recurrence 5) | current iteration | Triaged to: AGENT_FEEDBACK [A] 2026-09-28 (same class as above) |
| The rewritten `milestone-start.md` assumed the next major milestone is already fully formed in `roadmap.md`, but no prompt takes that role; the section it subsumed carried the judgment of closing the prior milestone, examining existing tasks, scoping a rough milestone-shaped direction, and choosing to take on the milestone. If that step is lost, milestones are never scoped or written to the roadmap without the operator manually calling `/plan` | design gap | current iteration | Triaged to: Decisions + Completed (milestone-start rewrite) |
| Operator correction: `milestone-start` must also carry the shaping steps of the role it subsumes (open/revise stories, investigate/design, resolve, release), so its end state is a milestone-shaped bundle of work tasks to take on; my draft delegated that interior shaping to `plan`, which is wrong | steering / scope change | current iteration | Triaged to: Decisions + Completed (milestone-start rewrite) |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | roadmap maintenance: U1 and U2 sub-rows of "Move the major and minor loops out of policy into workflows" checked - [x] (landed by handovers `20260928-05` and `20260928-07` but left unchecked) |
| `workflow/coding-agent/prompts/plan.md` | rewritten as plan-session-start procedure parallel to `/iter`: Orient, open session (create handover), gather context, align scope, interview via grill-me, decide outcome, write back; operator's five inline comments addressed; consensus after review |
| `workflow/coding-agent/prompts/milestone-start.md` | rewritten per operator + advisor: single propose-decision (covers stale/overfull/split + nesting), then organize, then promote; fractal-numbering pointer added; bin definition restored |
| `workflow/coding-agent/prompts/milestone-close.md` | gained the parked "Prior milestone close (parked for U4)" stub preserving the Step 1 close-prior content removed from `iteration_policy.md` Major Loop |
| `docs/operations/iteration_policy.md` | Major Loop section: step table replaced with rules + links to the prompts (option B) |
| `docs/operations/milestone_policy.md` | intro updated: adds links to the prompts (option B) |
| `src/reasoning/agent/prompts/advisor.md` | new prompt formalizing the advisor-review workflow: role split, invocation, brief construction, leader triage, consensus loop; self-reviewed to consensus by a fresh `glm-5.3-flash` subagent |
| `devlog/AGENT_FEEDBACK.md` | added the handover-table stray-pipe / write-tool trailing-newline class entry |

## Deferred items

None.

## What's Next

**Sub-milestone:** M3.2.1 - Loops as Workflows. Roadmap maintenance: U1, U2, U3 checked; U4 open; M3.2.1 not complete -- no compaction this iteration.

**Conclusions from this iteration:** `/plan` is a plan-session-start procedure parallel to `/iter`; `/milestone-start` is a single general fractal protocol (one propose-decision covering stale/overfull/split + nesting, then organize, then promote) that links `roadmap_policy.md` for the numbering rules. The advisor prompt now carries a mandatory clean-bill closing line, adjacent-file scope, direct-answers, and an anti-manufactured-finding guard. A fresh agent does NOT have fractal-awareness from a blank context; a two-sentence pointer to `roadmap_policy.md` Fractal Milestone Numbering suffices. The Step 1 close-prior content lives in `milestone-close.md` parked for U4.

**U4** (next unit): write the close procedure into `/milestone-close`, in the same redesigned form as U3 -- as a single general fractal protocol (a milestone and a sub-milestone close through the same prompt, per this iteration's decision), with option B stripping the close procedure from `milestone_policy.md` Closing the Major Loop and `iteration_policy.md` Sub-milestone close and Steps 8-9. The parked "Prior milestone close (parked for U4)" stub in `milestone-close.md` is the seed to expand. Note: the operator's close-practice requirements (resolve tasks, roadmap->changelog via `roadmap_policy.md` Top-level milestone close, resolve AGENT_FEEDBACK, write deferred/new tasks to the next milestone) are fold targets for U4, and the existing `milestone-close-run.md` body is the run template to reconcile.

Then: confirm the redesigned prompts are sound, then the four per-prompt quality passes. Advisor cadence: the operator directed that from here on the main agent alone suffices; invoke the advisor only when the operator explicitly asks.
