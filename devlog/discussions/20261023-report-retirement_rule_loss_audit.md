# The retirement's rule-loss audit

**Status:** settled

## What this is

Eight policy documents were retired under M3.3.2, one slice per iteration, each split between the procedure that runs it and the project's convention-skill. A reviewer was meant to check that split on every slice, and it never ran, so nothing had read a deleted policy against the tree that absorbed it. This record is that check. Every section of every retired policy carries one disposition, and a rule found stated nowhere is either restored here or traced to the handover that cut it deliberately.

## How the walk ran

Eight passes, one per retired policy, each a dispatched reviewer pair from the `_REVIEWER` role line, at thinking level `high`, two seats run separately through `src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh`, briefed with the source's `git show <commit>^:<path>`, the destinations the design record's map names for that policy, and the slice handovers. The pair comes from the `_REVIEWER` role line, so the runner carried no model of its own.

The two seats exist so that agreement is a signal rather than a tie-breaker. They disagreed on eleven positions across four of the eight policies, and each was settled by a command, because the tree decides which seat is right; where the two reports split the source at a different grain the position counts differ, so this record states the disposition I settled and not a vote. Where a report left a section out, I walked that section myself, and the policy's opening line says so.

| Disposition | Meaning |
|---|---|
| `present` | the rule is stated at the destination named, and the evidence phrase is grep-found in that file |
| `restored` | the rule was stated nowhere and no handover records a cut, so this iteration wrote it back |
| `cut` | the retiring slice dropped it deliberately, and the last column names the handover that says so |
| `no rule` | the section imposes nothing on a reader or a procedure |

## The eight walks

### handover_policy

Source: `git show 75deaa0d^:docs/policies/handover_policy.md`, 232 lines, 17 sections. Rows: 17.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.zInrR6`. Agreement: the seats disagreed on 3 positions, each settled by command. The five rules this pass restored were removed again on 2026-10-24, on the operator's direction, returning the file to its pre-audit state (handover `20261024-09`).

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | Purpose | restored | .agents/skills/work-log/SKILL.md | It is written for the agent that opens the next iteration | - |
| 2 | Brevity | restored | .agents/skills/work-log/SKILL.md | Implementation steps -- the file-by-file changes | - |
| 3 | File Naming Standard | present | .agents/skills/work-log/SKILL.md | YYYYMMDD-NN-<shortform>-<slug>.md | - |
| 4 | Types | restored | .agents/skills/work-log/SKILL.md | An iteration declares its own scope and inherits nothing | - |
| 5 | Lifecycle | restored | .agents/skills/work-log/SKILL.md | The prior record reads `Closed` before a new one opens | - |
| 6 | Format | present | .agents/skills/work-log/SKILL.md | The template carries the frontmatter block and the seven sections | - |
| 7 | Objective | present | .agents/skills/work-log/assets/handover.md | <One sentence: what this iteration achieves. Scoped to the iteration, not the su | - |
| 8 | Scope | present | .agents/skills/work-log/assets/handover.md | Reference by group name; do not copy the task list | - |
| 9 | Acceptance criteria | present | .agents/skills/work-log/SKILL.md | one row per criterion | - |
| 10 | Hot files | cut | - | - | `20261014-10`, Scope: the record carries no file list |
| 11 | Decisions | present | workflow/coding-agent/prompts/iter.md | A decision is recorded in the handover's Decisions table as it is made, with the | - |
| 12 | Decisions pending | restored | .agents/skills/work-log/SKILL.md | A pending decision is not a task | - |
| 13 | Findings | present | .agents/skills/work-log/assets/handover.md | Append-only. Written the moment something changes the plan. One row per finding, | - |
| 14 | Completed | present | .agents/skills/work-log/SKILL.md | No file changes this iteration. | - |
| 15 | The Format Window | present | .agents/skills/work-log/SKILL.md | A record with no frontmatter block is unreachable by the default scan | - |
| 16 | Canonical Null Markers | present | .agents/skills/work-log/SKILL.md | An empty nullable section carries its canonical marker and nothing else. Do not  | - |
| 17 | Corrections to Closed Handovers | present | workflow/coding-agent/prompts/record-correction.md | A closed record is edited only at the operator's direction, and every edit carri | - |

---
[CORRECTION -- 2026-10-24: the pass restored rows 1, 2, 4, 5 and 12 at `.agents/skills/work-log/SKILL.md`, and a later iteration removed them again on the operator's direction, returning the file to its pre-audit state. Handover `20261024-09`.]

---

### roadmap_policy

Source: `git show 89d0059c^:docs/policies/roadmap_policy.md`, 193 lines, 8 sections. Rows: 8. Both seats walked promotion, states, structure, changelog and corrections; neither reported the timing section or the maintenance section, so I walked those two and `## M{n} - {Title}` myself.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.P90Rku`. Agreement: the seats agreed on every position they both walked.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | `## When the Roadmap Is Touched` | present | `.agents/skills/task-list/SKILL.md` | The roadmap is the sole task list | - |
| 2 | `## Roadmap maintenance` | present | `workflow/coding-agent/prompts/milestone-close.md` | owns the milestone-grain compaction | - |
| 3 | `## Milestone Promotion` | present | `workflow/coding-agent/prompts/milestone-close.md` | promote the next incomplete milestone | - |
| 4 | `## Milestone States` | present | `.agents/skills/task-list/SKILL.md` | The milestone workflow does not begin before the prior top-level milestone | - |
| 5 | `## Structure and Filing Rules` | present | `.agents/skills/task-list/SKILL.md` | Non-integer labels | - |
| 6 | `## Changelog Format` | present | `.agents/skills/task-list/SKILL.md` | top-level milestone | - |
| 7 | `## M{n} - {Title}` | present | `.agents/skills/task-list/SKILL.md` | M{n}.{m} | - |
| 8 | `## Corrections to Closed Roadmap and Changelog Entries` | present | `.agents/skills/task-list/SKILL.md` | A closed roadmap or changelog entry | - |

