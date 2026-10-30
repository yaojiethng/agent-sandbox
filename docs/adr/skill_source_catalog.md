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

**Rationale:** The per-skill-only shape repeated the same upstream URL and import commit in every record. The four forks from one source would have written those facts four times, and the copies had no gate to keep them equal. `mattpocock/skills` supplied the four skills named in the `mattpocock-skills` row, and the row records the revision, license, copyright and the nine file hashes; the imported files match them, so the source facts are a property of the source, not of each skill. The adaptation and the name are properties of the skill: a reader at the skill must still get the local answer without following a central index. The split keeps both, and the generated skill list plus the local hash check make the catalog's staleness visible. The source revision had to be resolved from the files because the local import commit is a copy, not the upstream revision; the row records both. The license is recorded because the attribution obligation is part of the source record, and a catalog without it is incomplete. The catalog is not an upstream index; the later entry in this file requires a reason for an empty row. The `juliusbrussee-caveman` row is the first source this repository looked at and did not fork; the row records the reason, and the skill is not shipped.

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

Rejected on provenance. A local import commit copies files; it says nothing about which upstream revision those files came from. The four `mattpocock/skills` skills resolve to the source row's revision by blob matching, and the record names that revision. A source whose revision cannot be resolved does not enter the catalog until it is resolved; the gap is a finding and a roadmap row, not a guessed value.

**Edge cases / drivers:**

- **An accessible upstream that is not forked.** `JuliusBrussee/caveman` is the first source this repository looked at and did not fork; the `juliusbrussee-caveman` row records its revision, license and reason, and the skill is not shipped.
- **A skill with no upstream.** A home-grown skill is not in the catalog. Its `MAINTENANCE.md` states that it has no upstream in `## Source`, and the generator ignores it because it names no source id.
- **A skill that draws on several sources.** The manifest names one canonical source per skill, so the record has one pointer. Secondary sources are named in that record's `## Adapted`, not added as a second row.
- **A source whose revision cannot be resolved.** It stays out of the manifest until the revision is resolved. The finding records the gap and the command that would resolve it; a guessed commit would make the file hashes meaningless.
- **A nested skill.** pi's `loadSkillsFromDir` stops at the first `SKILL.md` in a directory, so a nested `SKILL.md` under `code-review/` is not discovered. If `improve-codebase-architecture` becomes a section of `code-review`, its adaptation moves into `code-review`'s record and the manifest lists `code-review` as the fork; the nested file is content, not a skill. The loader test in [`tests/test_skill_sources.sh`](../../tests/test_skill_sources.sh) holds the observed rule.
- **An upstream update.** Resolve the new revision by matching the imported blobs to the upstream, run `--write`, review the diff in the catalog and the records, and update each adaptation the diff touches. The license is re-read at the new revision; a license change is a new decision, not a silent edit.
- **The catalog ships as data.** `src/reasoning/agent/skills/` is copied to `/opt/workflow/agent/skills/`, so the manifest and the `MAINTENANCE.md` files ship with the skills. Neither is a skill: pi ignores a directory without `SKILL.md` and ignores a JSON file, so the catalog is readable data rather than a loaded instruction. The per-skill records are inert to the loader.
- **The earlier row.** The closed **Skill maintenance record** row records the per-skill-only shape. This ADR is the live decision; the row stays as the history of how the shape was first stated.

## 2026-10-29 -- An empty row records a source that is not forked

**Decision:** The catalog holds the source facts for every source this repository has looked at, forked or not. A source that is not forked is a row with `skills: []`, a `reason`, and `import_commit: null`. `juliusbrussee-caveman` and `pstack-skills` are the first such rows. This supersedes the non-empty-source rule in the entry above. The ADR states the shape; the source facts live only in the manifest.

**Rationale:** Live values in prose go stale, and the ADR is a decision record, not a lookup table; the manifest is machine-readable and gated. The `reason` keeps an empty row from turning the catalog into an upstream index: an empty row is a deliberate record of a source the repository has chosen not to fork. The pstack four are the first case: they stay in the config home because other agent-sandbox projects must not assume them, and `unslop` overlaps `writing-for-agents`. The caveman source is the second: the skill was removed and is not shipped. `writing-for-agents` is a different gap: it is a mattpocock fork with no record, and the backfill row owns it.

**Rejected alternatives:**

### Keep the source values in the ADR

Rejected on the operator's past experience: a live revision or license in prose goes stale, and no gate reports the copy. The manifest is the structured home.

### Allow an empty row with no reason

Rejected: that is the upstream index the previous rule was guarding against. The `reason` is the difference between a deliberate non-fork and an unexamined entry.

### Keep the non-empty rule

Rejected: it forces the source facts of a non-forked source into the ADR, which is the duplication this entry removes. The rule's intent is kept by the required reason.

### Import the four into the base tree

Rejected on optionality and the overlap. The config-home arrangement lets a project use them, and every other agent-sandbox project continue without them. An import would reverse that for every consumer.

### Import a subset

Rejected because `teach` calls `how`, `why` and `unslop`. A subset either ships a `teach` that names a missing skill, or ships `unslop` beside `writing-for-agents` and puts two prose standards in the tree.

**Edge cases / drivers:**

- **A source that is not forked.** `juliusbrussee-caveman` and `pstack-skills` are the first rows; each carries a `reason` and no import commit. The four pstack skills stay in the config home; the caveman skill is not shipped.
- **A source with a fork.** The `mattpocock-skills` row is unchanged: `skills` lists the four forks, the import commit is present, and the records carry the adaptations.
- **A source whose revision cannot be resolved.** It does not enter the catalog; the row would carry a guessed revision and the hashes would be meaningless. The gap is a finding.
- **An empty row with a record.** The generator reports it; a record belongs to a forked source. The empty row has no tree skill.
- **The installed copy.** The manifest ships as data, and the installed copy is read-only; the gate runs against the repository root. A per-sandbox installation log would be a per-project derived value, not the installation record; the image build and the repository gate are the places that check it.
