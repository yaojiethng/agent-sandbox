# Handover 20260901-03 — workflow ADR policy revision

**Milestone:** M2.6 - Session Persistence
**Type:** workflow
**Status:** Closed
**Session date:** 2026-09-01

## Objective

Redesign the ADR system as a **living, component-mapped record of rationale** —
not an immutable append-only ledger. Per operator steering (`20260901-03`):

- **docs** catalogue an interface, convention, or architecture component, to
  quickly orient someone/some-agent to it.
- **ADRs** record the *why*: design rationale, design philosophy, and rejected
  designs with reasons — a durable record of edge cases / incomplete
  requirements, and a retrievable justification for why a thing was done a
  certain way when iterating or extending it.
- **handovers** remain the transaction log (agent does not expect them current).

The prior `20260901-02` gap (partial-supersede status freshness on `20260722`)
is a *symptom* of the immutable-ledger model and is subsumed by this redesign —
a living per-module ADR has no binary settled/superseded freeze problem to fix.
Team's working direction (module-centric naming, single-file living journal,
component/module parent-child hierarchy) is the target this revision realizes,
critically adapted to these requirements below.

## Refined framing (`20260901-03` steering)

- **An ADR is a pattern-level commitment record** — deeper than a design. It
  records the moment + reasoning behind committing to a *standing principle*:
  a pattern, concept, interface shape, design philosophy, invariant, user-
  interaction contract, guiding principles. Local design choices ride under an
  existing ADR (or prove it inadequate → force a redesign); they do not each
  spawn a file.
- **Liveness mechanism**: dated entries, current-on-top, append-and-demote,
  prior entry condensed (esp. if it was an application of a pattern), always
  stating why the old pattern was rejected for the new. Not a blind append.
- **Immutability / timing relaxed**: ADR no longer required to be written when
  code lands; ADRs are not immutable. Existing ADRs are recreated after this
  policy lands (a follow-up, not this iteration).
- **Workflow preserved**: designs still start as discussion documents; an ADR is
  spawned only when the scope is deep enough (a pattern-level commitment). Not
  all designs require an ADR.
- **This iteration** is a workflow-style discussion framing the right policy,
  not the ADR recreation.

## Layer model (`20260901-03` steering, refined)

Three/ four distinct records with distinct purposes:

