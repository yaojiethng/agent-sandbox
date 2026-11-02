---
date: 2026-10-31
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - Refresh the remaining mattpocock edges

## Objective

Move the three remaining `mattpocock/skills` edges to `a496f55`, resolving the `domain-modeling` rename and the `improve-codebase-architecture` rework against the existing forks.

## Scope

Continues `Refresh the remaining mattpocock/skills edges` under M3.3.3, from handover `20261031-03`.

The three mattpocock edges still at `62f43a18`: `domain-model` takes the upstream rename to `domain-modeling`, its content and the `GLOSSARY.md` rename; `improve-codebase-architecture` takes the reworked HTML-report flow; `setup-pre-commit` takes the one-line prose change. The rename is atomic with this unit: `improve-codebase-architecture` is the only in-tree caller and is rewritten here, and the store edge and roadmap row are in the same unit. The local `ADR-FORMAT.md` stays; the `improve-codebase-architecture` siblings stay because this repository has no `codebase-design` edge to move them to.

Out of scope: forking the upstream `codebase-design` skill, which would be a fourth edge and is not named by the operator.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `domain-modeling` carries the upstream content, `GLOSSARY.md` replaces `CONTEXT.md`, and the local `ADR-FORMAT.md` stays | diff against `a496f55:skills/engineering/domain-modeling`; `rg -n 'CONTEXT' src/reasoning/agent/skills/domain-modeling/{SKILL.md,GLOSSARY-FORMAT.md}` returns nothing; the directory and `name` agree | Agent [x] |
| `improve-codebase-architecture` carries the reworked `SKILL.md` and `HTML-REPORT.md`, with the `codebase-design` calls resolved to the local `LANGUAGE.md` and `INTERFACE-DESIGN.md`, and the report under `.scratchpad/` | `rg -n 'codebase-design' src/reasoning/agent/skills/improve-codebase-architecture` returns nothing outside the record; `rg -n '.scratchpad' .../SKILL.md` | Agent [x] |
| `setup-pre-commit` carries the upstream colon line | `rg -n 'pre-commit hooks: a good' src/reasoning/agent/skills/setup-pre-commit/SKILL.md` | Agent [x] |
| The three edges' bases move to `a496f55`, and `domain-modeling`'s edge names the new path | `node scripts/source_bump.mjs check`; read the three edges | Agent [x] |
| The skill-source gate is clean across eleven records, and lint and the suite pass | `bash scripts/check_skill_sources.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |
| The roadmap row is `[x]` with `20261031-04`, and the tool gap has its own open row | `rg -n 'Refresh the remaining' devlog/roadmap.md`; `git diff devlog/roadmap.md` | Agent [x] |
| Every decision recorded this iteration is realized in the files | read `## Decisions`; check each destination | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Take the upstream rename to `domain-modeling` | The only in-tree caller is `improve-codebase-architecture`, rewritten in this same unit, so the rename and the bump are atomic; the store edge and roadmap row are in the same unit | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Renaming `ADR-FORMAT.md` dropped it out of the `doc-wrap` legacy exemption, so its unwrapped paragraphs surfaced as 13 findings | gate | the file was reflowed to one paragraph per line, and its stale legacy entry was removed from `.markdownlint-cli2.mjs` | this handover, Completed |
| `source-bump` has no operation that renames an edge's paths | tool gap | the `domain-modeling` edge's `local_path` and `upstream_path` were a hand edit to the source JSON | `roadmap.md`, `source-bump cannot rename an edge` |
| Eleven pre-existing stale entries remain in the `doc-wrap` legacy list, none of them in this unit | debt | `check_doc_wrap_legacy.sh --stale` reports them; they predate this iteration | flagged to the operator, not fixed |
| The local `domain-model` fork carried its own interview; upstream keeps `grilling` separate and makes `domain-modeling` the active discipline only | upstream rework | the local skill drops its interview text and reads the `grilling` skill instead | this handover, Completed |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/skills/domain-modeling/SKILL.md` | Rewritten from the upstream `domain-modeling` skill, with the `decision-records` link added. |
| `src/reasoning/agent/skills/domain-modeling/GLOSSARY-FORMAT.md` | New, from upstream, with the ASCII sweep. |
| `src/reasoning/agent/skills/domain-modeling/CONTEXT-FORMAT.md` | Deleted; the glossary format replaces it. |
| `src/reasoning/agent/skills/domain-modeling/ADR-FORMAT.md` | Kept, reflowed to one paragraph per line to clear the legacy wrap exemption. |
| `src/reasoning/agent/skills/domain-modeling/MAINTENANCE.md` | Records the rename, the glossary rename and the retained ADR format. |
| `src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md` | Rewritten from upstream, with the `codebase-design` calls resolved to local files. |
| `src/reasoning/agent/skills/improve-codebase-architecture/HTML-REPORT.md` | New, from upstream, with the report under `.scratchpad/`. |
| `src/reasoning/agent/skills/improve-codebase-architecture/INTERFACE-DESIGN.md` | The domain vocabulary reference becomes `GLOSSARY.md`. |
| `src/reasoning/agent/skills/improve-codebase-architecture/MAINTENANCE.md` | Records the rework and the retained siblings. |
| `src/reasoning/agent/skills/setup-pre-commit/SKILL.md` | The em dash becomes the upstream colon. |
| `src/reasoning/agent/skills/setup-pre-commit/MAINTENANCE.md` | The rewritten-line note no longer claims an ASCII substitution. |
| `.agents/registry/sources/mattpocock-skills.json` | Three bases moved to `a496f55`; the renamed edge's two paths updated. |
| `.markdownlint-cli2.mjs` | The stale `domain-model` legacy entry removed. |
| `devlog/roadmap.md` | The row is `[x]` with `20261031-04`, and the rename-operation gap has its own open row. |
