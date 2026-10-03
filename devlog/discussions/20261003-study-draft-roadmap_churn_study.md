# Roadmap churn diagnostic study

**Status:** draft

## Context

`devlog/roadmap.md` is edited by two thirds of all commits, and its review load drew repeated operator complaint across the sessions of 2026-09-30 to 2026-10-03. This report runs the diagnosis the operator asked for: why does that file churn, which of the causes are the model's, which are the mechanism's, and which are the workflow's.

The subject is the cost of the present mechanism, not the choice of a replacement. The T5 row `Roadmap-mechanism rewrite study` owns that choice, and this report is an input to it. The linear-style redesign row above it is the fold point for the requirements this report derives.

Excluded from scope: the model's contribution is stated as a separate and named cause, and is not diagnosed here, because it is a model-selection question and not a mechanism one. Also excluded: any change to the roadmap, its policies, or its gates. This iteration changed no record text and applied no fix.

## The brief

Three independent discovery tracks, each reading a disjoint evidence set under a read-only brief, fanned out to subagents on the `_IMPLEMENTER` role resolution, `deepseek/deepseek-v4-flash` at medium. The project table's first choice, `opencode/space-bunny-free`, is the model the operator flagged as misaligned in the very sessions under analysis, and the second, `opencode-go/deepseek-v4-flash`, answered every attempt with `429 GoUsageLimitError`, so the operator selected the deepseek provider directly.

| Track | Evidence set | Question |
|---|---|---|
| A | the 30 most recent session logs under `~/.pi/agent/sessions/--home-agentuser-sandbox--/` | what the operator and the agent tripped on, with verbatim quotes and counts |
| B | the three roadmap records, `roadmap_policy.md`, `scripts/lint.sh` and the lint modules | what the mechanism's shape makes expensive, measured with commands |
| C | `roadmap_policy.md`, `iteration_policy.md`, `handover_policy.md` and the seven loop prompts plus the two maintenance skills | which rules force churn and which drop context |

Each track was told to cite a command or a verbatim quote for every claim, to write `unclear` rather than speculate, and to name the driver of each friction class as model-driven, mechanism-driven, workflow-driven or tool-driven. Their full logs are transient; every number they report is reproducible from the commands reproduced below.

## Compact log of actions

| Step | Action | Result |
|---|---|---|
| 1 | Read `gm.md`, the maintenance skills, the T5 rows and the task-queue primitive's scope note | established the study's shape and the fan-out method |
| 2 | Wrote briefs for tracks A, B and C under `/tmp`, checked each non-empty | 3 briefs, 79 lines total |
| 3 | Fanned the three tracks out in one call, one log each, 1500s per-track timeout | all three returned; 199s wall clock; 144, 203 and 111 log lines |
| 4 | Read the three logs, checked each against its brief | each carried commands and raw output; no track returned empty |
| 5 | Measured the headline figures directly in the primary session | 105/157 commits, 66.9%, 80 at 6 lines or fewer |

Discovery by track, in numbers:

| Track | Headline output |
|---|---|
| A | 437 operator-authored messages across 30 sessions; 63 carry a re-steer marker; 15 of 30 sessions exceed 50 bash calls; 83 operator messages mention `roadmap` and 77 mention `handover`; 19 edit-tool misses; 51 `python3: command not found`; genuine rate-limit signatures in 9 sessions |
| B | 95,539 bytes, 175 rows, 110 open; median row 310 characters, 21 rows over 900; 197 positional references naming a roadmap record, 3 of 3 sampled stale; 12 invariant families with no machine check; 5 duplicated subjects across two records and one across three |
| C | 22 of 27 maintenance checks require reading and judging a row; the skill runs twice per iteration; 6 rules that force a record edit at a stated moment; 8 named context-loss points, including two worker briefs that omit the roadmap row entirely |

## Mid-run adjustments

Two method changes were made during the run.

The model changed before the fan-out. The project table's first choice was the misaligned model, and the second was rate-limited, so the operator selected `deepseek/deepseek-v4-flash` at medium for the three discovery tracks. Attribution for every quote and measurement below is that model, under these briefs.

