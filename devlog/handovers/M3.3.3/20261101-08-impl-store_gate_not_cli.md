---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the gate holds the store, not the CLI

## Objective

Retire the write half of the `source-bump` CLI, so the source store is edited directly and one gate holds its validity and its canonical form.

## Scope

Operator direction, 2026-11-01: route B over route A, after the question of whether the CLI's CRUD surface earns its keep.

The store is 3 files and 7 artifact edges of flat scalars: no derived value, no record referencing another by id, no lifecycle, one cross-file rule (`local_path` is unique). `add` and `record` (about 190 of 692 lines) re-run the validator before writing, so their refusals are the validator's findings printed earlier. What they add that nothing else has is a validator at all: `source_bump check` is in no gate, so every other path into the store - a merge, a rebase, a hand edit - is unvalidated. That was true when this session edited the store by hand twice.

This iteration moves the mechanism to where it covers every path: the validator becomes the library's, the gate runs it, and a `format` command rewrites a file into canonical form so a canonical shape is derived rather than hand-maintained. `add`, `record` and the never-written `move` go.

The roadmap row **`source-bump` cannot rename an edge** is retired with the write surface that produced it: under this design a rename is one field changed by hand, which the gate validates.

In scope: the validator's move into the library, the CLI's reduced command set, the gate that runs it, the canonical-form check and the `format` command that satisfies it, the four documents that state the writer rule, an ADR entry superseding it, the tests, and the roadmap.

Out of scope: the vendored-provenance record's move into the store, which the handoff owns and whose premise sentence this iteration only corrects; `check`, `diff` and `prepare`, which are the merge's instruments and stay unchanged; and any new gate beyond extending the one that already reads the store.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `add` and `record` are gone, and the CLI's five commands are four | `node scripts/source_bump.mjs --help`; `grep -c 'case "add"\|case "record"' scripts/source_bump.mjs` | accepted: help lists `check`, `format`, `diff`, `prepare`; the grep is `0` |
| The store's validity is held by a gate, so a hand edit that breaks it fails a gate that runs on every commit | `bash tests/test_skill_sources.sh` - `test_the_store_rules_fail_the_gate` and `test_a_duplicate_local_path_fails_the_gate` | accepted: 12 pass; the gate names an unknown field, an absent path, a non-canonical file and a `local_path` collision |
| A file that is not in canonical form fails the gate, and `source-bump format` brings it to canonical form without changing a field value | `bash tests/test_source_bump.sh` - `test_format_canonicalises_without_changing_a_value`, `test_format_leaves_a_canonical_file_identical`, `test_format_refuses_an_invalid_store` | accepted: 19 pass; values compare equal with key order and edge order normalised away, and a canonical file is byte-identical |
| One validator, two callers: the gate and `source-bump check` report the same finding for the same file | `bash tests/test_source_bump.sh` - `test_the_gate_and_check_agree`, over one fixture with an absent `local_path` | accepted |
| No live document states that the CLI is the store's only writer; the superseded rule appears only where the ADR quotes it | `grep -rn 'only writer'` over `source_tracking.md`, `skill_source_catalog.md`, `source-bump/SKILL.md` and the handoff | accepted: three hits, all in the ADR - the 2026-10-30 decision, its supersession, and the rejected alternative |
| The ADR supersedes the rejection by a dated entry that names what the rejection missed | `grep -n '2026-11-01' docs/adr/skill_source_catalog.md` | accepted: the entry `2026-11-01 -- The gate validates the store, and no command writes it`, and R6 restated under the requirements table |
| The roadmap retires the open rename row and records this unit | no `- [ ]` row naming `source-bump cannot rename an edge`; the new row is `[x]` | accepted: the row reads `The gate holds the store, not the CLI`, `[x]` |
| Every decision this iteration recorded is realized in the files | `git diff` read against the Decisions table | accepted: five decisions, each with its file |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The validator moves into `scripts/skill_store.mjs` and keeps one entry point | the gate and `check` are two callers of one rule set; leaving it in the CLI would make the gate import a command-line script's internals | this handover |
| The store gate is an extension of `check_skill_sources.sh`, not a twentieth gate | that gate already reads every source file to resolve the ids the skill records name, so the store's own validity is the same subject: the store and the records that point at it agree | this handover |
| A `format` command stays, and it writes only the derived form | order, key order and indentation are derived from the content, so a hand-written file can be brought to canonical form by one command; the command never sets a field value, so the writer question does not return with it | this handover |
| Source-fact immutability becomes a stated convention, not a check | `add` enforced it by not accepting the flag; a check would need `git` history inside a gate that must also run on a fixture with no repository, and a changed `url`, `license` or `copyright` is visible in the review diff the store exists for | this handover |
| The change supersedes the ADR's rejection of a store gate rather than reversing it silently | that rejection argued a gate would make a pinned store look like a failed build when upstream moved; `check` never fetches and never compares to upstream, so it holds validity, not currency, and the reason does not reach the operation being gated | this handover, and a new dated ADR entry |

## Decisions pending

| Decision | Question | Why it is not mine |
|---|---|---|
| none open | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `source_bump check` was in no gate, so the store's validity was held only by the write path | defect | every other route into the store - merge, rebase, hand edit - arrived unvalidated, and this session wrote it by hand twice without detection | this handover: the gate now runs the validator |
| `docs/adr/skill_source_catalog.md` rejected making `check` a lint gate | record | the rejection's reason is about currency, and `check` holds validity, so the reversal needed a dated entry naming that gap | this handover, and the 2026-11-01 ADR entry |
| The operator ruled route B over route A at the scope gate | steering | the unit stopped being "add a `move` command" and became "retire the write half", which retires the roadmap row that asked for `move` | this handover, and the roadmap |
| The M3.3.3 objective and two closed rows stated a defect the tree no longer held | defect | a reader of the active milestone read a stale state | corrected in `devlog/roadmap.md` before the scope gate |
| The canonical-form rule subsumes the sort rule | defect | two rules over one fact would have let `format` refuse the file it repairs; the form comparison states order, key order and indentation once | this handover, and `scripts/skill_store.mjs` |

## Completed

| File | One-line change |
|---|---|
| `scripts/skill_store.mjs` | the validator, the normalizers and `canonicalText` moved in here; `collectFindings` takes the root and the form rule |
| `scripts/source_bump.mjs` | `add`, `record` and their helpers deleted; `format` added; `check` imports the validator |
| `scripts/lint/skill_sources.mjs` | runs the store validation and the canonical-form comparison |
| `scripts/check_skill_sources.sh` | its header states the gate now holds the store as well as the records |
| `tests/test_source_bump.sh` | 8 write-command cases out, 4 in: two `format` cases, a refusal, and the gate/check agreement; an `add_edge` helper writes fixtures |
| `tests/test_skill_sources.sh` | two cases: the store rules and a cross-source `local_path` collision |
| `docs/development/source_tracking.md` | the CLI table loses two rows and gains `format`; `## The agent and the store` states the gate's ownership |
| `docs/adr/skill_source_catalog.md` | the 2026-11-01 entry, R6 restated, and the rejection answered |
| `.agents/skills/source-bump/SKILL.md` | four commands; step 8 edits the base and runs `format` and `check` |
| `.agents/drafts/vendored-provenance-store-handoff.md` | its writer premise and its path-move prerequisite corrected |
| `devlog/roadmap.md` | the rename row retired, this unit filed and ticked, the provenance row's prerequisite corrected |
| `devlog/handovers/20261101-08-impl-store_gate_not_cli.md` | this record |
