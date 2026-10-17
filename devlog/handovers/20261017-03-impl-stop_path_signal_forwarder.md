---
date: 2026-10-17
milestone: T - Harness Development Tracks
type: Implementation
status: Closed
---

# Handover - the stop signal reaches the agent

## Objective

Make a deliberate stop end the agent container inside the grace, and make the stop path report only what it confirmed.

## Scope

Continues the T2 row filed by handover `20261017-01`. The evidence was the operator's host run of the three PID 1 shapes and one real stop. This iteration lands the fix that matrix selected and the reporting corrections it exposed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The container shape that ends inside the grace is the one the compose file adopts | operator matrix run, init-child 0.83s exit 143 against bash-child and exec-child at 10.20s exit 137 | Agent [x] |
| The agent service carries `init: true` after compose generation | `bash tests/test_trace_compose_gen.sh` | Agent [x] |
| The entrypoint replaces itself with the agent, so the agent is the container's main process | `bash tests/test_provider_entrypoint.sh` (exit-code passthrough) | Agent [x] |
| Standard mode reports a signal end and exits 0, and still propagates any other code | `bash tests/test_run_agent.sh`, which fails with the mapping removed | Agent [x] |
| `stop.sh` never claims a removal it did not confirm | `bash tests/test_trace_stop.sh` | Agent [x] |
| `stop.sh` states its stop bound, per the conventions rule 1.18 released in handover `20261017-02` | `bash tests/test_trace_stop.sh` | Agent [x] |
| The suite and the gates are green | `make test` (1206 of 1206), `make lint` (8 gates) | Agent [x] |
| A real stop returns under two seconds with no 137, and `make start` prints no make error | `bash scripts/stop_probe.sh --perform-stop --session-id=<sid>`, then `bash scripts/stop_acceptance.sh --report=<report>` | Operator |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `init: true` on the agent service | The only measured shape that ends inside the grace. bash as PID 1 and the agent as PID 1 both held SIGTERM at default disposition and burned all 10.2 seconds | `src/build/docker-compose.yml` |
| `exec "$@"` in the reasoning entrypoint | The comment already claimed the command replaces the wrapper; the code ran it as a child. exec makes that true and removes an orphan window at stop | `src/reasoning/entrypoint.sh` |
| Standard mode maps 137 and 143 to 0, and prints the code | The census found no production reader of those codes, and `make` turning a deliberate stop into `Error 137` is the visible defect. The printed line keeps the outcome inspectable | `scripts/run_agent.sh` |
| `stop.sh` keeps tolerating a removal race and stops claiming success | Tolerating a failure and reporting it as success are different acts. Exit 0 stays | `scripts/stop.sh` |
| The matrix reports progress on stderr | Its own progress lines were captured into the JSON report by the row's command substitution, so the report was not parseable | `scripts/stop_signal_matrix.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does a 137 from a kill other than a stop (an OOM kill, for example) also read as a stop? | Whether standard mode distinguishes the reason for the signal | keep the mapping and print the code, as now; or record the stop request in the session state and map only when one exists |
| What bounds the same unbounded stop in `scripts/prune.sh:364` and the `compose down` in `scripts/run_agent.sh:364`? | The class-wide half of the T2 row | one bounded stop helper; or a `timeout` wrapper at each site |

## Findings

| Finding | Type | Impact |
|---|---|---|
| bash as PID 1: SigIgn `0000000000000004`, SigCgt `0000000000010002`, stop 10.20s, exit 137. Agent as PID 1: SigIgn `0000000000000000`, SigCgt `0000000000000000`, stop 10.20s, exit 137. tini as PID 1: stop 0.83s, exit 143 | measurement, operator host | `exec` alone does nothing; an init forwarder is the fix |
| One real stop: the slowest `docker stop` 10.238s, die codes 0 and 137 | measurement, operator host session `3f28b4` | Confirms the mechanism on the shipped path: the capability container ends cleanly, the reasoning container is killed |
| The matrix's JSON report was unparseable because its own progress lines were captured into the array | measurement, operator host | Fixed by reporting progress on stderr; a verdict that prints only PASS hides its own evidence |
| `docker network rm` at `scripts/stop.sh:124` also printed success for a non-zero return | code reading | Same honesty defect one step later in the same script |

## Completed

| File | One-line change summary |
|---|---|
| `src/build/docker-compose.yml` | The agent service sets `init: true`, so an init process forwards the stop signal |
| `src/reasoning/entrypoint.sh` | Replaces itself with the agent command; the SIGTERM note now states the measured contract |
| `scripts/run_agent.sh` | Maps a 137 or 143 exit to 0 with one printed line; other codes still propagate |
| `scripts/stop.sh` | States the stop bound (`--time 10`), prints the duration, and reports a removal outcome it confirmed instead of a fixed success sentence |
| `scripts/stop_signal_matrix.sh` | Progress on stderr, a decisive `burn` or `term` model per row, and the model recorded in the report |
| `tests/test_run_agent.sh` | New case: 143 and 137 exit 0 and are reported; fails without the mapping |
| `tests/test_trace_stop.sh` | Asserts a failed removal is reported as deferred, never as removed |
| `tests/test_trace_compose_gen.sh` | Asserts the generated agent service carries `init: true` |
| `tests/test_stop_probe.sh` | Declares a 20-second deadline, because 13 docker-stub cases exceed the 10-second default under parallel load |
| `docs/reference/execution_model.md` | Session exit semantics now state the 137/143 mapping and the init process at PID 1 |
| `devlog/roadmap.md` | The T2 row records what landed and what still waits on the host |
