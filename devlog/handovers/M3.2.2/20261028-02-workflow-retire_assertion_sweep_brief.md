---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - Retire the per-assertion sweep carrier

## Objective

Delete the superseded `test-assertion-sweep-brief` carrier and record its fate, so the consolidation's remaining carrier set shrinks by one and no dead instruction surface stays in `.agents/audits/`.

## Scope

Continues **The consolidation, run once over the whole set** (M3.2.2). The bash and container clusters are already done; this unit disposes of one carrier whose fate is still `pending`.

In scope: the deletion, the fate recorded on the consolidation row, and the verification that the frozen eval snapshot still resolves. Out of scope: the other pending carriers (`test-quality-campaign`, `architecture-doc-reviewer`, `documentation-audit-comparison`, `surface-area-report`), the settled census reports, and the frozen fixture under `tests/eval/instruction-cleanup/`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The source carrier is gone | `test ! -e .agents/audits/test-assertion-sweep-brief.md` | Agent [x] |
| The consolidation row records the carrier as deleted and names what replaced it | grep the row for `test-assertion-sweep-brief` and `deleted` | Agent [x] |
| The frozen eval snapshot still verifies | `cd tests/eval/instruction-cleanup && sha256sum -c SHA256SUMS` | Agent [x] |
| The documentation gates stay clean | `bash scripts/check_markdown.sh` | Agent [x] |
| Every decision recorded this iteration is realized in the files | each Decisions row checked against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The carrier is deleted rather than absorbed | its harness contract is in `docs/development/test_harness_mechanism.md`, its assertion judgements in the `testing` convention and the test-quality campaign, and its run record in handover `20260922-08` | this handover |
| The frozen eval fixture is left byte-identical | it holds its own `.orig` copy and `SHA256SUMS` pins it, so editing the generator or the copy would break the snapshot | this handover |
| The closed census row is amended in place, not marked | the roadmap is the live task list, and the changelog split retired the marker form for closed roadmap rows; the consolidation row is the live owner of the carriers' fates | this handover |

## Decisions pending

None.

## Findings

| # | Finding | Type | Impact | Triaged to |
|---|---|---|---|---|
| 1 | The live path is named by the frozen fixture's generator (`tests/eval/instruction-cleanup/tools/census-gen.mjs`) and by a historical grep snapshot in `.agents/drafts/close-the-model-bypass-run.md`; neither is a live consumer, and the fixture carries its own `.orig` copy | observation | deleting the source does not break the fixture or its checksum | Decisions table (the frozen fixture is left byte-identical) |

## Completed

| File | Change |
|---|---|
| `.agents/audits/test-assertion-sweep-brief.md` | deleted; the report-only per-assertion sweep is superseded by the `testing` convention and the test-quality campaign |
| `devlog/roadmap.md` | the census row names the deletion, and the consolidation row records the carrier's fate |
| `devlog/handovers/20261028-02-workflow-retire_assertion_sweep_brief.md` | this handover |
