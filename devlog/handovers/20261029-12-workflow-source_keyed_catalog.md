---
date: 2026-10-29
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - Key the maintenance catalog by source

## Objective

Replace the per-skill-only maintenance record with a per-source manifest and per-skill adaptation records, proved on `mattpocock/skills`.

## Scope

Delivers the M3.3.3 row **The maintenance catalog is keyed by source, and `mattpocock/skills` is its first subject**. The source resolves to `mattpocock/skills` at `62f43a18177be6ec82da242e59ffbc490a4c22ea` (2026-04-28), which holds `domain-model`, `grill-me`, `improve-codebase-architecture` and `setup-pre-commit`; the nine files the import added match that commit's blobs, and the source is MIT licensed. `caveman` is an accessible upstream at `JuliusBrussee/caveman` (Apache-2.0), but this repository does not fork it. The catalog holds only sources with at least one fork, so caveman is not a catalog row; the ADR names it as the accessible-but-unforked case. The local import commit `440577fe` is the route, not the source revision.

The unit covers the catalog shape, the source manifest, the four per-skill records, the generator and its check, the hash test, the loader test for the subskill question, and the ADR. It also adds `disable-model-invocation: true` to `improve-codebase-architecture`, which the operator directed on 2026-10-29.

Out of scope, one sentence each with the reason: `teach`, `how`, `why` and `unslop` are a different source and are filed as their own row, because they are not in the `440577fe` import; the full backfill stays with **Every skill in the tree carries a maintenance record**, because this iteration proves one source; the `grill-me` input contract stays with its own row, because the catalog records provenance, not behaviour; and the workflow packaging stays with its row, because this iteration settles the record contract.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The manifest records `mattpocock/skills` at `62f43a1` (MIT) for four skills, with the file hashes | `jq` reads the source; the nine blobs are recorded | Agent [x] |
| The four shipped skills carry `## Adapted`, `## Name` and a `## Source` pointer; the source URL and revision live only in the manifest | the four files exist; `rg` counts the URL once, in the manifest | Agent [x] |
| The generator's `--check` regenerates the skill list and fails on drift, and the hash test re-hashes each local file | `node scripts/lint/skill_sources.mjs --check`; the test passes; a temporary drift fails it | Agent [x] |
| The loader test records whether a nested `SKILL.md` under `code-review` is discovered, and the ADR states the rule | the test reports the observed result; the ADR carries the rule | Agent [x] |
| `improve-codebase-architecture` carries `disable-model-invocation: true` | `rg` finds the field; the frontmatter gate passes | Agent [x] |
| The ADR settles the shape, the nested-skill rule and the update path, and supersedes the old record row | the ADR sections; the roadmap row | Agent [x] |
| Every decision this iteration recorded is realized in the files | the Decisions table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The catalog is two-level: a per-source manifest and per-skill adaptation records | The source facts are properties of the upstream and are repeated in every skill record today; the adaptation and name are properties of the skill and must stay in its own directory. Separating them removes the duplication without losing the local answer. | this record; the ADR |
| The source revision is the upstream commit, not the local import commit `440577fe`: `mattpocock/skills` at `62f43a1` | The nine imported blobs match `62f43a1`; the local commit is a copy, not the upstream version. | this record; the manifest |
| Caveman is an accessible upstream, not a fork: the catalog keeps the non-empty-source rule and the ADR names it | The repo forked four of the imported skills. Caveman's canonical source is `JuliusBrussee/caveman`, but this repository does not ship it, so it is not a source with a fork. The ADR carries the accessible-but-unforked case. | this record; the ADR |
| The manifest is machine-readable and its skill list is generated; the per-skill records stay Markdown with `## Adapted`, `## Name` and a `## Source` pointer | A generated list cannot drift silently, and a gate can fail on it. The skill's own record remains the local answer the acceptance criterion asks for. | this record; the ADR |
| The source records its upstream `LICENSE`: MIT for `mattpocock/skills` | A source catalog without a license is incomplete. The ADR names the caveman upstream and its Apache-2.0 license as the accessible-but-unforked case. | this record; the manifest; the ADR |
| A nested `SKILL.md` is a skill only if the loader discovers it; the loader test decides | The answer changes where the provenance lives: a skill keeps its own record, a section moves its adaptation into the parent's record. | this record; the ADR |
| `improve-codebase-architecture` is operator-only | The operator directed `disable-model-invocation: true` on 2026-10-29, so the model cannot discover and fire it. | this record; the skill's frontmatter and record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The earlier plan put `teach` in the same source as `improve-codebase-architecture`; the `440577fe` import contains five skills and `teach` is not one of them. `how`, `why` and `unslop` are a different source again | source correction | the first test subject is the five imported skills; `teach` and its dependencies need their own source identification | roadmap M3.3.3, **Identify the source of `teach`, `how`, `why` and `unslop`** |
| `caveman` was attributed to the `mattpocock/skills` import; the canonical source is `JuliusBrussee/caveman` (Apache-2.0), and this repository does not fork it | source correction | the catalog omits it under the non-empty-source rule; the ADR names it as the accessible-but-unforked case; the skill directory is removed | this record; the ADR |

## Completed

| File | Change |
|---|---|
| [`source-catalog.json`](../../src/reasoning/agent/skills/source-catalog.json) | one source, four skills, the MIT license and the nine file hashes |
| [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs) | the generator and its check |
| [`scripts/check_skill_sources.sh`](../../scripts/check_skill_sources.sh) | the gate wrapper |
| [`scripts/lint.sh`](../../scripts/lint.sh) | registers the source-catalog gate |
| [`tests/test_skill_sources.sh`](../../tests/test_skill_sources.sh) | six tests: clean, drift, missing record, empty source, the real catalog, the nested-skill probe |
| [`tests/skill_source_loader.mjs`](../../tests/skill_source_loader.mjs) | the loader probe |
| [`domain-model/MAINTENANCE.md`](../../src/reasoning/agent/skills/domain-model/MAINTENANCE.md) | the adaptation and name, with the source pointer |
| [`grill-me/MAINTENANCE.md`](../../src/reasoning/agent/skills/grill-me/MAINTENANCE.md) | the adaptation and name, with the source pointer |
| [`improve-codebase-architecture/MAINTENANCE.md`](../../src/reasoning/agent/skills/improve-codebase-architecture/MAINTENANCE.md) | the two-level record, the dispatch fork and the operator-only field |
| [`setup-pre-commit/MAINTENANCE.md`](../../src/reasoning/agent/skills/setup-pre-commit/MAINTENANCE.md) | the adaptation and name, with the source pointer |
| [`improve-codebase-architecture/SKILL.md`](../../src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md) | `disable-model-invocation: true` |
| [`docs/adr/skill_source_catalog.md`](../../docs/adr/skill_source_catalog.md) | the two-level shape, the non-empty-source rule, the nested-skill rule and the update path |
| `src/reasoning/agent/skills/caveman/` | removed; the source is named in the ADR as accessible but not forked |
| [`devlog/roadmap.md`](../roadmap.md) | roadmap check at start; the catalog row marked; the source-identification row filed |
| [`devlog/handovers/20261029-12-workflow-source_keyed_catalog.md`](20261029-12-workflow-source_keyed_catalog.md) | this record |
