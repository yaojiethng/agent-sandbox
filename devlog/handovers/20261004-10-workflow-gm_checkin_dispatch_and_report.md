---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Workflow
status: Closed
---

# Handover - Workflow: the check-in dispatch and the report-only record audit

## Objective

Return `/gm` to the survey it ran before the record maintenance was delegated, make the delegation an opt-in the operator asks for by name, and split the record check into a dispatcher that owns the contract and two auditors that report into it. The check-in is quick by default, thorough when the operator says so, its task list carries work, and its record fixes are applied and committed by the one agent that ran it.

## Scope

Twelve files, one outcome: the record checkers stop writing, and every workflow that invoked them applies their report instead.

**The dispatcher.** A new skill directory, `workflow/coding-agent/skills/check-in/`. `SKILL.md` carries the procedure: the survey reads, the inventory and its axes, the output rules, the aggregation and inspection step, and the commit. Two references carry the record-report schema and the subcommand invocation template. The `/gm` prompt is reduced to frontmatter, the argument parse, and a dispatch into the skill.

The skill is the sole owner of the report schema. The intensive half loads only on the exhaustive argument: with no thoroughness argument the skill never opens the auditor references and never dispatches an auditor. `milestone-start.md` points at `gm.md` for the inventory axes today, and it is repointed to the skill they move into.

The dispatcher applies the report and makes the single `chore:` commit, in the main tree, after the auditors return -- never a subagent, never one commit per finding. It inspects each entry before applying it, as `no-comments` step 2 inspects a `comment-sicko` report, and rejects a finding that misstates the record.

**The two auditors.** [`roadmap-maintenance.md`](../../workflow/coding-agent/skills/roadmap-maintenance.md) and [`handover-maintenance.md`](../../workflow/coding-agent/skills/handover-maintenance.md) keep their checks and lose every apply instruction, becoming auditors in the `comment-sicko` sense: report only, write no record, invent nothing. Each returns one JSONL file, one object per finding, its locus named by section and never by line number, and an explicit skip entry where a check did not apply or could not be judged. Each reports the violations of the policy it checks -- `roadmap-maintenance.md` of [`roadmap_policy.md`](../../docs/operations/roadmap_policy.md), `handover-maintenance.md` of [`handover_policy.md`](../../docs/operations/handover_policy.md) and [`documentation_policy.md`](../../docs/operations/documentation_policy.md). That corrects the dangling pointer in `roadmap-maintenance.md` Step 5, "Report the changes per `roadmap_policy.md`": `roadmap_policy.md` carries no report rule, and a violation report names the rule it checks, so it needs none.

**The other three callers.** The contract change reaches every workflow that invokes a runbook, and none can be left behind, because a caller that still expects the skill to write invokes a skill that no longer does. Three prompts and one concept sentence are updated to apply the report: [`milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) line 36, which has `roadmap-maintenance` own the compaction pass and the summary table update; [`wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) step B8, which has `handover-maintenance` close or fold a landed document; [`iter.md`](../../workflow/coding-agent/prompts/iter.md) `## Roadmap maintenance check`, which runs roadmap maintenance to bring the roadmap into line; and [`autonomous_agent_loop.md`](../../docs/concepts/autonomous_agent_loop.md) line 72, which states that the record-check skills "own the record corrections each may apply".

**The contract.** The schema is owned by the gm skill and passed by the invocation template, so every auditor writes the same shape without restating it. Enforcement is the template plus the dispatcher's aggregation step; there is no validator script, and no commit-time gate can see the reports because they never enter the tree.

