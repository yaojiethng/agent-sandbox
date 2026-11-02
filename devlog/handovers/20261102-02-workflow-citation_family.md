---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Workflow
---

# Handover - a citation is a pointer with a record

## Objective

The linking convention gains the form a citation to an outside source takes, and a family of citation records holds what each source gave us and what we dropped, so a standard we adapt is not re-read from scratch the next time.

## Scope

This iteration delivers the second unit of the roadmap row **Move the documentation-writing and skill-writing guidelines under `skill-scaffolder`**, after the principle's rule-set case landed at `2a67fdab`.

**In scope.** The `linking` convention's `## Citations` section and the `S2` row it names; `docs/development/source_tracking.md` `## Citations`, which holds the record's fields; and three citation records, RFC 2119, Diataxis and Kaplow's rules-versus-standards.

**Deferred, and why.** The authoring surface that cites these records - the `instruction-authoring` skill, its two carrier sheets, and the retirement of `docs/development/prompt-authoring-conventions.md` - is a further iteration. Operator direction on 2026-11-02 is that this work land as individual edits read one at a time. That material is held uncommitted in the working tree and is not part of this commit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A citation is stated as a pointer whose target may be inside the repository or outside it, and the outside form names publisher, title, version or date, and URL | `grep -n -A8 '^## Citations' .agents/skills/linking/SKILL.md` | Agent [x]: four paragraphs, and the form names all four parts |
| The reason the version is load-bearing is stated with the gate's behaviour named rather than asserted | the section names `scripts/lint/linking.mjs`; `grep -n 'https' scripts/lint/linking.mjs` shows the skip | Agent [x]: the skip is at the target test in that scanner, and the section names the file rather than a line |
| The record's fields have one home, and `linking` points at it instead of restating them | `grep -c 'kept' .agents/skills/linking/SKILL.md` = `0`; the field table is in `source_tracking.md` `## Citations` | Agent [x]: `0`, and one table |
| Three citations exist, each carrying what was kept, rewritten, added and dropped | `ls .agents/registry/citations/`; each file parses and holds the five `record` keys | Agent [x]: three files, five keys each |
| Every URL in a citation resolved when it was written | `curl -sS -o /dev/null -w '%{http_code}' --max-time 20 -L <url>` for each, all `200` | Agent [x]: three of three, and the Kaplow page was read for title, author, journal and year before the record was written |
| The gate is clean on the tree this commit leaves | `bash scripts/lint.sh`; `bash scripts/check_document_shape.sh` | Agent [x]: 19 gates clean, 172 instruction files and 28 principle skills |
| The commit carries this unit and nothing from the deferred surface | `git show --stat HEAD` | Agent [x]: five paths, and the surface is absent |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A citation is a separate family from a forked source, not a new artifact kind in the source store | The two have different validity rules, and one validator cannot serve both: a fork's edge must resolve against the tree and a forty-character commit, and the store gate enforces exactly that. A citation resolves to a document somebody else publishes, and its pin is a version | `source_tracking.md` `## Citations`; the gate's pin rule at `scripts/skill_store.mjs` |
| `linking` owns how a citation is written and `source_tracking.md` owns what its record holds | A pointer's form is the linking convention's subject, and a record's fields are the store document's. Stating either in both files is the duplication this row exists to remove | both files |
| No validator reads the citation records | Three instances before a schema. A validator written over three examples encodes a guess, and the store's gate exists for a property citations do not have | `source_tracking.md` `## Citations` |
| The citation record does not list its citing documents | The arrow runs one way, as it does for the store, so a second document adopts a citation without editing the record | `source_tracking.md` `## Citations` |
| The three sources are read for what they settle and recorded with what was dropped | The point of the family is that the adaptation survives the session, so a later reader can tell a deviation from an oversight | the three records |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Nothing re-checks a citation's address, so a moved host or a revised standard is undetected | measured | a dead URL leaves the record reading as current, which is the staleness the `version` field exists to limit rather than remove | `source_tracking.md` `## Citations`: a reader who follows the address is what keeps it current |
| This unit has no consumer yet in its own commit, because the surface that cites the records is uncommitted | measured | a reviewer reads a capability with no use, so its shape is judged from three instances rather than from a citing text | the next iteration: the surface cites all three |
| The `linking` convention now separates an internal citation from an external one, and the story table carries both under one story | measured | a reader who stops at the stories sees one row for two forms and must read the section to find the difference | this record: the row names the section, so the row is a pointer rather than a summary |

## Completed

| File | Change |
|---|---|
| `.agents/skills/linking/SKILL.md` | `## Citations`, and the S2 row names it |
| `docs/development/source_tracking.md` | `## Citations`: the family, the field table, why nothing validates it, and the one-way arrow |
| `.agents/registry/citations/rfc-2119.json` | the MUST, SHOULD, MAY ladder, with the observer test as the addition |
| `.agents/registry/citations/diataxis.json` | the two axes and the one-form rule, with the advisor as the form the framework lacks |
| `.agents/registry/citations/kaplow-rules-versus-standards.json` | the rules-versus-standards cost asymmetry, stated as an authoring decision |
| `devlog/handovers/20261102-02-workflow-citation_family.md` | this record |
