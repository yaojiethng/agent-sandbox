# Agent Handover

**Date:** 2026-09-19
**Milestone:** M2.6 - Session Persistence
**Type:** design
**Status:** Closed

## Objective

Settle the deferred interface-contract compatibility design thread (roadmap
row 117, raised `20260901-02`, deferred since). The real need behind the
retired freshness signal: the host checkout driving a session and the wiring
baked into the image must speak the same SHAPE. Planned mechanism (operator-
directed, recorded in the thread): an explicit interface/contract version
declared and compared by each co-resident copy, bumped only when the
cross-boundary contract changes, immune to doc edits, with `container-sig`
as the interim implementation.

This iteration produces the design record and the ADR decision; implementation
is a follow-up `impl` iteration.

## Scope (confirmed by operator)

- Design doc in `devlog/discussions/` per discussion_policy (Context,
  Options Considered, Decision, Consequences) settling:
  - the contract-version scheme: ONE version, declared once in a host-side
    lib constant, with TWO declarations (baked into tier-3 images at build;
    stamped into .compose record + SESSION_STATE at write) and ONE comparator
    (preflight, start + resume paths; never entrypoint);
  - the three surfaces: host<->container wiring, container<->container
    pairing (--targets), session-record schema;
  - mismatch policy: warn in the parallel phase, fail-closed preflight-time
    refusal in the authoritative phase;
  - container-sig rollover: P0-P3 migration plan (parallel land, live proof,
    flip authoritative, strip), old check never stripped before new is proven;
  - doc consolidation end state: one interface concept doc + one lifecycle
    architecture doc, ADRs branching by link.
- ADR: `docs/adr/interface_contract_compatibility.md` (new principle-separate
  ADR, dated entry, skeleton confirmed, kept open until impl lands).
- Roadmap row 117 update (design settled; implementation task follows).
- No implementation code this iteration.

## Deferred / out of scope

- NO implementation: no version constants, no comparison code, no
  `container-sig` removal. The ADR stays open until the impl lands.
- Env-resolution thread (`20260917-06`) is unrelated and already closed.

## Acceptance criteria (proposed)

| # | Criterion | Status |
|---|---|---|
| AC1 | Design doc settled: contract-version scheme (single version, dual declaration, layered preflight + agent-entrypoint comparator), all three surfaces, mismatch policy (warn-then-strict, operator-released switch-over gates) | **done (agent)** — `devlog/discussions/20260919-design-interface_contract_compatibility.md`, Status settled |
| AC2 | `container-sig` interim role confirmed, P0-P3 rollover plan recorded (old check not stripped before new proven; exact switch-over moments in the table; live matrix defined) | **done (agent)** — design doc Rollover section |
| AC3 | ADR written recording the mechanism decision per adr_policy | **done (agent)** — `docs/adr/interface_contract_compatibility.md`, open/pending-impl until the impl lands |
| AC4 | Roadmap rows reconciled (row 117 design-settled marker + impl task; M2.6.7 future entry) | **done (agent)** — see Verification |
| AC5 | Design doc status -> settled; no code changed (suite untouched) | **done (agent)** — suite 876/876 (untouched); design doc Status settled |

## Completed

- Design doc settled: `devlog/discussions/20260919-design-interface_contract_compatibility.md` (Status settled; Context / Options A-D / Decision / Rollover with exact switch-over gates / Rename section / Consequences / Open items resolved).
- ADR created: `docs/adr/interface_contract_compatibility.md` (one version, two declarations, layered comparison; R1-R6 requirements preamble; rejected alternatives; open/pending-impl).
- Roadmap row 117 rewritten (design-settled marker; impl NEXT M2.6.7); `roadmap_future.md` gained the M2.6.7 sub-milestone entry.
- Operator steering folded in: entrypoint reframe (minimise wasted ops + blast radius; preflight for host<->container + record; agent entrypoint for container<->container; redundancy signals larger problem), rename to `sandbox_host_interface.md` (pro + assessed criticism), single-version-first confirmed.

## Findings

- No classes A/B/C this iteration. (Past-failure record — new-mechanism errors blocked start after old check stripped — already carried in the thread; encoded as the rollover hard rule.)

## Verification

- No code changed: suite untouched (876/876 baseline holds).
- Roadmap: row 117 has design-settled marker; M2.6.7 entry in roadmap_future.
- ADR linked from design doc; design doc linked from handover and roadmap.
- Consistency sweep: `interface_contract_compatibility.md` referenced in design doc + roadmap row 117 + roadmap_future M2.6.7; zero references to a non-existent ADR.

## Decisions

- **One version, two declarations, layered comparison** (ADR `interface_contract_compatibility.md`): `INTERFACE_CONTRACT_VERSION` in `src/libs/interface_contract.sh`; stamped into tier-3 images at build + `.compose` label set and `SESSION_STATE` key at write; compared at start/resume preflight (host<->container + record) and agent entrypoint (container<->container).
- **Warn-then-strict with operator-released switch-over gates** (P0-P3 rollover; the past-failure hard rule: old check not stripped before new proven).
- **Single version first**; per-surface split is a compatible extension later.
- **Rename**: `sandbox_host_correspondence_model.md` -> `sandbox_host_interface.md` (impl-milestone; 17-file propagation checklist); ADR `container_host_correspondence_mechanism.md` keeps its name.
- **Doc consolidation end state**: one interface concept doc + one lifecycle architecture doc (`sandbox_lifecycle.md`).

## What's Next
- Implementation iteration (M2.6.7) for the interface-contract version mechanism
  (after operator release of this design): the version constant + dual stamping +
  preflight/entrypoint comparators, per the rollover P0-P3 plan.
- The live matrix from this design (copy/mount x flatten on/off x start/resume/list/prune,
  plus deliberately drifted samples) is the operator-run gate for P1/P2.