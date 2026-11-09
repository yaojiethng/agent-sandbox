---
date: 2026-10-16
milestone: M3.4.2 - Environment declaration seam
type: Documentation
status: Closed
---

# Handover - the resolution model and the census defects

## Objective

Settle the resolution model as one ADR entry, rename its file to the widened subject, and file the defects the carrier census found.

## Scope

The design unit D1 of the M3.4 run, plus the ADR rename the operator directed.

In: `docs/adr/resolution_model.md` renamed from `env_resolution.md`, its five live citers, the new entry, the three defect rows the census produced, and the census record. Out: the T10 and T11 row relocation into M3.4.2, which is the next plan step, and the port of the draft branch, which follows the design units.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR is renamed and its five live citers resolve | `bash scripts/lint.sh` record-links gate | Agent [x] |
| The new entry carries the three carrier classes and the precedence primitive | a read of `docs/adr/resolution_model.md` | Agent [x] |
| The `2026-09-18` entry is historical and carries a `Reason superseded by` line | the same read | Agent [x] |
| The renamed file's wrapped header note is unwrapped and its exemption removed | `bash scripts/lint.sh` doc-wrap gate | Agent [x] |
| The census defects are filed | `devlog/roadmap.md` M3.4.2 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The unified resolution model is a new dated entry in the renamed file, not a new file | the subject is unchanged, so a new file would leave the old one fully superseded and archive it, which is churn for an unchanged subject | `docs/adr/resolution_model.md`; this handover |
| `env_resolution.md` becomes `resolution_model.md` | the widened subject names the principle and the rename eases future search. The seven closed-record citers are left dead, because the record-link gate exempts those trees and the correction policy forbids editing a closed record | this handover |
| The ladder's record level is rejected, so the resolver note's five-level proposal is refuted | the census found the only record reads are session state, replayed on resume, which is a different mechanism with a different lifetime | `docs/adr/resolution_model.md` |
| The three census defects are filed as rows rather than fixed here | each needs a decision that is not this unit's | `devlog/roadmap.md` M3.4.2 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Seven closed records cite `env_resolution.md` and now hold a dead link | defect, measured | expected; the record-link gate exempts the two record trees, and the correction policy forbids editing a closed record | this-record |
| The renamed ADR's header note was wrapped, and its `legacyFiles` doc-wrap exemption stopped matching the renamed path, so the gate fired on first touch | defect, measured | the note is unwrapped and the exemption removed | this-record |
| `start_agent.sh` derives `SANDBOX_DIR` at runtime, contradicting the ADR's "never at runtime" | defect, measured | filed as a row; verified at `scripts/start_agent.sh:333-337` | the-roadmap |
| `env_load` overwrites the ambient environment, so every non-identity `.env` key beats its ambient value | defect, measured | filed as a row; verified at `src/libs/env.sh:47` | the-roadmap |
| `INSTALL_DIR` is written to the sandbox `.env` and read from `$REPO_ROOT/.env` | defect, measured | filed as a row; verified at `scripts/onboard.sh:255` and `scripts/install.sh:124-131` | this-record |

## Completed

| File | Change |
|---|---|
| `docs/adr/resolution_model.md` | renamed from `env_resolution.md`; the H1 widens, R6 is added, and the new entry carries the three carrier classes and the precedence primitive |
| `devlog/roadmap.md` | the renamed cite, the three census defect rows under M3.4.2, and the row that retires the census record |
| `devlog/discussions/20261016-report-draft-carrier_census.md` | the census record, a working file to delete once its open set is empty |
| `docs/adr/command_flag_parsing.md`, `docs/reference/sandbox_identity.md`, `scripts/resume_agent.sh`, `.markdownlint-cli2.mjs` | the renamed path, and the doc-wrap exemption removed |
| `devlog/handovers/20261016-01-docs-resolution_model_and_census_defects.md` | this record |