### adr_policy

Source: `git show 5af32756^:docs/policies/adr_policy.md`, 123 lines, 11 sections. Rows: 16, because seat a walked the template fence's headings separately and split the timing rule from the spawn judgement; every source section has a row or a parent row.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.jeVyyu`. Agreement: the seats agreed on every position they both walked.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | # ADR Policy + frontmatter (line 7, MEASURED) | no rule | - | the title and the file locator; the skill names the record itself | - |
| 2 | ## Relationship to other records (9) | present | .agents/skills/decision-records/SKILL.md | The concept is the parent and links its ADRs as further reading | - |
| 3 | ## Unit of record (15) | present | .agents/skills/decision-records/SKILL.md | One ADR per standing principle | - |
| 4 | ## When an ADR begins -- spawn judgement, discussion origin, distillation steps (25) | present | .agents/skills/decision-records/patterns/distil.md | Open this when a discussion or design document has settled a principle | - |
| 5 | ## When an ADR begins -- timing paragraph and Suggest an ADR when list (25, paragraphs 3-5) | restored | .agents/skills/decision-records/SKILL.md | Write it when the principle is committed or being actively resolved | - |
| 6 | ## Liveness and evolution (46) | present | .agents/skills/decision-records/patterns/distil.md | Keep the primitives, the invariants, the design rationale, and any collision or  | - |
| 7 | ### Structure (50), with the Requirements preamble, Promotion cycle and Sub-headers paragraphs (73-85) | present | .agents/skills/decision-records/SKILL.md | An ADR holds the live decision and its history. When the principle changes, edit | - |
| 8 | ## Requirements (58, inside the text fence) | present | .agents/skills/decision-records/SKILL.md | opens with a numbered requirements table betw | - |
| 9 | ## YYYY-MM-DD -- <decision name> (63, fenced) | present | .agents/skills/decision-records/SKILL.md | keeps the template's field order | - |
| 10 | ## <prev date> -- <prior decision name> (70, fenced) | present | .agents/skills/decision-records/patterns/evolve.md | Keep the decision and its reason, and do not delete or rewrite its rationale. | - |
| 11 | ### Editing procedure (87) | present | .agents/skills/decision-records/patterns/evolve.md | Evolve an ADR in place | - |
| 12 | ## Statuses (96) | present | .agents/skills/decision-records/SKILL.md | A file has no single status | - |
| 13 | ## Archive (107) | present | .agents/skills/decision-records/SKILL.md | awaiting review for rewrite and consolidation, and fully superseded ADRs. A file | - |
| 14 | ## Naming (111) | restored | .agents/skills/decision-records/SKILL.md | The agent recommends the name from two or three candidates | - |
| 15 | ## Content (119) | present | .agents/skills/decision-records/SKILL.md | the template's field order: Decision, Rationale, Rejected alternatives, Edge cas | - |
| 16 | frontmatter description: (2-3) -- an obligation, not a section | no rule | - | the policy file's own metadata block; the form it belonged to is retired | - |

