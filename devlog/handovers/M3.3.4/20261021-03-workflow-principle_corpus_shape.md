---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - One shape for the principle corpus

## Objective

Give the principle corpus a single shape, state it where a writer reads it, and hold it with a gate, so a new principle can be written by copying one exemplar.

## Scope

The roadmap row **The principle corpus carries two document shapes**, closed on its first ending: one shape is stated and the mismatched files are converted. The design is [`20261021-design-settled-principle_corpus_shape.md`](../discussions/20261021-design-settled-principle_corpus_shape.md), which settles the shape at six parts, the pattern's free vehicle, the required test and the sentence-case title, and the decision behind it is [`principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md).

Ruled out of scope with a reason each. The draft `.agents/drafts/communication-principle-write-plainly/` is not converted, because the open row **The plain-wording standard** owns its promotion and the shape applies at promotion. The `principle-*` files are in scope as a corpus, and their subject boundary is the name's `principle-` segment rather than a hand list, so no row filters which of them the gate reads.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every skill whose name carries `principle-` carries the six parts in one shape, and a departure fails the gate | `bash scripts/check_skill_shape.sh` prints `skill shape: clean across 22 skill(s)` | Agent [x] |
| No principle file carries a `##` heading below its title | the same gate reads a level-two heading on every principle and reports none | Agent [x] |
| The rule is not vacuous: each branch has a fixture, and a skill outside the name segment still passes | `bash tests/test_skill_shape.sh` prints `Results: 8 passed, 0 failed, 0 skipped` | Agent [x] |
| A writer reads the shape in one place, and the gate cites that place | `grep -n '## The principle shape' docs/development/prompt-authoring-conventions.md` returns one line | Agent [x] |
| The installed copy matches the repository source for every principle directory | `for d in src/reasoning/providers/pi/config/agent/skills/*principle*; do diff -rq "$d" /home/agentuser/.pi/agent/skills/$(basename $d); done` prints nothing | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` prints `Lint: clean in 7s across 11 gates`; `bash scripts/run_tests.sh` prints `1270 tests across 92 files, 1270 passed, 0 failed, 0 skipped` | Agent [x] |
| Every decision this iteration recorded is realized in the files | one row per decision, each naming the file and the check that realizes it: the bold form by `grep -c '^## ' <each principle skill>` returning 0 for all 22; the six parts by the gate; the free vehicle by the corpus carrying both a two-column table and a list as its pattern; the required test by the gate; the sentence-case title by the gate; the converted outlier by `principle-guard-the-context-window` carrying `**The pattern.**`, `**Why.**` and `**The test.**`; the derived subject by the gate naming 22 skills with no list in its source | Agent [x] |
| Architecture documents in scope describe the system as built | the ADR's six parts and the authoring convention's table name the same six, and the gate reads them off 22 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The corpus adopts the exemplar's bold lead-in form rather than `##` headings | the exemplar is the artifact acceptance criterion 3 names and the artifact a writer copies, so its own form needs no redefinition of the exemplar sentence the roadmap carries | [`20261021-design-settled-principle_corpus_shape.md`](../discussions/20261021-design-settled-principle_corpus_shape.md), `docs/adr/principle_skill_shape.md` |
| The shape is six parts, and the title is the file's only heading | the parts are what a writer copies, and a heading below the title is the second serialization the row removes | the same two records |
| The pattern's vehicle is free: a table where a contrast exists, a list where the parts are steps | ten of the 22 state the pattern as a list, and requiring a table would assert a contrast the judgement does not draw | the same two records |
| `**The test.**` is required, and three files gain one written from their own content | the exemplar carries a test, and a principle without one gives the writer nothing to check their own draft against | the design record |
| The title is sentence case | the tree's document headings use it, and a writer copying a title-case exemplar beside a sentence-case file meets two conventions | the design record |
| `principle-guard-the-context-window` converts rather than being exempted | an exemption is a second shape, which is the defect the row removes | the design record |
| The gate's subject is derived from the name: every skill directory whose name carries `principle-` | a hand list is the pattern `devlog/AGENT_FEEDBACK.md` records from 2026-10-15, and a new principle must enter the check without an edit | the ADR |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's census is stale: it states five specimens against four and scopes nine skills, while the corpus holds 22 and splits 12 against 10, across four dimensions rather than one | record defect in a tracked row | a reader scoping the row under-sizes it, and the row's ending reads narrower than the defect | this row's premise, corrected in the same iteration |
| The design record `20261021-design-settled-initialize_corpus_boundary.md` closed its iteration at status `draft` although its decision landed | record defect, one edit | `discussion_policy.md` states a design that settles with an implementation decision is `settled`, so the record contradicts its own vocabulary | corrected in place this iteration |
| `principle-guard-the-context-window` carries a bulleted procedure under `**Why:**` and `**Pattern:**` rather than a judgement, and its bold lead-ins also open list items | content observation | it is the one file that needs authoring rather than conversion, so the iteration's cost sits there | the scope's file table |
| Two files carried their named parts before the why and one carried a named part after the test, so the drift had five dimensions rather than the four the design measured, the fifth being the order of the parts | census correction | a rule that fixed only the serialization would have left three files in a second order | the design record's decision, which states the order, and the conversion, which reordered the blocks |
| A `Where ...` label alone is too narrow a part vocabulary: the corpus labels parts `**What it does not cover.**`, `**The three kinds of criterion.**` and `**Stop.**` | design correction, found while writing the rule | a rule admitting only the `Where` form would have rewritten content to satisfy a serialization | the design record and the ADR, both narrowed to any bold label ending on a period |
| `principle-check-placement` carried a see-also as a part, `**Related.**`, after the test | placement defect in one file | the shape has no part after the test, and a see-also is not a part | the file, where the line is prose below the test |
| `bash tests/test_skill_shape.sh` reported `assert_ne_num: command not found` as a pass, so a missing helper read as a green branch | test defect, found on the first run | an assertion that does not exist cannot fail, and the suite counts the test as passing | the four branches, rewritten to the harness's `assert_ne`, and the run re-read line by line |
| No gate in `scripts/lint.sh` reads a skill body: the frontmatter gate parses the block, and the instruction-surface gate holds the manifest's cells, so the file's shape had no observer | gate gap | the shape could drift again with no signal, which is how the two shapes arrived | the gate this iteration adds |

