# Agent Handover

**Session date:** 2026-08-19
**Milestone:** M2.6.6 — specialized terminology (agent run/session + agent iteration)
**Session type:** Design (terminology registration — implemented, ready for close review)
**Status:** Closed

## Objective

Insert one design/plan iteration BEFORE the two sweep iterations. Deliverables this iteration:
1. **Broad terminology sweep + categorization**, recorded as a **working document in `output/`** (gitignored, not committed with the handover).
2. **A committed docs change**: a canonical register cataloguing **"session"** and **"iteration"** as reserved Technical Terms (settled from the run→session fold).

After this iteration, the two change-checklist classifications feed iterations 2 (session→iteration) and 3 (run→session).

## Context (verified)

- Operator redefined the mapping (reversing the earlier design-walk settlement):
  - **"session"** = one container lifecycle (harness unit; start→run→stop; the thing with a resume path and session-state).
  - **"iteration"** = one (handover + commit) work unit (ops unit; the `new-session` skill's concept).
- The current code already names the container-lifecycle identity `SESSION_TS`/`SESSION_STATE`/`RESUME_SESSION`/`--session`/`session-ts` — already correct under this mapping. The ONLY wrong harness token is **`RUN_ID`** (204 uses) + derivations (`run_id`, `agent-sandbox.run-id` label, `SESSION_STATE` write key `run_id`, `--run-id` stop.sh flag) → target **`SESSION_ID`**.
- The session→iteration half touches the ops-workflow "session" words: `new-session.md` prompt + invocation surface, `iteration_policy.md` (61), `handover_policy.md` (47), `git_policy.md` (31), root `AGENTS.md` (18), handover prose. Historical handovers stay as-is.
- Roadmap task line 149 encodes the OLD mapping (session→iteration for the harness unit) — must be revised to the new mapping.
- `output/` is gitignored — the correct non-committed staging area for the working doc.
- GOTCHAS `[G] 2026-08-09`: policy/AGENTS.md text changes need per-section chat approval. Iteration 2 (session→iteration) is policy-heavy and cannot be a pure mechanical sweep.

## Proposal (this iteration's deliverables)

### Deliverable 1 — Working document (not committed)
`output/terminology-sweep/categorization.md`, produced by the broad sweep. Sections:
- Methodology + grep surface.
- **Technically three buckets**, each a table of `term → target → files/count → action`:
  - A: run→session (container lifecycle mislabeled "run") — `RUN_ID` family.
  - B: session→iteration (ops work unit) — prompt, policy docs, AGENTS.md, handover prose.
  - C: already-correct / do-not-touch (container lifecycle already "session"; historical docs) — preventive, so no future session renames them.
- These tables become the change-checklists for iterations 2 and 3.

### Deliverable 2 — Committed docs change: reserved-term register
New doc [`docs/concepts/terminology.md`](../concepts/terminology.md), cataloguing "session" and "iteration" as reserved technical terms (settled run→session fold).

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Register lives at `docs/concepts/terminology.md`, framed as "reserved technical terms" (NOT `glossary.md`) | prior `glossary.md` discontinued for over-broad cataloging; new doc is narrowly scoped to the reserved terms; same-folder adjacency to `sandbox_identity.md` |
| 2 | Register structure: `## Usage` preamble + per-term `##` headers with `### Identity`/`### Scope`/`### Relationships` subsections + per-term `Last updated:` label; no stand-alone change-history or relationship section | extensible — new terms appended as sibling headers; per-term `Last updated` replaces a whole-doc changelog |
| 3 | Backlink convention: policy docs (`documentation_policy.md`, `adr_policy.md`) reference the register; ADRs establishing/relying on reserved terms section-link to the exact term; no register link from `sandbox_identity.md` — instead `sandbox_identity.md` get first-mention section links to the terms (it OWNS the identity tokens) | the owner of the identity tokens is the correct place for the first-mention link; policy docs establish the convention centrally |
| 4 | `RUN_ID` token rename to `SESSION_ID` is NOT done this iteration | deferred to the run→session sweep (iteration 3); this iteration registers the terms + backlink convention only |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | **Linking practice for reserved terms:** a reserved term is first-mention section-linked (to `terminology.md#term`) at its first use in each document, and the policy docs cite the register as the authority. Codified into `documentation_policy.md` (STE section) and `adr_policy.md` (Content). Future docs and ADRs must follow this — a reserved term is linked on first mention, not redefined locally. | Documented + encoded as policy. Sweep iterations 2/3 re-read this convention when linking terms across the codebase/prose. |

## Completed this session

- [x] Operator confirmed scope; placed register at `docs/concepts/terminology.md` (not `glossary.md`).
- [x] Working doc `output/terminology-sweep/categorization.md` produced (3-bucket categorization: A run→session, B session→iteration, C do-not-touch; sub-decisions D-A..D-E); NOT committed (gitignored `output/`).
- [x] Register `docs/concepts/terminology.md` created (Usage preamble + per-term headers with Identity/Scope/Relationships + per-term `Last updated:`).
- [x] Backlink convention: `documentation_policy.md` STE section (reserved terms link-first-mention, don't redefine locally); `adr_policy.md` Content (ADR referencing reserved terms section-links, doesn't redefine); `sandbox_identity.md` first-mention section links to `session`/`iteration`.
- [x] Roadmap task revised to the new reversed mapping (session=container lifecycle / SESSION_ID; iteration=ops work unit; three-phase sweep; sub-decisions D-A..D-E recorded).

## Acceptance criteria

- [x] Working doc `output/terminology-sweep/categorization.md` produced; not committed via git.
- [x] Committed docs change registering "session"/"iteration" as reserved technical terms (register + policy-doc backlinks + `sandbox_identity.md` first-mention links).
- [x] Roadmap task line 149 revised to the new mapping (run→session/SESSION_ID; session→iteration for the ops unit).
- [ ] Operator reviews and releases close (commit as `docs:`) — closing plan below.

## Next session (into the sweeps)

Iteration 2 = session→iteration (ops). Iteration 3 = run→session (`RUN_ID`→`SESSION_ID`).