The fan-out used subagents rather than `taskq`. The primitive's own scope note routes a read-mostly pass to `fanout-run` and not to the queue, because taskq exists to create per-task worktrees, branches, break points and bring-backs, and this run merges nothing. Using it would have produced three worktrees and three branches for notes the primary rewrites into one report.

## Findings summary

The churn is real and it is mostly the mechanism's. The model's contribution is real too, and it is separate. The three causes, in the order the evidence supports them:

### Cause 1 - the mechanism: no row identity, so every edit is a rename

A task row is its prose. `roadmap_policy.md` gives milestones a fractal number and a heading anchor, and gives a task row nothing. The consequence is measured: 197 references in the tree name a roadmap row by position, seven of them inside `roadmap.md` itself, and all three samples that were checked no longer hold the subject they claim.

```text
$ grep -rniE '\b(row|rows|line|lines) [0-9]+' devlog docs workflow | grep -iE 'roadmap' | wc -l
197
$ sed -n '126p;117p;83p;109p' devlog/roadmap.md
```

| Cited by | Claim | Line now holds |
|---|---|---|
| handover `20260929-04` | `roadmap row 126 marked done` | `Follow-on: the table omits the provider`; the claimed row is in no record |
| handover `20260919-03` | `row 117 design-settled ... M2.6.7` | `/document convergence ... round 3`; M2.6.7 is now `roadmap_future.md:210` |
| handover `20260925-07` | `roadmap row 83 (coverage campaign)` | blank; the subject survives in no record |
| handover `20261002-28` | `roadmap row 109` | still holds |

The cost is not only broken references. A row cannot be renamed safely, so a rename propagates into prose: the `/auto` to `/sequential-work` and `/parallel-auto` to `/parallel-work` change reached 24 and 17 files, and left two closed rows holding the retired token at `roadmap.md:245` and `:188`, which `roadmap_policy.md:172` forbids fixing.

### Cause 2 - the workflow: an unconditional write-back tax on every iteration

`iteration_policy.md:117` requires exactly one roadmap row event per iteration, and `wrapup.md:118` requires one row per handover. Measured: 28 of the last 30 handovers cite at least one roadmap row, and 103 of the 175 rows exist because an iteration wrote back. The file is therefore on the critical path of every commit.

```text
$ git log --since=2026-09-25 --oneline -- devlog/roadmap.md | wc -l
105
$ git log --since=2026-09-25 --oneline | wc -l
157
```

105 of 157 commits (66.9%) touch `roadmap.md`. Of those 105, 80 change six lines or fewer and only 3 change fifty or more. Each small edit costs a full commit, a gate run and a review pass, and each is a mandatory consequence of closing an iteration that may have changed nothing about the plan. The same promotion is executed from three edit sites: `/milestone-start`, `/iter`'s scope gate, and `/milestone-close`.

### Cause 3 - the mechanism: every semantic invariant is rule-only

`scripts/lint.sh` runs six gates. The only ones that read the records are generic Markdown shape, ASCII prose, line wrapping, and link-fragment resolution. No gate reads a checkbox, a nesting level, a completion context, a compaction state, a cross-record agreement, or a changelog entry's format.

| Policy invariant family | Checked by |
|---|---|
| Three-file agreement (one record) | rule only |
| Roadmap-update timing | rule only |
| Compaction cascading | rule only |
| Top-level milestone close | rule only |
| Summary-table update and format | rule only, anchors partly checked |
| Promotion invariant, milestone states, fractal numbering | rule only |
| Record shape, filing rules, changelog format, closed-record corrections | rule only |
| Prose shape, links and fragments | `check_markdown.sh` |

The cost lands on `roadmap-maintenance.md`: 22 of its 27 checks require reading a row and judging it, and the schedule runs the skill at every iteration open and close, over a 365-line file. That is the review load the operator described as intolerable, and it is a direct consequence of the invariants having no machine form. The defects this session fixed by hand - three mixed parents with no completion context, two fully-complete parents still expanded - are greppable and were never gated.

### Cause 4 - the mechanism: duplication across the three records

Five subjects are described in two records and one in all three:

