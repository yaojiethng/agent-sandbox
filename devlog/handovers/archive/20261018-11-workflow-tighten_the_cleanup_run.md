---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Tighten the cleanup run

## Objective

Cut what the history-cleanup run costs in the two places where it spent most, and remove the two defects in the run that cost a second pass.

## Scope

Two rewrites ran in this session, one over six commits and one over eight. Between them they spent about 35 minutes in suite runs, and the suite found no defect. It found two load-dependent failures and cost a further full run to clear each.

The measurement behind the change. Six of the eight commits in the second rewrite changed no executable file, only Markdown, skills, prompts and the ledger. The suite ran 88 test files against each of them, while ten lint gates already covered the same files in 7s.

This unit carries four changes to the runbook, and the detector header note that belongs with one of them. It does not change the detector's behaviour, which found the only real defect either rewrite produced.

Ruled out of scope. The per-commit gate stays mandatory and unchanged, because it is the instrument that fails. The positive control before a clean range stays, because it earned its place twice.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The rebuild step checks multi-writer paths before the reset | `## Rebuild with the gate on every commit`, opening paragraph and command | Agent [x] |
| The rule for a multi-writer fix names both writes | the paragraph applying the fix at every write or at none | Agent [x] |
| The per-commit test step names the runner's selector | `scripts/run_tests.sh` takes a file or directory selector | Agent [x] |
| The full suite runs once, at the tip | stated in the step and again after the flake rule | Agent [x] |
| The flake rule re-runs the failing file, not the suite | `## Prove each commit stands` | Agent [x] |
| The failure table carries both new rows | flake re-run, and the multi-writer revert | Agent [x] |
| The detector's length floor is stated beside the marker note | runbook paragraph and the script header | Agent [x] |
| Every gate passes | `bash scripts/lint.sh`, 10 gates | Agent [x] |
| The detector's header states both traps and the detector still runs | `grep` the header; `node .agents/drafts/history-cleanup/inversions.mjs d366378c HEAD` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Target the per-commit suite by changed file | A commit that changes only Markdown cannot break a shell test. The cost went to re-proving behaviour the commit did not touch. | runbook, `Two costs` paragraph |
| Keep the full suite at the tip | A targeted run per commit does not cover behaviour that more than one commit contributes to, and the tip is the tree a reviewer reads. Operator direction. | runbook, `## Prove each commit stands` |
| Put the multi-writer check before the reset rather than in the proof | The revert is created by the rebuild, so a check after it can only report the damage. Before the reset it costs one command. | runbook, `## Rebuild` |
| Record the fix rule as every write or none | The roadmap case failed because the fix was applied at the first write only, and the second write restored the file whole. Half a fix is what the next write reverts. | runbook, failure table |
| Leave the staging rule alone | The runbook already forbids `git add -A`. The deviation was in a rebuild script, not in the text. | this record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether a docs-only range needs the full suite at the tip either | Time on a range the gate already covers | keep it, one run and the tip is what a reviewer reads; skip it when no commit changes an executable file |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Six of eight commits in the range changed no executable file, and each still paid the full suite | process | the measurement that justifies the targeted run; 916s spent, no defect found |
| The suite found no defect across twelve gated commits and two rewrites, and the gate found every real one | process | the suite's per-commit cost buys reassurance in a docs range, not coverage |
| A second rebuild was forced by one line, because two commits write `devlog/roadmap.md` and the later one restored the file whole | process | the pre-check exists because that revert is invisible in the file-set table the earlier step produces |
| The detector skips content lines shorter than eight characters, and its header documented only the marker bug | agent experience | the first positive control reported `none` against a real inversion; both traps are now stated together |
| A rebuild script used `git add -A` inside its loop, which the runbook forbids | agent experience | safe here because the tree was clean at each step, and still the wrong form to model; the script should stage named paths |
| Two rewrites ran in one session, the second because work arrived after the first had closed | process | sequencing every commit before the run would have made it one pass |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/history-cleanup.md` | multi-writer pre-check before the reset with its command; targeted per-commit tests citing the runner's selector; the full suite once at the tip; the flake rule re-running the failing file; two new failure rows; the length-floor paragraph |
| `.agents/drafts/history-cleanup/inversions.mjs` | the header states the eight-character floor beside the marker note |
| `devlog/handovers/archive/20261018-11-workflow-tighten_the_cleanup_run.md` | this record |
