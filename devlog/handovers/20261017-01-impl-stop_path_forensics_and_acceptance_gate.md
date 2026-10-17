---
date: 2026-10-17
milestone: T - Harness Development Tracks
type: Implementation
status: Closed
---

# Handover - the stop path's forensics and its acceptance gate

## Objective

Turn `make stop`'s silent 11-second hang into a measured diagnosis with a rerunnable gate, and identify the smallest fix the evidence supports.

## Scope

The M3 lifecycle path that `make stop` drives: `scripts/stop.sh`, the reasoning container's PID 1 shape, and the unbounded `docker stop` calls in the same class. Filed under T2 on the measured ground that the defect is stop duration, so the roadmap row records the defect and the fix; the fix itself is not in this iteration because the deciding measurement needs a host with a docker socket.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The probe reports a stop that burns the grace as a failure, not as a stopped container | `bash tests/test_stop_probe.sh`, the SIGKILL case | Agent [x] |
| One command judges a real probe run against a two-second ceiling and the daemon's exit codes | `bash tests/test_stop_acceptance.sh`, six cases | Agent [x] |
| Every new script is shellcheck-clean and the suite is green | `make lint`, `make test` (1205 of 1205, 86 files) | Agent [x] |
| The three PID 1 shapes are distinguished on the real image | `bash scripts/stop_signal_matrix.sh` on a host with docker | Operator |
| A real stop returns in under two seconds with no 137 | `bash scripts/stop_acceptance.sh --report=<probe report>` on the operator's host | Operator |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Ship the instrument before the fix | The candidate fix rests on a premise no test in this container can settle, and the deciding data is one host run away. A patch now would be a guess with a green suite behind it. | this record, Findings row 1 |
| The probe reads `{{json .}}`, not three event fields | `timeNano` separates a signal from its die inside one second, and the die event carries the container exit code, which is the only field that tells a graceful end from SIGKILL | `scripts/stop_probe.sh` `check_events` |
| The acceptance is a script with a ceiling | A duration claim is checkable, and the operator can rerun it after the fix; a prose verdict is not | `scripts/stop_acceptance.sh` |
| Do not change `src/reasoning/entrypoint.sh` or `src/build/docker-compose.yml` in this iteration | The matrix chooses between `init: true` with `exec`, and a grace setting; writing one without the matrix is the premise the investigation already falsified once | this record, Decisions pending row 1 |
| File under T2 rather than T1 | The measured symptom is stop duration; T1 holds instruction surfaces and T2 holds runtime cost | `devlog/roadmap.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Which PID 1 shape ends the container inside the grace? | The fix in `src/build/docker-compose.yml` and `src/reasoning/entrypoint.sh` | `init: true` with `exec` at `:242`; a grace setting that accepts the kill; upstream pi gaining a TERM handler |
| Should a deliberate stop report 0 from standard mode, as serve mode already does? | Whether `make start` stops printing `Error 137` for a normal stop | keep the pass-through and let the fix remove the 137; branch on the stop state in `scripts/run_agent.sh:470` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The premise "exec the agent and SIGTERM will land" is false as stated: the installed agent registers `process.on("SIGINT", ignoreSigint)` and no TERM handler, so a PID-namespace init that inherits default disposition still ignores it | measurement, installed bundle | The `exec "$@"` fix alone is rejected; the matrix tests three shapes instead of one |
| `make stop`'s 11.0s is one `docker stop` call of 10.783s, rc=0, followed by `rm` and `network rm` at rc=1 in a tolerated teardown race | measurement, operator host session `c73a3b` | The wait is docker's grace, spent per container, not a slow export and not a wedged daemon |
| A capability-only session ends in 0.52s with exit 0 and no SIGKILL | measurement, two earlier sessions | Rules out the export path as the cause of the grace burn |
| `scripts/stop.sh:103` and `:124` print "Containers stopped and removed." and "Networks removed." after a tolerated non-zero removal | code reading | The teardown reports an outcome it did not confirm; the tolerance stays, the sentence must not claim success |
| Seven calls in `scripts/stop.sh` block with no bound; `scripts/prune.sh:364` and the `compose down` in `scripts/run_agent.sh:364` share the class | code reading | The class is one bounded stop helper, not seven edits |
| No production branch reads 137 or 143; the code reaches the operator as a pass-through only, and serve mode already discards it | code reading, census | Fixing the number changes the banner and nothing else; the real asymmetry is that serve mode calls a stop normal and standard mode calls it an error |
| Two of four dispatched workers returned rc=124 with an empty log, and one had left untracked files in the tree | measurement, this session | Recorded as an agent-feedback entry; the work was redone in the main thread |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/stop_probe.sh` | New host-side forensics probe; records the full event JSON with exit codes and makes a post-grace SIGKILL a `FAIL` |
| `scripts/stop_signal_matrix.sh` | New three-variant PID 1 matrix, with a stated model per row and a dry run for review without docker |
| `scripts/stop_acceptance.sh` | New acceptance check over one probe run; ceiling, exit codes, residue |
| `tests/test_stop_probe.sh` | New, 13 cases: report shape, read-only safety, session scoping, the SIGKILL failure and the graceful pass |
| `tests/test_stop_acceptance.sh` | New, six cases over fixture artifacts |
| `tests/stubs/docker` | Adds the `events` command and the stop-block and inspect-line knobs |
| `.markdownlint-cli2.mjs` | Ignores `.scratchpad`, the session scratch, so scratch files cannot fail the blocking markdown gate |
| `devlog/roadmap.md` | Records the defect, the shipped instruments and the open fix under T2 |
| `devlog/AGENT_FEEDBACK.md` | Records the timed-out dispatch that leaves a half-applied tree |
