# Agent Handover

**Session date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Session type:** Implementation (commit type: refactor)
**Status:** Closed

**Scope confirmed by operator (Gate 1 released):** array emission for sig-sources
(SC2046), `container_sig` fail-closed path validation (roll-in), `preflight`
`sandbox_dir` drop (SC2034), rule 1.4 doc rule, behavior-lock tests. SC1091 out of
scope per operator. `container_sig` guard confirmed as fail-closed-with-
diagnostic (not `|| true`).

## Objective
Remove the remaining `string-as-list` shellcheck findings in `scripts/build.sh`:
the `_sandbox_sig_sources`/`_agent_sig_sources` path lists are returned as
space-joined strings and expanded unquoted via `$(_sig_sources)` into
`container_sig`'s varargs (four SC2046 sites), relying on word-splitting.
Convert to real bash arrays so the word-splitting disappears and the list
intent is structural, and resolve the dead `sandbox_dir` parameter (SC2034).
Behavior unchanged. This is the direct continuation of the `20260810-12`
string-as-list refactor, which handled stop.sh + `build_image $no_cache` but
did not touch the sig-sources calls. Also rolls in (operator-confirmed, same
file) the roadmap `container_sig` defensive-guard task: `find` on a missing
source path returns non-zero through `pipefail` and would silently `set -e`
abort the whole script — currently dormant because all paths are valid.

## Scope (to be confirmed)
**Fix:**
1. `scripts/build.sh` — `_sandbox_sig_sources`/`_agent_sig_sources` return the
   source list as a real array (e.g. `mapfile`-consumed newline output, or
   building/printing a bash array); `container_sig` called as
   `container_sig "$repo_root" "${sources[@]}"`. Same class of fix as
   `20260810-12`, but for the `$(cmd)` varargs form (SC2046) rather than the
   scalar `$VAR` form (SC2086). Removes the four SC2046 warnings.
2. `scripts/build.sh` — `preflight`'s dead `sandbox_dir` param: determine from
   the callers whether the arity matters; if dead, drop it from the signature
   (with the paired negative check) or `readonly`-mark/use it. Resolves SC2034.
3. `scripts/build.sh` — `container_sig` **fail-closed source validation**
   (roll-in): after building `find_args`, assert each source path exists
   (`[[ -e ]]`); on the first missing path print a descriptive
   `container_sig: ERROR: source path not found: <path>` to stderr and fail
   explicitly (via the `|| _rc=$?` capture idiom) — not a silent abort, not a
   silent empty-hash pass. A naive `|| true` was rejected (would swallow the
   error and hash an empty set). Resolves the roadmap `container_sig` guard
   task (line 155).
4. `docs/development/bash-coding-conventions.md` — add the missing rule 1.4 rule:
   string-as-list / word-splitting a `$(cmd)` is an anti-pattern even when "it
   works today"; return and expand as a real array. Closes the convention gap
   that let this instance slip past `20260810-12`.

**Tests:**
5. `tests/test_trace_build.sh` (or new `container_sig` test) — prove the
   computed sig is byte-identical before/after the refactor (behavior lock),
   and that `container_sig` on a missing path fails with a diagnostic + non-zero
   (not silent). Shellcheck must report 0 SC2046 in `build.sh`.

SC1091 (sourced info files) is explicitly out of scope — benign info-level,
left as-is per operator instruction.

