---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - move vendored provenance into the source store

## Objective

Give the source, the revision and the local adaptation of a bumped artifact one home in the store, so a bump reads its facts from one place and the gate holds that place valid.

## Scope

The roadmap row `Give vendored provenance one home in the source store`, worked from the handoff `.agents/drafts/vendored-provenance-store-handoff.md`, which was deleted when this landed.

**The purpose is the bump, and nothing else.** An edge exists because someone wants to keep that artifact current against an upstream: it carries the source, the revision the next merge starts from, and what the local copy changed. No attribution obligation rides on it (every source is OSS), and no skill owes an edge. A skill with no edge is not home-grown, not unrecorded and not a finding - it is a skill nobody bumps. The operator is who loses when an edge is wrong, because the bump then has nothing to build on.

That framing deletes three things the handoff assumed, and this iteration records each deletion rather than working around it:

- **The completeness rule retires.** The gate no longer requires a record per skill, so `scripts/lint/skill_sources.mjs` loses its record-shape half and becomes the store's validator.
- **`R2` retires.** No marker stays in the artifact: the store is the record, and a second statement of its fact is a copy the gate cannot adjudicate.
- **The home-grown records retire with their prose.** Six of the fourteen say nothing a bump can use ("nothing rewritten", "no upstream"), and their history lives in the handovers that wrote them.

Three relations have to fit the store, and the operator's reading of them settles the schema:

| Relation | Shape in the store |
|---|---|
| One artifact from one source | one edge, `local_path` to a directory or a file |
| One artifact built from three sources | three edges, one per source, each on the same `local_path`, each describing what its own source contributed |
| A passage inside an otherwise-own file | one edge whose `local_path` is the file and whose `anchor` is a verbatim line inside it |

Measured before the scope gate: 14 `MAINTENANCE.md` records, 278 lines - 10 in the agent layer the gate enumerates, 4 in the pi provider config it does not read. Two carry no `Source:` line, because no gate reads them. The store holds 7 edges, all `mattpocock-skills`, so `principle-guard-the-context-window` states a fork from `pstack-skills` that no edge records.

The passage case is an ordinary edge. The ladder in `src/reasoning/providers/pi/config/agent/AGENTS.md` landed at `de7bbd37` on 2026-07-01, and `DietrichGebert/ponytail` at `16f6cbf4b87792938e47b0f8c650b6d80fcbc98c` (2026-06-30, MIT, `Copyright (c) 2026 DietrichGebert`) states it as the seven-rung ladder in its `AGENTS.md`. So the edge carries `upstream_path: "AGENTS.md"`, `origin` and `base` at that revision, and no null-commit rule is needed.

Two things the handoff states need correcting, and this iteration corrects them: it counts sixteen records where the tree holds fourteen, and its "Done when" asks the CLI to write records and to move an edge's paths, which `20261101-08` retired with the write commands.

The vendoring pattern registers the edge. The facts an edge needs - the source, the revision and the upstream path - are known at the moment of vendoring and nowhere later, so [`fork-and-strip.md`](../../.agents/skills/skill-scaffolder/patterns/fork-and-strip.md) step 1 writes them into the store instead of into a record file beside the skill. The store's shape is the bump pattern's to state, so that document carries the registration half beside the bump it already owns, and the vendoring pattern points at it rather than restating it.

The bump is a pattern, not a skill. It has the same usage as fork-and-strip - operator-directed, one artifact, steps with a done-check, opened by the operator naming the work - so it takes the same form: [`patterns/upstream-bump.md`](../../.agents/skills/skill-scaffolder/patterns/upstream-bump.md) in the same table, and `.agents/skills/source-bump/` retires. The word is `upstream` because `source` here names the store's record, and the act is bumping against an upstream.
**The fork lifecycle gets its own skill.** `skill-scaffolder` does two jobs with different inputs: an author invents text and chooses a signpost, and a fork inherits text and must record what it changed. Three of its five patterns are the second job, so the pattern home and the skill disagree. The split moves the three - `fork-and-strip`, `provider-artifacts` and the bump - under `skill-fork`, and `skill-scaffolder` keeps the four authoring steps and the two authoring patterns. The count does not move: `source-bump` retires and `skill-fork` arrives, so the project layer holds 12 skills before and after.