### discussion_policy

Source: `git show 0fa5e53d^:docs/policies/discussion_policy.md`, 191 lines, 30 sections. Rows: 35, because seat a walked the `###` subsections of the retired policy form separately.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.1DPKG2`. Agreement: the seats disagreed on 3 positions, each settled by command.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | ## Naming (L11) | present | .agents/skills/work-log/SKILL.md | YYYYMMDD-{type}-{status}-{description}.md | - |
| 2 | ## Document types (L55) | present | .agents/skills/work-log/SKILL.md | This file states the rules; the template states the shape. | - |
| 3 | ## Context (story, L69) | present | .agents/skills/work-log/assets/story.md | ## Context | - |
| 4 | ## Pain Points (L72) | present | .agents/skills/work-log/assets/story.md | <the concrete problems being investigated; what is broken or missing> | - |
| 5 | ## Constraints (story, L75) | present | .agents/skills/work-log/assets/story.md | <non-negotiable requirements any solution must satisfy; omit when none> | - |
| 6 | ## Open Questions (story, L78) | present | .agents/skills/work-log/assets/story.md | <unresolved questions blocking progress; updated as they resolve> | - |
| 7 | ## Study Findings (L81) | present | .agents/skills/work-log/assets/story.md | <what the studies found; one summary link per study; omit when no studies> | - |
| 8 | ## Resolution (story, L84) | present | .agents/skills/work-log/assets/story.md | <at closure: the decision, where the work went, and why> | - |
| 9 | ## Direction and parent story (L100) | present | .agents/skills/work-log/assets/study.md | <which direction this study belongs to; link to the parent story> | - |
| 10 | ## Required reading (L103) | present | .agents/skills/work-log/assets/study.md | <prerequisite documents; links only, no prose> | - |
| 11 | ## Summary (study, L106) | present | .agents/skills/work-log/assets/study.md | <what this candidate is and how it works; 2-4 sentences> | - |
| 12 | ## Findings (study, L109) | present | .agents/skills/work-log/assets/study.md | <what was discovered; iterative subsections> | - |
| 13 | ## Open Questions (study, L112) | present | .agents/skills/work-log/assets/study.md | <unresolved questions blocking a recommendation> | - |
| 14 | ## Constraints (study, L115) | present | .agents/skills/work-log/assets/study.md | <non-negotiable requirements this candidate must satisfy> | - |
| 15 | ## Next Steps (L118) | present | .agents/skills/work-log/assets/study.md | <immediate actions; replaced by Resolution at closure> | - |
| 16 | ## Resolution (study, L121) | present | .agents/skills/work-log/assets/study.md | <at closure: adopt, reject or defer; the rationale; where the decision was recor | - |
| 17 | ## Context (design, L137) | present | .agents/skills/work-log/assets/design.md | <what problem; what triggered the exploration> | - |
| 18 | ## Options Considered (L140) | present | .agents/skills/work-log/assets/design.md | <alternatives with trade-offs; at least two> | - |
| 19 | ## Decision (L143) | present | .agents/skills/work-log/assets/design.md | <the recommended approach and why> | - |
| 20 | ## Consequences (L146) | present | .agents/skills/work-log/assets/design.md | <what this changes, enables, or forecloses> | - |
| 21 | Context (L162, report) | cut | - | - | `20261022-08`, Scope and Decisions |
| 22 | ## The brief (L165) | cut | - | - | `20261022-08`, Scope and Decisions |
| 23 | ## Compact log of actions (L168) | cut | - | - | `20261022-08`, Finding naming the six dropped sections |
| 24 | ## Mid-run adjustments (L171) | cut | - | - | `20261022-08`, Finding naming the six dropped sections |
| 25 | ## Findings summary (L174) | cut | - | - | `20261022-08`, Decisions |
| 26 | ## Resolution methods (L177) | cut | - | - | `20261022-08`, Finding naming the six dropped sections |
| 27 | ## Post-review learnings and process adjustments (L180) | cut | - | - | `20261022-08`, Finding naming the six dropped sections |
| 28 | Final output artifacts (L183) | present | .agents/skills/work-log/SKILL.md | it states the context, what came of it, and the artifacts it produced, each nami | - |
| 29 | ## Resolution status (L186) | cut | - | - | `20261022-08`, Finding naming the six dropped sections |
| 30 | ## Records this supersedes (L189) | cut | - | - | `20261022-08`, Finding naming the six dropped sections |
| 31 | ### Types (L28) | present | .agents/skills/work-log/SKILL.md | Open one when | - |
| 32 | ### Statuses (L36) | present | .agents/skills/work-log/SKILL.md | The `status` vocabulary is `Active` | - |
| 33 | ### Standalone policy docs (L50) | present | .agents/skills/work-log/SKILL.md | A file under `docs/` is not a discussion record | - |
| 34 | ### Legacy docs (L52) | present | .agents/skills/work-log/SKILL.md | A record keeps an old-format name until it is substantively edited. On that edit | - |
| 35 | ### Types -- the investigation note (L33) | restored | .agents/skills/work-log/SKILL.md | `investigation` was an earlier name for `study` | - |

### git_policy

Source: `git show f05b750a^:docs/policies/git_policy.md`, 109 lines, 7 sections. Rows: 7.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.4mXN3i`. Agreement: the seats disagreed on 1 position, each settled by command.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | ## The convention | no rule | - | - | Pointer only, and its target resolves: .agents/skills/git-di |
| 2 | ## Checkpointing | present | workflow/coding-agent/prompts/commit.md | before its boundary, even when incomplete | - |
| 3 | ## WIP Commits | present | .agents/skills/git-discipline/SKILL.md | The delivery commit carries an active type. A | - |
| 4 | ## Transient commits fold into the delivery commit | present | .agents/skills/git-discipline/SKILL.md | The end state is one commit per unit. | - |
| 5 | ## Amending | present | workflow/coding-agent/prompts/record-correction.md | Report and stop when the fold needs an interactive rebase | - |
| 6 | ## Recovery (incl. ### Splitting interleaved changes) | present | workflow/coding-agent/prompts/commit.md | changes from more than one iteration is split | - |
| 7 | ## Merge Policy | cut | - | - | `20261022-10`, Decisions: the Merge Policy section is deleted, not relocated |

