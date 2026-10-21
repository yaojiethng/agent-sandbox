---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - The history-cleanup runbook, cut and shipped as a skill

## Objective

Run every communication-principle skill against `history-cleanup`, then convert the runbook into a skill so the inversion detector ships beside it.

## Scope

The roadmap row **The history-cleanup runbook, cut by the fourteen principles and shipped as a skill with its detector**.

The pass read the runbook once per principle, in the order the corpus lists them, and asked that principle's own test of the whole document. A principle that found nothing is recorded as having found nothing rather than skipped, because the record of a null result is what makes the next pass cheap.

The conversion answers a question handover `20261018-07` left open: whether the detector moves out of `.agents/drafts/` into a shipped home. Its stated reason for leaving it was "the skill pipeline that would own it is unbuilt". A skill is a directory and a prompt is one file, so the conversion is what makes the detector deliverable at all, whatever else that pipeline does.

## The fourteen findings

| Principle | Finding |
|---|---|
| align-the-mental-model | the description never used the document's own term, `inversion`, so a reader searching for it matched nothing. The word is in the description now. `The working tree is the invariant` named a git object where the invariant is the content, which the proof section compares as blobs |
| attach-as-you-read | three passives hid the actor: `Nothing is rewritten until the refs are checked`, `as each commit is produced`, `is staged silently by the wildcard`. All three name the actor now |
| cut-what-carries-nothing | three sentences carried nothing: `Use them;`, the pointer to the git policy's reference table, and the opening `You are rewriting the history of one branch`. Each is gone |
| dont-forecast-undone-work | nothing. The one forecast, the detector's draft status, left in handover `20261021-17` |
| hand-off-by-naming-the-boundary | `## Non-goals` named three things the runbook does not own and no owner for any of them. The porting operation now names `rebase.md`, which is the runbook that ports |
| keep-a-subject-near | `## Rebuild with the gate on every commit` carried three subjects: the path written twice, the reset and staging procedure, and the suite's grain. The first became `## Check every path the range writes twice`, with its own completion criterion, and the third moved to `## Prove each commit stands`, where the suite is already the subject and the rule was stated a second time |
| link-what-the-reader-can-open | nothing. Every pointer is either a path the reader's copy holds or a name with a stated rule for its absence |
| maximize-conceptual-leverage | `churn` stood for a mechanism the text never named, twice. `linear and useless` gave `linear` a second meaning, since the series is a line of commits by definition. Both are the mechanism now |
| name-the-value-not-a-literal | `scripts/run_tests.sh` was this repository's literal where the runbook's own input contract names the test command as an input the caller supplies. The literal contradicted the contract |
| one-addressing-axis | `Three checks, in this order` was followed by bullets, which assert no order. The three are numbered |
| only-derive-what-you-own | three counts sat beside their own lists: `Find four kinds`, `Two hit classes`, `Two costs`. `Record four results` stays, because its four are commands to run rather than a list the reader can see |
| show-dont-describe | `Table the result: hash, subject, type, ...` described a table. The header row is now the table. `## Report and retain` described the report and opened with a sentence that had no verb, so it is now a report skeleton of five items |
| single-train-of-thought | `## Mandate` opened on `A clean shape is not the goal`, a second argument running beside the invariants before the reader met them. The invariants now lead |
| write-for-the-reader | one sentence narrated this repository's history, `That defect has been live in this repository once`. The rule it supported stands without it, and the detector's own header carries the note to the person editing the detector |

`## Failure modes` was defended at first and then cut. Eleven of its twelve rows restated a rule their own section states, and the index argument fails for this runbook: it is read top to bottom in one sitting, so a reader who meets a failure is already in the section that produced it. Three responses appeared nowhere else, and each moved into its section. The runbook is 2391 words, 312 fewer than the pass left it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every principle is applied and recorded | the findings table above carries fourteen rows, eight with a defect and six with none | Agent [x] |
| The detector ships beside the runbook and is validated | `bash tests/test_history_cleanup_detector.sh` prints `4 passed, 0 failed` | Agent [x] |
| The detector reports all four kinds it claims | the fixture asserts an in-place rewrite and a whole-file deletion; the floor and the range boundary are asserted as negatives | Agent [x] |
| The skill is delivered where a session reads it | `grep -n "coding-agent/skills" src/build/container-interface.json` shows the payload row for `/opt/workflow/agent/modules/coding-agent/skills/` | Agent [x] |
| No shipped document names the prompt that no longer exists | `grep -rn "history-cleanup" docs/ workflow/ src/` names the skill and the policy row only | Agent [x] |
| Every gate passes | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints `1277 passed, 0 failed` | Agent [x] |

## Decisions

The skill is operator-invoked, `disable-model-invocation: true`, following `eval`. The runbook rewrites history, and a model that reaches for it while tidying a branch is the failure the runbook's own safety section exists to stop.

The argument slot is gone with the prompt. A prompt declares `argument-hint` and injects `$@`; a skill has neither, so the operator's message carries the branch, base, record path, gate command and test command, and the input contract states that. The skill stops being a slash command, which the operator accepted when scoping the unit.

A table of failure responses is not an index when the document is read once. The section that produces the condition is where the reader stands, so a response belongs beside that step.

A bundled detector is tested, not trusted. The runbook's own finding is why: a detector that reports a clean range and one that cannot match a line print the same report. The caller's control over their own range stays a step, because the shipped test proves the detector rather than the caller's range.

The `## Check every path the range writes twice` split does not invent a section. It moves an existing subject out from under a section whose title named a different one, and it supplies the completion criterion that subject lacked.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A file deleted whole never registered under its own path, so the detector's first kind, a file added in one commit and deleted in a later one, was reported as clean | defect | the detector keyed files from `+++ b/<path>`, which is `/dev/null` for a deletion. It keys from the `diff --git` line now, and the fixture test fails against the old code | fixed in this unit |
| `## Failure modes` restated rules its sections already state | defect | eleven of twelve rows were copies. The table is gone and its three unique responses moved into their sections, so the copy that could have diverged is gone with it | fixed in this unit |
| Two units landed as one commit, because the second unit moved the file the first edited | process | handover `20261021-17` was built and unreleased when this unit took its subject file into a new path. The two rows close together, and the message names both outcomes | recorded here |
| The pass found what a generic cut cannot: six of the eight defects are word-level judgements about this document's own terms | result | the prose cut phase measured lines across the corpus. A principle applied to one document finds the term, the actor and the mechanism, which a corpus-wide cut leaves alone | no new row; this is the instrument working as scoped |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/history-cleanup.md` | moved to the skill, and its cut text is the skill body |
| [`workflow/coding-agent/skills/history-cleanup/SKILL.md`](../../workflow/coding-agent/skills/history-cleanup/SKILL.md) | the runbook as a module skill, cut by the fourteen principles, with the detector's path, the range's exclusion of its base, and no argument slot |
| [`.../scripts/inversions.mjs`](../../workflow/coding-agent/skills/history-cleanup/scripts/inversions.mjs) | moved from `.agents/drafts/history-cleanup/`, and keyed from the `diff --git` line so a deletion registers |
| [`tests/test_history_cleanup_detector.sh`](../../tests/test_history_cleanup_detector.sh) | four cases: an in-place inversion, a whole-file deletion, the eight-character floor, and the range boundary |
| [`docs/policies/git_policy.md`](../../docs/policies/git_policy.md) | the runbook table names the skill and states why the third operation is one |
| [`devlog/roadmap.md`](../roadmap.md) | the row filed and closed |
