---
date: 2026-11-02
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Documentation
---

# Handover - the organization convention is one file

## Objective

One file per corpus states the mode, the folder and what the folder holds, and the text it borrows from upstream stays close enough to diff that a bump is a patch rather than a re-read.

## Scope

This iteration is the third unit of the roadmap row **Move the documentation-writing and skill-writing guidelines under `skill-scaffolder`**. It combines what two commits were carrying separately - the adoption of the frame and the vendored mode rules - because they are one subject and the operator reviewed them as one.

**In scope.** `.agents/skills/project-documentation/references/organization.md`, which holds the vendored section with this repository's additions between its paragraphs; the reduction of `project-documentation`'s own segment and of `docs/reference/documentation_taxonomy.md` to pointers; `work-log`'s statement that a record has no mode; the ADR repointed at the new owner; the store edge; and the citation record.

**Deferred, and why.** The authoring surface - the `instruction-authoring` skill, its two carrier sheets and the retirement of `docs/development/prompt-authoring-conventions.md` - is uncommitted in the working tree and is not part of this commit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One file states the four modes, the folder each serves and what the folder holds, and the convention points at it rather than repeating it | read `.agents/skills/project-documentation/references/organization.md`; `grep -c "docs/reference/" .agents/skills/project-documentation/SKILL.md` = `0` | Agent [x]: one table in the organization file, and the `SKILL.md` holds none |
| No upstream paragraph is rewritten: every addition sits between two of them, and the only change inside one is the accent | `diff` each of the six upstream paragraphs against `$AGENT_HOME/agent/packages/pstack/pstack/skills/technical-writing/SKILL.md` | Agent [x]: six paragraphs identical, and the heading's accent is the one character that differs |
| The file carries no maintenance prose: no statement that it is vendored, no diff narrative, no pin | `grep -ci 'vendored\|differs\|pin' .agents/skills/project-documentation/references/organization.md` = `0` | Agent [x]: none, and the adaptation lives in the edge's `record` |
| The source line is this repository's citation form and names the record | the last line of the file | Agent [x]: author, title, publisher, date read, URL, and the citation record |
| The how-to paragraph states the mode generally, names the surface's managing skill with the rename note, and points at the document that states the surface's scope | the paragraph after the how-to mode | Agent [x]: `skill-scaffolder` named with the note, and `docs/development/instruction-surface-conventions.md` `## Scope` linked by name |
| The folder list drops no folder that exists and keeps none that does not | `git ls-files 'docs/**/*_policy.md'` empty; `bash scripts/check_reach.sh` | Agent [x]: `policies/` gone from the table and from the reach sentence, and the gate is clean across four folders |
| The taxonomy states no frame and no folder table, and keeps reach and durability | read `## Folder taxonomy` and `## Durability` in `docs/reference/documentation_taxonomy.md` | Agent [x]: two paragraphs and a pointer, with no table |
| The edge carries the pin, an anchor the file holds once, and the adaptation record | `bash scripts/check_skill_sources.sh` | Agent [x]: clean across four sources and ten artifacts |
| One commit carries the unit, with the two earlier commits folded into it | `git log --oneline -3`; `git show --stat HEAD` | Agent [x]: one commit, and the two are gone from the log |
| The gates and the tests over this surface are clean | `bash scripts/lint.sh`; `bash tests/test_skill_sources.sh`; `bash tests/test_skill_map.sh`; `bash tests/test_document_shape.sh` | Agent [x]: 19 gates clean, and 10, 7 and 11 tests passing |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The file is named `organization`, not after the framework it borrows | Its subject is where a document lives and how it is organised; the framework is how it organizes, and naming the file after the teacher rather than the subject makes a second framework look like a second file | this record |
| Upstream's paragraphs stay whole, and this repository's additions sit between them | A bump's procedure is diff-based, so the useful property is that no upstream paragraph is rewritten and every change is an insertion. Writing inside a paragraph rewrites its single physical line | the edge's `record.rewritten`; this record |
| The file carries instruction only, and its maintenance story lives in the store and in the citation record | The same move as retiring the fourteen `MAINTENANCE.md` files at `20261101-09`: an artifact that narrates its own provenance makes a reader pay for the maintainer's information | the edge; `.agents/registry/citations/diataxis.json` |
| The source line takes this repository's citation form | The text is vendored around a principle that already has a record here, so its provenance is a citation like any other, and the form is the `linking` convention's | `linking` `## Citations`; the citation record |
| The how-to mode is stated generally and points at the surface's scope document | The mode is not this convention's to own. It is the instruction surface's, managed by `skill-scaffolder` today, and the procedures written in it work under that surface's scope | the organization file |
| `skill-scaffolder` is named as it stands, with a note that the rename corrects it | The rename is a separate unit and the operator directed that this reference be fixed then and not before, so the name is not churned twice | the organization file; this record |
| The `policies/` row goes with the table | No file matches `docs/**/*_policy.md`, the folder does not exist, and the reach gate counts four folders. The row described a tree of an earlier date, and the sentence beside it claimed the same folder was mounted | this record |
| The taxonomy keeps reach and durability and loses the organization rules | Reach and durability are axes of delivery, not of organization, and a view document that states no rules is exactly what those two are not | `docs/reference/documentation_taxonomy.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The how-to paragraph links `docs/development/instruction-surface-conventions.md` `## Scope`, which the operator intends to reorganize | measured | the link is correct today and its anchor moves in that later commit, so this file is a carrier of that move | the later commit, on operator direction |
| The organization file's title and the vendored section's heading both name a mode | measured | a reader sees two titles before the content, and the first says what the file is for | this record: the file title is the convention's subject, and the section keeps upstream's wording so a bump matches it |
| Interleaving means upstream's section is no longer one contiguous run, so a bump has three insertion points around it | measured | a bump still diffs to insertions, but a patch written against upstream's line numbers needs the offsets | the edge's `record.added` lists every addition, so the offsets are recoverable |
| The `SKILL.md` now points at a file whose content it no longer summarises | measured | a reader of the convention alone cannot answer which mode a folder serves without opening the sibling | this record: the convention is an index, and the sibling is where the rule lives |

## Completed

| File | Change |
|---|---|
| `.agents/skills/project-documentation/references/organization.md` | the vendored section, six upstream paragraphs whole, this repository's additions between them, the corpora table, and the source line in citation form |
| `.agents/skills/project-documentation/SKILL.md` | `## The folder and its mode` reduced to what this convention owns and a pointer to the organization file |
| `.agents/skills/work-log/SKILL.md` | a record has no documentation mode, and why |
| `docs/reference/documentation_taxonomy.md` | the frame and the folder table removed; reach, durability and pointers kept |
| `docs/adr/documentation_quadrants.md` | the decision that adopted the frame, its three rejected alternatives, and the owner it now names |
| `.agents/registry/sources/pstack-skills.json` | the edge for the vendored section, pinned at `ae5650fe`, with the adaptation record |
| `.agents/registry/citations/diataxis.json` | the record of what the framework gave us, and the two routes the text reached this repository by |
| `devlog/handovers/20261102-03-docs-organization_convention.md` | this record |
