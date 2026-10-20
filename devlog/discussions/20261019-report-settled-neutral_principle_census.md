# The neutral principle census

**Status:** settled

## Context

The census decides which prose standards survive as principles. The M3.3.4 spec census (`20261019-design-draft-prose_standards_specs.md`) assigned all 80 judgement lines of `documentation_policy.md` and `prompt-authoring-conventions.md` to 12 proposed principles, and carried two anchoring defects: its criterion forced every row to a side, and its worker saw the filed principles while it worked. The design (`20261019-design-settled-neutral_principle_census.md`) amended the method to a four-arm triangulation whose unit of analysis is a failure event rather than a prose line.

This report records the run, the pre-registered rule applied to it, and the resulting principle set. It does not file a principle. The filing of the surviving principles, the resolution of `documentation_policy.md` `## Communication Standards`, `prompt-authoring-conventions.md` and the `skill-scaffolder` duplicate, and the regeneration of `norm-ownership.tsv` are U2, filed as its own roadmap row.

Excluded by design: the 18 sentences of the sentence-structure study, because they produced the filed principle `communication-principle-attach-as-you-read` and re-testing them would re-induce a settled rule.

## The brief

The pre-registration was written before any arm ran. Its terms:

- **Corpus:** 21 failure events, each `id`, `sentence` (verbatim repository prose a reader misread), `misreading`, `intended`, `source`. Sources: the prose diffs of commits touching the two source documents, and `devlog/AGENT_FEEDBACK.md`.
- **Arm B:** three blind coders, one per model family, identical brief and identical input. Input is `id`, `sentence`, `misreading` only: no `intended`, no category list, no ledger, no principle. Each names its own categories bottom-up, carries a mandatory `residual`, and places every event once.
- **Agreement metric:** for every pair of events, each coder asserts or denies that the two share a category; pairwise agreement is the share of the 210 event pairs on which two coders agree.
- **Decision rule, fixed in advance:** a candidate rule is accepted when at least two of the three blind coders induce it independently and it is not a restatement of an existing principle; a merge is accepted when every coder collapses the same two principles; an event no coder places becomes its own finding; agreement is reported as a number.
- **Arm C:** five narrow `bool` probes per event, one classify call per event, probabilities kept, thresholded at 0.5 into a bit vector, one cluster per distinct vector. No label imposed.
- **Arm D:** one adversarial coder, given `intended`, the 6 filed principles and the 12 proposed ones, returning `no-home`, `existing-too-broad` or `none` per event.
- **Resolution:** every judgement row of the ledger resolves to a surviving principle, an existing principle, an unexercised deletion candidate, or `unattributed` (events touch it but no coder induced its judgement).

## Compact log of actions

| Phase | Run | Result |
|---|---|---|
| Corpus mining | one dispatch, `deepseek/deepseek-v4-pro` at high, 285 s | 28 candidate events, 7 rejected, 21 kept: 12 from prose diffs, 9 from the feedback record |
| Arm B | three dispatches in parallel: `deepseek/deepseek-v4-pro` 90 s, `openrouter/z-ai/glm-5.3-flash` 69 s, `opencode-go/qwen3.8-flash` 155 s | 21 placements each, 7 categories each, `residual` used by two coders (1 event each) |
| Arm C | one `codemode` script, 21 `models.classify` calls on `opencode/jev-1.13-free`, 3.1 s | 21 rows, 0 provider errors, 0 fallbacks to the paid route |
| Arm D | one dispatch, `deepseek/deepseek-v4-pro` at high, 367 s | 21 verdicts: 11 `no-home`, 7 `existing-too-broad`, 3 `none` |
| Comparison | dispatcher, deterministic scripts | pairwise agreement 0.85, 0.85, 0.92; mean 0.88; 4 accepted rules, 0 merges, 0 unplaced events |
| Resolution | dispatcher | 26 judgement lines mapped into the arm A groups; 51 with no group; 72 unexercised in total |

