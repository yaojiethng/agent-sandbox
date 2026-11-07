---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Audit
status: Closed
---

# Handover - The build contract, instrument and catalog audit

## Objective

Establish whether the reasoning-image build's requirements, instrumentation and domain catalog are sufficient to delegate the layout and pinning to an agent, including what the old conversation logs record, and produce the gap map the next iterations consume.

## Scope

The audit the scope brief proposed as the first M3.6.4 iteration, on operator direction 2026-11-07. In scope: the reasoning-image build inputs, the existing instrument and gates, the records that state requirements or domain facts, and the old conversation logs under `$AGENT_HOME/agent/sessions/`, mined per the `reflect` skill's transcript-location method. The audit is read-only; it writes the gap study and this record, and files the next work rows.

Out of scope: writing the requirements or the instrument (the next iterations), the host build measurement (this container has no Docker; the audit reads the existing reports), and the provider directory rename (its own row). The general verification surface is M3.4.5's and dispatch measurement is M3.6.2's; this audit keeps to the reasoning-image build.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The study states each build requirement and marks it stated, implicit or missing, with the record that holds it | read the study's requirement table; every row has a state and a source | Agent [x] |
| The study maps each requirement to the existing instrument or marks the gap | the trace table has no empty metric or check cell | Agent [x] |
| The study catalogs the seven domain subjects: edge cases, user flows, fast/slow, frequent/infrequent, security, layer locking, copy-in | the catalog table covers the seven subjects, each with a state and a source | Agent [x] |
| The study records the evidence: the commands, their output, and whether a host report exists under `$INPUT_DIR/build/` | the evidence section names each command and result; the two 2026-10-16 reports are read | Agent [x] |
| The study's operational-frequency and edge-case claims are backed by named transcripts, with the query and date boundary reproducible | the log section names the transcript set, the query and the date boundary; each count is a count, not a mention | Agent [x] |
| Every gap has a destination: a new roadmap row, an existing row, or a record fix | the gap table's destination column is non-empty; the roadmap grep finds the new rows | Agent [x] |
| The audit changes no live build file; only the study, this handover and the roadmap write-back are written | `git status --short` after the audit shows those three paths | Agent [x] |
| The architecture documents in scope describe the system as built; the audit lists any lapse and its destination | the study's doc-lapse table; each lapse is fixed or filed | Agent [x] |
| The audit classifies each existing record as a source or a digest, and names the raw material the next iteration starts from | the study's source/digest table | Agent [x] |
| Every decision this iteration recorded is realized in the files | read the `## Decisions` table against the study and the tree | Agent [x] |
| The roadmap is checked against the prior handover and no maintenance edit is needed | read the roadmap M3.6.4 section and the prior handover | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The audit is read-only and reports gaps; it does not write the requirements or the instrument | the operator's three questions are an audit, not a design; writing the artifacts before knowing the gaps would re-create what exists | this record |
| The unit is the reasoning-image build and its provider harness | the general verification surface is M3.4.5's and dispatch measurement is M3.6.2's; this is the build's own contract | this record |
| The catalog is classified as derived or prose, and the derivable parts are named for a generator | a hand-maintained catalog goes stale; the tree can produce the operation table | this record; the study |
| The host baseline is out of scope; the audit records the existing reports and the absence of a current one | this container has no Docker; the host run belongs to the instrument iteration | this record |
| The old conversation logs are a source, mined per the `reflect` skill's transcript-location method; every log figure names its transcript set and date boundary | the operator named the logs as an additional source on 2026-11-07; they carry the operational frequency and edge cases no document holds | this record; the study |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| G1 the requirements are stated but scattered; the log-only requirements and the edge cases have no document | the new `The build requirements and domain catalog are stated` row |
| G2 the instrument covers the layer cache and the layout, not the pin, copy-in, security, frequency or concurrency requirements | the new `The host build probe records the production run` row |
| G3 the two probe rows the M3.6.4 acceptance criteria name do not exist, and the only host baseline is the 2026-10-16 old-shape report | G2 and the open `The host build probe is re-run against the new shape` row |
| G4 the pin policy has no implementation or scan | the open `Pin every build input` row |
| G5 no `.dockerignore`; the context includes `.git` and `devlog` | the new `The build context is narrowed to the declared inputs` row |
| G6 `--rebuild` stops at tier 2 while the tool interface says everything | G1 states the semantics; G2 tests them |
| G7 the 2026-10-16 census and invalidation study are stale digests | G1; re-derive or mark historical |
| G8 the M3.6.4 design step and acceptance criteria describe a superseded frame | G1 rewrites the M3.6.4 text |
| G9 the old logs are the only carrier of several requirements and edge cases | G1 writes them down with the transcript date |
| G10 the provider directory rename is a separate open row | the existing `The provider directory is renamed to agent-runtime` row |

## Completed

| File | Change |
|---|---|
| the audit study, since deleted | the gap map; the study was retired at `20261107-07` once its rows closed, and this table is its surviving index |
| `devlog/roadmap.md` | targeted roadmap check; the audit row and the three next rows |
