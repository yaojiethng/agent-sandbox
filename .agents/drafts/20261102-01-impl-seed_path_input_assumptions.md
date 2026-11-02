---
date: 2026-11-02
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Implementation
status: Active
---

# Handover - The seed path assumes the shape of its input

## Objective

Make the copy-delivery seed accept every path git can record, and make a seed failure report itself instead of exiting in silence.

## Scope

In scope: the two fix commits on `fix/seeder-start-diagnostics`, their tests, the root-cause trace below, and the T7 row that carries the general repair.

Out of scope: the other guards on the delivery path, which the T7 row audits; the `find -iname` glob-character defect recorded as a finding here and fixed nowhere; and the ASCII-only documentation lint a project may run over its own files, which is a project convention rather than the harness's.

This record is written after the fact, at operator direction. The two commits landed before it existed, and the close gate it would normally pass through did not run.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A committed repository whose tracked path is non-ASCII and nested seeds in full mode with status parity verified. | `bash tests/test_snapshot_host.sh` (`test_case_mismatch_non_ascii_path_is_non_fatal`); end-to-end `SEED_SRC=... SEED_DEST=... SEED_LIB_DIR=src/libs bash src/capability/seed_volume.sh` prints `Seed complete: ... git status parity verified.` | Agent [x] |
| A command that trips `errexit` in the seeder names its line and command. | `bash tests/test_seed_volume.sh` (`test_seeder_names_the_failing_command`). | Agent [x] |
| A seeder that exits non-zero with no output produces a message saying so, the reproduce command, and a log file that survives the volume discard. | `bash tests/test_run_agent.sh` (`test_seeder_failure_without_output_says_so`). | Agent [x] |
| Both new tests fail against the pre-fix sources and pass against the patched ones. | `git stash push -- src/capability/snapshot.sh scripts/run_agent.sh src/capability/seed_volume.sh` then run the three suites; `git stash pop` and re-run. Recorded: 1 failed/23 passed for the snapshot suite, 1 failed/18 for the seeder suite, 1 failed/42 for the run-agent suite, all green after. | Agent [x] |
| T7 carries the row that audits the remaining assumptions on this path. | `rg -n "seed path assumes its input" devlog/roadmap.md`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Enumerate the tree NUL-delimited (`git ls-tree -r -z --name-only`) and read it with `read -r -d ''`, rather than unquoting git's C-quoted output. | The authority for a path is the byte sequence git stores. Unquoting re-implements git's escaping rules, which is the same defect one layer later. | `src/capability/snapshot.sh` |
| The case-collision preflight keeps its stated contract: it returns 0 always and reports a warning, so no internal failure of it can abort a seed. | The check's decision is "warn about a case collision". A missing directory in a probe is not that decision, so it must not take the seed's fate. | `src/capability/snapshot.sh` |
| The seeder reports its own abort through an `ERR` trap, and the start path keeps the seeder's output in a log beside the session compose file. | A `set -e` abort prints nothing by construction, and the start path discards the volume before anything can be re-read. Both halves of the silence had to close. | `src/capability/seed_volume.sh`, `scripts/run_agent.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the `ERR` trap belong in every capability entrypoint (`entrypoint.sh`, the mount-delivery path) or only the seeder? | Nothing now. The seeder is the only site where a silent abort was observed and where no container survives to inspect. | (a) Seeder only, as it stands. (b) One sourced `abort_names_itself` helper in `src/libs/`, called by every entrypoint. |
| Is `.compose/<session-id>.seed.log` kept after a successful start, or written only on failure? | Nothing now. A successful start leaves one small file beside the compose record it already writes. | (a) Keep it: it is the session's only seed record and it costs one file. (b) Write to a temp file and move it beside the compose file on failure only. |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `snapshot_check_case_mismatch` read `git ls-tree --name-only` without `-z`. With `core.quotePath` default, a non-ASCII path arrives C-quoted (`"` plus octal escapes), which is not a filesystem path: the leading quote lands on the first directory component. | Defect | The check's own parse produced a path that does not exist. Every non-ASCII path one directory deep entered this branch. | Fixed in `6b5e1d05`. |
| `dirname` on the quoted path yielded a nonexistent directory, `find` exited 1, `head -1` exited 0, and `pipefail` made the pipeline status 1, so the assignment inherited it and `set -e` aborted the seed. | Mechanism | A probe whose answer was "no case collision" became the operation's execution error. | Fixed in `6b5e1d05`. |
| The probe's stderr was redirected to `/dev/null`, so the one line naming the cause was discarded, and `die` never ran because no guarded call was reached. | Defect | The abort had no message on any stream. | Fixed in `6b5e1d05` and `9dc1f151`. |
| The start path runs the seeder with `docker compose run --rm`, so the container is deleted on exit and `docker logs` cannot reach it; the failure path then runs `down --volumes`, discarding the network and the half-seeded volume. | Mechanism | The only remaining evidence is what the seeder printed, which was nothing. | `9dc1f151` keeps the output in `.compose/<session-id>.seed.log`. |
| The start path printed "Seeder output above names the failure" unconditionally. | Defect | The message asserted evidence that did not exist, and pointed the operator at a dead end. | Fixed in `9dc1f151`. |
| `tests/test_snapshot_host.sh` runs under `set -uo pipefail`, without `-e`, and calls the check inside `$(...) \|\| rc=$?`, so a mid-function failing command neither aborts nor changes the function's status. | Defect | The suite could not observe this class at all: the function returned 0 while the seeder aborted. | The new test runs `bash -c 'set -euo pipefail; ...'` as a child process; a command substitution in the test file inherits the parent's errexit suppression and would have passed against the defect. |
| The first version of the new test passed against the broken source. | Method | The fixture placed the non-ASCII file at the repository root, where `dirname` collapses to `.` and `find` succeeds; the abort needs a directory component. | Fixture nested at `subdir/<name>.md`, a non-ASCII name one directory deep; re-measured against the pre-fix source: FAIL. |
| Operator's reading, recorded as the general defect: the input's shape was assumed from the author's sample (ASCII, no quoting) and encoded as the check's constraint, so the check fails on input that is legal to every party that owns it. The delegation principle is violated in the direction the check reads: the shape of the input is delegated to the authority that produced it (git, the filesystem), and this check re-derived it instead. Closest stated principle: `communication-principle-state-intent-delegate-method` (installed in the agent config home, not in this repository). | Principle | The instance is fixed; the class survives wherever a guard reads formatted output instead of the evidence, and a guard's failure is allowed to decide an operation it does not own. | T7 row "The seed path assumes its input's shape". |
| `find -iname "$(basename "$tree_path")"` treats `*`, `?` and `[` in a tracked filename as glob syntax. | Defect | A file whose name contains a glob character can produce a false case-mismatch report. | Not fixed; flagged. |

## Completed

| File | Change |
|---|---|
| `src/capability/snapshot.sh` | The preflight enumerates NUL-delimited, guards its `find` probe, and keeps its non-fatal contract on both blob lookups. |
| `src/capability/seed_volume.sh` | `set -E` plus an `ERR` trap, so an `errexit` abort prints the line and command that failed. |
| `scripts/run_agent.sh` | Tees the seeder's output to `<session>.seed.log`, reports the log path on failure, and says plainly when the seeder printed nothing, with a reproduce command built from the live compose args. |
| `tests/test_snapshot_host.sh` | `test_case_mismatch_non_ascii_path_is_non_fatal`, the nested non-ASCII fixture and its errexit child shell. |
| `tests/test_seed_volume.sh` | `test_seeder_names_the_failing_command`. |
| `tests/test_run_agent.sh` | `test_seeder_failure_without_output_says_so`. |
| `devlog/roadmap.md` | The T7 row that carries the broad repair. |
| `.agents/drafts/20261102-01-impl-seed_path_input_assumptions.md` | This handover. |
