# Agent Handover

**Session date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Session type:** Implementation (commit type: refactor)
**Status:** Closed

## Objective
Refactor the string-as-list pattern out of `stop.sh` and `build.sh`: container
and network IDs are held in plain newline strings and expanded unquoted with
`# shellcheck disable=SC2086` at each consumer. Convert to real bash arrays
(`mapfile` + `"${arr[@]}"`) so the disables disappear, empty-checks become
`[[ ${#arr[@]} -eq 0 ]]`, and the list intent is structural. Behavior must be
unchanged.

Carried from session `20260810-10` finding 4 (stop.sh) and session
`20260810-11` finding 1 (`$no_cache` in build.sh, roadmap-tracked to land
together).

## Root cause (established)
`docker ps -aq` / `docker network ls -q` emit one ID per line. stop.sh captures
them into a single string and relies on word-splitting (`$CONTAINER_IDS`,
`$NETWORK_IDS`) to expand back into multiple docker args — three SC2086
disables. build.sh does the same for the optional cache flag (`$no_cache`
unquoted, two sites). The string-as-list pattern works only because docker IDs
and `--no-cache` contain no whitespace; it is fragile and shellcheck-flagged.

## Scope (to be confirmed)
**Fix:**
1. `scripts/stop.sh` — `CONTAINER_IDS` and `NETWORK_IDS` → arrays via
   `mapfile -t ... < <(docker ...)`; consumers use `"${arr[@]}"`; empty-checks
   use `${#arr[@]}`; delete the three `shellcheck disable=SC2086` comments.
2. `scripts/build.sh` — `build_image`: replace the `$no_cache` unquoted
   expansion (2 sites) with a `cache_args` array built from the param
   (`[[ -n "$no_cache" ]] && cache_args+=(--no-cache)`), used as
   `"${cache_args[@]}"`. Interface unchanged (callers keep passing `""` or
   `--no-cache`).

**Tests:**
3. Verify `tests/test_trace_stop.sh` and `tests/test_trace_build.sh` still
   pass unchanged (behavior-preserving). Shellcheck must report zero SC2086 in
   both files.

## Mid-session findings (to record)
| # | Finding | Disposition |
|---|---|---|
| 1 | `test_stop_uses_docker_ps` was latently stale: asserted "no docker rm" while stop.sh does `docker rm` when containers exist. It passed only because the stub's `ps -aq` returned nothing. | fixed in this session (test-enablement, operator-rolled-in): stub now emits container/network IDs via `DOCKER_STUB_PS_IDS`/`DOCKER_STUB_NETWORK_IDS`; stale test replaced by three behavior tests, each verified to fail on regression |
| 2 | `git restore` during negative-test verification wiped the session's uncommitted stop.sh refactor (reverts to HEAD). Mutation was re-applied; verified green. | recorded in `devlog/AGENT_FEEDBACK.md` (session 20260810-12): revert scratch mutations from a temp copy, never git, while uncommitted work exists |
| 3 | **Thermo-nuclear review P1**: `mapfile -t X < <(cmd)` swallows the command's exit status under `set -euo pipefail` — the array refactor silently changed stop.sh from aborting on docker failure to continuing as if no containers exist. | fixed: command substitution + mapfile + empty-element guard; lock-in test `test_stop_docker_failure_aborts` (verified: buggy form rc=0/Fail, fixed form rc=1/Pass). Note: the reviewer's own proposed remedy (pipeline `cmd \| mapfile`) was wrong — lastpipe off means mapfile runs in a subshell and the array is lost entirely |
| 4 | **Thermo-nuclear review P2**: stub-ID env vars leak between tests (run_test runs in same shell) — `test_stop_removes_containers`'s `DOCKER_STUB_PS_IDS` contaminated `test_stop_removes_networks`; order-dependent. | fixed: `unset` all three stub vars in `setup_stop_fixture`. The leak was empirically confirmed — `DOCKER_STUB_FAIL_PS` leaked into `test_stop_prune_has_system_prune` and broke it until the unset was added |
| 5 | **Thermo-nuclear review P3**: the stub's own `printf '%s\n' $DOCKER_STUB_PS_IDS` reintroduced the exact SC2086 class this session removes. | fixed: `read -ra` + `"${_ids[@]}"`; shellcheck now reports 0 SC2086 in stub. Stale stub header comment corrected |
| 6 | **Thermo-nuclear review P4**: new `"${cache_args[@]}"` didn't match the file's defensive `${arr[@]+${arr[@]}}` idiom (bash < 4.4 errors on empty-array expansion under `set -u`). | fixed: both docker build sites now use `"${cache_args[@]+${cache_args[@]}}"` |
| 7 | **Thermo-nuclear review P5**: no test asserted exit codes, so P1 was invisible to the suite. | fixed: `DOCKER_STUB_FAIL_PS` stub mode + `test_stop_docker_failure_aborts` |
| 8 | Session friction recorded (operator-confirmed): subagent review remedies need empirical verification; negative-test mutations need syntax + intended-failure checks; python3 absent from container | recorded in `devlog/AGENT_FEEDBACK.md` session 20260810-12 (3 new entries) |

