---
date: 2026-11-06
milestone: M3.5.3 - The unified record layer
type: Implementation
status: Closed
---

# Handover - The concurrency proof

## Objective

Prove, with one rerunnable test, that two sessions can advance two sub-milestones concurrently on the current record layer for a fixed round count, with no lost update and no record conflict.

## Scope

The concurrency-proof row of M3.5.3. The proof exercises the confirmed record protocol: each session writes only its own track's handover, and the shared roadmap is written once by the merge role. It does not change the `active-milestone` scalar; that is the parallel-milestone rule's, the next row.

Out of scope, with reasons: the parallel-milestone rule, which changes the scalar to a set; the task-list mechanism (M3.5.2), which the proof does not need; any change to `worklog.sh` or the record layout.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `tests/test_parallel_records.sh` runs two concurrent writer sessions for a fixed round count and completes every round | `bash tests/test_parallel_records.sh` prints `rounds=3` and exits 0 | Agent [x] |
| Every round's write from both sessions survives the merge: no lost update | the test's marker assertions over the merged fixture | Agent [x] |
| The two session branches merge with no conflict and both sub-milestone updates reach the roadmap: no record conflict | the test's merge exit codes and roadmap assertions | Agent [x] |
| The negative control shows two writers on one roadmap row conflict, so the proof can fail | the test's second case asserts a non-zero merge | Agent [x] |
| The suite discovers and runs the new test with 0 failed | `bash scripts/run_tests.sh` | Agent [x] |
| The concurrency-proof row closes with its landing note | `grep -n "concurrency proof" devlog/roadmap.md` | Agent [x] |
| M3.5.3 reads `In progress` and the frontmatter names it | `sed -n '1,3p' devlog/roadmap.md` and the M3.5.3 summary row | Agent [x] |
| Every decision this iteration recorded is realized in the files | the Decisions table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The proof runs real concurrent writers for three rounds against a fixture git repository | the run directive requires real writers, not a simulation, and a fixed round count | this record and the test |
| Each session writes only its own track's handover; the merge role writes the shared roadmap | the confirmed single-writer invariant for the shared part, and the reproduced record conflict | `20261105-design-concluded-handover_tracks.md` and this record |
| A negative control asserts two writers on one roadmap row do conflict | the proof must be able to fail | the test |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | M3.5.3 promoted to `In progress`; the concurrency-proof row closed with its landing note |
| `tests/test_parallel_records.sh` | the proof: two concurrent writers, three rounds, the merge and the negative control |
| `devlog/handovers/M3.5.3/20261106-04-impl-concurrency_proof.md` | this record |

Roadmap-maintenance run over `devlog/roadmap.md`: 0 findings.
