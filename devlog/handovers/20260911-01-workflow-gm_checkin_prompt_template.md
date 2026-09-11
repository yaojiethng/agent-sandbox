# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: reasoning-layer prompt scaffolding)
**Type:** Workflow
**Status:** Closed

## Objective
Refine the session check-in procedure: rename `whats-next.md` to `gm.md`, replace its command recipes with a source checklist, add a structured work inventory (per-field plain-language descriptions, progress and impact as separate axes), an optional intent argument, and bounded-depth rules; log the record discrepancies the check-in experiments surfaced.

## Scope

Confirmed and executed (operator release, chat 2026-09-11):

- Renamed `src/reasoning/agent/prompts/whats-next.md` to `gm.md` and rewrote it per the released draft: source checklist replaces command recipes, inventory table with progress and impact as separate axes, optional intent argument, depth constraints, sequencing guard.
- Rename sweep: no external references existed (verified).
- Record corrections applied: roadmap probe item (D1), roadmap version-identity residue (D2), handover `20260904-03` F2 status via the corrections procedure (D3), AGENT_FEEDBACK dual-use-guards entry (D4).
- New roadmap tasks: entrypoint map document (D6), architecture-doc staleness sweep with the `security.md` violation (D7).
- Sandbox stashes dropped (D5, 21 -> 0); the transfer-of-stale-stashes cause recorded as a finding.
- D8 recorded as a finding; the roadmap item confirmed as the canonical source.
- AGENTS.md dereference result recorded in Decisions; no AGENTS.md edits made.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | `whats-next.md` is gone; `gm.md` carries the released content; no stale `whats-next` references under `src/` or `docs/` | `ls src/reasoning/agent/prompts/`; `grep -rn "whats-next" src/ docs/` | Agent (pass: rename shown, grep 0) |
| AC2 | `gm.md` carries the released elements: operator-facing description, no-changes phrasing with iteration-policy link, source list with paths, inventory example with field meanings, depth constraint, three intents, sequencing guard | grep for each key string in `gm.md` | Agent (pass) |
| AC3 | The roadmap probe item names only the remaining seam (`template_version_probe_real`); the three-probe description is gone | `grep "Delete the remaining sed-extraction probe" devlog/roadmap.md` | Agent (pass) |
| AC4 | The roadmap carries no `Next: impl iteration` residue | `grep -c "Next: impl iteration" devlog/roadmap.md` returns 0 | Agent (pass: 0) |
| AC5 | The roadmap carries the entrypoint-map task and the architecture-doc staleness-sweep task | grep for both task titles | Agent (pass: 2) |
| AC6 | Handover `20260904-03` F2 reads Resolved with the landing reference; dated correction block present | grep in the handover file | Agent (pass) |
| AC7 | The AGENT_FEEDBACK entry mitigation text reflects the tree; the follow-up names the roadmap item as canonical | grep in `devlog/AGENT_FEEDBACK.md` | Agent (pass) |
| AC8 | The sandbox stash list is empty | `git stash list` returns nothing | Agent (pass: 0) |
| AC9 | Handover closed with Status Closed; findings routed at the publish step | operator review | Operator |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/agent/prompts/whats-next.md`](src/reasoning/agent/prompts/whats-next.md) | Renamed to `gm.md` and rewritten per the confirmed skeleton |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Write-backs for D1/D2 if approved; structural tasks for D5/D6 if approved |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | Mitigation-text correction for D4 if approved |
| [`devlog/handovers/20260904-03-design-seed_transport_correctness_amendments.md`](devlog/handovers/20260904-03-design-seed_transport_correctness_amendments.md) | F2 status correction for D3 if approved (correction-to-closed-handover procedure) |
| [`docs/architecture/security.md`](docs/architecture/security.md) | Stale copy-delivery row, D7; ride-along or deferral |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Strip the command recipes from the check-in template; keep a source checklist | A/B experiment (2026-09-11, four flash-model runs): both models produced correct core output without the recipes; the recipes are brittle against record-format drift. The source checklist (findings, stashes, design docs) surfaced sweep categories the bare runs missed, so coverage stays, procedure goes | This handover; `gm.md` |
| Split progress and impact into separate inventory axes | Different decisions: stale-text write-back is high progress (urgent housekeeping) but low impact; full-history mount is high impact but zero progress pressure. Operator framing, chat 2026-09-11 | `gm.md` inventory fields |
| Intent is an optional argument; when absent, suggest work along common intents instead of assuming | Check-in must work after a break, after a complex landing, before a sweep. Both template-condition runs recommended the priority-correct task (mount runnability) instead of a warm-up because the template carried no intent slot | `gm.md` close section |
| Rename `whats-next` to `gm` | Shorter, memorable, fits the conversational check-in context the operator actually uses | File rename plus reference sweep |
| Depth constraint: dimensions filled from records already read; unclear cells become listed options; response ends at the scope gate | No run-off observed in any experiment run, but the inventory table raises verification demand; the constraint encodes the bounded behavior B2 exhibited organically ("verify what is left" listed as the task itself) | `gm.md` survey rules |
| No AGENTS.md changes proposed | Dereference of both AGENTS.md layers found no gm-specific task items to move out; general rules (read discipline, roadmap-as-sole-task-list, one-question-at-a-time) stay ambient and `gm.md` cites them by name instead of restating | This handover |
| Recommendations respect landing order: a prefactor is suggested before the task that needs it | A suggestion that names a milestone-closing task while its prefactors are open breaks the workflow's sequential landing order; complexity and impact are balanced, not traded off | `gm.md` close section |
| Record corrections D1-D4 applied in place; each corrects record text to the tree state | Operator approval, chat 2026-09-11 | The corrected record files; this handover Completed table |
| D5: stash drop only, no dedicated task; the transfer cause recorded as a finding | Operator disposition; the task comes when the finding is processed | This handover Findings |
| D6 and D7: new roadmap tasks (entrypoint map document; architecture-doc staleness sweep with the `security.md` violation) | Operator approval; D7 is a task, not a ride-along fix | `roadmap.md` M2.6 open items |
| D8: the roadmap item is the canonical source for follow-ups | Operator decision; divergence potential recorded as a finding | This handover Findings; the corrected AGENT_FEEDBACK entry |

## Findings

| Finding | Type | Impact |
|---|---|---|
| D1: roadmap item 108 (delete sed-extraction probe layer) describes three probes; two (`_env_field_probe`, `_wsl_path_probe`) were already deleted in `505a06ad`/`7600307d`; only `template_version_probe_real` (`tests/test_onboard.sh:296`) remains. Roadmap text is stale; the item is two-thirds done on disk, unrecorded | contradiction | this iteration (write-back if approved) |
| D2: roadmap line 105, harness-version-identity item marked `[x]` but body still ends "Next: impl iteration"; impl landed in `20260904-07` | contradiction | this iteration (write-back if approved) |
| D3: handover `20260904-03` F2 (negation leak in `snapshot_copy_worktree`) status "Open (fix scheduled)"; the fix landed with the seed-transport item (roadmap line 111 records "enumeration fix (negation leak)"). Finding status stale | contradiction | this iteration (correction procedure if approved) |
| D4: AGENT_FEEDBACK dual-use-guards entry (probation, reconciled 2026-09-01) mitigation text names all three probes as current; two are deleted. Entry text stale vs tree | contradiction | this iteration (write-back if approved) |
| D5: 21 git stashes, oldest from May, on dead draft/feature branches; none hold in-progress M2.6 work (per survey runs; stash list verified 21) | scope change | roadmap (future task or sub-milestone cleanup) |
| D6: entrypoint landscape undocumented: `gm` (orientation, options), `new-iteration` (directive known), audit skills (specific audit target) are distinct kickoff paths; no doc maps them | scope change | roadmap (future task, candidate) |
| D7: `docs/architecture/security.md:42` still describes copy delivery as "Reinitialized -- fresh `git init`, no link to host repo"; the helper-container seed copies the real host `.git` (ADR 2026-09-04). Stale, security-relevant. Surfaced in session 2026-09-11 08:15, unrecorded until now | contradiction | this iteration (ride-along) or next |
| Operator steering on the gm draft (chat 2026-09-11): drop the use-when clause (description targets operator invocation); reframe the opening to the no-changes phrasing with an iteration-policy link; survey section carries explicit paths and links; "greatest blocker" intent reframed to balance complexity and impact -- prefactor suggested before the large task that needs it; recommendation phrasing must never break sequential landing order | steering | this iteration |
| D8: authority conflict on the probe item: AGENT_FEEDBACK entry says probation, "drop if it does not resurface; follow-up candidate, not this fix"; roadmap carries it as a live open task. Which record wins needs operator triage | contradiction | this iteration (operator decision) |
| Test suite state: last recorded run 731/731 green at HEAD `fc3f844` (handover `20260904-10` close); HEAD unchanged since. Live run not possible in the reasoning layer (`make` is a capability-layer tool) | none (record current) | none |
| D5 disposition (operator, chat 2026-09-11): root cause is stale stashes transferred from the host to the sandbox. The 21 sandbox stashes were dropped with `git stash clear` (verified 21 -> 0). No dedicated task now; a task is added when the transfer bug is processed | bug | future task when processed |
| D8 disposition (operator, chat 2026-09-11): feedback entries can carry follow-up task assignments that diverge from the roadmap. The roadmap item is the canonical source. The AGENT_FEEDBACK entry now points at the roadmap item | contradiction | route at publish step (gotcha candidate: a feedback follow-up note is not a task assignment) |

## Completed

| File | Change |
|---|---|
| [`devlog/handovers/20260911-01-workflow-gm_checkin_prompt_template.md`](devlog/handovers/20260911-01-workflow-gm_checkin_prompt_template.md) | Iteration handover opened |
| [`src/reasoning/agent/prompts/gm.md`](src/reasoning/agent/prompts/gm.md) | whats-next.md renamed and rewritten: source checklist replaces command recipes, inventory table with progress/impact split, optional intent argument, depth constraints, sequencing guard (released by operator, chat 2026-09-11) |
| [`devlog/roadmap.md`](devlog/roadmap.md) | D1 probe item rewritten to the remaining seam; D2 stale Next sentence removed; D6/D7 task entries added |
| [`devlog/handovers/20260904-03-design-seed_transport_correctness_amendments.md`](devlog/handovers/20260904-03-design-seed_transport_correctness_amendments.md) | D3: F2 status corrected to Resolved; dated correction block appended per the corrections procedure |
| [`devlog/AGENT_FEEDBACK.md`](devlog/AGENT_FEEDBACK.md) | D4: dual-use-guards entry mitigation text corrected to the tree state; the follow-up points at the roadmap item as canonical |

## Deferred items

None.

## What's Next

Sub-milestone: M2.6.6 -- Mount Model (unchanged by this cross-cutting iteration; its runnability task remains the active delivery item).

Post-close bookkeeping: not applicable -- no sub-milestone completed.

Conclusions from this iteration: the check-in procedure is now `gm` (rename from `whats-next`); source-checklist survey replaces command recipes; the work inventory separates progress and impact; intent is an optional argument, with common-intent suggestions when absent; recommendations respect landing order. All eight surfaced discrepancies were dispositioned: D1-D4 corrected in place, D5 stashes dropped with the transfer cause recorded as a finding, D6/D7 added as roadmap tasks, D8 routed to GOTCHAS with the roadmap confirmed canonical. The surface-area audit of the drafts and prompts directories follows immediately (handover `20260911-02`); the reorganization itself targets M3.

Watch-out for the next agent: `gm` is a pre-iteration check-in -- it must not open a handover; the roadmap probe item now names exactly one remaining seam (`template_version_probe_real`, `tests/test_onboard.sh`).