| Subject | Locations |
|---|---|
| Environment-change persistence | `roadmap.md:315`, `roadmap_future.md:214` |
| STE-clean sweep | `roadmap.md:321`, `roadmap_future.md:202` |
| Atomic install and semantic versioning | `roadmap.md:283`, `roadmap_future.md:171`, `changelog.md:135` |
| Skill installation | `roadmap.md:313`, `roadmap_future.md:151` |
| Commit-metadata capture | `roadmap.md:314`, `roadmap_future.md:41` |
| Session and image identity | `roadmap.md:306` and `:330`, `changelog.md:113` |

`roadmap_policy.md:7` makes this structural: a milestone title, status or anchor that disagrees across the three files is one defect, so the fix for an inconsistency is an edit in each file. The rename case adds a third home, the ADR, and a fourth, the handover.

### Cause 5 - the workflow: context is dropped at exactly the points a worker needs it

A dispatched worker's brief carries the subject, commit type, owned files, acceptance criteria and report format. It does not carry the roadmap row, the milestone, the dependencies, or the sibling rows (`sequential-work.md:45`, `task-queue.md:97`). The worker is also forbidden to read a record. So the row's state is unavailable to the unit doing the work, which is why the primary holds the whole plan and re-derives it each iteration.

The record layer drops detail in the same direction: compaction removes implementation notes on the ground that "the handover retains them" (`roadmap_policy.md:29`), the changelog entry holds 2 to 4 mechanism sentences, and `handover_policy.md:9` retains a handover only for the life of its milestone. A completed task's detail therefore has no durable home once the milestone closes.

### Cause 6 - the model and the tooling, stated separately

The operator named the model cause: the sessions ran on `space-bunny-free`, "slightly misaligned and does not read context fully or follow instructions well". Track A measured the footprint: 63 of 437 operator messages carry a re-steer marker across 10 of 30 sessions; 15 of 30 sessions exceed 50 bash calls; one session edited `roadmap.md` 37 times.

Track A also measured tool friction that no mechanism change touches: 19 edit-tool exact-match misses, 51 `python3: command not found` (the image has no python3, so every mutation-tier run in that window was blocked), and genuine rate-limit signatures in 9 sessions.

| Friction class | Count | Driver |
|---|---|---|
| Roadmap staleness and repeated hygiene passes | 83 operator messages, 6 sessions editing `roadmap.md` | mechanism |
| Handover chain maintenance and format drift | 77 operator messages | mechanism |
| Agent over-reach and premature action | 63 re-steer markers in 10 sessions | model |
| Work-unit and commit discipline | 2 direct corrections, plus standalone close/roadmap commits re-landed | workflow |
| Policy-file overlap and repeated rewrites | 5 policy files edited 9 to 13 times each | workflow |
| Edit-tool exact-match misses | 19 | tool |
| Missing `python3` in the image | 51 | tool |
| Provider quota exhaustion | 9 sessions | tool |

## Resolution methods

The findings split into three lanes, and the split is the point of the study: the model lane is not this mechanism's, the local lane is cheap, and the rewrite lane is T5's.

**Lane 1 - not the mechanism's to fix.** Agent over-reach, edit-tool misses, the missing `python3`, and provider quota. The model lane is a model-selection question; the tool lane is a harness question (the `python3` absence is the sharpest of the three, because it silently blocked a whole test tier).

**Lane 2 - low-hanging improvements, each a small local change.** These cost little and remove load immediately. Each is stated as a change to a named file or rule, and none requires the rewrite.

| # | Improvement | Fixes | Cost |
|---|---|---|---|
| L1 | Give every row a stable id (a trailing `[[row-<key>]]` or an explicit key column) and make the maintenance skill rewrite positional references to it | cause 1, 197 stale references | one policy rule, one pass over the records, one grep check |
| L2 | Add a record-shape gate: markers, nesting, completion context on mixed parents, compaction candidates, cross-record title/status agreement | cause 3, all 22 judgement checks | one lint module, and it retires most of the hand-run maintenance pass |
| L3 | Batch the write-back: allow an iteration with no plan change to accumulate its row event, and write the batch at the next plan-gated moment | cause 2, 80 small commits | a change to `iteration_policy.md:117` and `wrapup.md` |
| L4 | One home per task: a row in a roadmap file names an existing section rather than restating it, and the changelog cites the row | cause 4, 6 duplicated subjects | a filing-rule change plus a dedup pass |
| L5 | Put the row's identity and state into the worker brief | cause 5, two briefs omitting the row | one line in `sequential-work.md` and `task-queue.md`, once L1 exists |
| L6 | Cap row prose and move detail to the linked record | row width: median 310 characters, 21 rows over 900, file at 95 KB | a policy rule plus a compaction pass |
| L7 | Generate the summary table from the section headings | cause 3 and cause 4, table drift | a small generator wired into the lint gate |

