---
date: 2026-11-07
milestone: M3.3.5 - The eval pipeline
type: Documentation
status: Closed
---

# Handover - the eval failure modes are prose again

## Objective

Keep what the failed eval runs taught about isolation, attribution and measurement, and state it as prose without the run record that produced it.

## Scope

The failure-record half of the eval convention. The harness and its cases are `20261107-01`; the caller gate is `20261107-02`; the record census and roadmap write-back are `20261107-03`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The isolation rule is prose and names no run, cell count or transcript quote | read `patterns/isolation.md`; a search for a run identifier or an archived transcript returns nothing | Agent [x] |
| The failure modes are prose and each one names the harness check or the open gap | read `antipatterns/README.md`; all eight modes carry a detected-by or remains-open statement | Agent [x] |
| The convention and the measurement contract point at the prose directories | links in `SKILL.md` and `references/contract.md` resolve | Agent [x] |
| The Markdown and handover gates are clean | `bash scripts/lint.sh`; `bash scripts/check_handover_format.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The failure modes are prose, not `catalog.jsonl` | The directory is read by a maintainer adding a case or a check, and a prose account carries the mechanism without a schema or a run id | `antipatterns/README.md` |
| The isolation rule stays a pattern file | One rule with its failure modes and its test is the unit a maintainer reads before writing a case | `patterns/isolation.md` |
| The run evidence is not restored | The modes are kept; the run identifier, cell counts and transcript quotes are not | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The denominator mode has no detector | measurement gap | The failure-mode entry says it remains open, and the measurement contract's A4 row is where the check will land | `devlog/roadmap.md` *A graded cell names the assertion it failed* |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/antipatterns/README.md` | Names the eight failure modes as prose, with the current check or the open gap beside each |
| `.agents/skills/evals/patterns/isolation.md` | States the isolation root, name, reach and escape test without the run narrative |
| `.agents/skills/evals/SKILL.md` | Points at the failure record and the pattern directory |
| `.agents/skills/evals/references/contract.md` | Routes a harness defect to a case, a gate or a prose entry |
