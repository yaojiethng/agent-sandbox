---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Suggest the skill name, and parse with pi's own parser

## Objective

Settle the skill naming scheme as a suggestion, define the maintenance record's shape, and make the frontmatter gate parse with pi's parser rather than a reimplementation.

## Scope

Delivers the M3.3.3 row **Skill maintenance record**, which states the record's shape and reserves the naming and placement decision to itself rather than to the first skill to land. The scheme is settled here, and the record's filename, sections and placement with it. The import that exercises them is the next iteration.

Also in this unit, because both are the same subject: the frontmatter gate stops reimplementing a parse of a format pi owns, and the subtask for ingesting the remaining `principle-*` skills is filed.

Ruled out of scope. Gating the naming scheme. Nothing in the tree detects a skill name that breaks it, and the ledger classifies it `judgement` with observer `none`; a name check in the frontmatter gate would promote a suggestion to a rule.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The scheme states both name classes, with the domain prefix and its examples | `prompt-authoring-conventions.md` `**Suggested skill name.**` | Agent [x] |
| The scheme reads as a suggestion, not a rule | the paragraph states that nothing observes a name; the ledger records `judgement` with observer `none` | Agent [x] |
| The record's shape is stated: filename, placement, three sections | `devlog/roadmap.md` row **Skill maintenance record** | Agent [x] |
| The clause the scheme contradicts is amended | the `principle-` prefix clause in the M3.3.4 blurb now says a name states the class, not the origin | Agent [x] |
| The frontmatter gate parses with pi's parser | `scripts/lint/frontmatter.mjs` imports `loadPiFrontmatter`; `parseFrontmatter` is the only parse path | Agent [x] |
| The gate's verdict on the tree is unchanged | clean across 87 files, 20 shipping documents | Agent [x] |
| The gate still fails a block pi would drop | a fixture carrying `description: a: b` reports the file, the line and the offending text | Agent [x] |
| A missing pi install fails the gate rather than skipping it | `loadPiFrontmatter` exits 1 naming the search attempts and `PI_PACKAGE_DIR` | Agent [x] |
| Every gate passes | `scripts/lint.sh`, 10 gates, ledger 168 rows | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Principles pay `[<domain>-]principle-<judgement>`; every other skill pays `<verb-noun>` | The class is legible from the name, and `/<action>` reads to the operator as "do <action>", matching `node run` and `uv run`. Shadows `pstack`, so a fork and a home-grown principle share one shape. | the conventions document; the roadmap row |
| The scheme is a suggestion, and the text says so | Nothing observes a skill name. Calling it a convention invited a reader to treat an unobserved rule as binding, which the authority doctrine forbids. | the conventions document |
| The record is `MAINTENANCE.md` beside `SKILL.md`, with `## Source`, `## Adapted`, `## Name` | Beside `SKILL.md` because it is the skill's own record and moves with it. Three sections because the row names three required contents. | the roadmap row |
| Load pi's `dist/utils/frontmatter.js` rather than the `yaml` package | The gate exists to catch what pi drops. Two parsers agree until one is bumped, and the gate would then pass a file pi refuses. The narrow module, not the package entry, because the entry pulls the whole SDK into a gate. | `scripts/lint/pi-frontmatter.mjs` |
| Resolve the package from `pi` on PATH, with `PI_PACKAGE_DIR` as fallback | A hardcoded absolute path breaks on a moved install and would skip the gate. Naming the search in the error is what makes a missing install a failure rather than a pass. | `scripts/lint/pi-frontmatter.mjs` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether to gate the skill naming scheme | Nothing in the tree can detect a breach, so the scheme is advisory | add a name check to `scripts/check_frontmatter.sh` with a test; leave it a suggestion and accept the drift |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The scheme has no observer, and the ledger says so | agent experience | raised as the pending question; a suggestion nothing observes will drift once the set grows past what an operator reads |
| The tree's stated reason for the `principle-` prefix was wrong. It claimed the prefix separates the project's own from an upstream set the pi provider ships; the fork source is `pstack` and it uses the same prefix | document defect | clause amended; the provenance job belongs to the maintenance record |
| A gate that reimplements a product's parser is a gate against the repository's idea of the product, not the product | agent experience | routed to the gate itself; the same question applies to every scanner that parses a format pi owns |
| The inversion detector written for this rewrite carried a defect that made it report a clean range. It compared added and removed lines without stripping the diff marker, so no line could match | process | fixed, and persisted at `.agents/drafts/history-cleanup/inversions.mjs` with the defect recorded in its header, because a clean result from a broken instrument is the failure the check exists to prevent |

## Completed

| File | Change |
|---|---|
| `docs/development/prompt-authoring-conventions.md` | `**Suggested skill name.**` states both classes and that the scheme is a suggestion; the `disable-model-invocation` membership claim replaced with the condition that decides it |
| `devlog/roadmap.md` | the **Skill maintenance record** row marked decided; the `principle-` prefix clause amended; the subtask **Ingest `pstack` upstream** filed under M3.3.3 |
| `scripts/lint/pi-frontmatter.mjs` | resolves pi's own frontmatter module from `pi` on PATH, else `PI_PACKAGE_DIR`, and fails the gate when neither resolves |
| `scripts/lint/frontmatter.mjs` | parses with pi's `parseFrontmatter`; the block extraction stays only for line offsets and the reader check |
| `scripts/lint/yaml-loader.mjs` | header narrowed to the scanners that read a file pi never loads |
| `scripts/lint/norm-ownership.tsv` | regenerated, 168 rows |
| `.agents/drafts/history-cleanup/inversions.mjs` | the inversion detector, with its defect and its two non-design hit classes in the header |
| `devlog/handovers/20261018-03-workflow-skill_naming_and_pi_parser.md` | this record |
