# Agent Handover

**Session date:** 2026-03-18
**Milestone:** Workflow Policy Refinement — pre-M2.1
**Session type:** Workflow

## Objective
Restore `iteration_policy.md` as a true index document: move all inline rule content to the child documents that own each domain, replace the minor loop step prose with a navigable table (entry | action + link | exit), and add a two-loop overview tree. No rules are removed — only relocated.

## Scope

### Phase 1 — Acceptance criteria additions (complete)
Targeted additions to `iteration_policy.md`, `roadmap_policy.md`, `handover_policy.md`. Done this session.

### Phase 2 — Null marker lifecycle gap (complete)
Added `### At Step 6` block to `handover_policy.md` Population Rules. Gate is now explicit in the document where the marker lives.

### Phase 3 — Audit inline rules in `iteration_policy.md` (complete)
Move list produced. Conclusion: no rules needed to move to new documents — child documents already own everything. Restructuring is purely converting step prose to gate descriptions with links.

### Phase 4 — Restructure `iteration_policy.md` (complete)
Two-loop overview tree added. Minor loop section replaced with step tree + table (70 lines → 33 lines).

### Phase 5 — Update child documents (complete)
`roadmap_policy.md` — added `###` subsection headers for Session open, Session close, Trigger B, Trigger A. Index links updated to resolve correctly.

### Phase 6 — Verify `milestone_policy.md`, `story_policy.md`, `investigation_policy.md` (complete)
All three have named sections matching major loop index links. No changes required.

### Phase 7 — Cross-document link audit (complete)
All child document references to `iteration_policy.md` are navigational only. No rules flow from child to index. Clean.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | All phases — primary restructure target |
| [`docs/development/roadmap_policy.md`](docs/development/roadmap_policy.md) | Phase 1 + Phase 5: acceptance criteria rule + subsection headers |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | Phase 1 + Phase 2: acceptance criteria rules + Step 6 gate |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Acceptance criteria describe observable outcomes, not file state | File state already covered by task checklist and completed table | `iteration_policy.md` Principles |
| Rule phrasing: align with template comment, not "names a command" | "Names a command" too narrow for timing/behavioural observations | `handover_policy.md` Rules |
| Restore `iteration_policy.md` as index document | Inline rules cause duplication, gap opacity, runtime adherence failures | `iteration_policy.md` (structural) |
| Runtime workflow: table + plain text overview tree | Works in both plain text and rendered markdown; stays in context for full session | `iteration_policy.md` Minor Loop |
| No rules removed during restructure — relocation only | Restructuring is a structural fix, not a pruning | Phase 3 move list |
| Null marker gate in `handover_policy.md` Population Rules | Constraint must be visible in the document where the marker lives, not only in `iteration_policy.md` Step 7 entry | `handover_policy.md` — At Step 6 |
| `roadmap_policy.md` trigger blocks → `###` subsection headers | Enables precise links from index; previously only bold labels with no anchor | `roadmap_policy.md` — When the Roadmap Is Touched |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | Phase 1: new principle + Step 6 sharpened. Phase 3–4: two-loop tree added, minor loop step prose replaced with table |
| `docs/development/roadmap_policy.md` | Phase 1: acceptance criteria rule. Phase 5: subsection headers for all four trigger blocks |
| `docs/operations/handover_policy.md` | Phase 1: format template comment + operator-runnable checks rule. Phase 2: At Step 6 population block added |
| `agent_context_brief.md` | Stale link fixed: `handover_policy.md` entry now points to correct target |

## Deferred items

None.

## Next session

**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Implementation

All workflow policy work is complete. Resume M2.1 implementation directly from `roadmap.md`.