```json
{"skill":"roadmap-maintenance","file":"devlog/roadmap.md","section":"M2.7 summary row","check":"3.18","rule":"roadmap_policy.md#corrections-to-closed-roadmap-and-changelog-entries","finding":"row reads Complete while the changelog entry records a supersession; no marker","recommendation":"fix-now","evidence":"grep -n SUPERSEDED devlog/changelog.md"}
{"skill":"roadmap-maintenance","file":"devlog/roadmap.md","section":"closed rows across the milestone","check":"3.6","rule":"roadmap_policy.md#compaction-cascading","finding":"twenty-plus closed rows carry landed narrative and counts that go stale","recommendation":"defer","deferTo":"the T12 pi-bump and extension pass","evidence":"grep -c 'Handover' devlog/roadmap.md"}
{"skill":"roadmap-maintenance","file":"devlog/roadmap.md","section":"M3.2 sub-milestone","check":"3.10","rule":"roadmap_policy.md#fractal-milestone-numbering","finding":"a M3.2.1 node with no M3.2 parent, and no summary row","recommendation":"escalate","evidence":"no M3.2 heading exists in the tree or in git history"}
{"skill":"handover-maintenance","check":"3","result":"skip","reason":"no acceptance criterion names a validation tool that misses its failure mode"}
```

`recommendation` is the auditor's judgement of whether the finding is fixable now, and nothing more. It names no commit, no message, no fold. Three values, and each maps to exactly one dispatcher action:

| value | condition | dispatcher action |
|---|---|---|
| `fix-now` | determinable from the tree or the policy, and bounded to a record edit | applies it in the `chore:` commit |
| `defer` | determinable, and an existing roadmap unit of work already names the broader task this finding belongs to | nothing. The named unit owns it, and clearing it ahead of that pass is premature. A `defer` entry without a named existing unit is a bad flag and the dispatcher rejects it, so the dispatcher never writes a row back for one. |
| `escalate` | two sources disagree, or a value cannot be re-derived | presents it as a point below the table |

A line is either a finding or a skip. A skip carries `result` and `reason` and no recommendation: it records a check that did not apply, could not be judged, or found something the auditor's own exception clause protects, with the clause named. A finding the exception clauses protect is a skip, not a recommendation -- an auditor that wanted to say `ignore` would be overriding the rule it was given.

**The report is never committed.** Each auditor writes its file under a run-scoped path outside the tree, and the dispatcher aggregates the files in place. The check-in's diff carries record fixes and nothing else.

**The survey.** The base is `026803f`, the commit before `0ecddb6` replaced the inline survey with the two runbooks. The cheap reads -- the latest handover, the active milestone and its open rows, the recent history, the open feedback entries, the stale-state sweep -- stay in both modes; they build the inventory and are not the cost. The thoroughness argument -- `be thorough`, `deep dive`, `full audit` -- is what dispatches the auditors; any other argument is the intent filter.

Four output rules travel with it. No inventory row carries Progress `write-back` or Impact `cosmetic`; the count is one line. The three closing suggestions -- easiest start, highest leverage, most urgent -- draw only from work items. A record defect is never one of the three. A `defer` finding adds no row and no point.

