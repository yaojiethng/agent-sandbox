---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - A claim line per principle, and one home per repeated rule

## Objective

Give every principle a declared claim so the corpus can be read by family, and remove the three rules that two files state in different words.

## Scope

The roadmap row **The principle corpus states derived patterns without naming the claim each one applies**. It ends on three conditions: each repeated rule has one home, each skill names its claim in a line a grep finds, and the family map is derived rather than written. The claims and the criterion that separates a permitted pair from a duplicate were settled in the row when it was filed, so this iteration implements them rather than re-deciding them. The five claims are `evidence`, `source`, `scope`, `reader` and `authority`.

Ruled out of scope with a reason each. The design record is not reopened: the row carries the claim set, the criterion and the two prohibitions, and re-deriving them would produce a second statement of the same reasoning. The corpus keeps its shape and its parts, because the last iteration settled them. This iteration adds one frontmatter field to each principle, rewrites the pattern table of `communication-principle-link-what-the-reader-can-open` and the two convention bullets that repeated its rule, adds the claim declaration to the authoring convention, and adds three branches to the shape test.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every principle declares a claim the declared set states, and a departure fails the gate | `bash scripts/check_skill_shape.sh` prints `skill shape: clean across 22 skill(s)` with the claim rule on | Agent [x] |
| The claim set has one home: the gate parses the authoring convention's section and validates a claim against it | `grep -c 'CLAIMS_HEADING = "## The principle claims"' scripts/lint/skill-shape.mjs` returns 1, and the unknown-claim fixture in `bash tests/test_skill_shape.sh` fails a claim the table lacks | Agent [x] |
| The family map is derived, not written | `bash scripts/check_skill_shape.sh --map` printed `claim map: 22 skill(s) across 5 claim(s) of 22` and one row per skill | Agent [x] |
| The duplicated clause has one home | `grep -rc "the target moves and the link does not" .agents/skills/linking/SKILL.md src/reasoning/providers/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md` returns zero for both, because the clause was removed and the principle states the class of pointer instead | Agent [x] |
| The numbering convention defers the reason to the principle instead of restating it | `grep -n "one-addressing-axis" .agents/skills/numbering/SKILL.md` names the principle at the chat section and at the frozen-number rule | Agent [x] |
| The rule is not vacuous: each new branch has a fixture | `bash tests/test_skill_shape.sh` printed `Results: 11 passed, 0 failed, 0 skipped` with a branch for a declared claim, a missing claim, an unknown claim and the map | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` printed `Lint: clean in 7s across 11 gates`; `bash scripts/run_tests.sh` printed `1273 tests across 92 files, 1273 passed, 0 failed, 0 skipped` | Agent [x] |
| Every decision this iteration recorded is realized in the files | seven decisions, each read against its file: the `metadata` declaration in 22 frontmatters, the table in the convention, the two assignments, the gate's derived set, the `--map` mode, the class-versus-members split, and the deferred reasons in `numbering` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A principle declares its claim in the frontmatter's documented `metadata` key, as `metadata: claim: <name>` | `metadata` is the field pi documents for extra key-value pairs, so the declaration needs no new top-level field, and the same documented parser the frontmatter gate uses reads it | this record; `docs/development/prompt-authoring-conventions.md` `## The principle claims` |
| The five claims are `evidence`, `source`, `scope`, `reader` and `authority`, declared once in the authoring convention's table | the table is the only place that decides the set; a claim listed in the gate's own source would be a hand list that a reader has to find | the same two records |
| `name-the-value-not-a-literal` takes `scope`, and `attach-as-you-read` takes `reader` | a literal in a snippet speaks for situations it does not hold for, which is the scope claim; a sentence the reader must attach to as it arrives is the reader claim. The row's own grouping left this skill out, and the assignment is the reading that closes it | this record |
| A principle that names no claim, or one the table lacks, fails the gate, while which claim it picks stays a judgement | a closed set is what makes the map work; deciding the membership of one skill is a reading, which no gate can verify | the acceptance criteria and the ADR's edge cases |
| The map is a `--map` mode on the existing shape gate | the claim declaration is part of the file's declared shape, and a second gate would scan the same 22 files for a second property of the same frontmatter | this record |
| The reference principle keeps the class of pointer and the reference convention keeps this repository's members | the split the corpus states: a judgement is a principle, and the structure a project chooses is its convention. A class holds in any repository, while a handover and a session export are this repository's record kinds | the design record's split criterion, applied here |
| The numbering convention keeps the mechanics and defers both reasons to the principle | the reason a chat token must map to one item, and the reason a position is not stable, are the principle's judgement; the letters, the restart rule and the frozen-number rule are this repository's structure | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's grouping names 21 skills across five claims, while the corpus holds 22, so one principle had no claim when the assignment was made | census gap in the row | a principle with no claim would fail the gate this iteration adds, so the gap had to close before the work started | the assignment recorded in Decisions, which takes `name-the-value-not-a-literal` as `scope`, and the row's ending, which a rerun of the map now verifies |
| `metadata` is pi's documented field for extra key-value pairs, and it parses through the same module the frontmatter gate loads | verification, not a defect | a custom top-level field would have been read as nothing and might have been dropped silently by a future pi version | the frontmatter declaration in Decisions |

## Completed

| File | Change |
|---|---|
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | `## The principle claims`: the five claims, the `metadata` declaration, the two-skills rule and the gate boundary |
| [`scripts/lint/skill-shape.mjs`](../../scripts/lint/skill-shape.mjs) | the claim rule, the set read from the convention's table, a missing or unknown claim a finding, and a `--map` mode |
| [`scripts/check_skill_shape.sh`](../../scripts/check_skill_shape.sh) | passes its arguments to the scanner, so `--map` reaches it, and the header documents it |
| [`tests/test_skill_shape.sh`](../../tests/test_skill_shape.sh) | three branches: a declared claim with its map row, a missing claim, and a claim the table lacks |
| Twenty-two principle skills | each declares its claim under `metadata`, so the corpus reads by family |
| [`communication-principle-link-what-the-reader-can-open`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md) | the pattern table states the class of pointer, and the convention holds this repository's members |
| [`.agents/skills/linking/SKILL.md`](../../.agents/skills/linking/SKILL.md) | the transient-evidence bullet keeps the members and cites the principle's class instead of repeating its reason |
| [`.agents/skills/numbering/SKILL.md`](../../.agents/skills/numbering/SKILL.md) | the chat section and the insertion section each name the principle for its reason |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | regenerated for the new convention lines, classified as rules observed by the shape gate. The grouping map regroups to the same rows, so it carries no diff |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed on its three endings, with the assignment and the three fixes recorded |
| [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | the edge cases gain the claim declaration, the set's home and the gate's boundary, ahead of the part vocabulary |
