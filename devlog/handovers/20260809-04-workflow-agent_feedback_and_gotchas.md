# Agent Handover

**Date:** 2026-08-09
**Milestone:** M2.6.6 — Mount Model: Host-backed Sandbox
**Type:** Workflow
**Status:** Closed

## Objective
Run a workflow exploration session (grill-me style) to design two operator-facing feedback/workflow mechanisms in `devlog/` — AGENT_FEEDBACK (agent-experience feedback, subsumes the existing bash_complaints friction log) and GOTCHAS (operator-recorded agent boo-boos) — and write artifacts summarising the design and the finalized workflow. The workflow is to be fully implemented in a follow-up session.

## Scope
Exploration by conversation. No code/file changes beyond the summary artifacts at session end. The finalized workflow (to be fully implemented next session) comprises:

**Documentation**
- `devlog/AGENT_FEEDBACK.md` and `devlog/GOTCHAS.md` (flat, no-index, per-entry state, STE-clean).
- Subsume `bash_complaints.md`.

**Policy**
- Expand Mid-session findings (shared stream; classify at publish).
- Replace mid-session findings triage gate with review/publish step.
- Pre-close review gate + dismiss/maintain/escalate probation at sub-milestone cleanup.
- Trim Next session (context-only) + always-push-to-roadmap (coupled).
- AGENTS.md pointers.
- Milestone lifecycle reframe (`active → pre-close → close`).

**M3 (record only)**
- Sub-milestone-containment finding; close-script automation; re-word linear/next-task tasks.

**ADR:** none.

## Carried forward
None.

## Acceptance criteria
| # | Criterion | Verifiable by |
|---|---|---|
| 1 | A settled design record (handover) + a finalized-workflow artifact exist in `devlog/` describing the full Bucket-1 implementation list (D1/D2, P1–P6, T1) | `ls devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md` |
| 2 | AGENT_FEEDBACK/GOTCHAS file structure (flat, no-index preamble, per-entry states open/mitigated/probation, dismiss/maintain/escalate, scoped/legacy attributes) is defined in the artifact | grep on artifact |
| 3 | The review/publish step (replacing mid-session findings triage gate) and pre-close review gate + probation are defined | grep on artifact |
| 4 | Next-session trim + always-push-to-roadmap coupling is defined | grep on artifact |
| 5 | M3 additions/re-words (containment finding, close-script, next-session re-word) specified in the artifact AND applied to the M3 section in `roadmap_future.md` | grep on artifact + M3 section in `roadmap_future.md` |
| 6 | STE-clean language principle + doc-review-sweep backlog are recorded | grep on artifact + handover |
| 7 | Operator confirms scope (Q18 list) is complete before artifacts are finalized | Operator in chat |

## Hot files
| File | Why in scope |
|---|---|
| [devlog/discussions/20260809-story-active-bash_complaints.md](devlog/discussions/20260809-story-active-bash_complaints.md) | Existing friction-log precedent; to be subsumed into AGENT_FEEDBACK |
| [docs/operations/iteration_policy.md](docs/operations/iteration_policy.md) | Mid-session findings write-back + session-close triage gates the new mechanism must tie into; minor-loop pre-close review-gate precedent |
| [docs/operations/roadmap_policy.md](docs/operations/roadmap_policy.md) | Sole-task-list change, sub-milestone close/compaction lifecycle, post-close bookkeeping |
| [docs/operations/milestone_policy.md](docs/operations/milestone_policy.md) | Major-loop close; lifecycle reframe destination |
| [AGENTS.md](AGENTS.md) | Wire the agent feedback/gotchas instructions into the collaboration protocol |

