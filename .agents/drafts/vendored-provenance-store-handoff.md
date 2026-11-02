---
description: "Handoff - give vendored provenance one home in the source store: the record moves out of the per-artifact MAINTENANCE.md files into the store, the record gate is its validator, a record can cover a passage rather than a whole artifact, and a check catches drift."
argument-hint: "[scope note, e.g. migration order or one source at a time - optional]"
---

> $ARGUMENTS

# Handoff - move vendored provenance into one store

## What the next session is for

Today a vendored artifact's record sits beside the artifact, in a `MAINTENANCE.md`. That shape only works while the artifact owns a directory: a flat `prompts/` folder cannot hold one named after the prompt, a single instruction file like `AGENTS.md` has nowhere to put one, and records scattered across the tree hide the maintenance work. The task is to give every vendored record one home in the source store, with the record gate as its validator.

**This supersedes a landed decision.** `docs/adr/skill_source_catalog.md` R7 reads "Attribution ships with the forks", and that record rejects "ship the store instead of a `NOTICE`" on that ground. The licence obligation is not what changes: the `NOTICE` stays and keeps carrying URL, licence and copyright to the image. What moves is the *record* -- the adaptation history and the source a local artifact derives from.

Delete this file when the task lands.

## Where things stand

The store exists and is the live provenance record for edges: `.agents/registry/sources/<source-id>.json`, one file per source, holding `id`, `url`, `license`, `copyright`, and either `reason` or `artifacts[]` with `local_path`, `kind`, `parent`, `upstream_path`, `origin`, `base`. The store is edited by hand and validated by the record gate `scripts/check_skill_sources.sh`, which also reads the sixteen `MAINTENANCE.md` files that exist today and refuses a record naming a source id the store does not hold.

Prior art worth reading before designing: commit `8fa1cc4a` (the catalog-to-store migration), `devlog/handovers/20261030-02-impl-provenance_store_migration.md`, and `docs/adr/skill_source_catalog.md`. Nothing there moves adaptation prose into the store; that is the new part.

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One home for vendored provenance | every vendored record is an entry in the store; no artifact carries a record file of its own |
| R2 | One validator | every edit is judged by the gate, whichever route produced it; a write command is not the guarantor of validity |
| R3 | The record is keyed by the thing that moves | a rename or a move is one field changed in the store, and the gate holds the result |
| R4 | A record covers a whole artifact or a passage inside one | a copied paragraph in an otherwise-owned file is a record, so the store must express "this file, this passage, this source" |
| R5 | The record states what the merge review needs | source, revision, and what was kept, rewritten, added and dropped; its reader is the maintainer running a bump, not the agent reading the artifact |
| R6 | Drift is caught by a check, not by proximity | a record naming a file that no longer exists is a finding, and so is an artifact with no record |
| R7 | A licence notice travels with shipped bytes and is not the store's job | the `NOTICE` stays as it is; different question, different reader |

## The first fragment record

The concrete case that forces R4: `src/reasoning/providers/pi/config/agent/AGENTS.md` carries a seven-step code ladder copied from an old version of `dietrichgebert/ponytail`, revision unrecorded. The file is otherwise ours, so it is neither a fork nor home-grown, and the record must name the passage rather than the file. Keep the ladder whole: steps 2, 4 and 5 state delegation, 1, 6 and 7 state minimality, and the order is the instruction.

## The path-move prerequisite is retired

The CLI lost its write commands on 2026-11-01 (`20261101-08`): `check`, `format`, `diff` and `prepare` remain, the store is edited by hand, and the gate validates it. A rename is therefore one field changed in the store, and the row that asked for a move operation was retired with the write surface that produced it.

## Suggested skills

| Skill | Why this session needs it |
|---|---|
| `source-bump` | the store's writer and validator; the intent and the steps for a bump live there |
| `decision-records` | superseding R7 is an ADR entry, not an edit to the old one |
| `testing` | the gate changes from reading files to reading the store, and needs coverage both ways |
| `principle-guard-derived-state` | the migration creates records that can go stale, and R6 is the answer to that |

## Done when

- The store holds a record for every vendored artifact and for the copied passage, and the sixteen `MAINTENANCE.md` files are gone.
- `source-bump` writes those records, including a passage record, and can move a record's paths without a hand edit.
- The gate reads the store, still refuses a record naming an unknown source, and now also reports a record whose artifact is missing.
- `docs/adr/skill_source_catalog.md` carries a new entry superseding R7 for the record, leaving the `NOTICE` obligation intact.
- `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean.

## Do not resurrect

A declaration file for the added packages, a per-class pin taxonomy, a stage-two lockfile, an install-time name filter, and a form gate over bytes the repository does not hold. All were built and withdrawn on 2026-10-31. This task is about the records of bytes we *do* hold, which is the opposite side of the seam and the only side with a review behind it.