### documentation_policy

Source: `git show 70ed3923^:docs/policies/documentation_policy.md`, 211 lines, 11 sections. Rows: 14, because seat a split the `## Communication Standards` subsections out. The seats disagreed on five positions here, the widest of the eight.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.fNZnZb`. Agreement: the seats disagreed on 4 positions, each settled by command.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | Frontmatter block (description, scope, reader) | no rule | - | the policy file's own metadata block; the form it belonged to is retired | - |
| 2 | Title and untitled preamble (2 paragraphs before ## Rule authority) | present | .agents/skills/docs/SKILL.md | Each document belongs to exactly one folder | - |
| 3 | ## Rule authority | cut | - | - | `20261022-11`, Decisions: the judgement half moved to M3.3.4 |
| 4 | ## Folder Structure | present | .agents/skills/docs/SKILL.md | Plain ASCII. | - |
| 5 | ## Communication Standards > ### Rule placement | cut | - | - | `20261022-11`, Decisions: the rule-placement section is deleted without a move |
| 6 | ## Communication Standards > ### Simplified Technical English | cut | - | - | `20261022-11`, Decisions: the seven-skill index is deleted rather than relocated |
| 7 | ## Communication Standards > ### Reserved terminology | present | .agents/skills/docs/SKILL.md | Propose the skeleton of an ADR or a reference document in chat before writing pr | - |
| 8 | ## Format (7 subsections) | present | .agents/skills/docs/SKILL.md | ## How a document opens | - |
| 9 | ## Drafting (3 subsections) | present | .agents/skills/docs/SKILL.md | Pick the folder before the first sentence. Update only the sections a change aff | - |
| 10 | ## Prohibited content > ### No speculative language or TODO content in reference/ | present | .agents/skills/docs/SKILL.md | A concept document stands alone and reads complete | - |
| 11 | ## Prohibited content > ### Stale code examples | restored | .agents/skills/docs/SKILL.md | A reference document keeps its code examples current | - |
| 12 | ## Tooling checks (2 subsections) | present | workflow/coding-agent/skills/doc-maintenance/SKILL.md | A per-file disable is not a fix | - |
| 13 | ## Document Types (2 subsections, 2 sub-subsections) | present | .agents/skills/docs/SKILL.md | restates its requirements as user-observable guarantees, without seam vocabulary | - |
| 14 | ## Record maintenance (2 subsections) | present | workflow/coding-agent/prompts/record-correction.md | A record that states what is true is corrected in place. A record that tracks op | - |

### testing_policy

Source: `git show 8dfeb9c2^:docs/development/testing_policy.md`, 274 lines, 6 sections. Rows: 6. Neither seat reported `## Running the Test Suite`; I walked it.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.dMYnur`. Agreement: the seats agreed on every position they both walked.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | `## Core Principles` | present | `.agents/skills/testing/SKILL.md` | Clean before create | - |
| 2 | `## Shared Fixtures (tests/libs/)` | present | `.agents/skills/testing/SKILL.md` | Every shared helper is sourced from | - |
| 3 | `## Test Placement` | present | `.agents/skills/testing/patterns/structure.md` | Keep no roster | - |
| 4 | `## Running the Test Suite` | present | `.agents/skills/testing/SKILL.md` | not complete until | - |
| 5 | `## Keeping Tests Current` | present | `.agents/skills/testing/SKILL.md` | Where a test belongs | - |
| 6 | `## See Also` | no rule | - | a further-reading pointer, four bare links | - |