## Decisions made this session
| # | Decision | Rationale |
|---|---|---|
| 1 | Two separate files in `devlog/`: `AGENT_FEEDBACK.md` and `GOTCHAS.md` | Distinct intents (agent→operator experience feedback vs operator→agent recorded boo-boos) |
| 2 | `bash_complaints.md` subsumed into `AGENT_FEEDBACK.md` (migrate now, before it grows) | Bash friction is a narrow category of agent experience feedback; file is young so migration is cheap |
| 3 | Flat files; no index layer. Preamble states: a category getting too long is a signal to seek a durable resolution (extract to skill / fix stack), not to build an index | Indexes are a smell; length → durable fix |
| 4 | Recording surface = handover's Mid-session findings, agent-managed, fed by conversation; no separate scratch file | Live stream is conversation; agent wholly manages the handover; no concurrent-write concern |
| 5 | Capture is in-session via expanded Mid-session findings; publish at close (review/publish replaces mid-session findings triage gate) | Reuses existing write-back discipline; captures context while fresh; transient handover vs persistent devlog |
| 6 | Classification/attribution is operator-owned; agent proposes, operator confirms | Agent should not self-classify its own boo-boos as not-its-fault |
| 7 | Gotchas capture tied to mid-turn steering: agent reacts, lists as finding, moves to GOTCHAS.md at publish | Mid-turn steering is the dominant feedback channel |
| 8 | Proposed solutions never self-implemented; interim mitigation recorded on entry; long-term fix scoped+assigned to milestone+roadmap | Operator reviews all solutions |
| 9 | Sub-milestone cleanup (major loop, ~1–2 wks) is the probation review cadence, not daily | Durable-but-not-daily work belongs at milestone boundaries |
| 10 | Cleanup tri-state: **dismiss** (fix held → delete entry) / **maintain** (not stress-tested enough → extend probation) / **escalate** (resurfaced → past-solution-aware re-scope) | Positive/negative/expire closure model |
| 11 | Escalation wording / blast-radius writing is intentionally evolving; note as such in workflow | Will be discovered in practice |
| 12 | Retirement of a failed fix is **not** a roadmap action in general — "add X/remove X" cancel on compaction; work history stays in handover. Named task only when non-trivial blast radius | Keep `Y` as feature set in changelog/docs, not `X` |
| 13 | Resurfacing → past-solution-aware re-scope, optional retirement, `.legacy` annotation preserved on entry | Don't repeat a failed approach; stop maintaining dead weight |
| 14 | Escalated substantive work: high-blast-radius/correctness → **interrupt milestone close** (don't ship shit); low-urgency → top of next sub-milestone | Keep `main`/tags free of known-broken code |
| 15 | Milestone lifecycle reframe: `active → pre-close → close → [post-close admin only if broken]` | All substantive work before close; heavy post-close work is a lifecycle smell |
| 16 | Pre-close carries a formal review gate (agent surfaces ship-shit check items for operator review, minor-loop Gate-3 style) | Close is ceremonial; the real decision happens in pre-close |
| 17 | Close = ceremonial, no decisions; manual-admin checklist for now; close **script automation scoped to M3** | Repo has no `make close-milestone` yet; scope to current state |
| 18 | Post-close = only genuine admin (index prune etc.); documented model, not codified hard | Reframe target for major-loop policy |
| 19 | Handover **Next session** trimmed to context-only (sub-milestone, bookkeeping flag, blocking questions, watch-outs, Conclusions) | Roadmap becomes sole authoritative task list; fewer ambiguous locations |
| 20 | **Roadmap = sole task list**; Deferred items escalate into roadmap named entries at close | Avoids task fall-through; one tracked location |
| 21 | **M3 finding**: milestones aren't always wholly contained; partial implementations from other milestones are urgently needed often. Record under M3; immediate workflow-improvement blockers done now, harmless items deferred to M3 | Operator steering |
| 22 | Agent integration of GOTCHAS = **session-open primer** (load open gotchas at Step 1, avoid/re-check day-to-day; sweep at sub-milestone cleanup; durable housing = fold into a skill when they accumulate) | GOTCHAS must stay short to remain an effective primer; reinforces decision 3 |
| 23 | Operator integration of AGENT_FEEDBACK = **surfaced at sub-milestone pre-close review gate** (agent presents open entries; operator reviews prompt/stack pain points in review frame). Ad-hoc spot-check optional | Natural human checkpoint; operator won't re-read a growing file every session |
| 24 | Both files are **pointed to from AGENTS.md** (GOTCHAS in agent-facing section; AGENT_FEEDBACK adjacent to Bash Friction Log, which now redirects to it) | AGENTS.md loads every session → integration is automatic on both sides |
| 25 | **Scope (Q17)**: handover Next-session trim (#19) AND always-push-to-roadmap (#20) both ship immediately (coupled — trimming without a destination leaks). Only *breaking the sub-milestone system* is deferred to M3 | Trim is useless without a task destination; defer only the containment-model change |
| 26 | **M3 language**: record findings concise, framing-only, propose no solutions; keep correct framing while context fresh | M3 linear-roadmap-*app* may solve it; cross that bridge later |
| 27 | **STE language**: new/changed policy language drafted in Simplified Technical English style (ASD-STE100) — objective, disambiguated from session context, no dead prose | Works for future agents without today's conversational context |
| 28 | **Doc-review sweep** (backlog): bring the *rest* of docs/policies/agent files to the same STE-clean standard — recorded here, executed later (not this session) | Scope is large; deferred |
| 29 | **M3 recorded to `roadmap_future.md` now** (not pending next session): containment finding, close-script subtask, re-worded linear/next-task tasks | It is normal session cleanup to persist generated tasks at session end |
| 30 | **Roadmap-update timing rule**: when a session generates tasks, update the roadmap at end of session. This behavior must be stated cleanly so it is unambiguous | Operator steer (mid-session finding): roadmap update timing should be explicit, not implicit |

## Mid-session findings
| Finding | Type | Impact |
|---|---|---|
| 1 | Session is exploration-by-conversation; deliverables = summary artifacts + finalized workflow; implementation to follow | scope change | current unit | Triaged to: Decisions 3, 4, 25 |
| 2 | Operator repeated original decisions 1 & 2 (two files; subsume bash_complaints) | steering | settled | Triaged to: Decisions 1, 2 |
| 3 | Probation concerns: changelog-scan isn't reliable; fixes can resurface; dead fixes are maintenance weight | design | informed decisions 9–13 | Triaged to: Decisions 9–13 |
| 4 | Maintenance-surface-area concern: roadmap_future/handovers/discussions growing — avoid adding unmanageable tracked lists (leads to M3 prune task) | design | informed decisions 3, 9, 10 | Triaged to: Decisions 3, 9, 10 |
| 5 | Next session section often not followed in practice → trim + roadmap sole task list | realization | decision 19, 20 | Triaged to: Decisions 19, 20, 25 |
| 6 | Milestones not wholly contained; partial impls from other milestones needed often | realizations | decision 21 | Triaged to: Decision 21; M3 finding recorded in roadmap_future.md |
| 7 | New/changed policy must use STA / STE-clean language (objective, disambiguated, no dead prose) — future agents lack today's context | steering | decisions 27–28 | Triaged to: Decisions 27, 28 |
| 8 | Doc-review sweep of the rest of docs/policies/agent files to STE standard — deferred, scope too large for this session | scope change | roadmap / deferred | Triaged to: Deferred item 2 |
| 9 | Roadmap-update timing language should be stated cleanly: tasks generated in a session update the roadmap at end of session | realization | decision 30 | Triaged to: Decision 30; P4 companion in artifact |

## Completed this session
| File | Change |
|---|---|
| [devlog/handovers/20260809-03-workflow-agent_feedback_and_gotchas.md](devlog/handovers/20260809-03-workflow-agent_feedback_and_gotchas.md) | Created; updated incrementally as exploration decisions landed (renamed to `workflow` type at close) |
| [devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md](devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md) | Finalized-workflow artifact (spec for next session); consolidates design record + implementable workflow + M3 finding text |
| [devlog/roadmap_future.md](devlog/roadmap_future.md) | M3: added sub-milestone-containment finding, added close-milestone-automation subtask, re-worded linear/next-task tasks (M3-3, M3-4) to reflect immediate-scope split |

## Deferred items
| # | Item | Reason / next home |
|---|---|---|
| 1 | Close-script automation (`make close-milestone`) | Scoped to M3 (decision 17) — recorded in `roadmap_future.md` |
| 2 | Doc-review sweep of remaining docs/policies/agent files to STE-clean standard | Too large for this session; roadmap backlog (decision 28, finding 8) |

## Next session
Implement finalized workflow (Bucket 1): D1 create `AGENT_FEEDBACK.md`, D2 create `GOTCHAS.md`, T1 subsume `bash_complaints.md`, P1–P6 policy changes (mid-session findings expansion, review/publish step, pre-close review gate + probation, Next-session trim + always-push-to-roadmap, AGENTS.md pointers, milestone lifecycle reframe). Draft all in STE-clean language. No ADR. See finalized-workflow artifact.

**Conclusions from this session:** the two feedback mechanisms (AGENT_FEEDBACK / GOTCHAS) tie into mid-session findings for recording and a pre-close review gate at sub-milestone cleanup with dismiss/maintain/escalate probation for reconciliation; milestone lifecycle reframed to `active → pre-close → close` with close ceremonial/scriptable (M3); Next-session trimmed with always-push-to-roadmap; new/changed policy drafted in STE-clean language; doc-review sweep of remaining docs deferred.

---
[CORRECTION — 2026-08-09]: A finding surfaced during the close review (handover close-order contradiction) was mis-routed to M3 (`roadmap_future.md`) instead of being treated as a mid-session finding routed to a current destination. It is corrected to a current-roadmap item under M2.6 in `roadmap.md`, with a companion note in the finalized-workflow artifact. Finding routed to `roadmap.md` (M2.6 — handover close-order contradiction) and the workflow artifact (close-order reconciliation / P2 companion).

[CORRECTION — 2026-08-09]: The Hot files entry `devlog/discussions/20260809-story-active-bash_complaints.md` refers to a file deleted by session `20260809-04` (T1 migration into `devlog/AGENT_FEEDBACK.md`). The bash entries now live in `devlog/AGENT_FEEDBACK.md` (`## Bash` section, 8 entries). The AGENTS.md Bash Friction Log pointer was updated accordingly.