## Carried forward
| Item | From handover |
|---|---|
| Shellcheck findings cleanup in `build.sh` — SC2046 sig-sources + SC2034 `sandbox_dir` (roadmap task) | `20260812-03-fix-refresh_silent_build_failure.md` (escalated, finding #7) |

## Acceptance criteria
| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `shellcheck scripts/build.sh` reports 0 SC2046 + 0 SC2034 (SC1091 info-lines remain — expected, out of scope) | `shellcheck scripts/build.sh` | Agent |
| 2 | array refactor behavior-preserving: `container_sig` source-lists byte-identical to pre-refactor (exact ordered membership + element counts) | `test_container_sig_sources_list` | Agent |
| 3 | `container_sig` plumbing end-to-end: returns a 64-hex hash over real sources | `test_container_sig_hashes_real_sources` | Agent |
| 4 | `container_sig` on a missing source path fails loudly: diagnostic + non-zero, no empty-hash pass, no silent abort | `test_container_sig_missing_path_fails_with_diagnostic` + manual `set -e` repro | Agent |
| 5 | `preflight` signature 3 params (no `sandbox_dir`); only caller passes 3; negative grep for 4-arg/`$SANDBOX_DIR` call is clean | grep | Agent |
| 6 | `bash-coding-conventions.md` rule 1.4 documents the string-as-list / unquoted-`$(cmd)` anti-pattern and array fix | read rule 1.4 | Agent |
| 7 | full test suite green | `scripts/run_tests.sh` | Agent |
| 8 | conventions/conventions docs in scope describe the system as built (no stale comment in changed functions) | agent review | Agent |

## Hot files
| File | Why in scope |
|---|---|
| [`scripts/build.sh`](scripts/build.sh) | `_sandbox_sig_sources`/`_agent_sig_sources`/`container_sig` calls (SC2046); `container_sig` fail-closed path validation (roll-in); `preflight` `sandbox_dir` (SC2034) |
| [`tests/test_trace_build.sh`](tests/test_trace_build.sh) | behavior-lock test for the sig computation |
| [`docs/development/bash-coding-conventions.md`](docs/development/bash-coding-conventions.md) | add rule 1.4 string-as-list / array rule |

## Decisions made this session
None.

## Mid-session findings
| Finding | Type | Impact |
|---|---|---|
| `read -ra X <<< "$(multiline_cmd)"` reads only the first line of a herestring (the rest of the emitted lines are discarded), silently producing a 1-element array. The initial container_sig tests used this and captured only `src/libs`, giving a wrong hash. Fixed with `mapfile -t X < <(cmd)` (process substitution) — consistent with the `20260810-12` P1 lesson on mapfile. | bug (test-authoring trap) | current unit |
| `container_sig` fail-closed guard confirmed necessary: `find` on a missing path returns non-zero through `pipefail`, and without the guard the whole `set -euo pipefail` script aborts silently. Reproduced deterministically before the fix. | bug | current unit |

## Completed this session
| # | Item | Notes |
|---|---|---|
| 1 | `scripts/build.sh` — `_sandbox_sig_sources`/`_agent_sig_sources` → per-line `printf` array emission | 4 call sites consume via `mapfile -t ... < <(...)` + `"${sources[@]+${sources[@]}}"`; removes all 4 SC2046 |
| 2 | `scripts/build.sh` — `container_sig` fail-closed path validation | asserts each source path exists; on miss `container_sig: ERROR: source path not found: <path>` + `return 1` (not silent abort, not empty-hash pass) |
| 3 | `scripts/build.sh` — `preflight` dropped dead `sandbox_dir` param (SC2034) | signature now `<provider> <project> <repo_root>`; single caller `start_agent.sh` updated; negative grep clean |
| 4 | `docs/development/bash-coding-conventions.md` — rule 1.4 rule | string-as-list / unquoted-`$(cmd)` (SC2046) anti-pattern; array emit + `mapfile` + `"${arr[@]}"`; `read -ra <<<` reads only first line |
| 5 | `tests/test_trace_build.sh` — 3 new behavior tests | list-construction lock (element-count catches SC2046 regression), end-to-end 64-hex plumbing check, missing-path loud-fail check |
| 6 | Fresh-subagent thermo-nuclear review findings triaged | reworked hash tests → list-lock (spurious-fail + blind-to-word-split); hardened missing-path test for `set -e` forward-compat; fixed stale `container_sig` doc comment |

## Deferred items
None.

## Next session
M2.6 general CLI/infra track — remaining open items: `.compose/*.yml` pruning, `compose_sandbox_wait` teardown gap, session-naming collision, STALE=1 prune, test harness `set -e` (roadmap). Post-close bookkeeping run (roadmap checkboxes updated for the two resolved tasks).
