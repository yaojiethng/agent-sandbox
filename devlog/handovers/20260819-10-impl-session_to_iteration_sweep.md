# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — terminology (session→iteration)
**Type:** Planning (reordered 2A/2B — plan released and executed)
**Status:** Closed

## Objective

Split the terminology **iteration 2** (session→iteration) into **2A** and **2B** and reorder them so the handover field-schema migration runs FIRST (2B), then the prose/entity sweep (2A). Both the iteration-2 scope and the phase sequence below are re-recorded cleanly. All half-applied changes from the earlier attempt have been **undone**; the tree is back at commit `c511500` plus this handover, ready for the operator to compact and start fresh.

## Context (verified, post-undo)

- Iteration 1 committed `c511500` (reserved-term register `docs/concepts/terminology.md`); working doc `output/terminology-sweep/categorization.md` Bucket B defines the session→iteration surface.
- **Working tree restored to clean** (reverted the premature `new-session.md`→`new-iteration.md` rename, its swept body, the two swept policy files, and the roadmap edit). Only untracked file is this handover.
- Root cause of the earlier deadlock: the handover **field headings are a stable schema** whose names carry "session" (`## Mid-session findings`, `## Next session`, `## Session type`, `## Session date`, `## Completed this session`, `## Decisions made this session`), and many consumers reference them by name. Sweeping those in prose (2A) collides with keeping them as schema. Resolved by running the **schema migration (2B) first**, using schema-**neutral** names so neither "session" nor "iteration" appears in the headings.

## The reordered plan

New sequence for the whole terminology program:
1. ✅ **Iteration 1** — reserved-term register (`docs/concepts/terminology.md`), done at `c511500`.
2. **Iteration 2B (now FIRST)** — **handover field-schema migration**: rename the field headings to schema-neutral names (strip "session"/"iteration" from the headings entirely), coordinate all consumers, and provide a formal historical transition (Bucket C3 — historical handovers not retro-renamed; read/grep tools must handle both old and new).
3. **Iteration 2A (now SECOND)** — **session→iteration prose/entity sweep**: now clean, because no field heading carries "session" anymore. Includes the `new-session` skill → `new-iteration` rename.
4. **Iteration 3** — run→session (`RUN_ID`→`SESSION_ID`, D-A/D-D).
5. **Iteration 4** — bundles refactor (`--session`→`--bundle` CLI/label surface + `output/diff` cleanup).

## Iteration 2B — field-schema migration (first)

**Target:** the handover field headings (stable schema) → schema-neutral names. Operator-suggested approach: strip the word "session" (and "iteration") from the headings entirely.

| Field heading (current) | Neutral target (operator-approved) |
|---|---|
| `## Session directive` | `## Directive` |
| `## Session type` | `## Type` (concept: "iteration type") |
| `## Session date` | `## Date` |
| `## Next session` | `## What's Next` (operator: instead of "Next") |
| `## Mid-session findings` | `## Findings` |
| `## Completed this session` | `## Completed` |
| `## Decisions made this session` | `## Decisions` |
| `## Carried forward` | (already neutral — keep) |
| `## Hot files` | (already neutral — keep) |

**In scope for 2B:**
- Rename all field headings in `handover_policy.md` (the template + canonical-marker table) and everywhere the headings appear.
- **Coordinate every consumer** that reads the field names: `prompts/whats-next.md` (greps `Mid-session findings` / `Next session`), `drafts/audit.skill.md` (required-sections list), `drafts/recovery.skill.md` (greps `**Session date:**`), `prompts/wrapup.md`, `AGENTS.md` (root), `git_policy.md`, `project_index.md`, `tests/eval/*` (historical — handle per 2B transition rule), and the `new-session.md` prompt body (field refs to neutral names).
- **Formal historical transition:** historical handovers keep old headings (not retro-renamed). The consumers that grep the live-format fields must either read both, or the transition must be staged so old and new handovers both parse. Decide the transition mechanism here (e.g. greps match both `## Next session` and `## What's Next`; or `head`-range reads tolerate the rename).
- Update `docs/concepts/terminology.md` if it references any field heading.

## Iteration 2A — session→iteration sweep (second, after 2B)

- Rename `new-session` skill → `new-iteration` (entity rename) + invocation surface (`handover_policy.md` Related Skills table, tests/eval refs — historical).
- Sweep **independent prose** "session"→"iteration" across B2 files (policy docs, AGENTS.md, prompts, drafts/skills, concepts, dev docs). After 2B, no field heading collides, so this is mechanical.
- Container-lifecycle "session" (Bucket C) and draft-context `SESSION_TS`/bundle-CLI tokens (B3 → deferred to the bundles refactor) remain untouched.
- B4 new devlog prose.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| A | **Reorder: 2B (schema migration) before 2A (prose sweep)** | the field schema carries "session" in heading names; migrating to neutral names first eliminates the collision that stalled the prose-only sweep |
| B | **2B neutral heading targets** — `## Directive`, `## Type`, `## Date`, `## What's Next` (operator-specified, not "Next"), `## Findings`, `## Completed`, `## Decisions` | strip "session"/"iteration" from the schema entirely to prevent recurrence |
| C | **Undo all half-applied changes** — revert prompt rename + body, revert iteration_policy/handover_policy sweeps, revert roadmap edit | begin 2A/2B on a clean slate after operator compacts |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | A session can produce multiple bundles; the draft/apply `--session=<name>` selector and `--session-summary` label are legacy-exact but misleading (`output/bundles` is the real home; `--bundle=` would be clearer). The `output/diff` folder is a potentially stale `package-diff` artifact. | Deferred — bundles refactor (phase 4), out of scope 2A/2B |
| 2 | `tests/eval/*` are archival point-in-time audits (not run by `make test`), referencing historical `new-session.md`/`new-session-v2.md`. | Bucket C3 — not swept; handle only via the 2B historical-transition rule for any grep they share |
| 3 | **DEAD LINK:** `devlog/AGENTS.md` referenced by planning/working doc does not exist; real provider AGENTS are `src/reasoning/providers/pi/config/agent/AGENTS.md` and `src/reasoning/providers/claude-ai/AGENTS.md`. | working doc + planning corrected; no live link |
| 4 | The handover field headings are a **stable schema** whose names carry "session" — they collided with the 2A prose sweep and forced the 2B-first reorder. | Adopted as the reordering rationale (Decision A) |
| 5 | Premature `sed` sweep applied before the stable-schema decision caused a half-consistent state; the fix is a full undo + clean restart. | Undone (Decision C); pre-close practice: confirm schema scope before sweeping |

## Acceptance criteria

- [x] All half-applied changes undone; working tree = `c511500` + roadmap update + this handover only (verified clean code/policy/prompt).
- [x] 2A/2B split and reorder recorded in this handover.
- [x] Roadmap terminology task updated to the reordered 5-phase plan (field-schema migration first; session→iteration; run→session; bundles).
- [ ] Operator compacts; next session re-opens on the clean slate with 2B first.

## Next session (after compact)
Open iteration **2B (field-schema migration)** first, per the reordered plan.
