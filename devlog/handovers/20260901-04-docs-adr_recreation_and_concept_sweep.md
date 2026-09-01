# Handover 20260901-04 — docs ADR recreation and concept-doc sweep

**Milestone:** M2.6 - Session Persistence
**Type:** docs
**Status:** Closed
**Session date:** 2026-09-01

## Objective

Recreate the six archived ADRs in `docs/adr/archive/` as living per-principle
ADR files under the new format (`docs/operations/adr_policy.md`, settled
`20260901-03`): component-scoped names, dated entries, current-on-top,
historical stack with explicit why-rejected lines. Sweep `docs/concepts/` to
distill content that is really ADR rationale into ADRs, keeping the concepts
current as the *what*. Re-point now-stale `docs/adr/` links to the new stable
names. Reconcile or drop the non-conforming
`src/reasoning/agent/skills/domain-model/ADR-FORMAT.md`. Record the candidate
first new ADR: the drift/state-coherence guarantee (container-sig general
model vs the minimise-not-detect redesign settled in the version-identity
design).

## Scope

- Recreate archived ADRs as living files (consolidation of partially
  superseded chains into single per-principle files; naming per policy is
  agent-recommends / operator-decides).
- New ADR for the drift/state-coherence principle (candidate content per
  roadmap line 162 and handover `20260901-02` interface-contract thread).
- Concept-doc sweep: move model-selection rationale from `docs/concepts/`
  into ADRs; refresh stale concept content (`staleness` terminology,
  `sandbox_identity.md` image-staleness section vs the version-identity ADR).
- Re-point stale `docs/adr/` links: `docs/architecture/security.md`,
  `docs/concepts/sandbox_identity.md`, `AGENTS.md`,
  `src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md`,
  `src/reasoning/agent/skills/domain-model/SKILL.md` + `ADR-FORMAT.md`,
  `devlog/roadmap.md`.
- Decide with operator: closed handovers/discussions referencing archived
  ADR paths — re-point or leave as immutable transaction-log records.

Out of scope (unless steering changes it): the version-identity *impl*
iteration (roadmap line 158, separate task); writing ADRs for principles
beyond the archived set and the drift/coherence candidate.

## Carried forward

- Open gotcha `2026-08-09` (policy text needs per-section approval) — applies
  if any policy text is touched; this iteration should avoid policy edits.
- ADR naming rule: agent recommends, operator decides final names.

## Acceptance Criteria

- AC1: Each archived ADR is recreated as a living `docs/adr/<principle>.md`
  under the new format (or explicitly retired to `archive/` as fully
  superseded, with operator agreement).
  **done (agent)** — six living files; all archived content represented;
  archive/ retained untouched.
- AC2: A drift/state-coherence ADR exists recording the container-sig
  general model vs the minimise-not-detect redesign rationale.
  **done (agent)** — `drift_state_coherence.md`, container-sig as historical
  entry with why-rejected + interim status.
- AC3: Concept docs carry the *what* only; rationale distilled into ADRs and
  linked as further reading; stale concept content refreshed.
  **done (agent)** — sandbox_identity/terminology/correspondence/two_layer
  updated; stale framing framed as current-until-impl with ADR links.
- AC4: No active document links to `docs/adr/archive/` or to an archived
  ADR filename (except `adr_policy.md` archive section and closed
  transaction-log records if operator says leave).
  **done (agent)** — re-point scope widened per operator to *all* documents;
  link check green (see pre-close output).
- AC5: `ADR-FORMAT.md` reconciled to the project ADR convention or dropped.
  **done (agent)** — rewritten to the living format.
- AC6: Grep confirms zero stale references; all markdown link targets resolve.
  **done (agent)** — see verification output below.

## Hot files

- `docs/adr/` (six new living files; `archive/` untouched)
- `docs/concepts/sandbox_identity.md`, `terminology.md`,
  `sandbox_host_correspondence_model.md`, `two_layer_model.md`
