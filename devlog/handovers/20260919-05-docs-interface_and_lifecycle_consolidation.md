# Handover 20260919-05 -- doc-consolidation: interface + lifecycle architecture

- **Type:** docs
- **Milestone:** M2.6 (Session Persistence) / M2.6.7 (Interface Contract Compatibility)
- **Status:** Closed
- **Branch:** feat/M2_6_mount_model_redesign
- **Depends on:** design settlement `20260919-03` (doc consolidation end state, rename section); P0 mechanism landed `20260919-04`.

## Objective

Land the doc consolidation of the interface thread (ADR `interface_contract_compatibility.md`, design `20260919-03`): rename `sandbox_host_correspondence_model.md` -> `sandbox_host_interface.md`, re-scope it as the interface contract document, and settle the relationship to the host-side `MAKEFILE_VERSION` marker (operator question, this iteration).

## Scope

- Rename + re-scope `docs/concepts/sandbox_host_interface.md`:
  - one interface concept doc: contract surfaces, expectations per co-resident copy, version declaration + comparison points;
  - one-line distinction from `tool_interface.md` (different boundary);
  - `MAKEFILE_VERSION` relationship section (separate number, separate use case, write-only today);
  - branches by link to the ADRs it resolves.
- One lifecycle doc already exists (`docs/architecture/sandbox_lifecycle.md`) - check it carries the version-check position in the sequence; add if missing.
- Propagation: update all active references to the old filename (closed handovers are read-only per handover_policy and intentionally excluded).
- Roadmap row 117 / M2.6.7: note docs landed (row stays open - P1/P2/P3 rollover pending operator release).
- ADR `interface_contract_compatibility.md`: document-status update.
- The container-sig rollover itself (P1/P2/P3) is NOT in scope - P0 code is landed and untouched this iteration.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `sandbox_host_interface.md` exists; old filename gone; title + scope = interface contract | grep | - |
| 2 | Interface doc covers: contract surfaces, per-copy expectations, version declaration + comparison points, ADR branches | read-back | - |
| 3 | `tool_interface.md` distinction carried as a one-liner | read-back | - |
| 4 | `MAKEFILE_VERSION` relationship recorded (separate use case/number; write-only) | read-back | - |
| 5 | `sandbox_lifecycle.md` carries the contract-check position in the lifecycle sequence | read-back | - |
| 6 | Zero active (non-handover) references to the old filename; all active markdown links resolve | grep + link check | - |
| 7 | Suite still green (docs-only should not disturb; run to confirm) | suite | - |

## Hot files

| File | Why in scope |
|---|---|
| `docs/concepts/sandbox_host_interface.md` (renamed) | the interface concept doc - re-scope target |
| `docs/architecture/sandbox_lifecycle.md` | lifecycle doc - contract-check position |
| `docs/concepts/sandbox_identity.md`, `docs/adr/container_host_correspondence_mechanism.md`, `docs/adr/diff_packaging.md`, `docs/concepts/copy_delivery.md`, `docs/concepts/context_resolution.md` | active references to the old filename |
| `docs/adr/interface_contract_compatibility.md` | ADR status/document update |
| `devlog/roadmap.md`, `devlog/roadmap_future.md` | row 117 / M2.6.7 note |

## Decisions made this iteration

- `MAKEFILE_VERSION` is a **separate use case** from `INTERFACE_CONTRACT_VERSION`: different boundary (host-internal vs cross-boundary), no container party, frequent template bump cadence, no consumer today (write-only). Keep separate numbers. Do not fold into the interface contract. Record in the interface doc.
- Doc consolidation does NOT include the rollover (P1/P2/P3) - that is operator-gated live-matrix work, separate.
- Closed handovers stay read-only (handover_policy): old-filename references there are intentional history, not propagated.

## Completed

- Renamed `docs/concepts/sandbox_host_correspondence_model.md` -> `docs/concepts/sandbox_host_interface.md` (git mv; rename recorded).
- Re-scoped the renamed doc: interface contract scope; added Contract surfaces, Expectations per co-resident copy, Version declaration + comparison (P0 live, P2 deferred), one-line tool_interface distinction, MAKEFILE_VERSION relationship section, ADR branches.
- Added contract-check position to `docs/architecture/sandbox_lifecycle.md` (preflight paragraph + References row reworded).
- Repointed all active references: copy_delivery, context_resolution, container_host_correspondence_mechanism (x2), diff_packaging, sandbox_identity (plus parallel-check link added per design "linked from sandbox_identity.md"). Archived ADR + closed handovers intentionally excluded (recorded below).
- ADR `interface_contract_compatibility.md`: added Documentation note; status unchanged (stays open until authoritative).
- Roadmap row 117 + roadmap_future M2.6.7: noted P0 + docs landed; row stays `- [ ]` (P1-P3 pending operator release).
- MAKEFILE_VERSION question answered and recorded (separate marker; not the interface contract).

## Findings

- Propagation scope caveat: the design record's "17-file propagation checklist" counted closed-handover references; handover_policy makes those read-only, so the actual propagated set is 9 active files + the renamed doc. The archived ADR's mention is a backtick file list, not a link. Both excluded deliberately.

## Verification

- `grep -rn "sandbox_host_correspondence_model"` across active paths -> zero link references; remaining hits are historical records only (closed handovers, archived ADR backtick list, the design record that records the rename, and the ADR note's intentional "renamed from" phrasing).
- `git grep -n "sandbox_host_interface"` -> renamed doc + 9 active referencing docs/roadmap files.
- Link check: all markdown link targets in the 8 touched docs resolve (scripted check, 0 missing).
- Suite: **888/888 across 50 files** (docs-only change; confirmation run).

## What's Next

- P1 live proof matrix (operator-run, gates P2/P3 per design rollover).
- P2 flip authoritative (needs P1 release) + entrypoint check.
- P3 strip container-sig.
- MAKEFILE_VERSION consumer wiring - deferred, not in any roadmap row yet (flag-only this iteration).