The store's procedure has to live in one of the two, and either choice splits the record's home from its reader until the split lands. Doing the split here is why the bump pattern is written once rather than written in `skill-scaffolder` and moved out of it later.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A store edge carries what the bump review reads: the source narrative, and what was kept, rewritten, added and dropped | `bash tests/test_source_bump.sh` - `test_a_bad_record_field_fails`, and the seven migrated edges round-trip through `format` | accepted: 21 pass; a numeric value and an unknown field are both named |
| One artifact may carry several edges, one per source | a fixture with two sources naming one `local_path`, each with its own record, passes `source-bump check` and the gate | accepted: `test_an_artifact_in_two_sources_is_allowed` and `test_one_artifact_in_two_sources_passes` |
| A passage edge validates, and its anchor is what the gate checks | the `AGENTS.md` ladder edge passes; a fixture whose `anchor` does not occur in its `local_path`, or occurs twice, is refused | accepted: `test_a_broken_anchor_fails` covers both directions |
| A skill with no edge is not a finding | `bash tests/test_skill_sources.sh` - a fixture holding a skill directory and no edge for it passes | accepted: `test_a_skill_with_no_edge_passes` |
| The 14 `MAINTENANCE.md` files are gone, their fork records are edges, and their home-grown prose retires | `grep -rn 'MAINTENANCE.md' src/` = `0`; the store holds an edge for every artifact a bump reads | accepted: 9 edges across 4 sources, and the name survives only in the dated ADR entries and the migration paragraph |
| The gate resolves every edge against the tree | `bash tests/test_skill_sources.sh` - an edge whose `local_path` is absent, or whose directory holds no `SKILL.md`, is refused | accepted: `test_an_absent_local_path_fails` and `test_a_skill_edge_needs_a_skill_md` |
| The ADR records the retirement of `R2` and the narrowing of `R6`, and leaves the licence obligation intact | a dated entry in `docs/adr/skill_source_catalog.md`; `NOTICE` unchanged | accepted: `## 2026-11-01 -- The record moves into the store, and the store is opt-in`, with five rejected alternatives |
| The vendoring pattern registers the edge, and the bump pattern states the store's shape so registration needs no other document | `grep -rn 'MAINTENANCE' .agents/skills/skill-fork/patterns/*.md` = `0`; `patterns/upstream-bump.md` carries a registration section a reader can follow with no other file open | accepted: `## Register an edge` carries the field table and a canonical edge |
| The fork lifecycle has one home: `skill-fork` holds the three fork patterns, `skill-scaffolder` holds the two authoring ones, and no third skill names either job | `ls .agents/skills/skill-fork/patterns` = 3 files; `ls .agents/skills/skill-scaffolder/patterns` = 3 files; `node scripts/skill_map.mjs` counts 12 project skills; neither skill's description reaches the other's act | accepted: the scaffolder keeps `nested-patterns`, `prose-entrypoint` and `signposting`; the map reports 12 project skills and 62 in total |
| Every document that names a record's home is corrected | `grep -rln 'MAINTENANCE.md' docs/ .agents/ scripts/ tests/` read row by row | accepted: the dated ADR entries and the migration paragraph, and nothing live |
| The suite and the lint gates are clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | accepted: clean across 19 gates; 1432 tests across 104 files, 0 failed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The store is opt-in bump data, and no skill owes an edge | the only reader is the maintainer running a bump; a skill nobody bumps needs no record, and neither does the tree | the dated ADR entry; operator ruling |
| The gate drops the completeness rule and the record shape, and validates the store alone | nothing else has a claim to check, and the store's own validity is what a bump needs | the gate, and the same entry |
| No marker stays in the artifact: the store points at the tree, and nothing points back | a marker repeats a fact the store owns, so a check could not say which copy was wrong | the same entry |
| One `local_path` may appear in more than one source, and uniqueness is per `(source, local_path, anchor)` | a skill built from three forks has three contributions to describe separately | the validator |
| A passage is an edge with an `anchor`, and `KINDS` gains a file kind for an instruction file | a per-file marker cannot describe a passage, and `AGENTS.md` is neither a skill, a runbook nor a prompt | the validator |
| The `## Name` sections fold into the edge's record | a rename is part of what a bump review reads, and a commit message is not a durable record | the migrated edges |
| The pstack edge pins the last upstream commit before the skill entered the tree, and its `record.source` says the revision is a first pin and the differences are hand specialization | the revision it was taken from was never recorded, and a nullable commit would put the caveat in the schema instead of where the bump review reads it | the edge, and the ADR entry's rejected alternative |
| An edge's address is the source, the `local_path` and the `anchor`, and one artifact may carry one edge per source | a composite skill has three contributions to describe, and a passage and its file are two edges, not one | `scripts/skill_store.mjs`, and `source_tracking.md` |
| The vendoring pattern registers the edge, and the bump pattern states the shape | the facts are known at vendoring time, so the edge is written then or never; one document owns the store's shape rather than two describing it | `patterns/fork-and-strip.md` step 1, and `patterns/upstream-bump.md` |
| `skill-fork` owns the fork lifecycle, and `skill-scaffolder` keeps authoring | three of the five patterns serve a job the skill's own steps do not describe, and a fork's inputs are inherited rather than invented | the two skills, and `skill-scaffolder/SKILL.md`'s table |
| The bump becomes a pattern beside `fork-and-strip`, and the `source-bump` skill retires | the two have the same usage, so they take the same form; a pattern has no description, so no model-visible trigger has to name two acts | `.agents/skills/skill-fork/patterns/`, and that skill's table |
| The two descriptions split the trigger: `skill-fork` takes vendoring and bumping, `skill-scaffolder` loses `or clone a skill` | one description reaching both acts was the problem, and the split answers it without widening either | both skills' frontmatter |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The purpose is the bump, not attribution: the store is opt-in and no skill owes a record | steering | the completeness rule, `R2` and six home-grown records leave scope; the gate loses its record-shape half | this record, and the ADR entry |
| The `local_path` uniqueness rule landed on 2026-11-01 forecloses a skill built from three sources | defect | the rule reads a legitimate shape as a duplicate | fixed in this iteration: uniqueness is per `(source, local_path, anchor)` |
| `principle-guard-the-context-window` states a fork from `pstack-skills`, and no edge records it | defect | the live record disagrees with the artifact, and the migration is where it becomes load-bearing | fixed: the edge names `harness/pstack/claude-code/skills/principle-guard-the-context-window` at `190d2873`, the last upstream commit before the skill entered the tree |
| The ladder's upstream is locatable: `de7bbd37` landed it on 2026-07-01, and ponytail `16f6cbf4` states it in its `AGENTS.md` | finding | the passage needs no null-commit rule and no operator-supplied fact | the migrated edge, and this record |
| Two records carry no `Source:` line, and the gate reads neither | defect | the record shape is unenforced outside the agent layer, so an unreadable record reads as a valid one | fixed: both files retire, and the store's validator replaces the per-file shape |
| `KINDS` holds no file kind for an instruction file | defect | `AGENTS.md` cannot carry an edge | fixed: `instruction` is a file kind |
| The pstack set was read for anything else the tree took on: one skill, one name | finding | only `principle-guard-the-context-window` is pstack-derived; a six-word-run scan of all 62 tree skills against the 56 pstack skills and 12 guide documents finds three other hits, all incidental or a URL citation | this record: no other edge is owed |
| The ledger read a path as vendored-or-not, which the tree never stated | finding | the gate was about to check a distinction no artifact makes | fixed: the gate asks only that an edge resolve against the tree |
| Nothing registers a new vendored artifact: `fork-and-strip.md` pins the source into `MAINTENANCE.md`, and `source-bump` begins at an edge that already exists | defect | a skill vendored today gets no edge, and its source facts are re-derived from memory at the first bump | this iteration: the vendoring step writes the edge |
| The bump is a top-level skill whose description would have to name two acts, one of which the operator always directs | steering | the same usage as `fork-and-strip` takes the same form, which removes the description rather than widening it | this record, and the patterns table |
| `skill-scaffolder` holds the vendoring lifecycle its own steps never describe: three of five patterns serve it | finding | a reader reads an authoring procedure and then a fork procedure with no statement of when each applies | fixed: `skill-fork` takes the three, and each skill's description names one act |
| The roadmap's `Package skill ingestion as its own workflow` row names `skill-management` as a candidate and leaves the name open | finding | `skill-fork` is that module's first member, and this iteration decides a name the row reserved for itself | out of scope: the row keeps its name question, and this record states the relation |
| The handoff counts sixteen records and asks the retired CLI to write them | defect | a reader of the handoff plans work the tree no longer needs | fixed: the handoff is deleted with its task |

