---
date: 2026-10-29
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - Record every workflow skill and gate the tree

## Objective

Give every skill under `src/reasoning/agent/skills/` a maintenance record, put the `writing-for-agents` source in the committed lockfile with its own import revision, and make a missing or stale record a hard finding.

## Scope

Delivers the M3.3.3 subtask **The provenance records and the tree-wide gate**. The three home-grown skills -- `propagation-check`, `state-machine-specification` and `write-locations` -- gain a record that states `Source: home-grown.` and has no catalog entry. `writing-for-agents` gains a record and a `mattpocock-skills` catalog entry pinned to upstream `5beb35b0` (2026-10-19), imported at `0ec59c6a`; the source row stays at `62f43a1` for the four earlier forks, and the source URL, license and copyright stay on the row.

The scanner now walks the skill tree, not only the catalog. Every skill directory needs a record with `## Source`, `## Adapted` and `## Name`; a forked record must name a source in the catalog; a home-grown record states `Source: home-grown.` and is accepted. A per-skill `upstream_revision` and `upstream_revision_date` must be pinned together, and every per-skill commit field is a 40-character commit. `--write` still drops a catalog skill whose record is gone, but the tree walk refuses the remaining directory, so the missing record cannot be made to disappear.

The layer map's four warnings -- one per missing agent-sandbox record -- are gone; the map is clean across 58 skills. The M3.3.3 parent row is `[x]` with both subtask handovers; the full discoverability map and budget stay in M3.3.6.

Out of scope, one sentence each with the reason: the provider and project skill records stay out of this subtree, because the tree-wide gate covers `src/reasoning/agent/skills/` and the provider set is a different layer; the full discoverability map and the budget stay in M3.3.6; and the source-bump implementation stays with its roadmap row, because this unit records the source and does not move it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every skill under `src/reasoning/agent/skills/` has a `MAINTENANCE.md` with the three sections | `node scripts/lint/skill_sources.mjs`; `find` the records | Agent [x] |
| The three home-grown records state `Source: home-grown.` and are accepted without a catalog entry | `bash tests/test_skill_sources.sh` | Agent [x] |
| The `writing-for-agents` entry pins upstream `5beb35b0` and import `0ec59c6a`, with both file hashes | `jq` the catalog; the scanner | Agent [x] |
| A missing record, an unknown source and an invalid per-skill revision fail the gate | the new tree-wide tests | Agent [x] |
| The layer map is clean and no longer warns about the four records | `node scripts/skill_map.mjs` | Agent [x] |
| The four layer tests and the source-catalog tests pass | `bash tests/test_skill_map.sh`; `bash tests/test_skill_sources.sh` | Agent [x] |
| The repository suite is green | `bash scripts/run_tests.sh`; 1367 tests across 100 files | Agent [x] |
| The lint umbrella is clean with the skill-layer gate | `bash scripts/lint.sh`; 17 gates | Agent [x] |
| The parent and subtask rows are `[x]` with their handovers | `rg` the roadmap rows | Agent [x] |
| Every decision this iteration recorded is realized | Decisions table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The completeness gate walks the skill tree, not only the catalog | A home-grown skill is not in the catalog, so a catalog-only check would pass over the skill that has no provenance answer. | this record; the catalog ADR; `scripts/lint/skill_sources.mjs` |
| A home-grown record states `Source: home-grown.` and has no catalog entry | The catalog lists forked sources; a source row for a home-grown skill would invent an upstream. | this record; the ADR; the three records |
| A skill may pin its own `upstream_revision`, `upstream_revision_date` and `import_commit` | One source can be imported at different upstream revisions; a source-level row cannot be true for both the four older forks and the later writing skill. | this record; the catalog ADR; the writing entry |
| The writing entry pins `5beb35b0` and `0ec59c6a`; the source row stays at `62f43a1` | The writing was imported later than the four forks, and the local import commit is not the source revision. | this record; the catalog; the writing record |
| `--write` may drop a catalog skill, but the tree walk still refuses its directory | The write mode refreshes the catalog; it must not turn a missing record into a clean tree. | this record; the scanner; the test |
| A record names a known source id, or states home-grown | The record is the local answer; an unknown id would point at a source no one can open. | this record; the ADR; the scanner |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `writing-for-agents` is a second import from `mattpocock-skills` at a different upstream revision, and no single source revision could describe both it and the four older forks | provenance | the source row keeps its default and the skill entry pins its own revision, date and import commit | this record; the catalog ADR; the catalog |
| Four agent-sandbox skills had no record; the layer map warned about them but did not fail | provenance gap | the records land, and the tree-wide gate now fails a missing or malformed record | this record; the scanner; the records |
| The scanner's old check was catalog-only, so a home-grown skill could be absent from both the catalog and the record gate | completeness | the tree walk covers every skill, and the three home-grown records are the first accepted case | this record; the ADR; the tests |
| The layer map's warnings disappear once the records land | observation | the map is clean across 58 skills, with only the five allowed project-to-shipped links | this record; the map |
| The writing local `SKILL.md` hash differs from upstream because the local source blockquote and inline principle names are adaptations | provenance | the catalog records both hashes, and the record states the adaptation; the local hash is refreshed after the link removal | this record; the catalog; the writing record |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/agent/skills/propagation-check/MAINTENANCE.md`](../../src/reasoning/agent/skills/propagation-check/MAINTENANCE.md) | the home-grown record |
| [`src/reasoning/agent/skills/state-machine-specification/MAINTENANCE.md`](../../src/reasoning/agent/skills/state-machine-specification/MAINTENANCE.md) | the home-grown record |
| [`src/reasoning/agent/skills/write-locations/MAINTENANCE.md`](../../src/reasoning/agent/skills/write-locations/MAINTENANCE.md) | the home-grown record |
| [`src/reasoning/agent/skills/writing-for-agents/MAINTENANCE.md`](../../src/reasoning/agent/skills/writing-for-agents/MAINTENANCE.md) | the adapted record, with the source pointer and the local changes |
| [`src/reasoning/agent/skills/source-catalog.json`](../../src/reasoning/agent/skills/source-catalog.json) | the writing entry with its own revision, date and import commit, and its two file hashes |
| [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs) | the tree-wide record check, the record shape, the unknown-source check and the per-skill fields |
| [`tests/test_skill_sources.sh`](../../tests/test_skill_sources.sh) | five new tests: pinned revision, invalid revision, home-grown record, tree skill without a record, unknown source |
| [`docs/adr/skill_source_catalog.md`](../../docs/adr/skill_source_catalog.md) | the tree-wide record decision and the per-skill revision decision |
| [`devlog/roadmap.md`](../roadmap.md) | the parent and both subtasks are `[x]` with their handovers |
| [`devlog/handovers/20261029-16-workflow-provenance_records.md`](20261029-16-workflow-provenance_records.md) | this record |
