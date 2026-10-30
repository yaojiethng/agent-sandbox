# The Skill Source Store

**Current:** 2026-10-30

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Source facts have one home | The upstream URL, license, copyright and the artifact edges appear once per source, in the per-source store |
| R2 | The local answer stays local | A reader opening a skill can tell whether it was adapted or home-grown, in the skill's own directory |
| R3 | The store carries no derived data | No file hash, revision date or import commit is stored; `origin` and `base` are the only commits |
| R4 | A regroup does not lose provenance | Moving a skill, or folding it into another skill, leaves the source edge in place and the adaptation with the surviving skill |
| R5 | The merge base is per artifact | One source can feed artifacts at different revisions, so each edge carries its own `base` |
| R6 | The bump is operator-directed and pinned by default | A bump runs only on the operator's direction; `source-bump check` is a validation command, not a lint gate |
| R7 | Attribution ships with the forks | The source URL, license and copyright reach the image in a shipped `NOTICE` |

R3 replaced the retired drift rule on 2026-10-30. A historical entry below that names R3 refers to the drift rule that was current when it was written.

## 2026-10-30 -- The catalog retires into the per-source store

**Decision:** The source facts and the artifact edges live in `.agents/registry/sources/<source-id>.json`, one file per source. A source file holds `schema`, `id`, `url`, `license`, `copyright` and `artifacts`; an empty source adds `reason`. Each artifact edge holds `local_path`, `kind`, `parent`, `upstream_path`, `origin` and `base`. The store is repository-only; the `source-bump` CLI is its only writer. `origin` is the revision the artifact was first taken from; `base` is the reviewed upstream revision the next merge uses, and it moves after each review.

The source catalog and the per-skill hashes are retired. The five agent-layer forks name `mattpocock-skills` and the shipped `NOTICE`; the three home-grown records keep `Source: home-grown.`. `NOTICE` at `src/reasoning/agent/skills/NOTICE` lists the URL, license and copyright for every source and ships under the existing skills `COPY`. The record gate checks complete records and known source ids, with no hash, catalog or `--write`. `source-bump check` is a validation command, not a lint gate; a bump runs only when the operator directs it, and the store stays pinned by default.

**Rationale:** The catalog mixed the structured source facts, the artifact edges and a hash table that had to be refreshed after every local edit. The hash is derived data: it says the file is what it was when the catalog was written, not whether the local adaptation still matches the upstream intent. One source can also feed artifacts at different revisions, which a source-level revision cannot express. The store keeps the facts and the two commits that make a merge reproducible, and the CLI validates every write. The `NOTICE` is the one shipped copy of the attribution; the store is repository-only, so without it the image would lose the license and copyright. The record gate keeps the local answer and the known-source invariant deterministic without making the bump a gate.

**Rejected alternatives:**

### Keep the catalog and add the store

Rejected on R1. Two source-fact homes would need a gate to keep them equal, and the catalog's hash table is exactly the derived data the redesign removes.

### Keep the hashes and the drift gate

Rejected on R3. A local hash is stale on every edit, and a changed local file is the normal state of an adapted fork. The hash reports the edit, not a defect; the review decides whether the upstream intent still holds.

### Ship the store instead of a `NOTICE`

Rejected on R7. `.agents/` is not copied into the image, so the store cannot carry the attribution to the shipped skills. A `NOTICE` in the copied skills root is the smallest shipped copy.

### Make `source-bump check` a lint gate

Rejected on R6. A bump is a discretionary upstream review the operator directs; a lint gate would turn a pinned store into a drift alarm and make a routine check look like a failed build.

### Keep the revision date and the import commit

Rejected on R3. The revision date is metadata for a review, and the local import commit is the copy that produced the tree. Neither is the merge base. `origin` and `base` carry the two revisions the merge needs.

**Edge cases / drivers:**

- **An empty source.** `pstack-skills` and `juliusbrussee-caveman` carry `artifacts: []` and a `reason`; the store keeps the source facts and no edge.
- **A per-artifact base.** `writing-for-agents` sits at `5beb35b0` while its four siblings sit at `62f43a1`; the edge, not the source, carries the pair.
- **A home-grown skill.** It is absent from the store and states `Source: home-grown.` in its record.
- **A record naming an unknown source.** The record gate reports it; the store is the source-id set, and the CLI owns its schema.
- **The provider pstack records.** They name no source id and stay outside this decision; **Ingest `pstack` upstream** owns their provenance.
- **The historical catalog references.** Closed handovers and the older ADR entries still name `source-catalog.json`; they describe the system as it stood and are not rewritten.
- **The installed copy.** `src/reasoning/agent/skills/` is copied to `/opt/workflow/agent/skills/`; the `NOTICE` and the `MAINTENANCE.md` records ship, and pi loads neither as a skill.

## 2026-10-29 -- Every skill carries a record, and the catalog lists only forks

**Decision:** Every skill directory under `src/reasoning/agent/skills/` has a `MAINTENANCE.md` with `## Source`, `## Adapted` and `## Name`. A forked record names a source id in the catalog; a home-grown record states `Source: home-grown.` and has no catalog entry. The scanner walks the tree, not only the catalog, so a skill that is not a fork still has to answer the question. The catalog remains the list of forked sources; it does not become an index of every skill. The tree-wide check is in [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs), and the shipped gate is [`scripts/check_skill_sources.sh`](../../scripts/check_skill_sources.sh).

