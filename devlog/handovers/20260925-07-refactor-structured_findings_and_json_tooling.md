# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Switch the read-through findings register from Markdown tables to structured JSON, and land the JSON tooling and references that decision needs.

## Scope

The read-through close's post-processing, first decision, as one unit: the register-format decision record, the JSON Lines data file and its two conventions, the propagation to the workflow briefs, the issue-tracker roadmap home with the three subsumed items, the `jq` dependency in the reasoning base image, and the documentation policy's TODO destination.

## Carried forward

| Item | From handover |
|---|---|
| The read-through close's post-processing: the register's form, and the jq dependency it raised | roadmap M3.1 (`Read-through close: operator review, then a findings-to-tasks plan session`) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The findings file holds one JSON value per line, one line per finding | a per-line parse; 312 lines; ids unique 1..312 | Agent [x] |
| The file follows the report's name with a different extension | the tracked file name beside the report | Agent [x] |
| `status` holds one of six fixed values, and resolved rows are checked off | a group-by over the field | Agent [x] (`open=214`, `resolved=78`, `accepted=11`, `blocked=6`, `needs-decision=2`, `stale=1`) |
| The counts a plan needs are derivable from the data, not asserted | the `status`, `action_kind` and `class` queries | Agent [x] (`test=152`, `code=68`, `docs=22`, `none=69`, `comment=1`) |
| The register declares the companion file, the naming convention and the computed-count rule | the register's Format section | Agent [x] |
| The two workflow briefs' register rules match the data design | the briefs' register and fan-out sections | Agent [x] |
| The issue-tracker question has a roadmap home, and the three named items are subsumed | `devlog/roadmap.md` T5 and `devlog/roadmap_future.md` M4 | Agent [x] |
| `jq` is installed by the shared reasoning layer | reading the apt list | Agent [x] |
| The documentation policy names only a destination that exists | the TODO destination clause | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20260925-design-draft-findings_register_format.md`](../discussions/20260925-design-draft-findings_register_format.md) | new: the format decision, the schema, the conventions, the query commands, the propagation list |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | new: 312 findings as JSON Lines |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.md`](../discussions/20260924-design-active-test_suite_readthrough.md) | the Format section declares the pairing |
| [`workflow/coding-agent/prompts/read-through-run.md`](../../workflow/coding-agent/prompts/read-through-run.md) | its register-integrity rules change shape |
| [`workflow/coding-agent/prompts/fanout-run.md`](../../workflow/coding-agent/prompts/fanout-run.md) | its findings block is now the schema |
| [`src/reasoning/node.dockerfile`](../../src/reasoning/node.dockerfile) | the shared reasoning base image gains `jq` |
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | the TODO destination clause |
| [`devlog/roadmap.md`](../roadmap.md), [`devlog/roadmap_future.md`](../roadmap_future.md) | the issue-tracker home and the subsumption |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| JSON Lines, one finding per line, paired with the prose register | perl core `JSON::PP` and node both read it with no new dependency; YAML needs a parser that is absent; a single JSON array rewrites and diffs whole regions on every append | the register-format design note |
| The data file takes the report's name with a different extension | a register's data file is found from its report, never by scanning a directory for data files | the register-format design note |
| `status` holds one of six fixed values | the field is how a finding is checked off, so a free-text status would be unusable by any query; `resolved` covers a landed fix and `accepted` covers a finding whose disposition is to leave the behaviour | the register-format design note |
| Split by kind of content, not by audience | the data holds what a query needs and the prose holds the reasoning, so a label lives in exactly one place and the two records cannot disagree | the register-format design note |
| Counts are computed from the data and never asserted in prose | a stated count has no owner and drifts from the thing it counts, which happened three times in this register | the register's Format section |
| No reader script and no new lint gate; `jq` instead | the data file is a log, its whole interface is a handful of documented queries, and `jq` makes those queries one shell line; live counts are no longer needed inside a pass | the register-format design note |
| `jq` goes in the shared reasoning layer, not the capability layer | the reasoning container is where an agent queries data; the capability layer runs the diff pipeline and has no JSON work | this handover |
| The issue-tracker question is owned by the roadmap-mechanism rewrite study | that task already exists and the labelled register is its first step; M6.3 in `roadmap_future.md` is two milestones away and unrelated | `devlog/roadmap.md` T5 |
| The documentation policy names the roadmap, not a tracker | the roadmap is the only task list that exists today; naming a mechanism that does not exist makes the clause unverifiable | the policy clause |

## Findings

| Finding | Type | Impact |
|---|---|---|
| A JSON Lines file is not valid JSON as a whole document by design: a whole-file parse fails and each line is what parses. Any consumer must read it line by line. | steering | next iteration |
| The `jq` line is confirmed by reading, because an image build cannot run from inside this container; it is validated at the host's next image build. | blocker | next iteration |
| The policy clause was the only operational reference to an issue tracker in the repository, so removing it completes the fix; the process review's Option C is a considered option, not a destination. | contradiction | next iteration |
| The `status` field is a snapshot of this iteration's fix lanes, so a row that changes state is edited in the data, not in prose. | steering | next iteration |
| The unit boundary is the unit of approval, not the kind of file: this work first landed as three commits split by file class (data, build, policy) and the operator collapsed them into one commit, because one reviewer accepts or rejects the register's move to JSON as a whole. Recorded on the autonomous-scope entry in `devlog/AGENT_FEEDBACK.md`. | steering | roadmap |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20260925-design-draft-findings_register_format.md` | new: five options, the chosen JSON Lines design, the schema table with the six status values, the naming convention, the query commands, the risks and the propagation checklist |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | new: 312 objects, ids 1..312, each with title, sector, class, action, action text, action kind, files, status and refs |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.md` | Format section declares the companion file, the naming convention and the computed-count rule, naming the three count defects as the evidence |
| `workflow/coding-agent/prompts/read-through-run.md` | register-integrity rules replaced by the schema rule, the status vocabulary and the data check |
| `workflow/coding-agent/prompts/fanout-run.md` | the findings block is the schema; the integrity check is a pass over the data plus the BDD-coverage count |
| `src/reasoning/node.dockerfile` | `jq` added to the apt list beside the existing agent utilities |
| `docs/operations/documentation_policy.md` | the TODO destination clause names `roadmap.md`, the only task list |
| `devlog/roadmap.md` | the roadmap-mechanism rewrite study names the register file as its first step and subsumes the Symphony-spec study, the next-task placement and the metadata suggestion |
| `devlog/roadmap_future.md` | `.workspace/metadata.json` degraded from a scheduled task to a suggestion pointing at the study |

## Deferred items

None beyond the roadmap. The tracker itself belongs to the roadmap-mechanism rewrite study (roadmap T5).

## What's Next

M3.1 - Backpressure remains active. Candidates are roadmap row 83 (the coverage campaign, 152 test-class rows) and row 84 (the mutation-suite discussion).

Watch-outs (three): a JSON Lines reader parses per line, never the whole file; a row whose state changes is edited in the data, because the prose no longer repeats a label; the register's prose still holds the narratives under their ids and is the only place the reasoning lives.

Read at iteration start: this handover, the register-format design note, and the register's Format section.

**Conclusions from this iteration:** the register can shed its table rules entirely, because the fragility they managed - escaping, ordering, fragments - does not exist in a line-oriented data file; and with `jq` present, no reader script is owed.