## Decisions
| # | Decision | Rationale |
|---|---|---|
| 1 | `mapfile` fed by command substitution (`ids_out="$(...)"` + `<<<`), not `mapfile < <(cmd)` and not pipeline | Only form that both populates the array in the parent shell AND propagates docker failure under `set -e` |
| 2 | `build_image` builds `cache_args` array from the `no_cache` param | Interface unchanged (callers still pass `""` or `--no-cache`); removes the two unquoted `$no_cache` sites |
| 3 | Stub ID emission gated behind env vars; `network` case only emits for `ls`; `DOCKER_STUB_FAIL_PS` for failure simulation | Zero impact on existing trace tests; `rm` must not echo IDs back; enables exit-code lock-in |
| 4 | Review fixes accepted as part of this session (reviewer's P1 remedy rejected — see finding 3) | P1's real fix preserves both array population and `set -e` failure semantics |

## Completed this session
| # | Item | Notes |
|---|---|---|
| 1 | `scripts/stop.sh` — `CONTAINER_IDS`/`NETWORK_IDS` → arrays (`mapfile`), `"${arr[@]}"` consumers, `${#arr[@]}` empty-checks | Three `shellcheck disable=SC2086` comments deleted |
| 2 | `scripts/build.sh` — `build_image` builds `cache_args` from `no_cache` param, used as `"${cache_args[@]+${cache_args[@]}}"` | Both docker build sites; interface unchanged |
| 3 | `test/stubs/docker` — `ps` and `network ls` emit IDs from `DOCKER_STUB_PS_IDS`/`DOCKER_STUB_NETWORK_IDS`; `DOCKER_STUB_FAIL_PS` failure mode | Env-var gated; existing trace tests unaffected; SC2086-clean |
| 4 | `tests/test_trace_stop.sh` — stale test replaced by `test_stop_no_containers_does_not_teardown`, `test_stop_removes_containers`, `test_stop_removes_networks`; added `test_stop_docker_failure_aborts`; `unset` stub vars in fixture | Each verified to fail on the corresponding regression; 9 tests |
| 5 | Thermo-nuclear review round (findings 3–7) applied | Fresh-subagent review; all five findings triaged, verified, fixed, lock-in tested |
| 6 | Verification | 462 tests, 456 passed, 0 failed, 6 skipped; shellcheck: 0 SC2086 in stop.sh, build.sh, stub |

## Not in scope
run_agent unified teardown refactor; compose-file persistence; docker-verb
semantics decision; provider default; M2.6 mount work.

## Carried forward
| Item | From |
|---|---|
| (none — this session closes the SC2086 string-as-list finding; remaining M2.6 findings stay on the roadmap) | |

---

## Session open — status
- [ ] Handover created (this file)
- [ ] Scope confirmed by operator
- [ ] stop.sh array refactor
- [ ] build.sh cache_args refactor
- [ ] Tests green + shellcheck clean
- [ ] Handover updated (findings, decisions, completed)
- [ ] Roadmap checkboxes updated
- [ ] Operator released pre-close gate
- [ ] Status → Closed; committed