These pairs are the ones the runs used, read back from each session header. They are not the role table's. `$AGENT_HOME/model-recommendations.md` names `opencode/deepseek-v4.1-flash-free at high` for `_IMPLEMENTER`, `opencode/deepseek-v4.1-flash-free at high` for `_REVIEWER`, and `opencode/glm-5.3-flash-free at high` for `_ADVISOR`. The dispatcher bought family diversity instead, on provider routes the table does not name, and recorded no provenance. Handover `20261020-01` corrects the instruction surface that allowed it.

[CORRECTION -- 2026-10-20: the section recorded which pairs ran and not that they left the role table, so a reader could take them for the operator's choice. The provenance paragraph is added; the pairs and every result are unchanged.]

The corpus, the briefs, the arm outputs, the agreement script and the pre-registration are session-local under `.scratchpad/`. The tables below carry what they produced.

## Mid-run adjustments

1. **`intended` is withheld from arm B.** The design says the coder receives "the sentence and the misreading". Held to the letter, so a coder cannot simply restate the writer's correction as a category.
2. **The Findings source produced no event.** The mining brief asked for five. Six candidates came back and every one was a fragment with no evidenced misreading ("resume", "Keeping a subagent alive", "`$AGENT_HOME/skills/`"), so the source has no representation and the corpus leans on diffs and feedback instead.
3. **The corpus is 21 events, below the 25 to 40 asked of the mining dispatch.** The seven rejects are listed here: one quoted a shell-transcript line rather than prose, six were fragments. A mistyped commit sha (`aaa1246d`) was corrected to `aaa1246f` against the tree.
4. **Arm D was given the 12 proposed principles as part of the current partition**, although the design does not say whether the proposed set counts as current. It is the only way the adversarial arm can test the partition this census replaces.
5. **`$AGENT_HOME/model-recommendations.md` was dropped from the file table.** The coder pins are fixed by the design rather than by a role tag, and initializing the operator-owned file needs its own confirmation round.

## Findings summary

- **21** failure events entered the census.
- **3** blind coders induced **7** categories each, from the same 21 events and the same brief. Pairwise agreement over the 210 event pairs: **0.85**, **0.85**, **0.92**; mean **0.88**.
- **4** candidate rules were accepted under the pre-registered rule: three by all three blind coders, one by two of three. **0** merges were supported, and **0** events were left unplaced by every coder.
- **7** Jev clusters separated the 21 events; the largest holds 9. The probe that was meant to separate undefined terms fired on nearly every event (median 0.81) and the past-versus-current probe fired on almost none (median 0.08).
- **26** of the 77 judgement lines fall inside the 12 groups the spec census proposed. Of those, **2** fall under an accepted rule, **2** are touched by events with no induced judgement, **1** restates a filed principle, and **72** judgement lines are unexercised by any event in this corpus.
- **3** of the 4 accepted rules have no line in either source document that states them. That is the census's main result: the partition had no home for the failure classes that recur most in this repository.

## The corpus

One row per event. B, C and D are the blind coders' placements, `Jev` the probe cluster, and the last column the adversarial verdict.

| id | sentence | misreading | B | C | D | Jev | adversarial |
|---|---|---|---|---|---|---|---|
|---|---|---|---|---|---|---|---|
| E01 | The roadmap is the accumulated decision log for the milestone | a closed roadmap row is durable history that must be preserved | label over-read | is-implies-ought | description read as rule | J1 | existing-too-broad |
| E02 | A closed roadmap entry ... does not change | a closed row is immutable and must not be edited | obligation inflation | truncated excerpt | description read as rule | J2 | existing-too-broad |
| E03 | Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active. | a non-active milestone must never carry a task list | scope widened | residual | scope over-read | J1 | no-home |
| E04 | work to consensus | convergence is mandatory for every review run | obligation inflation | unscoped directive | scope over-read | J4 | no-home |
| E05 | a surviving mutation is a coverage finding | the agent must write a source-text assertion pinning the survivor | obligation inflation | is-implies-ought | description read as rule | J1 | none |
| E06 | replaced by a newer doc | a doc rolled into a handover and deleted is superseded | scope widened | truncated excerpt | term without boundary test | J5 | none |
| E07 | terminal -- no active references | a rolled-up-and-deleted doc is archived | label over-read | truncated excerpt | term without boundary test | J1 | none |
| E08 | follow through everything autonomously | the grant collapses four fix lanes into one commit | grant over-extended | unscoped directive | scope over-read | J1 | no-home |
| E09 | review at the end of the milestone, all together | the grant covers a task-list reassignment | grant over-extended | unscoped directive | scope over-read | J1 | no-home |
| E10 | `disable-model-invocation: true` marks a skill the model cannot fire on its own, only the operator can invoke it by typing its name. | the model can still discover the skill; it only cannot fire it | completeness assumed | one-case ruling | negation with unstated reach | J3 | no-home |
| E11 | A skill sets it when the operator should trigger it deliberately and the agent should not reach for it unprompted, which covers every `principle-` skill, the two quality skills and the two loop runbooks that set it. | every principle- skill sets the field | scope widened | faulty enumeration | list read as rule | J3 | existing-too-broad |
| E12 | The two repo skills that set it (`thermo-nuclear-code-quality-review`, `domain-model`) are user-invoked because the operator triggers them deliberately and the agent should not reach for them unprompted. | only those two skills set the field | completeness assumed | faulty enumeration | list read as rule | J2 | existing-too-broad |
| E13 | Each `docs/` document belongs to **exactly one** folder: `reference/`, `reference/`, `operations/`, `development/`, or `adr/`. | the reader cannot resolve the folder set, since `reference/` is named twice | unresolvable name | faulty enumeration | residual | J6 | existing-too-broad |
| E14 | Architecture, concepts, and policy documents carry no status line -- the layer-freeze table in `system_overview.md` governs them. | the reader resolves `architecture` and `concepts` folders that no longer exist | stale name | unanchored name | unresolvable name | J1 | no-home |
| E15 | Architecture and concepts documents keep their code examples current. | the reader resolves the retired `architecture` and `concepts` folders | stale name | unanchored name | unresolvable name | J3 | no-home |
| E16 | Before writing an ADR, concept doc, or architecture doc, propose the skeleton in chat -- section list and what each section holds -- and get operator confirmation. | the reader resolves document kinds `concept doc` and `architecture doc` that no longer exist | stale name | unanchored name | unresolvable name | J1 | no-home |
| E17 | The record-links gate does not scan `src/`, so nothing catches it: the link passes every gate and fails the reader. | the reader trusts that no check scans `src/` for broken links | scope widened | residual | negation with unstated reach | J2 | existing-too-broad |
| E18 | A design document records the completed design, not the open-questions-and-replies transcript that produced it. | a design document holds only the final design and no rejected alternatives | completeness assumed | one-case ruling | negation with unstated reach | J2 | no-home |
| E19 | A constraint that exists only in a skill is not authoritative. | a judgement living only in a skill is also not authoritative | scope widened | one-case ruling | term without boundary test | J7 | existing-too-broad |
| E20 | Their steps map the minor and major loop procedures, and the rules stay in the policy documents. | the reader must resolve the terms `minor` and `major` loop | unresolvable name | unanchored name | unresolvable name | J3 | no-home |
| E21 | `documentation-pass.md` is the diagnostic register for these checks. | the reader follows a retired `documentation-pass.md` file | stale name | unanchored name | unresolvable name | J1 | no-home |

## Arm B, blind open coding

| Pair | Agreement | Pairs |
|---|---|---|
| B - C | 0.85 | 179 of 210 |
| B - D | 0.85 | 179 of 210 |
| C - D | 0.92 | 194 of 210 |
| Mean | 0.88 | - |

The category-to-category table is the dispatcher's, read from the coders' own definitions. It is the table the acceptance rule is applied to.

| Accepted rule | B | C | D | Events in all three |
|---|---|---|---|---|
| N1 a name resolves to a current referent | `stale name`, `unresolvable name` | `unanchored name` | `unresolvable name` | E14, E15, E16, E20, E21 |
| N2 a classification is not read as an action | `obligation inflation` | `is-implies-ought` | `description read as rule` | E05 |
| N3 an aggregate grant names the units it covers | `grant over-extended` | `unscoped directive` | `scope over-read` | E08, E09 |
| N4 an enumeration of current instances is not the definition of the set | `completeness assumed` (partly) | `faulty enumeration` | `list read as rule` | E11, E12 |

Categories with no counterpart in another coder: `label over-read` and `scope widened` (B), `truncated excerpt`, `one-case ruling` and `residual` (C), `term without boundary test`, `negation with unstated reach` and `residual` (D). A `residual` category is a placement, not a failure of the run: C and D each used it once.

## Arm C, the Jev probe matrix

`opencode/jev-1.13-free`, 21 calls, no provider error. P1 must the reader hold a word before it attaches; P2 does the sentence name the actor before it is needed; P3 does the sentence use a term the reader has not met; P4 can it be read two incompatible ways; P5 does it state a past fact where a current rule is needed.

| cluster | probes on | size | events |
|---|---|---|---|
| J1 | P1, P3, P4 | 9 | E01, E03, E05, E07, E08, E09, E14, E16, E21 |
| J2 | P2, P3, P4 | 4 | E02, E12, E17, E18 |
| J3 | P1, P2, P3, P4 | 4 | E10, E11, E15, E20 |
| J4 | P3, P4 | 1 | E04 |
| J5 | P1, P3, P4, P5 | 1 | E06 |
| J6 | P2, P4 | 1 | E13 |
| J7 | P3 | 1 | E19 |

The matrix separates weakly. P3 fires on 17 of 21 events (median 0.81), so it behaves as a constant rather than an axis; it is the probe that would have separated an undefined term from a retired name, and it does not. P5 separates two events apart from the rest (median 0.08, spread 0.67), which is the one axis the corpus does not exercise. The clusters cannot be read as natural categories: J1 mixes retired names, label failures and scope failures, and the four singleton clusters are one event each.

| id | P1 | P2 | P3 | P4 | P5 | cluster |
|---|---|---|---|---|---|---|
| E01 | 0.56 | 0.37 | 0.72 | 0.63 | 0.12 | J1 |
| E02 | 0.47 | 0.58 | 0.80 | 0.69 | 0.10 | J2 |
| E03 | 0.58 | 0.47 | 0.75 | 0.56 | 0.04 | J1 |
| E04 | 0.48 | 0.23 | 0.81 | 0.77 | 0.07 | J4 |
| E05 | 0.54 | 0.31 | 0.85 | 0.57 | 0.08 | J1 |
| E06 | 0.65 | 0.20 | 0.70 | 0.61 | 0.70 | J5 |
| E07 | 0.57 | 0.24 | 0.86 | 0.62 | 0.12 | J1 |
| E08 | 0.50 | 0.23 | 0.81 | 0.71 | 0.06 | J1 |
| E09 | 0.53 | 0.20 | 0.84 | 0.64 | 0.11 | J1 |
| E10 | 0.53 | 0.50 | 0.66 | 0.61 | 0.03 | J3 |
| E11 | 0.65 | 0.63 | 0.86 | 0.65 | 0.05 | J3 |
| E12 | 0.46 | 0.52 | 0.77 | 0.63 | 0.06 | J2 |
| E13 | 0.41 | 0.61 | 0.48 | 0.63 | 0.05 | J6 |
| E14 | 0.54 | 0.48 | 0.83 | 0.66 | 0.14 | J1 |
| E15 | 0.51 | 0.58 | 0.78 | 0.61 | 0.08 | J3 |
| E16 | 0.51 | 0.32 | 0.90 | 0.53 | 0.06 | J1 |
| E17 | 0.45 | 0.60 | 0.83 | 0.62 | 0.10 | J2 |
| E18 | 0.45 | 0.59 | 0.55 | 0.56 | 0.08 | J2 |
| E19 | 0.49 | 0.40 | 0.80 | 0.49 | 0.04 | J7 |
| E20 | 0.64 | 0.67 | 0.92 | 0.62 | 0.13 | J3 |
| E21 | 0.53 | 0.33 | 0.85 | 0.60 | 0.08 | J1 |

## Arm D, the adversarial coder

| id | verdict | named principle or missing property |
|---|---|---|
| E01 | existing-too-broad | one-term-one-meaning -- "decision log" is one word for two things, but the body bans only "a rotating synonym" (one thing, many words). |
| E02 | existing-too-broad | describe-only-what-is-true -- a false absolute is neither "speculation" nor "TODO", which is all the body bans. |
| E03 | no-home | missing a rule that states the invariant it protects, not a stricter proxy. |
| E04 | no-home | missing a mode marked as one of several. |
| E05 | none | show-dont-describe -- "a coverage finding" is a description the reader interpreted; give the artifact. |
| E06 | none | one-term-one-meaning -- "replaced" rotates in for the defined term "superseded". |
| E07 | none | one-term-one-meaning -- "terminal -- no active references" rotates in for the defined status "archived". |
| E08 | no-home | missing an aggregate word that names the units it aggregates. |
| E09 | no-home | missing a scope phrase that enumerates exactly the units it covers. |
| E10 | no-home | missing a restriction statement that says what it leaves unrestricted. |
| E11 | existing-too-broad | describe-only-what-is-true -- a false scope quantifier is neither "speculation" nor "TODO". |
| E12 | existing-too-broad | describe-only-what-is-true -- a false scope claim is neither "speculation" nor "TODO". |
| E13 | existing-too-broad | describe-only-what-is-true -- a duplicated and member-missing enumeration is neither "speculation" nor "TODO". |
| E14 | no-home | missing a retired name replaced at every reference site. |
| E15 | no-home | missing a retired name replaced at every reference site. |
| E16 | no-home | missing a retired name replaced at every reference site. |
| E17 | existing-too-broad | describe-only-what-is-true -- a false gate claim is neither "speculation" nor "TODO". |
| E18 | no-home | missing a negation that excludes exactly what it names. |
| E19 | existing-too-broad | one-term-one-meaning -- "constraint" is one word for two things, but the body bans only "a rotating synonym". |
| E20 | no-home | missing a retired term replaced at every reference site. |
| E21 | no-home | missing a retired file name replaced at every reference site. |

`describe-only-what-is-true` and `one-term-one-meaning` are recorded as over-broad in the way arm D states: each name claims a defect its body does not ban. `describe-only-what-is-true` bans speculation and TODO, and five events are false present-tense claims that carry neither. `one-term-one-meaning` bans a rotating synonym, and two events are one word carrying two meanings, the inverse. The proposed `own-the-step-you-write` and `a-copy-points-to-its-source` took no event, in either direction.

## The verdict

| Candidate rule | Induced by | Core events | Verdict |
|---|---|---|---|
| N1 a name resolves to a current referent | all three | E14, E15, E16, E20, E21 | accepted |
| N2 a classification is not read as an action | all three | E05, E01, E02 | accepted |
| N3 an aggregate grant names the units it covers | all three | E08, E09 | accepted |
| N4 an enumeration of current instances is not the definition of the set | two of three (C, D) | E11, E12 | accepted |
| a merge of two existing principles | none | - | not supported |
| an event placed by no coder | none | E03 and E13 were each placed by two of three | none |

N1 absorbs the `define-before-you-use` proposal: all three coders' categories include a term the reader has never met, and all three also carry the retired-and-renamed case that proposal does not. N2, N3 and N4 are new: no filed principle and no proposed one states them, and arm D independently reached the same gap from the other side, calling E08, E09, E10, E18 and the retired-name events `no-home`.

## The ledger resolution

Only ledger rows classified `judgement` are in the 77. The spec census's line references also name six lines that are now headings, blanks or other kinds; those are counted under `unexercised` only if they are judgement rows, and they are not, so the six drop out of the 77 rather than inflate a group.

| Arm A group | judgement lines | line ids | resolution | events touching |
|---|---|---|---|---|
| `write-plainly` | 4 | doc-51, doc-56, doc-58, doc-59 | unexercised | none |
| `one-term-one-meaning` | 1 | doc-57 | unattributed | E06, E07, E19 |
| `define-before-you-use` | 2 | doc-60, doc-61 | N1 | E20 |
| `describe-only-what-is-true` | 1 | doc-37 | unattributed | E02, E17 |
| `disclose-by-need` | 2 | pal-40, pal-42 | unexercised | none |
| `colocate-what-belongs-together` | 1 | pal-44 | unexercised | none |
| `match-guidance-to-fragility` | 1 | pal-46 | unexercised | none |
| `end-a-step-on-a-check` | 2 | pal-52, pal-81 | unexercised | none |
| `one-document-one-subject` | 1 | pal-92 | unexercised | none |
| `one-trigger-per-branch` | 1 | pal-98 | unexercised | none |
| `a-copy-points-to-its-source` | 4 | pal-88, pal-102, pal-104, pal-105 | unexercised | none |
| `own-the-step-you-write` | 5 | pal-115, pal-117, pal-119, pal-120, pal-123 | unexercised | none |
| filed absorptions (`only-derive-what-you-own`, `write-for-the-reader`) | 1 | doc-23 | existing principle | none |

The 51 judgement lines that no group names are all unexercised; they are the remainder of the ledger after the 26 mapped lines, and no corpus event touches them. The counts sum to 77: 2 (N1) + 1 (filed) + 2 (unattributed) + 21 (grouped, unexercised) + 51 (remainder) = 77.

`unattributed` is a class the pre-registration did not name. It covers a line whose group an event touches while no coder induced that group's judgement, and it is a retirement candidate beside `unexercised`, not a surviving home.

## Post-review learnings and process adjustments

- **The corpus measures the corpus.** 21 events against 77 lines leaves 72 unexercised, and a line can be unexercised because it is useless or because the corpus is narrow. This run cannot tell those apart, and the report does not pretend to: the 72 are deletion candidates, not deletions. Broadening the corpus is the alternative to deleting, and it is a decision for U2.
- **The 12-group frame was too coarse for the failures that recur.** The four accepted rules describe 13 of the 21 events, and only N1 maps onto a proposed group. A method that starts from the proposed set cannot produce N2, N3 or N4, which is the defect the design predicted, measured rather than asserted.
- **Agreement is high but does not imply the same categories.** 0.88 pairwise agreement comes largely from coders agreeing that events do *not* share a category. The category-to-category table, not the agreement number, is what decides a rule.
- **The probes are a prior, and a weak one.** P3 saturates and P5 is inert on this corpus. A later census should drop P3 and treat P5 as a selector for the events to mine, not as a property to score.
- **A dispatch can quote a sha it mistyped.** One mining event carried `aaa1246d` for `aaa1246f`. Every source reference is now resolved against the tree before an event enters the corpus; put that check in the mining brief next time.

## Final output artifacts

| Artifact | Home |
|---|---|
| this report | `devlog/discussions/20261019-report-settled-neutral_principle_census.md` |
| the U2 filing row | `devlog/roadmap.md`, under M3.3.4 |
| the corrected design | `devlog/discussions/20261019-design-settled-neutral_principle_census.md` |
| the iteration record | `devlog/handovers/archive/20261019-11-audit-neutral_principle_census.md` |
| the corpus, briefs, arm outputs, scripts | session-local `.scratchpad/`, not committed |

## Resolution status

Closed: the census, the pre-registered comparison, and the four accepted rules.

Open: the filing of N1 to N4 as principle skills; the resolution of the three communication surfaces; the ledger regeneration; the operator's decision on the 72 deletion candidates; and the W2 handoff, which keeps the corpus beyond these events, the controlled vocabulary and the signalling experiment.

## Records this supersedes

The spec census `20261019-design-draft-prose_standards_specs.md` stays a draft of the operator's unsettled 12 names, and this report replaces its method rather than its text: the 12 groups remain the comparison baseline, arm A. The sentence-structure study `20261019-design-settled-sentence_structure_principle.md` and its evidence report are settled by their own filing and are not touched here.