**Rationale:** The catalog-only check could not answer for a home-grown skill: it was not in the catalog, so nothing asked whether it had a record. A separate home-grown index would be a second list to maintain, and a source row for a home-grown skill would claim an upstream it does not have. The tree is the complete set of skills, so the tree is the subject of the completeness check, and the catalog stays the source-fact home. The four missing records in the agent-sandbox layer are the first case the gate catches.

**Rejected alternatives:**

### Check only the skills in the catalog

Rejected on completeness. A home-grown skill is not in the catalog, so the check would pass over the exact skill that has no provenance answer. The catalog's list and the tree's list are different sets, and only the tree is complete.

### A second home-grown index

Rejected on single source. A list of home-grown skills would repeat the tree and go stale; the record in each skill directory is the local answer, and the tree walk discovers it.

### A source row for every home-grown skill

Rejected on truth. A home-grown skill has no upstream; a catalog row would invent one or use a placeholder, and the source facts would be fiction.

### Require the record only in the source manifest

Rejected for the same reason as the catalog-only check: the manifest is keyed by source, and a home-grown skill has none.

**Edge cases / drivers:**

- **A home-grown record.** `Source: home-grown.`; the record is accepted and the skill is not counted as a catalog skill.
- **A forked record.** The `Source: \`id\`` line must name a source the catalog holds; an unknown id is a finding.
- **A skill with no record.** The tree walk reports it even when the skill is absent from the catalog; the four agent-sandbox records were the first case.
- **The `--write` mode.** It drops a catalog skill whose record is gone, but the tree walk still refuses the directory that remains; the two modes cannot make a missing record disappear.
- **A nested `SKILL.md`.** The walk stops at a skill root, as pi does; a runbook under a skill is content, not a second skill.
- **The records ship as data.** The tree is copied to `/opt/workflow/agent/skills/`; the records and the catalog are inert to the loader and readable to the agent.

## 2026-10-29 -- A skill may pin its own source revision

**Decision:** A skill entry may pin its own `upstream_revision`, `upstream_revision_date` and `import_commit`. The source row keeps the source identity and its default revision; the skill's values override the default for that skill alone. `writing-for-agents` is the first case: the `mattpocock-skills` row stays at `62f43a1` for the four earlier forks, and the writing entry pins `5beb35b0` (2026-10-19) with its own import commit `0ec59c6a`. The source URL, license and copyright stay on the source row; the skill record points at that row by id. The catalog entry is in `src/reasoning/agent/skills/source-catalog.json`, and the writing record is in [`writing-for-agents/MAINTENANCE.md`](../../src/reasoning/agent/skills/writing-for-agents/MAINTENANCE.md).

**Rationale:** One source can be imported more than once at different upstream revisions. A single source revision cannot be true for the four older forks and the later writing skill at once. A second source row would duplicate the URL, license and copyright and would split one upstream into two identities. The per-skill override keeps the source facts at their one home and records the revision where it differs. The local import commit is not the source revision; the writing entry records both, as the earlier entry requires for the source row.

**Rejected alternatives:**

### A second source row for the same upstream

Rejected on R1. The row would repeat the URL, license and copyright, and a source update would have two copies with no gate keeping them equal. The source identity is the upstream, not the revision that happened to be imported.

### Move the source row to the writing revision

Rejected on provenance. The four earlier forks were imported from `62f43a1`; moving the row's revision would make their recorded hashes describe a revision they did not come from.

### Put the revision in the per-skill record

Rejected on R1. The record would repeat source-level values in prose, and the source manifest is the machine-readable home. The record points at the source id; the entry carries the revision.

### Pin the revision only when the source row has one skill

Rejected as an arbitrary exception. A source with a second import has the same problem whatever its size; the override is a property of the skill entry, so it applies uniformly.

**Edge cases / drivers:**

- **A skill with no override.** It uses the source row's `revision`, `revision_date` and `import_commit`; the four earlier forks do.
- **A source update.** A new import gets its own skill entry and its own pinned revision; the source row changes only when the default itself moves.
- **A local edit after import.** The local hash changes while the pinned upstream hash stays; the catalog reports the difference, and the record states the adaptation.
- **A per-skill import commit without a revision.** The gate refuses it: the two fields are pinned together, and a commit with no upstream revision says nothing about the source.
- **The installed copy.** The manifest and the records ship with the skills as data; the gate runs against the repository root.

## 2026-10-29 -- Two levels: a source manifest and a per-skill record

**Decision:** The maintenance catalog has two levels. The per-source manifest at `src/reasoning/agent/skills/source-catalog.json` holds the upstream URL, the resolved revision, the license, the copyright, the import commit, the file hashes and the skills forked from that source. A per-skill `MAINTENANCE.md` holds `## Adapted`, `## Name` and a `## Source` pointer to the manifest. The manifest's skill list is generated from the records, and [`scripts/lint/skill_sources.mjs`](../../scripts/lint/skill_sources.mjs) re-hashes every local file and fails on drift. The catalog holds only sources with at least one fork: an accessible upstream this repository does not use is named in this ADR, not added as an empty source. A source revision is resolved by matching the imported blobs to the upstream commit; the local import commit is a route, not the source revision. A nested `SKILL.md` is not a separate skill: pi's loader treats a directory containing `SKILL.md` as a skill root and does not recurse further, so a skill that becomes a section of a parent moves its adaptation to the parent's record and the manifest lists the parent as the fork.

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