The `backlog-triage` clause leaves the prompt. Its sentence reads: when the direction picked from a survey is an unattended run rather than a supervised iteration, run triage on the inventory before opening the run. That trigger belongs to [`backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md), which owns the classification and already names `gm.md` as the survey that feeds it. It does not go to [`workflow/coding-agent/drafts/auto.md`](../../workflow/coding-agent/drafts/auto.md): that stub is reserved, fails closed, refuses every input but a single sequential list, and belongs to M4.

`workflow/coding-agent/prompts/gm.md` carries nine `doc-wrap` findings today. It is named in `legacyFiles`, so the Markdown gate skips it and `scripts/check_doc_wrap_legacy.sh` ends the exemption on the commit that next touches it. This iteration rewrites the file, so the debt is cleared here.

### What this does to handover `20261003-02`

Commit `c1bc00e` (handover `20261003-02`) deleted `workflow/coding-agent/audits/audit.skill.md` and `workflow/coding-agent/audits/handover-audit.skill.md`, and reduced `handover-maintenance.md` Track B Step 5 to the gate command. This iteration takes back the part of that change that made a maintenance run write corrections, and restores no audit file. The two runbooks keep their names and their checks; the write authority leaves them, and the report they already carry becomes the whole deliverable.

Out of scope: restoring `audit.skill.md` or `handover-audit.skill.md`, or creating any other audit file. Shipping the skill directory into the provider image; it stays repo-only, read by path, as the two runbooks are. Promoting `drafts/auto.md` or `drafts/maintenance.md` out of draft. `backlog-triage.md`'s own survey of the project, which the gm skill owns.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | `/gm` carries frontmatter, the argument parse and the dispatch, and no survey procedure | read it; `wc -l` | `Agent [x]` |
| 2 | `workflow/coding-agent/skills/check-in/` holds `SKILL.md`, `report-schema.md` and `auditor-invocation.md` | `ls workflow/coding-agent/skills/check-in/` | `Agent [x]` |
| 3 | No thoroughness argument means no auditor reference is opened and no auditor is dispatched | read the skill's exhaustive branch | `Agent [x]` |
| 4 | Only the gm skill enumerates the report schema; neither auditor restates the fields | `grep -n "deferTo\|fix-now\|escalate\|recommendation:" workflow/coding-agent/skills/*maintenance*.md` returns nothing | `Agent [x]` |
| 5 | Neither auditor carries an apply imperative | `grep -n "is applied\|are applied\|Edit inline\|apply it\|applied immediately" workflow/coding-agent/skills/*maintenance*.md` returns nothing | `Agent [x]` |
| 6 | Neither auditor is told to commit | `grep -ni commit workflow/coding-agent/skills/*maintenance*.md` returns no instruction | `Agent [x]` |
| 7 | Each auditor reports the violations of the policy it checks, and names it | read each purpose and report section | `Agent [x]` |
| 8 | The `Report the changes per roadmap_policy.md` pointer is gone | `grep -rn "Report the changes per" workflow/coding-agent/` returns nothing | `Agent [x]` |
| 9 | The schema defines `fix-now`, `defer` and `escalate`, and requires `deferTo` on a `defer` | read `report-schema.md` | `Agent [x]` |
| 10 | The dispatcher inspects each entry and rejects one that misstates the record | read `SKILL.md` | `Agent [x]` |
| 11 | The reports are written outside the tree and are never committed | read the invocation template; the path is named | `Agent [x]` |
| 12 | `milestone-close.md` applies the roadmap report instead of expecting the skill to write | read the compaction section | `Agent [x]` |
| 13 | `wrapup.md` step B8 applies the handover report | read B8 | `Agent [x]` |
| 14 | `iter.md` applies the roadmap report at the maintenance check | read that section | `Agent [x]` |
| 15 | `autonomous_agent_loop.md` no longer claims the skills apply corrections | `grep -n "corrections each may apply" docs/concepts/autonomous_agent_loop.md` returns nothing | `Agent [x]` |
| 16 | `milestone-start.md` resolves the inventory axes to the skill that owns them | `grep -n "skills/check-in" workflow/coding-agent/prompts/milestone-start.md` | `Agent [x]` |
| 17 | `backlog-triage.md` carries the unattended-run trigger, and `/gm` no longer does | `grep -n "unattended"` on each; the negative on the gm prompt | `Agent [x]` |
| 18 | `gm.md` clears its nine `doc-wrap` findings | `bash scripts/check_doc_wrap_legacy.sh workflow/coding-agent/prompts/gm.md` returns 0 | `Agent [x]` |
| 19 | Every prompt and skill frontmatter parses, and the Markdown gate is clean | `bash scripts/check_prompt_frontmatter.sh`, `bash scripts/check_markdown.sh` | `Agent [x]` |
| 20 | With no argument no auditor runs and no fix is applied; with a thoroughness argument both auditors run and the applied fixes land as one `chore:` commit | two runs | `Operator` |
| 21 | The skill passes the workflow-document authoring conventions: a subject name, a `When to use` routing, failure modes, one home for the rule, and the invocation flag | `grep -n "^## When to use\|^## Failure modes\|^disable-model-invocation" workflow/coding-agent/skills/check-in/SKILL.md`; `grep -c "is a check-in, not an iteration" workflow/coding-agent/prompts/gm.md` returns 0 | `Agent [x]` |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/prompts/gm.md` | reduced to frontmatter, argument parse and dispatch; wrap debt cleared |
| `workflow/coding-agent/skills/check-in/SKILL.md` | new: the procedure, the axes, the aggregation, the commit |
| `workflow/coding-agent/skills/check-in/report-schema.md` | new reference: the JSONL schema and its value sets |
| `workflow/coding-agent/skills/check-in/auditor-invocation.md` | new reference: the subcommand invocation template |
| `workflow/coding-agent/skills/roadmap-maintenance.md` | audit-only, JSONL report |
| `workflow/coding-agent/skills/handover-maintenance.md` | audit-only, JSONL report |
| `workflow/coding-agent/prompts/milestone-close.md` | applies the roadmap report |
| `workflow/coding-agent/prompts/wrapup.md` | applies the handover report |
| `workflow/coding-agent/prompts/iter.md` | applies the roadmap report |
| `docs/concepts/autonomous_agent_loop.md` | the consumer/producer sentence |
| `workflow/coding-agent/prompts/backlog-triage.md` | receives the unattended-run trigger clause |
| `workflow/coding-agent/prompts/milestone-start.md` | repointed at the skill that owns the inventory axes |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The thoroughness trigger is an argument on `/gm`, not a second prompt | the operator chose this over `gm-quick.md` | this record |
| Both modes keep the base survey's cheap reads | the inventory needs them, and they are not the cost | this record |
| The triage clause moves to `backlog-triage.md`, not to `drafts/auto.md` | the stub refuses every input but one sequential list and is M4's; a live routing rule needs a live prompt | this record |
| The `chore:` commit takes every record fix whose correct form the tree or the policy determines | the operator's rule: whatever can be folded in is folded in by default | this record |
| The runbooks become auditors, modelled on `comment-sicko` | one writer, one commit point; the reporter returns findings and the dispatcher applies them | this record |
| The schema lives in the gm skill, and the invocation template passes it to each auditor | one owner for one format, held by the consumer that must parse it; the auditor restates none of it | this record |
| The report carries a recommendation, not a disposition | the auditor says whether a finding is fixable now; the dispatcher decides how the fix lands. A `fold` field would have the auditor choosing a commit shape it does not own | this record |
| `defer` requires an existing roadmap unit, and the dispatcher writes nothing back for it | the operator's amendment: a record defect that falls under a broader task in flight is premature to clear, and the dispatcher must not gain an easy way to create rows | this record |
| The report is written outside the tree and never committed | the check-in's diff holds record fixes and nothing else | this record |
| No validator script | enforcement is the invocation template and the dispatcher's aggregation step. A report never enters the tree, so no commit-time gate could see it | this record |
| The skill directory stays repo-only | the operator's call; `workflow/coding-agent/skills/` is copied into no image, and a repo-root-relative path resolves for every reader | this record |
| The skill directory is `check-in/`, and the skill is named for its subject | `prompt-authoring-conventions.md` `## Naming` requires a workflow document's name to state its subject. `gm` is the command name and had become the skill name too; `/gm` stays the command. | this record |
| The rule and the argument semantics have one home, the skill | the prompt restated both, and `## Consumers as fast paths, never sources` gives a rule one owner. The prompt now carries the dispatch, and names the policy rather than linking it. | this record |
| The skill sets `disable-model-invocation` | the convention marks a skill the operator triggers deliberately and the model must not fire on its own; `/gm` is a command. The flag is inert while the directory is repo-only and load-bearing if it ever ships. | this record |
| Impact is the inventory's severity axis, and a record finding carries no severity | the operator's direction. Severity grades a work item's cost of delay, so the inventory's Impact value set is a severity scale -- `blocking`, `degrading`, `cosmetic` -- and the three closing suggestions read it. A record finding is not work: its severity is expressed as its recommendation, where a serious one is an `escalate`. | this record |

## Decisions pending

None.

## Findings

All findings are triaged.

- **The contract change has four callers, not one.** `milestone-close.md:36` and `wrapup.md:114` invoke a runbook to perform a write, and `iter.md` `## Roadmap maintenance check` does the same. The read-only change cannot land behind them, because a caller that expects a write invokes a skill that no longer writes, and the breakage is silent. Triaged to: completed in this iteration -- all four callers now apply the report.
- **The committer was lost at `0ecddb6`.** The delegation moved the applying of record fixes into two subagent runbooks and left the committing with nobody. Triaged to: completed in this iteration -- the gm skill names itself as the one committer, and neither auditor is told to commit.
- **The report pointer dangled.** `roadmap-maintenance.md` Step 5 said "Report the changes per `roadmap_policy.md`", a policy rule that does not exist. Triaged to: completed in this iteration -- both auditors now report violations of the policy they check.
- **A shipped prompt reaches a repository path by a form that does not resolve from its loaded location.** Fixed for the two runbook references and left standing for the policy links. Triaged to: `roadmap.md` T1, row `A shipped prompt reaches a repository path by a form that resolves`.
- [`workflow/coding-agent/drafts/maintenance.md`](../../workflow/coding-agent/drafts/maintenance.md) describes a delegation that changed shape. Triaged to: `roadmap.md` T1, row `drafts/maintenance.md describes a delegation that changed shape`.

## Completed

| File | Change |
|---|---|
| [`gm.md`](../../workflow/coding-agent/prompts/gm.md) | reduced to the dispatch alone; the rule and the argument semantics deleted to their one home, and the policy named rather than linked; the nine `doc-wrap` findings cleared |
| [`check-in/SKILL.md`](../../workflow/coding-agent/skills/check-in/SKILL.md) | new: the survey, the inventory axes, the exhaustive check, the apply rules, the output rules and the commit; Impact is the severity axis; sited under a subject name with a `When to use` routing and failure modes |
| [`check-in/report-schema.md`](../../workflow/coding-agent/skills/check-in/report-schema.md) | new: the JSONL schema, the three recommendations, the skip form, and the no-severity rule for a record finding |
| [`check-in/auditor-invocation.md`](../../workflow/coding-agent/skills/check-in/auditor-invocation.md) | new: the subcommand invocation template that hands each auditor the schema |
| [`roadmap-maintenance.md`](../../workflow/coding-agent/skills/roadmap-maintenance.md) | report-only; every correction clause became a report clause; the JSONL output shape replaces the markdown table; severity routing replaced by the recommendation |
| [`handover-maintenance.md`](../../workflow/coding-agent/skills/handover-maintenance.md) | report-only; Step 9 names the correction form instead of writing it; the JSONL output shape |
| [`milestone-close.md`](../../workflow/coding-agent/prompts/milestone-close.md) | applies the roadmap report; the runbook named by its repository-root-relative path |
| [`wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | step B8 applies the handover report and writes the block the report names |
| [`iter.md`](../../workflow/coding-agent/prompts/iter.md) | the roadmap maintenance check applies the report |
| [`backlog-triage.md`](../../workflow/coding-agent/prompts/backlog-triage.md) | receives the unattended-run trigger clause from the check-in |
| [`milestone-start.md`](../../workflow/coding-agent/prompts/milestone-start.md) | the inventory axes resolve to the check-in skill |
| [`autonomous_agent_loop.md`](../../docs/concepts/autonomous_agent_loop.md) | the record-check sentence states report-only and names the exhaustive gate |
| [`roadmap.md`](../../devlog/roadmap.md) | two T1 rows raised from this iteration's findings |

Verified: `bash scripts/lint.sh` clean across six gates -- markdown, frontmatter over 40 files, handover format over 26, legacy wrap; `bash scripts/run_tests.sh` reports 1052 passed and 0 failed across 72 files. Acceptance criteria 1 to 19 pass by their stated commands; criterion 20 is the operator's two-run check.