| The two record audits ran at pre-close over the roadmap and over this handover with its closed chain. The roadmap check reported 12 findings and the handover check 8; the ones this iteration produced are fixed above, and the ones it did not produce are carried by the row **The record-check backlog** | audit result | every finding needs a destination, and 17 of the 20 are outside this iteration's carriers | the new roadmap row, and this table |
| `20261021-02` carried two Decisions rows below a blank line, outside the table, and this record's own claims about the closed design record named a file the tree still held as `-draft-` with a `draft` status | format and landing defect in a closed record, plus a false landing claim in this one | a reader of the table loses the two ordering decisions, and an unsettled record carried a landed decision | both design records renamed to `-settled-`, both status lines set, every citation updated, and `20261021-02` reattached with a `[CORRECTION]` tag |
| `20261020-32` states four out-of-scope items with no reason and claims "Each is a finding below" for an item it never records, one acceptance criterion names a deconfliction table no record holds, and its last Decisions row sits outside its table | handover defects in a closed record | three answers a reader cannot reach | the record-check backlog row: they are corrections to another iteration's closed record, and they need that iteration's evidence |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261021-design-settled-principle_corpus_shape.md`](../discussions/20261021-design-settled-principle_corpus_shape.md) | the design record: four dimensions of drift, four options, the six-part shape and its consequences |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | `## The principle shape`: the six parts, the fixed order, the label period, the name-derived subject and the exemplar |
| [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | the standing decision, with the part vocabulary widened to any bold label after the implementation showed what the corpus uses |
| [`scripts/lint/skill-shape.mjs`](../../scripts/lint/skill-shape.mjs) | the rule: a stray `##`, the three required parts in order, named parts only between the why and the test, and a sentence-case title |
| [`scripts/check_skill_shape.sh`](../../scripts/check_skill_shape.sh) | the gate wrapper, with the scan-root test seam and the fail-closed branch over an empty subject |
| [`scripts/lint.sh`](../../scripts/lint.sh) | `check_skill_shape.sh` joins `GATES`, and the header comment names it |
| [`tests/test_skill_shape.sh`](../../tests/test_skill_shape.sh) | eight branches: clean, heading, missing test, order, part after the test, title case, a runbook skill outside the subject, and an empty subject |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv), [`norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv) | the four new authoring-convention lines classified, three as rules observed by the new gate and one as a description; regrouped |
| Ten principle skills converted from `##` headings to bold lead-ins | `communication-principle-attach-as-you-read`, `communication-principle-dont-forecast-undone-work`, `communication-principle-dont-scatter-what-belongs-together`, `communication-principle-hand-off-by-naming-the-boundary`, `principle-approval-writes-the-artifact`, `principle-define-terminology-before-use`, `principle-effective-skill-routing`, `principle-match-precision-to-stakes`, `principle-own-the-scope-you-declare`, `principle-say-what-done-looks-like` |
| Nine principle skills moved to a sentence-case title | `communication-principle-cut-what-carries-nothing`, `communication-principle-link-what-the-reader-can-open`, `communication-principle-name-the-value-not-a-literal`, `communication-principle-only-derive-what-you-own`, `communication-principle-show-dont-describe`, `communication-principle-write-for-the-reader`, `principle-guard-the-context-window`, `principle-minimal-corrections`, `principle-propagation-discipline` |
| Three principle skills gained `**The test.**` | `communication-principle-only-derive-what-you-own`, `principle-one-home-per-rule`, `principle-guard-the-context-window`, each written from that file's own content |
| [`principle-guard-the-context-window`](../../src/reasoning/providers/pi/config/agent/skills/principle-guard-the-context-window/SKILL.md) | the outlier: `**Why:**` and `**Pattern:**` became parts, the pattern sentence was written, and the four bullets stayed as its material |
| Eight principle skills reordered | the parts moved after the why, and `attach-as-you-read`'s caveat moved before the test |
| `/home/agentuser/.pi/agent/skills/` | all 22 principle directories re-synced; `diff -rq` reports nothing |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed on its first ending, its premise corrected to name the gate as the counter and the five dimensions it found; the record-check backlog row filed for the 17 audit findings this iteration did not produce |
| [`devlog/discussions/20261021-design-settled-initialize_corpus_boundary.md`](../discussions/20261021-design-settled-initialize_corpus_boundary.md), [`20261021-design-settled-principle_corpus_shape.md`](../discussions/20261021-design-settled-principle_corpus_shape.md) | both renamed from `-draft-` to `-settled-`, both status lines set, and every citation in the two handovers and the roadmap updated |
| [`devlog/handovers/20261021-02-workflow-initialize_corpus_boundary.md`](20261021-02-workflow-initialize_corpus_boundary.md) | the two milestone-ordering rows rejoined to the Decisions table, with a `[CORRECTION]` tag at the record end |
| [`devlog/discussions/20261021-design-settled-principle_corpus_shape.md`](../discussions/20261021-design-settled-principle_corpus_shape.md) | status settled, the part vocabulary widened, and the reordering recorded as a consequence |
