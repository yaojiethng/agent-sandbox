---
date: 2026-11-16
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - history-cleanup as a change-pipeline workflow

## Objective

Rewrite `history-cleanup` as a change-pipeline workflow under the history-as-commons framing: define the properties of a desirable review series, make the skill state them and dispatch to `git-discipline` and `prepare` for what they own, and make its audit's content check exclude every record path it can meet.

## Scope

M3.7.2, the row **`history-cleanup` is a branch-preparation primitive** and its open audit sub-row, continuing [`20261112-07`](20261112-07-workflow-history_cleanup_audit.md). The row's name is now too narrow: the corrected frame is a workflow under the change pipeline, of which the git-discipline mechanism is a part.

The layers are distinct. `git-discipline` owns the per-commit properties -- atomic, bisectable, self-explanatory, blameable -- and the history-as-commons framing. `prepare` owns trunk alignment and conflict resolution. `history-cleanup` owns the sequence above those: a feature branch's series is messy, the individual commits may each satisfy the convention, and the sequence still carries corrections, tangles, reversals, record noise and checkpoints. Its consumer is PR or merge-request review, its granularity a feature branch, and its contract a commit range in and a range conforming to the defined properties out. The change pipeline owns the branch point, the export and the draft; the skill does not.

The audit's check 4 excludes only the handover root, so a tip-level delta in `devlog/roadmap.md`, `devlog/AGENT_FEEDBACK.md` or `devlog/discussions/` reads as non-record content and fails a sound rewrite. The exclusion becomes its own list; check 1's `--records` root stays the handover tree.