## Completed

| File | One-line change |
|---|---|
| `scripts/skill_store.mjs` | `record` and `anchor` validate, `instruction` joins `KINDS`, the edge address replaces the path as the uniqueness key, canonical form orders both |
| `scripts/lint/skill_sources.mjs` | the record-shape half is gone; the gate is the store's validator |
| `scripts/check_skill_sources.sh` | its header states the store as the subject |
| `scripts/skill_map.mjs` | the missing-`MAINTENANCE.md` warning retires with the rule |
| `.agents/registry/sources/mattpocock-skills.json` | seven edges carry their adaptation note |
| `.agents/registry/sources/pstack-skills.json` | the context-window edge, pinned at `190d2873`, with its note; the empty-source reason retires |
| `.agents/registry/sources/dietrichgebert-ponytail.json` | a new source, and the passage edge for the ladder in the pi `AGENTS.md` |
| `src/**/MAINTENANCE.md` | fourteen files deleted |
| `.agents/skills/skill-fork/` | the fork lifecycle: `SKILL.md` plus `patterns/fork-and-strip.md`, `provider-artifacts.md` and `upstream-bump.md` |
| `.agents/skills/source-bump/` | retired; its body is the bump pattern |
| `.agents/skills/skill-scaffolder/SKILL.md` | the authoring half only, its description naming one act and pointing at `skill-fork` |
| `docs/adr/skill_source_catalog.md` | the 2026-11-01 entry, `R2` retired and `R6` narrowed |
| `docs/development/source_tracking.md` | `record` and `anchor` documented, the store framed as opt-in bump data |
| `devlog/roadmap.md` | the row closes, and the delegation row stops asserting a record file |
| `tests/test_skill_sources.sh` | rewritten for the store: 10 cases |
| `tests/test_source_bump.sh` | the duplicate-path case becomes composite-allowed plus in-source-duplicate, and a bad record field |
| `tests/test_skill_map.sh` | the missing-record case becomes "a skill with no record passes" |
| `.agents/drafts/vendored-provenance-store-handoff.md` | deleted with its task |
| `devlog/handovers/20261101-09-impl-vendored_provenance_home.md` | this record |
