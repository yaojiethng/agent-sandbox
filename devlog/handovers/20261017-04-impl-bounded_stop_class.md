---
date: 2026-10-17
milestone: T - Harness Development Tracks
type: Implementation
status: Closed
---

# Handover - a stated bound on every stop call

## Objective

Give every stop and teardown call in the lifecycle a stated bound, so no path waits on docker's inherited default in silence.

## Scope

Continues the T2 row on the stop path, after handovers `20261017-01` and `20261017-03`. Covers the four unbounded sites that census found: `scripts/prune.sh`, `session_teardown` and `session_destroy` in `src/build/compose.sh`, and the seeder-failure abort in `scripts/run_agent.sh`. The behaviour of the containers themselves is out of scope, because the init fix already made a stop end in 0.287s.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Rule 2's container stop states a five-second bound | `bash tests/test_prune.sh`, which matches `stop --time 5 c1` | Agent [x] |
| Both compose teardowns carry `--timeout 10` | `bash tests/test_trace_dry_run.sh` distinguishes bare `down` from `down -v` by the full call | Agent [x] |
| The seeder-failure teardown carries the same bound | `bash tests/test_run_agent.sh` asserts the teardown line | Agent [x] |
| No path relies on docker's default grace | `grep -rn "docker stop\|compose .* down"` shows `--time` or `--timeout` on every lifecycle site | Agent [x] |
| The suite and the gates are green | `make test` (1206 of 1206), `make lint` (8 gates) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Five seconds for `prune.sh`, ten for the compose teardowns | Prune exists to remove, so a container that holds the signal should be killed sooner; a teardown must let the capability layer's export finish, and the export is measured at 0.52s | `scripts/prune.sh`, `src/build/compose.sh` |
| The bound is written at the call site | The conventions rule 1.18 forbids holding it in a variable elsewhere, and a reader of the call must see the bound | `docs/development/bash-coding-conventions.md` section 1.18 |
| The seeder keeps `timeout "$seed_timeout"` | It was the one site already bounded, and it is the precedent the other sites now follow | `scripts/run_agent.sh:355` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does a 137 from a kill other than a stop, such as an OOM kill, still read as a stop? | Whether standard mode can tell a deliberate stop from a kill the operator did not ask for | record the stop request and map only when one exists; or keep the number-only mapping and rely on the printed code |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Three tests pinned the unbound call shape and failed on the change: `test_prune.sh` matched `stop c1`, and `test_trace_dry_run.sh` matched a line ending at `compose down` | measurement, suite run | The failures are the tests doing their job. Both now assert the bound, so a site that loses it fails a gate |
| `scripts/prune.sh` is the highest-risk site of the four | code reading | It sweeps containers from older sessions, which are exactly the ones that still hold SIGTERM, and it reports a count with no timing |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/prune.sh` | Rule 2's container stop states `--time 5` |
| `src/build/compose.sh` | `session_teardown` and `session_destroy` pass `--timeout 10` |
| `scripts/run_agent.sh` | The seeder-failure teardown passes `--timeout 10` |
| `tests/test_prune.sh` | Matches the bounded stop call |
| `tests/test_trace_dry_run.sh` | Distinguishes the two teardowns by their full calls |
| `tests/test_run_agent.sh` | Asserts the teardown states its bound |
| `devlog/roadmap.md` | Closes the stop-path row and files the open 137 question |
