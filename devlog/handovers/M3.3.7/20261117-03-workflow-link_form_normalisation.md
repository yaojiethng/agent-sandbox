---
date: 2026-11-17
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - Normalise the principle cross-reference form

## Objective

Give every cross-reference in the principle corpus the one form a reader can open, in the repository and in the image, on the census's evidence.

## Scope

Roadmap row "The link form is normalised, conditional on the survey". In scope: the 15 principle cards that carry a pointer to another principle in the provider root, the form sentence in the skill authoring convention, and the retirement of the census record once its evidence has landed. Out of scope, one sentence each: the two references whose targets sit outside the provider root stay bare names, because those targets do not ship with the corpus; the neighbour fields and the card bodies' arguments are other work.

The census measured 31 references across 16 cards: 23 bare names, 6 `$AGENT_HOME` paths and 2 Markdown links, with 2 of the bare names pointing outside the provider root. The bare name is not openable, and the `$AGENT_HOME` path fails the reader holding the repository; only a sibling-relative link resolves in both.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every in-scope pointer is a sibling-relative link that resolves in the repository and in the image. | `bash scripts/lint.sh` clean; `node .scratchpad/census.mjs \| tail -1` reports `forms: {"markdown-link":23,"bare-name":2}`. | Agent [x] |
| No principle body carries an `$AGENT_HOME` path. | `grep -rln '\$AGENT_HOME' src/reasoning/agent-runtime/pi/config/agent/skills/*principle-*/SKILL.md` prints nothing. | Agent [x] |
| The form is stated once, in the skill authoring convention. | Read `## Where its references resolve` in `skill-conventions.md`. | Agent [x] |
| The census is retired, its two citations removed, and the record gates are clean. | `ls devlog/discussions/*link_census*` empty; `grep -rn link_census devlog/discussions` empty; `bash scripts/check_record_lifecycle.sh` clean. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the diff. | Agent [x] |
| The roadmap row is `[x]` with its Landed note. | Read `devlog/roadmap.md` row 381. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The normal form is the sibling-relative link, `[`<skill-name>`](../<skill-name>/SKILL.md)`. | It resolves under both roots. The bare name is not openable, and the `$AGENT_HOME` path fails the repository reader. | This record; `skill-conventions.md` `## Where its references resolve`. |
| The two cross-layer references stay bare names. | Their targets sit outside the provider root and do not ship with the corpus. | This record. |
| No new gate. | `scripts/lint/linking.mjs` already fails a link that does not resolve, and it runs over the shipped set. | This record; `linking/SKILL.md` `## The check`. |
| The census is retired, and the map and dry-run records drop their `**Census:**` line. | Closing row 381 orphans the census, and the work-log rule deletes a concluded orphan. | This record; `work-log/SKILL.md` `### Two facts, not one`. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The census counts spans, not pointers: 6 of its 31 rows are the path half of a name-plus-path pair, so 27 non-link rows are 21 edits. | record | The rewrite is 21 links, and the expected post-state is 23 links over 25 rows, not 29. | This record; the acceptance criteria. |
| The census says the `$AGENT_HOME` path fails a shipped reader. It resolves in the image and fails the repository reader instead. | record | The normal form is unchanged; the reason is stated correctly in the convention. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| The 13 principle `SKILL.md` files carrying a non-link pointer | Each pointer takes the sibling link; the name-plus-path pairs collapse to one link. |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | States the sibling link form and where it resolves. |
| `devlog/roadmap.md` | Row 381 is `[x]` with its Landed note, and its census and survey links are removed. |
| `devlog/discussions/20261116-report-concluded-principle_corpus_map.md` | Drops its `**Census:**` line. |
| `devlog/discussions/20261116-report-concluded-reader_context_dry_run.md` | Drops its `**Census:**` line. |
| `devlog/discussions/20261116-report-concluded-principle_link_census.md` | Deleted; row 381's close orphaned it. |
| `devlog/handovers/M3.3.7/20261117-03-workflow-link_form_normalisation.md` | This record. |
