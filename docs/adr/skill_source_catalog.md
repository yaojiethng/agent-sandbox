# The Skill Source Catalog

**Current:** 2026-10-29

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Source facts have one home | The upstream URL, revision, license and file hashes appear once per source, not once per skill |
| R2 | The local answer stays local | A reader opening a skill can tell whether it was adapted or home-grown, in the skill's own directory |
| R3 | Drift is detected | A changed local file, a missing record, or a skill that stops pointing at its source fails a gate |
| R4 | A regroup does not lose provenance | Moving a skill, or folding it into another skill, leaves the source facts in place and the adaptation with the surviving skill |

## 2026-10-29 -- Two levels: a source manifest and a per-skill record

**Decision:** The maintenance catalog has two levels. The per-source manifest at [`source-catalog.json`](../../src/reasoning/agent/skills/source-catalog.json) holds the upstream URL, the resolved revision, the license, the copyright, the import commit, the file hashes and the skills forked from that source. A per-skill `MAINTENANCE.md` holds `## Adapted`, `## Name` and a `## Source` pointer to the manifest. The manifest's skill list is generated from the records, and [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs) re-hashes every local file and fails on drift. The catalog holds only sources with at least one fork: an accessible upstream this repository does not use is named in this ADR, not added as an empty source. A source revision is resolved by matching the imported blobs to the upstream commit; the local import commit is a route, not the source revision. A nested `SKILL.md` is not a separate skill: pi's loader treats a directory containing `SKILL.md` as a skill root and does not recurse further, so a skill that becomes a section of a parent moves its adaptation to the parent's record and the manifest lists the parent as the fork.

**Rationale:** The per-skill-only shape repeated the same upstream URL and import commit in every record. The four forks from one source would have written those facts four times, and the copies had no gate to keep them equal. `mattpocock/skills` at `62f43a18177be6ec82da242e59ffbc490a4c22ea` supplied four skills (`domain-model`, `grill-me`, `improve-codebase-architecture`, `setup-pre-commit`), and all nine imported files match that commit's blobs, so the source facts are a property of the source, not of each skill. The adaptation and the name are properties of the skill: a reader at the skill must still get the local answer without following a central index. The split keeps both, and the generated skill list plus the local hash check make the catalog's staleness visible. The source revision had to be resolved from the files because the local import commit `440577fe` is a copy made on 2026-04-28; it names neither the upstream revision nor the upstream's license. The license is recorded because MIT carries an attribution obligation, and a source catalog without a license is incomplete. The catalog is a fork catalog, not an upstream index: a source with no fork is a note, and the non-empty rule keeps a row from claiming a relationship this repository does not have. `JuliusBrussee/caveman` is the first such note: the import carried a condensed variant of the upstream, but this repository removed the skill and does not ship it, so the source is named here with its Apache-2.0 license and its revision `af5375d6f0151b1441f638d855f6829f5e6724df`, and the catalog does not list it.

**Rejected alternatives:**

### Keep the record per skill only

Rejected on R1. Every skill would repeat the source URL, revision and license, and a source update would be a sweep of every record with nothing reporting a copy left behind. The current `improve-codebase-architecture` record already carried the URL and the import commit; the next two forks would have made three copies.

### Keep the catalog per source only

Rejected on R2. The operator opening a skill would have to know which source to open before the question could be answered, and a skill moved between sources would lose its local answer. The acceptance criterion for the pipeline asks for the answer in the skill's own directory, so the adaptation record stays there.

### Allow a source row with `skills: []`

Rejected on the catalog's meaning, not on mechanics. An empty source would turn the catalog into an index of every upstream the repository has heard of, and the row would say nothing about what this repository actually forked. The non-empty rule keeps the invariant crisp: a catalog row is a source with at least one fork. An accessible upstream that is not forked is a note in this ADR, where the reason can be stated. The `caveman` removal is the first case.

### Keep a hand-written catalog

Rejected on R3. A hand-written list of skills and hashes is a second copy of the tree, and nothing reports when the tree changes. The generator reads the records and the files, so the list is derived, and `--write` is the only way to refresh it.

### Treat the local import commit as the source revision

Rejected on provenance. `440577fe` is a local commit that copies files; it says nothing about which upstream revision those files came from. The four `mattpocock/skills` skills resolve to `62f43a1` by blob matching, and the record names that commit. A source whose revision cannot be resolved does not enter the catalog until it is resolved; the gap is a finding and a roadmap row, not a guessed value.

**Edge cases / drivers:**

- **An accessible upstream that is not forked.** `JuliusBrussee/caveman` at `af5375d6f0151b1441f638d855f6829f5e6724df`, Apache-2.0, Copyright 2026 Julius Brussee. The local import carried a condensed variant, and this repository removed the skill. It is not a catalog row; this ADR names it so a reader who asks for caveman can find the source and the reason it is absent.
- **A skill with no upstream.** A home-grown skill is not in the catalog. Its `MAINTENANCE.md` states that it has no upstream in `## Source`, and the generator ignores it because it names no source id.
- **A skill that draws on several sources.** The manifest names one canonical source per skill, so the record has one pointer. Secondary sources are named in that record's `## Adapted`, not added as a second row.
- **A source whose revision cannot be resolved.** It stays out of the manifest until the revision is resolved. The finding records the gap and the command that would resolve it; a guessed commit would make the file hashes meaningless.
- **A nested skill.** pi's `loadSkillsFromDir` stops at the first `SKILL.md` in a directory, so a nested `SKILL.md` under `code-review/` is not discovered. If `improve-codebase-architecture` becomes a section of `code-review`, its adaptation moves into `code-review`'s record and the manifest lists `code-review` as the fork; the nested file is content, not a skill. The loader test in [`tests/test_skill_sources.sh`](../../tests/test_skill_sources.sh) holds the observed rule.
- **An upstream update.** Resolve the new revision by matching the imported blobs to the upstream, run `--write`, review the diff in the catalog and the records, and update each adaptation the diff touches. The license is re-read at the new revision; a license change is a new decision, not a silent edit.
- **The catalog ships as data.** `src/reasoning/agent/skills/` is copied to `/opt/workflow/agent/skills/`, so the manifest and the `MAINTENANCE.md` files ship with the skills. Neither is a skill: pi ignores a directory without `SKILL.md` and ignores a JSON file, so the catalog is readable data rather than a loaded instruction. The per-skill records are inert to the loader.
- **The earlier row.** The closed **Skill maintenance record** row records the per-skill-only shape. This ADR is the live decision; the row stays as the history of how the shape was first stated.