L1 and L2 are the pair with the best ratio: identity makes references durable, and a shape gate removes the judgement pass that consumes the operator's attention. L3 is the one that answers the operator's complaint most directly, because it stops the per-iteration bookkeeping commit.

**Lane 3 - requirements for the T5 rewrite.** Derived from the measurements, for the rewrite study to fold in, and deliberately stated as requirements rather than as a design.

| # | Requirement | Derived from |
|---|---|---|
| R1 | Every work item has an identity that survives a reorder, a rename, and a file move | cause 1: 197 positional references, 3 of 3 stale |
| R2 | The machine holds the state; a human or agent reads a rendered view | cause 3: 12 invariant families rule-only, 22 judgement checks |
| R3 | Invariants are machine-checkable, so an unmet invariant is a gate finding and not a review duty | cause 3: the six gates read none of it |
| R4 | One home per fact, with other surfaces derived | cause 4: 6 duplicated subjects, three-file agreement rule |
| R5 | The durable record is append-only and separate from the working task list | `[O]` 2026-10-01 feedback entry; compaction drops detail to a handover that is not durable |
| R6 | A review surface proportional to the change, not to the file | cause 2 and 3: 66.9% of commits, 105 commits for 80 six-line edits |
| R7 | A brief is derived from the item, so a dispatched worker receives its item's state | cause 5: two briefs omit the row |
| R8 | Detail lives at a stable address, so compaction removes redundancy rather than information | cause 5: compaction removes notes that the handover only holds for the milestone |

## Post-review learnings and process adjustments

The study's method is reusable and cheap: three briefs, one call, 199 seconds, 458 log lines, and a report with commands behind every number. The cost of the diagnosis was two orders of magnitude below the cost of the churn it explains, which argues for running it earlier next time rather than only when the load becomes intolerable.

Two process adjustments follow, and both are local to this study's own subject.

The maintenance skill's judgement load should be measured as a first-class number whenever it is amended. It ran at 22 judgement checks against 5 mechanical ones, and that ratio is the operator cost of the roadmap, and it is invisible in the policy.

Attribution discipline is worth keeping. Separating the causes into model, mechanism, workflow and tool stopped the study from either excusing the mechanism by blaming the model or the reverse, and the split makes the fix lanes unambiguous.

## Final output artifacts

| Artifact | Home | Fate |
|---|---|---|
| This study | `devlog/discussions/20261003-study-draft-roadmap_churn_study.md` | draft, awaiting review; on review it moves to settled and feeds the T5 rewrite study |
| The eight rewrite requirements (R1 to R8) | this study's `Resolution methods` section | input to the T5 `Roadmap-mechanism rewrite study` |
| The seven local improvements (L1 to L7) | this study's `Resolution methods` section | candidates for the immediate-pain rows the operator asked the study to isolate |

The three discovery logs were written to `/tmp` and are transient by design. Every number in this study is reproducible from the command printed beside it; the session quotes are reproducible from `~/.pi/agent/sessions/--home-agentuser-sandbox--/` by timestamp id.

## Resolution status

Closed: the diagnosis, the three-way cause separation, and the requirement set.

Open: the operator's review of this study; the choice between L1 to L7 as the immediate fixes; the T5 rewrite that folds R1 to R8; and one deliverable-shape question the iteration left open, whether this stays one study with a requirements section or splits into a study plus a story once reviewed.

## Records this supersedes

None. This study replaces no document. It relates to, without superseding, the T5 rows `Roadmap mechanism: linear-style task tracking` and `Roadmap-mechanism rewrite study`, and to the open `[O]` feedback entry of 2026-10-01 on closed rows as ritual re-description, which its cause 5 and requirement R5 restate with measurements.