- `docs/architecture/security.md`
- `src/reasoning/agent/skills/domain-model/ADR-FORMAT.md`
- `docs/development/project_index.md`
- `devlog/roadmap.md` (link re-point + checkbox update)
- Closed handovers/discussions (link re-point only, per operator)

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Iteration type `docs` (commit prefix `docs:`) | confirmed (operator) |
| D2 | Living ADR names: `session_identifier`, `harness_versioning`, `sandbox_delivery_model`, `policy_declarative_framing`, `diff_packaging`, `drift_state_coherence` — grounded in operator steering (no `session_identity`/`sandbox_backing`; delivery-model topic named per canonical usage) | confirmed (operator) |
| D3 | Consolidation: 20260722 derivation + 20260831 canonical → one `session_identifier.md` (historical→current); 20260721 worktree-mount-model (removed pre-settlement) → historical entry in `sandbox_delivery_model.md`; remaining archived ADRs map 1:1 | confirmed (operator) |
| D4 | Re-point **all** documents, including closed handovers/discussions (operator override of transaction-log immutability for link targets) | confirmed (operator) |
| D5 | References to ADRs that never landed / were deleted uncommitted (`20260721-adr-stl-worktree-mount-model`, `20260722-adr-settled-mount_model_axes`) left as historical descriptions — not links to resolvable content | confirmed (agent) |
| D6 | New `drift_state_coherence.md` records the 20260722 container-sig detection model as its historical entry, keeping the interim-implementation status explicit | confirmed (agent) |

## Completed

- Orientation: adr_policy.md, documentation_policy.md, iteration/handover/git
  policy, roadmap ADR entries, prior handovers `20260901-02/-03`, archived ADR
  full reads, stale-link grep, open gotchas.
- Wrote six living ADRs in `docs/adr/` per the new format (dated entries,
  current-on-top, condensed historical entries with why-rejected lines):
  `session_identifier.md`, `harness_versioning.md`,
  `sandbox_delivery_model.md`, `policy_declarative_framing.md`,
  `diff_packaging.md`, `drift_state_coherence.md`.
- Concept sweep: `sandbox_identity.md` (SESSION_ID section link; further-
  reading note on the container-sig section), `terminology.md` (staleness
  term links to drift/versioning ADRs, current-until-impl framing),
  `sandbox_host_correspondence_model.md` (SESSION_ID row link),
  `two_layer_model.md` (removed non-conforming Status line, fixed broken
  discussion link, merged duplicated `execution_model.md` table row).
- Re-pointed all `docs/adr/` references across `docs/`, skills, roadmap, and
  closed handovers/discussions (19 files); fixed wrong relative prefixes on
  the roadmap and one discussion link I touched.
- Rewrote `skills/domain-model/ADR-FORMAT.md` to the living format (kept its
  when-to-offer guidance); verified both other skill files need no change.
- Registered all six ADRs in `project_index.md` (new ADR section) and updated
  touched rows; added missing `sandbox_identity.md`/`terminology.md` rows.
- Roadmap task entry marked `[x]` with summary.

## Findings

- `AGENTS.md` needed no change — its only ADR reference is to
  `adr_policy.md` and remains valid; the prior handover's stale-link
  inventory overstated it.
- Three pre-existing broken links outside ADR scope, flagged not fixed:
  `agent_workflow.md` → `../operations/quickstart.md` (file lives in
  `docs/development/`), `autonomous_task.md` stub → `../development/roadmap.md`
  (roadmap lives in `devlog/`), and several roadmap links with a `../../`
  prefix that resolves outside the repo (only the two I touched were fixed).
- References to never-landed/deleted ADRs (`20260721-adr-stl-worktree-mount-model`,
  `20260722-adr-settled-mount_model_axes`) left as historical descriptions.
- Sed re-pointing also updated visible link *text* in closed handovers
  (operator-directed); one row (`20260722-05` "Deleted (git rm)") now names
  the successor file anachronistically — content intent preserved.
- `sandbox_identity.md`/`terminology.md` were absent from `project_index.md`
  despite "complete registry"; rows added for them. Other unregistered
  concepts (`autonomous_agent_loop.md`, `context_resolution.md`) remain —
  adjacent, flagged.
- `two_layer_model.md` was marked "Do not edit; reference only" in the index;
  only mechanical corrections applied (header format, broken link, duplicate
  row) — no model content changed.

## Deferred items

- New ADR candidates surfaced but not created (out of scope):
  two-layer separation rationale (`two_layer_model.md` "Why the layers are
  separate"; reasoning currently lives in `investigation_mcp_server.md`),
  and the sandbox/host correspondence core principle (git-agnostic diff
  exchange). Flag for the operator as possible next ADRs.
- Pre-existing broken links listed in Findings — candidate `chore` iteration.
- Interface-contract compatibility design thread (roadmap line 159) — the
  drift ADR records the principle; the contract-version mechanism is its own
  deferred thread.

## What's Next

- Operator pre-close review (Gate 3), then single `docs:` delivery commit.
