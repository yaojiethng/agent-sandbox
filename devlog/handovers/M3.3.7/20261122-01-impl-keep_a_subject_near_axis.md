---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - Naming the `keep-context-in-view` axis

## Objective

Settle the `keep-context-in-view` name and axis (formerly `keep-a-subject-near`), and the placement gaps the scan finds.

## Scope

The row is `keep-context-in-view` names its axis. In scope: the skill's name, title, description, intent, mechanism and body, its ten live carriers (the five neighbour lists, the provider index, `cut-metadiscourse`, `instruction-authoring`, `writing-for-agents` through its store edge, `scope.md`), and the roadmap row. The placement scan reopens the name decision of handover [20261116-15](20261116-15-impl-colocation_leitwort.md), which kept the name because the signposting pattern names the act; the later axis work moves that ground. Out of scope: the other M3.3.7 rows and the M3.3.8 merge.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The axis row is one `keep-a-subject-near` task; the `order-for-incremental-parsing` half merges into its closed cleanup row. | The `order` half landed in iteration 2; a second closed row would record the same work twice, and a one-child parent states one outcome twice. | This record; `roadmap.md`. |
| The intent is "Write as if the reader's contextual memory is limited"; the mechanism is "Proximity by colocation: co-locate the relevant information with the part that needs it". | The operator approved both; the proximity rule falls out of the memory premise. | This record; the skill's frontmatter. |
| The two scan consolidations resolve as `keep` yielding: the second subject to `single-train-of-thought` (the clarity of the intent), the definition to `define-terminology-before-use`. | The operator's ruling; the survivors already state the determination. | This record; the skill's boundary part. |
| The `i-have-adhd` skill is a citation, not a vendored copy; it conflates concerns our principles split, and only its memory premise and its restate-state rule are kept. | The operator's ruling; the citation record's `dropped` field records the split. | This record; `.agents/registry/citations/i-have-adhd.json` (lands with the body). |
| The leitwort is `colocation`; the mechanism is proximity by colocation. | The operator's ruling: `colocation` is the concept the reader thinks with, and proximity is the effect it produces. | This record; the skill's frontmatter. |
| The neighbour set is the five existing plus `cut-metadiscourse` and `single-source-of-truth`; `organize-by-diataxis` is not a neighbour. | The operator accepted the edge-tested set and rejected the mode principle. | This record; the skill's frontmatter and the two symmetric lists. |
| The skill is renamed `communication-principle-keep-context-in-view`; the H1 is "Write for a small working memory"; the description names the concrete triggers. | The operator chose the name for the placement plus the limit, without a budget to ration; the title states the premise. | The skill; this record. |
| The body is the bulleted `When X, do Y` rule, the sharpened Why in `order`'s terms (extraneous load, working memory, reanalyse, parse), the boundary dispatch and the test; `Fires on`, `Where it sits`, `The family` and the vacuous sentence are cut. | The operator's rulings on readability, the shared terms, and the `Why` rule. | The skill; this record. |
| The Why rule is stated once in `principle-skills.md`; `principle-change.md` cites it. | SSOT: the reference owns the artifact, the runbook owns the procedure. | The two files; this record. |
| `writing-for-agents` points at the principle for colocation; the explanation moves out. | A principle rule is more generally invoked than a reference rule. | `writing-for-agents`; the store edge; this record. |
| The `writing-for-agents` two loads are a local rewrite: the context load is the retrieval and volume cost, the cognitive the working-memory cost of comprehension, the extraneous the presentation's waste. | The operator reconciled the two loads; the store edge records the local rewrite. | `writing-for-agents`; the store edge; this record. |
| The `keep` and `order` boundaries state their scope anchors and dispatch by the corpus's names. | The operator accepted the corrected boundaries after the scope split. | The two skills; this record. |
| The `i-have-adhd` is the sole source in the principle's `Source:` line; the Sweller and retrieval-literature citations are `writing-for-agents`'. | The operator accepted the citation record and the reference's citations. | The skill; `writing-for-agents`; this record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The cold-reader name test: `keep-a-subject-near` predicted proximity, while the test is the placement. The runbook's `Rename` rule applied. | Design | Resolved: renamed to `communication-principle-keep-context-in-view`, with the H1 "Write for a small working memory". | Decisions; this record. |
| `keep`'s pattern row 5 ("a section carrying a rule and a second, unrelated subject") and `single-train-of-thought`'s row ("a section that opens a second argument beside the first") claim one case and reach one determination. | Design | Resolved: the case is `single-train-of-thought`'s; `keep` yields its row. | Decisions; this record. |
| `keep`'s pattern row 2 (a definition's placement) and `define-terminology-before-use`'s body ("stated once and pointed at from every use") reach one determination. | Design | Resolved: the definition is `define-terminology-before-use`'s; `keep` yields its row. | Decisions; this record. |
| "subject" carries the topic in `keep`, `single-train-of-thought` and `cut-metadiscourse`, and the grammatical actor in `order-for-incremental-parsing`; no definition exists. | Design | The re-frame drops "subject" from `keep`; the corpus's use of the word is a later row's. | Decisions; this record. |
| The intent says "concepts", the mechanism and title say "subject" and "parts"; three words for one unit. | Design | `align-the-mental-model` applies to the skill's own fields. | This record. |
| The boundary part points "one place carrying a second subject" at `single-source-of-truth`, which owns a second copy, and points at the same target twice (lines 45 and 47). The mode owner is `organize-by-diataxis`. | Design | The pointer misroutes; the roadmap's `Every reference to the organizational judgement says something true` row already flags the double pointer. | This record; that roadmap row. |
| The boundary part discusses `single-source-of-truth`, not a declared neighbour, and states no edge with the five declared neighbours; `order-for-incremental-parsing` points at `keep` and `keep` does not point back. | Design | The declared field and the prose disagree. | This record. |
| The body hyphenates `co-location` at line 36 and writes `colocation` elsewhere; `writing-for-agents` line 49 spells `Co-location` and says `concept`. | Record | One term under two spellings and two words for the unit. | This record; the rename. |
| The two-modes judgement is credited to `single-source-of-truth` with `keep` in `instruction-authoring` line 12, and to `single-source-of-truth` in `keep` line 47; the owner is `organize-by-diataxis`. | Design | A sixth live reference carries the old state; the roadmap's `Every reference to the organizational judgement says something true` row lists five and misses this one. | This record; that roadmap row. |
| The test checks caveats and sections but not the definition or the part-order rows of the pattern. | Design | The test does not cover the pattern it states. | This record. |
| The borrowed terms `information hierarchy`, `progressive disclosure`, `findability` and `overload` were decided as umbrella words in handover [20261116-15](20261116-15-impl-colocation_leitwort.md); no gap. | Record | The decision stands. | This record. |
| The corpus map `20261116-report-concluded-principle_corpus_map.md`, cited by handover 20261116-15 for the D8 rationale, is absent from `devlog/discussions/`. | Record | The D8 rationale survives only in the handover. | This record; `/milestone-close`. |
| The `writing-for-agents` two-load section had drifted into a retrieval-versus-reasoning taxonomy that lost the agent-window/human-index split; the operator reconciled it with the per-party halves and the corrected definitions. | Design | Local rewrite; the store edge records it. | This record; the store edge. |
| The `keep` and `order` boundaries were prose without a scope anchor; the two were separated by scale (the text versus the sentence). | Design | The corrected boundaries landed, with the `order` and `keep` names. | This record; the two skills. |
| The inline Sweller and retrieval-literature citations in `writing-for-agents` are not `.agents/registry/citations/` records; `source_tracking.md ## Citations` wants one record per source. | Record | A convention gap; the fork's store edge carries the provenance. | This record. |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-keep-context-in-view/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-keep-context-in-view/SKILL.md) | Renamed; the H1, description, bullets, sharpened Why, boundary and test rewritten. |
| The seven neighbour skills | The frontmatter lists name the new skill; `cut-metadiscourse` and `order-for-incremental-parsing` also rewrite their prose boundary and pointers. |
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The index entry and its short description. |
| [`instruction-authoring/SKILL.md`](../../../.agents/skills/instruction-authoring/SKILL.md) | The step-1 reference names the new skill. |
| [`writing-for-agents/SKILL.md`](../../../src/reasoning/agent/skills/writing-for-agents/SKILL.md) | The two loads are a local rewrite; the co-location paragraph points at the principle. |
| [`mattpocock-skills.json`](../../../.agents/registry/sources/mattpocock-skills.json) | The fork records the two-load local rewrite and the co-location pointer. |
| [`i-have-adhd.json`](../../../.agents/registry/citations/i-have-adhd.json) | The citation record. |
| [`principle-skills.md`](../../../.agents/skills/instruction-authoring/references/principle-skills.md) | The Why rule: benefit and violation consequence. |
| [`principle-change.md`](../../../.agents/skills/instruction-authoring/runbooks/principle-change.md) | The Why step cites the reference. |
| [`scope.md`](../../../workflow/coding-agent/prompts/scope.md) | The brief-phrasing list. |
| [`devlog/roadmap.md`](../../roadmap.md) | The axis row closes; the `Every reference` row drops the fixed `keep` item. |
| [`20261122-01-impl-keep_a_subject_near_axis.md`](20261122-01-impl-keep_a_subject_near_axis.md) | This record. |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The directory and frontmatter name are `communication-principle-keep-context-in-view`. | Read the path and the `name` field. | Agent [x] |
| The H1 is "Write for a small working memory"; the body is the bulleted rule, the sharpened Why in `order`'s terms, the boundary dispatch and the test; the description names the concrete triggers. | Read the skill. | Agent [x] |
| The neighbours are the seven accepted, symmetric in both directions. | `principle_inventory`; `check_principle_frontmatter.sh`. | Agent [x] |
| The ten live carriers name the new skill; `writing-for-agents` points at the principle and its two loads are the local rewrite; the store edge records both. | `grep`; the store edge. | Agent [x] |
| The `keep` and `order` boundaries state their scope anchors and dispatch by the corpus's names. | Read both skills. | Agent [x] |
| The Why rule is stated once in `principle-skills.md` and cited by `principle-change.md`. | Read both files. | Agent [x] |
| The roadmap closes the axis row and drops the fixed `keep` item from the `Every reference` row. | Read the roadmap. | Agent [x] |
| The gates hold. | `check_principle_frontmatter.sh`, `principle_inventory`, `lint.sh`, `run_tests.sh`. | Agent [x] |
