---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Audit
status: Closed
---

# Handover - run the neutral principle census

## Objective

Run the four-arm neutral census over this repository's prose failure events, and record the induced principle set, the merges, the residual events and the unexercised lines under the pre-registered decision rule.

## Scope

The first half of the M3.3.4 row **The neutral census and the communication-surface filing**, split as work unit U1 of 2. It produces the settled census report. The filing of the surviving principles is U2, and it files as its own roadmap row in this iteration.

Out of scope, with reason: the filing half, because its file set depends on the census result and cannot be scoped before the census settles; the deletion of an unexercised line, because the design makes it a candidate for deletion and the operator confirms the list at U2's scope.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The report carries one row per corpus failure event, with the sentence, the misreading and each arm's placement | the corpus section holds 21 event rows, equal to the corpus count stated in `## Findings summary` | Agent [x] |
| Three blind coders ran, one per model family, one of them GLM, and no brief names a category, a filed principle or the ledger | the report's log names `deepseek/deepseek-v4-pro`, `openrouter/z-ai/glm-5.3-flash` and `opencode-go/qwen3.8-flash`; the brief carries no category name | Agent [x] |
| Each blind coder returns its own named categories plus a residual bucket, and pairwise agreement among them is stated as a number | the report's `## Arm B` agreement table: 0.85, 0.85, 0.92, mean 0.88 | Agent [x] |
| The Jev matrix answers every probe for every event with `stopReason: stop`, and the answer vectors are clustered with membership stated | the report's `## Arm C` table carries 21 rows, five probabilities and a cluster id; the log states 21 calls, 0 errors | Agent [x] |
| The adversarial arm returns a verdict for every event: `no-home`, `existing-too-broad`, or `none` | the report's `## Arm D` table carries 21 rows; 11, 7 and 3 respectively | Agent [x] |
| The decision rule is applied as pre-registered, with one verdict row per candidate and the count of independent blind coders behind it | the report's `## The verdict` table carries four accepted candidates, 3, 3, 3 and 2 of 3, and no merge | Agent [x] |
| Every judgement row of the ledger resolves to exactly one of a surviving principle, an existing principle, or an unexercised deletion candidate | the report's resolution table sums to 77; `bash scripts/check_norm_ownership.sh --check` stays clean | Agent [x] |
| The report exists only under its settled name | `test -f devlog/discussions/20261019-report-settled-neutral_principle_census.md` passes and the `-draft-` name is absent | Agent [x] |
| The census row carries its landing note and U2 exists as its own open row under M3.3.4 | `grep -c '^- \[x\] \*\*The neutral census\*\*' devlog/roadmap.md` and `grep -c '^- \[ \] \*\*The communication-surface filing\*\*'` each print 1 | Agent [x] |
| Every decision this iteration records is realized in the files | read this record's `## Decisions` against the tree | Operator [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The row splits into U1, the census run, and U2, the communication-surface filing | the filing's file set depends on the census result, so it cannot be scoped before the census settles | this record; the U2 roadmap row |
| The iteration type is Audit with a `docs` commit | the outcome is a measurement record plus a decision, and every changed file is a record | this record |
| Arm B runs one coder per enabled model family: `deepseek/deepseek-v4-pro`, `openrouter/z-ai/glm-5.3-flash`, `opencode-go/qwen3.8-flash` | the design requires three families, one of them GLM; `openrouter/qwen/*` resolves to no model in this session, so qwen runs on the `opencode-go` route | the report, `## Compact log of actions` |
| Arm C runs on `opencode/jev-1.13-free`, falling back to `openrouter/typesafe/jev-1.13` | the free route keeps the probe off the paid families the coders use; no fallback was needed | the report, `## Compact log of actions` |
| The design's stale blocker paragraph is corrected and the design is settled here (D1) | the paragraph stated that codemode was off and the classify path unreachable, and the tree contradicted it in the iteration that executes the design | the design, `### The blocker and its fix` |
| The three stale `draft` statuses are corrected here (D2) | their products landed, and the status is carried in the file name, so a stale status is a wrong name | the four renamed discussion records |
| The corpus starts from mined events only, and the 18 sentence-study sentences are excluded | those 18 produced a filed principle, so re-testing them would re-induce a settled rule | the report, `## Context` |
| No ADR is written | the census method governs one measurement, not a standing principle whose consequences reach beyond this iteration | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `$AGENT_HOME/model-recommendations.md` is dropped from the file table | scope amendment | the census coder pins are fixed by the design rather than by a role tag, and initializing the file needs its own operator confirmation round | the U2 row in `devlog/roadmap.md` |
| L1: the design's `### The blocker and its fix` states codemode is off and `models.classify` is unreachable, and 12 classifier routes resolve | record defect, pre-existing | corrected in this iteration per D1 | the design record, corrected with its tag |
| L2: the design's status reads `draft` though its decisions were recorded and its blocker fixed | record defect, pre-existing | settled and renamed in this iteration per D1 | the design record |
| L3: three discussion statuses read `draft` while their product landed | record defect, pre-existing | settled and renamed in this iteration per D2 | the four renamed discussion records |
| Three of the four accepted rules have no judgement line in either source document, so the ledger cannot point at them | result | U2 files them against a line it adds, or states that the rule has no line yet | the report, `## Findings summary`; the U2 row |
| 72 of the 77 judgement lines are unexercised by this corpus, and an unexercised line is a deletion candidate | result | the operator decides at U2 whether to broaden the corpus or delete; this run deletes nothing | the report, `## Post-review learnings`; the U2 row |
| Two lines resolve to `unattributed`, a fourth class beyond the criterion's three values | scope amendment | the report names it and U2 treats it as a retirement candidate beside `unexercised` | the report, `## The ledger resolution`; the U2 row |
| The Jev probe P3 fires on 17 of 21 events and P5 on almost none, so the matrix separates weakly | method | a later census drops P3 and uses P5 to select events rather than to score them | `devlog/AGENT_FEEDBACK.md`, entry of 2026-10-19 |
| The Findings mining source yielded no event, so the corpus leans on prose diffs and the feedback record | method | the report states it; a later census mines Findings with a sharper query | `devlog/AGENT_FEEDBACK.md`, entry of 2026-10-19 |
| One mined event carried a mistyped commit sha | process | the report records it; the next mining brief resolves every source reference against the tree before an event enters | `devlog/AGENT_FEEDBACK.md`, entry of 2026-10-19 |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261019-report-settled-neutral_principle_census.md` | new settled report; the corpus, the four arms, the verdict, the 77-line resolution and the learnings |
| `devlog/discussions/20261019-design-settled-neutral_principle_census.md` | renamed from `-draft-`, status `settled`, and the stale blocker paragraph corrected with its `[CORRECTION]` tag |
| `devlog/discussions/20261019-design-settled-sentence_structure_principle.md` | renamed from `-draft-`, status `settled` |
| `devlog/discussions/20261019-report-settled-sentence_structure_evidence.md` | renamed from `-draft-`, status `settled` |
| `devlog/discussions/20261018-study-settled-numbering_scheme_census.md` | renamed from `-draft-`, status `settled` |
| `devlog/roadmap.md` | the census row marked done with its landing note, the new U2 row, and the plan row's census verdict |
| `devlog/handovers/archive/20261019-07-plan-neutral_census_and_codemode.md` | link path updated, `[CORRECTION]` tag |
| `devlog/handovers/archive/20261019-10-workflow-file_attach_as_you_read.md` | link path updated, `[CORRECTION]` tag |
| `devlog/handovers/archive/20261019-05-design-sentence_structure_principle.md` | link paths updated, `[CORRECTION]` tag |
| `devlog/handovers/archive/20261018-02-docs-measure_numbering_demand.md` | link path updated, `[CORRECTION]` tag |
| `.agents/drafts/communication-domain-taxonomy-run.md` | link paths updated |
| `devlog/AGENT_FEEDBACK.md` | three `[A]` entries: the near-constant classifier probe, the mining source that held no event, and the mistyped commit sha |
| `devlog/handovers/archive/20261019-11-audit-neutral_principle_census.md` | this record |
