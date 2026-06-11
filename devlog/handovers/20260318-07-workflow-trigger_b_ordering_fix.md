# Agent Handover

**Session date:** 2026-03-18
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Workflow

## Objective
Identify and fix the ordering and linkage gap in the Trigger B workflow across `roadmap_policy.md`, `iteration_policy.md`, and `handover_policy.md`.

## Scope
Workflow audit of the sub-milestone close sequence. No roadmap tasks — this session addressed a policy gap surfaced by a real failure in the prior M2.1 session.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/roadmap_policy.md`](docs/operations/roadmap_policy.md) | Trigger B section rewritten and renamed |
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Step 1 and Step 8 updated; anchor links added |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | Step 1 recovery gate, Step 8 Trigger B instruction, Step 9 seed note added |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Trigger B step 1 is removal, not compaction | "Compact" was ambiguous — prior session collapsed M2.1 to outcome sentences but left the section standing. Explicit removal mirrors Trigger A and is unambiguous. | `roadmap_policy.md` — Sub-milestone close (Trigger B) |
| Trigger B fires at Step 8, before handover is closed | Canonical sequence: mark tasks → run Trigger B → close handover → seed next session. Chat boundary may fall anywhere in this sequence; roadmap state signals whether Trigger B has run. | `roadmap_policy.md`, `iteration_policy.md`, `handover_policy.md` |
| Step 1 recovery gate added | If a chat boundary falls before Trigger B, the next session must detect and run it before opening the new handover. Signal: prior handover names new sub-milestone, roadmap still shows old sub-milestone as active. | `iteration_policy.md` Step 1, `handover_policy.md` At session open |
| Cross-document references converted to anchor links | "Trigger B" was only defined in `roadmap_policy.md`; other documents referenced it by prose only. Anchor links make the connection navigable and greppable. | All three files |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/roadmap_policy.md` | Renamed section to "Sub-milestone close (Trigger B)"; rewrote step 1 as explicit removal; added trigger timing paragraph; added step 3 to Session close (Step 8) |
| `docs/operations/iteration_policy.md` | Step 1 action: Trigger B recovery check added; Step 8 action: Trigger B conditional added; Step 8 exit condition extended; tree diagram updated; anchor links throughout |
| `docs/operations/handover_policy.md` | At session open: Trigger B recovery check added as first bullet; At session close: Trigger B instruction added; At session seed: Trigger B pending/run note added; Next session format block updated; References table updated |

## Deferred items

None.

## Next session
**M2.2 — Reasoning Layer Modularisation.**

Trigger B was run in the prior session (20260318-05). `roadmap.md` should show M2.2 as the active sub-milestone. Confirm this at Step 1 before compacting.

**Watch-out items:**
1. The three policy files edited this session (`roadmap_policy.md`, `iteration_policy.md`, `handover_policy.md`) must be committed before M2.2 work begins — they affect session workflow and must be in effect.
2. M2.2 opens with a design step — audit `start_agent.sh` and `container-entrypoint.sh` before any files are changed.
3. The base reasoning image extraction must not bake project-specific content — constraint carried from M2.1.