Out of scope: the host verbs, the queue, the `prepare` mechanism, and the other open M3.7.2 row. The suite-runner deadline row is M3.7.2's, not this one.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states the trigger, the range contract, the six sequence properties, the proof, the two gates, and dispatches to `git-discipline` and `prepare`; it does not restate the four per-commit properties or the rebase. | read the skill; `grep -n "## The properties\|## The contract\|## When it runs"` | Agent [x] |
| The convention declares only the boundary -- per-commit local, the series the cleanup's pass -- and carries no sequence property. | `grep -n "history-cleanup" .agents/skills/git-discipline/SKILL.md`; read | Agent [x] |
| The ADR carries the 2026-11-16 entry with the six properties, the PR consumer, the agent-effort rationale and the rejected alternatives. | `grep -n "2026-11-16" docs/adr/git_commit_history_commons.md` | Agent [x] |
| The change model places the cleanup operator-invoked and independent of `prepare`, for the PR consumer. | `grep -n "History-cleanup" docs/reference/change_model.md` | Agent [x] |
| The convention, the change model and the ADR state the cleanup is operator-invoked and independent of `prepare`; no ordering implies a chain. | `grep -rn "independent of prepare\|two separate operator calls" .agents/skills/git-discipline/SKILL.md docs/reference/change_model.md docs/adr/git_commit_history_commons.md` | Agent [x] |
| The skill defines inversion and the ungated-commit rule, prescribes no retry count, and carries no record-correction exception. | `grep -n "An inversion is"`; `grep -c "Two attempts"` is 0; `grep -c "record a later commit corrects"` is 0; `grep -n "no gate"` | Agent [x] |
| Check 4 excludes the handover tree, both roadmaps, the feedback record, the discussion tree and the changelog; a record-only delta in each is clean. | `bash tests/test_history_cleanup_audit.sh` | Agent [x] |
| `--addition` no longer disables check 4: a non-record delta it does not name still fails; one it names is clean. | `bash tests/test_history_cleanup_audit.sh` | Agent [x] |
| Both spent briefs are deleted; no live reference remains. | `test -e` false for both; `grep -rn` over `.agents docs workflow` | Agent [x] |
| The roadmap parent and its sub-rows are compacted into the closed outcome. | `git diff HEAD -- devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table against the file table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `history-cleanup` is a change-pipeline workflow, not a branch-preparation primitive beside `prepare`. It runs on a feature branch, operator-invoked and independent of `prepare`; its consumer is PR or merge-request review. | The primitive frame hid the real consumer and let the skill duplicate the convention and `prepare`. | this handover |
| `git-discipline` owns the per-commit properties; the skill cites them and does not restate them. The skill owns the sequence-level properties and their detection. | Progressive context disclosure: the reader already has the convention; a second statement is a second source. | this handover |
| The convention declares only the boundary -- its properties are per-commit and local; the sequence is the cleanup's pass. The sequence properties are not a commit-time obligation. | A commit cannot know its successors, and making every commit read its neighbours spends O(n) agent turns and tokens per commit instead of once at cleanup; O(1) and O(n) name agent effort, not runtime, and the full range exists only at cleanup. | this handover |
| `prepare` owns trunk alignment and conflict resolution; the skill dispatches to it. | The skill's rebase, per-commit gate and conflict sections duplicate `prepare`. | this handover |
| The cleanup is operator-invoked and independent of `prepare`; no order chains the two. | The two are separate operator calls; either can run on its own. | this handover |
| The method is the agent's, with no retry count; the skill states the residue stop without prescribing how many attempts. | The operator allows the method to follow the unit's complexity and the series' shape. | this handover |
| The skill defines inversion and restores the ungated-commit rule; every property carries its definition. | The rewrite dropped both while shortening the skill. | this handover |
| The record-correction exception is dropped; the audit's record exclusion is the only allowance, and a record delta is a record move, not an inversion. | A state record is born final, and a derived value is removed rather than corrected; the audit already excludes every record path from the content proof, so no second exception is needed. | this handover |
| The skill's input is a commit range and its output is a range conforming to the properties; the base is unchanged. The pipeline owns the branch point, export and draft. | The change pipeline records the branch point at export and the draft forks there; cleanup does not need it. | this handover |
| The desirable sequence is defined by properties, not by a mechanism. The skill states the invariants, the proof and the release gates; the agent chooses the rewrite. | The current skill prescribes a data model and per-path operations the agent may not use. | this handover |
| The skill is short and progressive: purpose, trigger, contract and properties first; then the proof, the gates, the dispatch, and the method left to the agent. | The current 182 lines yap, repeat the convention and `prepare`, and bury the trigger. | this handover |
| Check 4's record exclusion is its own list: the handover tree, both roadmaps, the feedback record, the discussion tree and the changelog. `--records` stays the handover root for check 1. | A record delta is not a content delta, and check 1's pathspec is a different question. | this handover |
| Fix the `--addition` exclude: the leading `\|` makes the pattern match every line, which disables check 4 whenever an addition is named. | It is in the check this iteration changes, and it silently disables the content proof. | this handover |
| Delete both spent briefs: the history-cleanup brief, and the history-readers brief whose delete condition (row 755b) has closed. | A spent draft is a carrier of the old state; the readers brief has no reader left. | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None. The readers brief is deleted here, on operator direction. | | |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator reframed the row: `history-cleanup` is a change-pipeline workflow under history-as-commons, not a branch-preparation primitive beside `prepare`. | design | the row's scope and the skill's frame were wrong | this iteration |
| The skill's `## Mandate` restates the convention's four properties; the refs check, data model, per-commit gate and proof sections duplicate `git-discipline`, `prepare` and the audit scripts. | design | the skill is a second source for content another file owns | this iteration |
| The skill is 182 lines and prescribes a mechanism -- patch-id tables, per-path checkout, a data model -- the agent may not use. | design | the skill dictates method instead of stating the invariant and the proof | this iteration |
| The consumer and granularity are unstated: feature branch, PR or merge-request review; the host's one-commit delivery is a different consumer. | design | a reader cannot tell whose review the series serves | this iteration |
| The sequence properties are not defined; the convention defines the per-commit properties only. | record | the cleanup has no target to conform to, so it cannot say what a desirable series is | this iteration |
| The change model, the convention and the ADR implied a `prepare` -> cleanup -> export chain; the cleanup is operator-invoked and independent. | design | a reader would wait for `prepare` or assume the pipeline sequences them | this iteration |
| The method's "two attempts" prescribed a retry count; the operator intends the agent to choose the method by complexity. | design | the skill dictates a method the agent may not use | this iteration |
| The rewrite dropped the definition of inversion and the ungated-commit rule. | record | the proof names a detector whose term is undefined, and an ungated commit can pass silently | this iteration |
| The inversion paragraph carried a record-correction exception; a state record born final makes it dead, and a derived value is removed rather than corrected. | design | the exception would license the stale-count correction the record rules forbid | this iteration |
| The purpose brief's mapping says "one unit per commit" is enforced by audit check 4; check 4 is content identity, and the unit shape is the manifest plus checks 6-7. | record | a reader would look for the unit check in the wrong place | this iteration |
| The brief's "every commit builds" row says no check enforces it, while audit check 5 runs the gate in each commit's tree. | record | the mapping understates the audit and hides the real bisect trade | this iteration |
| Check 4's exclusion names only the handover root; a roadmap, feedback or discussion delta at the tip is reported as non-record content. | code | a sound rewrite fails on a record-only delta | this iteration |
| `--addition` builds its exclude as `\|<path>`, so the empty alternative matches every line and check 4 compares nothing. | code | the content proof is disabled whenever an addition is named | this iteration |
| `.agents/drafts/history-readers-brief.md` is spent: its `Delete when` row 755b has closed, and it still sits in the drafts folder. | record | a spent draft remains a second source for the convention's properties | this iteration, the brief deletion |

## Completed

| File | One-line change |
|---|---|
| `devlog/roadmap.md` | `roadmap-maintenance` run: 0 findings; the branch-preparation group compacts to its closed outcome |
| `workflow/coding-agent/skills/history-cleanup/SKILL.md` | Rewritten as the change-pipeline series pass: trigger, range contract, six properties, proof, two gates, dispatch, method left to the agent |
| `workflow/coding-agent/skills/history-cleanup/scripts/audit.sh` | Check 4's record list and the `--addition` exclude |
| `tests/test_history_cleanup_audit.sh` | The record-tree cases and the addition case |
| `.agents/skills/git-discipline/SKILL.md` | `prepare` is the branch-preparation primitive; `history-cleanup` is the series pass; the per-commit/series boundary |
| `docs/adr/git_commit_history_commons.md` | The 2026-11-16 entry and the current date |
| `docs/reference/change_model.md` | The primitives row places the cleanup operator-invoked and independent of `prepare`, for the PR reviewer |
| `.agents/drafts/history-cleanup-purpose-brief.md` | Deleted: spent when the row closes |
| `.agents/drafts/history-readers-brief.md` | Deleted: its delete condition closed |
| `devlog/handovers/M3.7.2/20261116-05-workflow-history_cleanup_primitive.md` | This record |