### iteration_policy

Source: `git show e43837ad^:docs/policies/iteration_policy.md`, 145 lines, 6 sections. Rows: 6. The seats agreed on every position.

Pass: `deepseek/deepseek-flash` high, seats a and b, run directory `review-dispatch.ofuGaH`. Agreement: the seats agreed on every position they both walked.

| # | Section | Disposition | Destination | Evidence | Cut by |
|---|---|---|---|---|---|
| 1 | ## Loop workflow prompts | present | AGENTS.md | iteration_protocol | - |
| 2 | ## Sidequests | present | docs/reference/iteration_protocol.md | The open iteration pauses; it does not close. | - |
| 3 | ## Principles | present | devlog/handovers/20261022-12-workflow-retire_iteration_policy.md | The six echoed principles and the two findings rules are cut, not moved | - |
| 4 | ## The autonomous agent loop | present | docs/reference/autonomous_agent_loop.md | The autonomous agent loop is the continuous cycle | - |
| 5 | ## Iteration Invariants | present | workflow/coding-agent/prompts/milestone-close.md | Do not decide a probation entry yourself; the operator owns the decision. | - |
| 6 | ## File Tracking | present | workflow/coding-agent/prompts/iter.md | There is no document registry; the docs tree is the authoritative file list. The | - |

## What was restored

Nine rules were restated nowhere and traced to no cut. Each is back at the destination the map assigns, and each is one clause, which is what a convention-skill holds; the slice that retired the policy stated the remainder was "stated where it is enforced" and named no artifact, which is how the loss went unnoticed.

