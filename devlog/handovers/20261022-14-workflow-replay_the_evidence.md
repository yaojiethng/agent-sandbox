---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Active
---

# Handover - Make the handover's evidence runnable

## Objective

Give the one claim surface in this repository that no gate reads an observer, and a grammar it can hold: the `Result` column of the handover acceptance-criteria table, where 439 rows across 68 records assert that something holds and nothing ever reran the cell that says what holds.

## Scope

The claim was raised twice in this session. In `Retire documentation_policy` a `grep` for one row's wording passed a different row's prose cell, and in `Retire iteration_policy` a roadmap checkbox was reported closed while the file still read `- [ ]`. Both are one class: a mark whose own cell cannot decide it, so any command that exits 0 satisfies it. The premise under every earlier fix was "verify more carefully", and it failed twice. The premise this unit attacks instead is the cell's form.

Two design alternatives, stated before the build.

| Alternative | Why it was not chosen |
|---|---|
| A rule in the `work-log` skill saying a mark needs a runnable command | No observer, so it is a judgement by the test in `docs/adr/norm_kinds.md`, and the repo already holds 405 marks that break it |
| A date cutover on the acceptance-criteria table, beside the existing `20261001` one | A cutover set to tomorrow binds no record, which is a rule with no member, the defect `Retire iteration_policy` fixed in the taxonomy |

The chosen shape is a classifier plus a replay lever, and a grammar held by the gate that already reads the table.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One classifier, imported by both consumers | `grep -c 'from "./criteria-form.mjs"' scripts/lint/handover-format.mjs` | Agent [x] |
| The classifier reports every criteria row of a handover | `node scripts/lint/criteria-form.mjs --table devlog/handovers/20261022-13-docs-split_the_framing_adr.md` | Agent [x] |
| The replay reports the corpus and changes nothing | `bash scripts/replay_criteria.sh --report` | Agent [x] |
| The replay fails on a contradiction and passes without one | `bash tests/test_replay_criteria.sh` | Agent [x] |
| The gate refuses a prose mark on a live record | `bash tests/test_handover_format_gate.sh` | Agent [x] |
| The gate exempts every closed record | `bash scripts/check_handover_format.sh` | Agent [x] |
| The template states the five marks | `grep -c 'Reviewed' .agents/skills/work-log/assets/handover.md` | Agent [x] |
| Lint and the suite are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Four forms, judged from the backticked spans: `command`, `path`, `mixed`, `prose` | A pile of regexes in two files would drift. One module states the vocabulary, and the gate and the replay call it, so `mixed` means one thing | `scripts/lint/criteria-form.mjs` |
| A `command` cell carries an expectation from a closed set: `exit0` or `empty` | The exit status alone does not state the claim. `grep` exits 1 on no match, which is what "prints nothing" asserts, so the first replay reported four honest cells as contradictions | `scripts/lint/criteria-form.mjs`, `scripts/replay_criteria.sh` |
| The grammar binds `status: Active` records, not a date | 405 existing marks would fail a corpus-wide rule, and a future date binds nothing. An open record is the one that will be re-read and acted on, so the rule reaches live work and its first member is the next handover | `scripts/lint/handover-format.mjs` |
| `Reviewed` is the fifth mark in the template | A prose criterion still gets marked, and the mark has to say which act it records: read, or run. `[x]` stays reserved for run | `.agents/skills/work-log/assets/handover.md` |
| The replay is not a lint gate | Three records hold marks whose commands cannot run today, so a gate would be red on history. It ships as a lever with `--fail-on-failures` for the day the corpus is clean | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Of 439 marked criteria, 409 sit on a `mixed` or `prose` cell, and 233 carry no command at all | defect | the corpus's evidence is mostly a sentence a reader must interpret, which is why a wrong check satisfied a real row | measured by `scripts/replay_criteria.sh`; the grammar covers records written from here, and the records stay as history |
| Three marked rows fail their own command today | defect | `20261020-07:25` reads a ref that no longer exists, `20261022-05:29` greps with no file and reads stdin, `20261022-05:34` greps a file a later slice deleted | reported by the lever, left as the record shows them; a re-run names them again |
| The first replay reported six contradictions, and four were the instrument's fault | defect | a lever that reports honest cells as failures is one a reviewer stops trusting, which is the whole point of shipping it | the classifier gained the `empty` expectation; the count fell from 6 to 3 |
| The 120 second bound is below the suite's own runtime | defect | a cell that runs `bash scripts/run_tests.sh` reports `timeout` or `holds` depending on load, so one verdict is not reproducible | the flag is documented; a replay that trusts that row raises `--timeout` |

## Completed

| File | Change |
|---|---|
| `scripts/lint/criteria-form.mjs` | new: the four forms, the expectation set, the criteria-row reader, a TSV and a JSON printer |
| [`scripts/replay_criteria.sh`](../../scripts/replay_criteria.sh) | new: the lever. One throwaway worktree, a deny list, a per-command timeout, a per-handover block and a corpus total |
| [`scripts/lint/handover-format.mjs`](../../scripts/lint/handover-format.mjs) | an `Agent [x]` row on an Active record must classify as `command` or `path` |
| [`.agents/skills/work-log/assets/handover.md`](../../.agents/skills/work-log/assets/handover.md) | the five marks and what each one records |
| [`tests/test_replay_criteria.sh`](../../tests/test_replay_criteria.sh) | new: seven cases over a fixture repository, including the deny list and the tree-unchanged check |
| [`tests/test_handover_format_gate.sh`](../../tests/test_handover_format_gate.sh) | three cases: a live prose mark fails, a live command mark passes, a closed record is exempt |