- **handovers** = transaction log (not expected current; immutable).
- **docs/** (interface, conventions, architecture) = *orientation* to a system
  component (the *what* at component level).
- **docs/concepts/** = the *conceptual models* the system runs on — abstract
  state transitions, multi-component interactions, principles of interaction
  that are NOT governed by a single system. NOT orientation. Carries the *what*
  at the conceptual level.
- **ADRs** = the *why* — rationale for selection between possible models /
  principles. Concepts link to ADRs as **"further reading"** (like a paper cites
  references). Conceptually concepts are the parents; ADRs are the explainers.

The operator wants a **sweep of concept docs** to distill content that should be
ADRs and keep the remainder current.

## Scope

The revision covers `docs/operations/adr_policy.md` (per-section approval per the
open policy-text gotcha). Design decisions in scope:

- **Unit of record**: module/component-scoped living ADR file (namespaced), vs
timestamped immutable snapshots.
- **Liveness mechanism**: how a module's ADR absorbs a changed decision with the
history preserved (the *why* durability) without a freeze/multiple-file web.
- **Naming / hierarchy**: component-scoped file identity, parent-child linkage,
and whether a bare status-in-filename survives.
- **ADR ↔ doc boundary**: how a rationale record and its orientation doc relate
and cross-link without duplication.
- **Migration**: how the existing timestamped ADRs convert to the new form
(on-demand vs batch; the version-identity ADR is fresh and could be a worked
example).
- The original partial-supersede *status* problem is deprioritized to a symptom
under the redesign — not a standalone fix.

No implementation (policy-document revision only). Scope may contract or expand
as the grill resolves each decision.

## Acceptance Criteria

- AC1: `adr_policy.md` defines the **unit of record**: a component-scoped living
ADR as the home of a standing principle (pattern/concept/interface-shape/philosophy/invariant/contract), not a per-design snapshot.
  **done (agent)** -- Unit of record section written.
- AC2: The policy specifies the **liveness mechanism** -- dated entries,
current-on-top, append-and-demote with condensation + explicit why-rejected,
per-entry status, no-file-status.
  **done (agent)** -- Liveness/Statuses/Archive sections written.
- AC3: The policy defines **naming/hierarchy**: flat bare principle names in
`docs/adr/`, no date/status, sub-scope suffix for multiple principles; naming is a
living recommendation, agent recommends + operator decides.
  **done (agent)** -- Naming section written.
- AC4: The policy states the **ADR vs doc/concept boundary**: ADR = *why*;
`docs/` = *what* (component); `docs/concepts/` = *what* (conceptual level);
concepts link ADRs as further reading.
  **done (agent)** -- Relationship/Unit/Concepts sections.
- AC5: **Migration** defined: existing ADRs archived to `docs/adr/archive/`; recreation
is a follow-up (NOT this iteration).
  **done (agent)** -- archived 6 ADRs; follow-up roadmap entry written.
- AC6: The policy is internally consistent -- Statuses, evolve procedure, naming,
boundary, header reconciliation (documentation_policy) agree.
  **done (agent)**

## Post-close correction

(none)

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Iteration type: `workflow` (policy change; commit prefix `workflow:`) | confirmed |
| D2 | Steering `20260901-03`: ADR = live per-component *why*-record; docs = orientation; handover = transaction log; immutability overturned | confirmed |
| D3 | Partial-supersede *status* freshness is a symptom of the immutable model; subsumed by the living-record redesign, not a standalone fix | confirmed |
| D4 | Working direction: module-centric naming + single-file living journal + parent-child hierarchy (adapted critically, not adopted verbatim) | accepted pending refinement |
| D5 | **Liveness shape**: dated entries, current-on-top, append-and-demote — with CONDENSED prior entries (esp. if prior was just an application of a pattern), plus an explicit "why the old pattern was rejected for the new" | confirmed (refines D6) |
| D6 | **Trigger**: ADR = home of a distilled *standing principle*; discussion documents seed it; an ADR is spawned only when the design's scope is *deep enough* (a pattern-concept-interface-philosophy-invariant commitment). Local design choices ride under an existing ADR or prove it inadequate → force a redesign. Not all designs spawn ADRs | confirmed (refines AC1/AC3) |
| D7 | **Immutability relaxed**: heavily relax the "written when code lands" rule; ADRs are NOT immutable. Existing ADRs will be **recreated after this policy lands** (follow-up, not this iteration) | confirmed |
| D8 | **Layer model corrected**: docs/concepts/ = conceptual *what* (abstract models, principles of interaction, not single-system) — NOT orientation; ADRs = *why* (rationale between models); concepts link ADRs as "further reading"; concepts are conceptual parents, ADRs are explainers | confirmed |
| D9 | **Concept-doc sweep** desired: distill concept content that is really ADR rationale into ADRs + keep concepts current. (timing: this iteration vs recreation follow-up — pending) | pending timing |
| D10 | naming & hierarchy | pending |
| D11 | evolve/append protocol & Statuses table | pending |
| D12 | **Confirmed scope**: rework `adr_policy.md` (unit/liveness/trigger/naming/archive/boundary) + parallel purpose-sweep of `documentation_policy.md` (add `adr/` to Folder Structure, refine concepts row + Concepts-docs section, header-format reconciliation) + `project_index.md` row update + archive existing ADRs to `docs/adr/archive/` + roadmap follow-up entry (recreate + concept-sweep + re-point links). NO concepts/ADR recreation this iteration | confirmed |
| D13 | **Naming rule final**: flat bare component/principle names in `docs/adr/`, no date/status/prefix, sub-scope suffix for multiple principals, archive/ for superseded; naming is a living recommendation, agent recommends + operator chooses; no hierarchy-in-filename | confirmed |
| D14 | **Liveness final**: single-file, dated entries, current-on-top (`Current:` marker), append-and-demote with condensed prior + explicit why-rejected (a `Reason superseded by` line); per-entry status, no file status | confirmed |
| D15 | **When ADR begins**: spawn when consequences reach beyond the introducing change (contract/compat or coding-convention stabilisation) - reach, not size | confirmed |
| D16 | **Steering**: concepts/ = the *what* at conceptual level (models the system runs on), not orientation; ADRs = *why*; concepts link ADRs as further reading (parents), ADRs are explainers | confirmed |
| D17 | `adr_policy.md` released block-by-block (Purpose/Relationship/Unit/When begins; Liveness/Statuses/Archive; Naming/Content) and written; `documentation_policy.md` sweep + `project_index.md` done; 6 ADRs archived; roadmap follow-up entry written | done (agent) |

## Completed

- Read `docs/operations/adr_policy.md` (full) + `documentation_policy.md` + `project_index.md` (relevant rows) + roadmap entry + concept-doc inventory.
- Swept roadmap/future/agent_feedback/gotchas for ADR-related issues; found: the motivating partial-supersede status defect (`20260722`), the removed-ADR precedent (`20260730`), STALE concept content vs the version-identity ADR (terminology `staleness`, `sandbox_identity`), roadmap_future "decision recording", AGENT_FEEDBACK "ADR owed but not written", a non-conforming `skills/domain-model/ADR-FORMAT.md`.
- Realigned iteration from the narrow "partial-supersede status fix" to a full ADR redesign: living component-scoped rationale record. Operator steering captured: ADR = *why*; docs = *what* (component); concepts = *what* (conceptual level); handovers = transaction log; immutability overturned.
- Released block-by-block and wrote the new `docs/operations/adr_policy.md`.
- Released + applied `documentation_policy.md` sweep (add `adr/` to Folder Structure, slim Concepts-docs section, add record-invariant-shifts-now rule, header reconciliation for ADRs, remove `discussions/` row).
- Updated `project_index.md` `adr_policy.md` row; archived all 6 existing ADRs to `docs/adr/archive/`.
- Updated roadmap: marked ADR-policy revision `[x]`; added the ADR-recreation + concept-sweep follow-up `[ ]` entry with affected-link inventory and candidate first ADR.

## Findings

- **Stale `docs/adr/` links now exist** in active docs after the archive move (architecture/security, concepts/sandbox_identity, AGENTS.md, two skill files incl. non-conforming `ADR-FORMAT.md`, recent handovers/discussions) - all targeted by the follow-up re-point task.
- **`skills/domain-model/ADR-FORMAT.md`** describes a sequential-numbering, minimal-paragraph ADR scheme unrelated to project policy; a candidate for the follow-up to reconcile or drop.
- **Documentation-policy Concepts section was over-specified** (production guidance duplicated `adr_policy.md`); slimmed to the boundary; "how to produce" now lives in `adr_policy.md`.

## What's Next

- Content of the live ADRs themselves is the follow-up task (roadmap entry
  "ADR recreation + concept-doc sweep"): recreate archived ADRs under the new
  living per-principle format, sweep concepts to distill ADR rationale, re-point
  the now-stale `docs/adr/` links, reconcile/drop the non-conforming
  `skills/domain-model/ADR-FORMAT.md`.
- This iteration: close as `workflow:` after operator confirmation of the pre-close
  AC table.