| Rule | Restored to | From |
|---|---|---|
| A record is written for the agent that opens the next iteration, and its job is to remove that agent's reconstruction of state | `.agents/skills/work-log/SKILL.md` | `handover_policy` Purpose |
| Implementation steps belong in the commit, not the record; a criterion whose verification means reading the record is too detailed | `.agents/skills/work-log/SKILL.md` | `handover_policy` Brevity |
| An iteration declares its own scope and inherits nothing from the previous record | `.agents/skills/work-log/SKILL.md` | `handover_policy` Types |
| The prior record reads `Closed` before a new one opens; when it does not, the iteration continues that record | `.agents/skills/work-log/SKILL.md` | `handover_policy` Lifecycle |
| A pending decision is not a task: it never lands in the roadmap, and its row is written the moment the block appears | `.agents/skills/work-log/SKILL.md` | `handover_policy` Decisions pending |
| `investigation` was an earlier name for `study` and is retired | `.agents/skills/work-log/SKILL.md` | `discussion_policy` Types |
| An ADR is written when the principle is committed or being actively resolved, and the three subjects that call for one | `.agents/skills/decision-records/SKILL.md` | `adr_policy` When an ADR begins |
| The agent recommends the ADR name from two or three candidates | `.agents/skills/decision-records/SKILL.md` | `adr_policy` Naming |
| A reference document keeps its code examples current, and an update checks each example against the implementation | `.agents/skills/docs/SKILL.md` | `documentation_policy` Stale code examples |

## The deliberate cuts

| Section | Cut by | What stands instead |
|---|---|---|
| `handover_policy` Hot files | `20261014-10` | the record carries no file list; the scope proposal owns it |
| `discussion_policy` Context, The brief, Compact log of actions, Mid-run adjustments, Findings summary, Resolution methods, Post-review learnings, Resolution status, Records this supersedes | `20261022-08` | the report type's three binding rules, in place of a template |
| `git_policy` Merge Policy | `20261022-10` | `merge` and `rebase` state the two replay situations the agent meets; the operator-side landing models went with them |
| `documentation_policy` Rule authority | `20261022-11` | the judgement half moved to M3.3.4 as the principle corpus; the ledger it governed is retired |
| `documentation_policy` Rule placement | `20261022-11` | deleted without a move, on the slice's own decision |
| `documentation_policy` Simplified Technical English index | `20261022-11` | each phrasing rule is a principle skill, and the `docs` skill cites four of them |

## What the walk left open

Two narrowings are recorded as `present` and worth a reader's eye, because the walk found the rule in a weaker form rather than the source's form:

- `iteration_policy` `## Principles`: four of the five principles sit verbatim in `iteration_protocol.md`; the fifth, "acceptance criteria describe a delta", is carried by `iter.md` Step 5 plus the weaker "verify at the weakest sufficient level" bar. The source's "the operator verifies by running the system, never by reading source alone" is not stated. Not restored: the live bar is stricter where it matters and the sentence would restate a rule one file over.
- `documentation_policy` and `adr_policy` frontmatter blocks: recorded `no rule`. They are the retired files' own metadata. The `reader` obligation is stated in the `docs` skill and enforced by `scripts/lint/document-shape.mjs`; a `description` and `scope` duty on a `docs/` document is stated nowhere, so a reader looking for it will not find it. It was never prose in the policy either, so there is no rule to restore.

## Coverage

| Policy | Source | Lines | `##` headings | Rows |
|---|---|---|---|---|
| `handover_policy` | `docs/policies/handover_policy.md` at `75deaa0d^` | 232 | 17 | 17 |
| `roadmap_policy` | `docs/policies/roadmap_policy.md` at `89d0059c^` | 193 | 8 | 8 |
| `adr_policy` | `docs/policies/adr_policy.md` at `5af32756^` | 123 | 11 | 16 |
| `discussion_policy` | `docs/policies/discussion_policy.md` at `0fa5e53d^` | 191 | 30 | 35 |
| `git_policy` | `docs/policies/git_policy.md` at `f05b750a^` | 109 | 7 | 7 |
| `documentation_policy` | `docs/policies/documentation_policy.md` at `70ed3923^` | 211 | 11 | 14 |
| `testing_policy` | `docs/development/testing_policy.md` at `8dfeb9c2^` | 274 | 6 | 6 |
| `iteration_policy` | `docs/policies/iteration_policy.md` at `e43837ad^` | 145 | 6 | 6 |

A row count above the heading count is a finer grain, never a gap: the rows of a split section share its parent heading. `testing_policy`'s source is read at `8dfeb9c2^` because the deletion commit's parent is the emptied bridge the slice left behind, not the policy.
