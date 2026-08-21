# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Impl
**Status:** Closed

## Objective
Implement the **`make resume` command** first, per operator steering (`2026-08-21`: "next session, just focus on implementing resume first") and the **reduced scope** (operator, this session): a standalone `resume_agent.sh` (ID 01) covering only the `--session-id=<id>` direct resume path and a primitive `resume --list` (reads `.compose/` filenames), plus proper command-shape tests (ID 02). `PROVIDER=` filtering and `--interactive` are deferred to after a shared picker/parser (ID 03). Once resume is confirmed clean, the `start`-side `--resume`/`_auto_resume_or_new` strip (D6/D10) happens (ID 04). The `start` config wizard (D11) is a later impl. Design settled in `20260821-02` (D1–D11).

## Deferred (not this iteration)
`make start` new-only (D6/D10) and its `--interactive` config wizard (D11) — **removed from this iteration's concern**; per operator the `start`-side `--resume`/`_auto_resume_or_new` strip happens **after** resume is confirmed clean (ID 04), and the `start` wizard is a later impl. Also deferred: `PROVIDER=` filter + `--interactive` picker logic (ID 03).

## Acceptance criteria
| # | Criterion | Verifiable by | Verified by | Status |
|---|---|---|---|---|
| 1 | `agent-sandbox resume --session-id=<id>` resumes the session identified by that id (reads identity from the `.compose/<session-id>.yml` registry record + volume labels; runs preflight; execs `run_agent.sh` **without** `--reset-volume` / snapshot / new-identity) | `resume_agent.sh` trace test with docker stub; registry fixture | Agent | ✅ implemented (ID 06 identity recovery; exec without reset-volume); full resume path not docker-trace-tested yet (deferred to confirm-clean step) |
| 2 | `resume --list` renders the `.compose/` session filenames (primitive, no field parsing) | trace test | Agent | ✅ test_list_renders_filenames |
| 3 | `resume` called with NO `--session-id`/`--list`/filter prints help hinting `--list` and `--interactive` (D13/D10) and exits non-zero; malformed flags → help (D2); `--interactive` and `--provider` are routed but return a `not yet implemented` error (ID 05) | trace test | Agent | ✅ 4 shape tests |
| 4 | `resume` subcommand route added to `agent-sandbox.sh` and `Makefile.template` (`resume:` target); `stop` prints `make resume SESSION_ID=<id>` on teardown (finding-1/L152) | route trace test + grep | Agent | ✅ route verified; stop print added |
| 5 | Suite green after changes | `scripts/run_tests.sh` | Agent | ✅ 465/465 (30 files) |

## Findings
| Finding | Type | Impact |
|---|---|---|
| Review: `resume_agent.sh` duplicated the host-side prelude from `start_agent.sh` and bypassed the canonical `dirs_resolve`; also lacked `set -euo pipefail`; and `preflight` rebuilt on missing images (wrong for resume) | code-quality (thermo-nuclear review) | **resolved this iteration** — extracted shared `src/libs/session_env.sh` (uses `dirs_resolve`; both entrypoints source it), added `set -euo pipefail`, and `preflight` gained a no-build `build_missing=false` mode that resume uses. Suite 465/465. |

## Decisions
*Design decisions D1–D11 settled in `20260821-02`. Implementation-level decisions:

**ID 01 — standalone `resume_agent.sh`.** Resume gets its own `scripts/resume_agent.sh` (accepted design decision, operator). `start_agent.sh` is being decomposed (D10); a focused standalone resume script ownership-matches the split rather than reusing/extending `start_agent.sh`.

**ID 02 — reduced scope: `--session-id` only + primitive `--list` + command-shape tests.** This iteration implements the **`--session-id=<id>`** direct resume path and a **primitive `resume --list`** that reads the `.compose/` directory filenames (no field parsing yet), plus proper command-shape tests.

**ID 03 — `PROVIDER=` filter deferred to after `--interactive`.** Filter parsing of the registry record comes after the `--interactive` picker, because the picker will also need a parser and the two should share it. Not built this iteration.

**ID 04 — after resume is confirmed clean, strip resume out of `start`.** The `start`-side `--resume` flag / `_auto_resume_or_new` / volume-discovery-on-start removal (D6/D10) happens only once resume is confirmed clean, then is stripped from `start`. Ordering: split-out resume → confirm clean → strip `start`.

**ID 05 — `resume` routes `--interactive` and `--provider` but errors "not yet implemented".** The `resume` command accepts (`--interactive`, `--provider=<n>`) and returns a clear `not yet implemented` error (exit non-zero), mirroring how `start --interactive` was wired-but-erroring in the prior `fix` iteration. Rationale: the flags' surfaces exist (picker, filter) but their logic (ID 03) is deferred; routing them now keeps the command-shape stable so `start` can reference the same flags, and prevents silent-drop. `--session-id` remains the implemented path.

**ID 06 — `--session-id` resume recovers the provider from the registry record (not the `PROVIDER=` filter).** To actually execute a resume, `resume_agent.sh` must pass `--provider` to `run_agent.sh` and run `preflight`. The provider is recovered from the `.compose/<session-id>.yml` record's agent service image (`<provider>-agent-<project>`, embedded by `compose_generate`), and `SESSION_TS`/`HOST_HEAD_SHA` from the record's session labels. This is identity recovery required to resume, **distinct** from the deferred ID 03 `PROVIDER=` filtering UX.

**ID 07 — `resume_agent.sh` dispatch order.** (1) `--list` → list `.compose/*.yml` filenames, exit 0; (2) `--interactive` or `--provider` (without `--session-id`) → `not yet implemented` error, exit non-zero (ID 05); (3) `--session-id=<id>` → resume path; (4) bare (no target flags) → help hinting `--list`/`--interactive`, exit non-zero (D13); (5) malformed/unknown flag → help + exit non-zero (D2).

## Completed
| File | Change |
|---|---|
| `devlog/handovers/20260821-03-impl-resume_command.md` | Created this impl handover (resume-first F2 implementation); recorded ID 01–07 and the reduced scope |
| `scripts/resume_agent.sh` | NEW — standalone resume entrypoint: `.compose/*.yml` registry inventory, `--list` (primitive, filenames), `--session-id=<id>` direct resume (provider recovered from record; exec `run_agent.sh` without reset-volume; **preflight with build_missing=false** — resume never rebuilds), `--interactive`/`--provider` routed-but-not-implemented, bare→help, unknown→help. `set -euo pipefail`; uses shared `session_env` prelude (review point) |
| `src/libs/session_env.sh` | NEW — shared host-side session env bootstrap (`session_env_common_init` + `session_env_names`), sourced by both `start_agent.sh` and `resume_agent.sh`; uses canonical `dirs_resolve` for path derivation (review point #1 — eliminates the duplicated host-prelude) |
| `scripts/start_agent.sh` | Refactored to source shared `session_env` prelude (phase 1 early, phase 2 after identity); removed inline `.env`/path/image/git/name derivation duplicates (review point #1); keeps `source build.sh` for rebuild/preflight |
| `scripts/build.sh` | `preflight` gains `build_missing` param (default true, backward-compatible); resume passes false → error instead of build on missing images (review point #3) |
| `scripts/agent-sandbox.sh` | Route `resume` subcommand (require_base_args → resume_agent.sh); `--help` routing; updated usage/subcommand-list strings |
| `scripts/templates/Makefile.template` | NEW `resume:` target (SESSION_ID/LIST/INTERACTIVE/PROVIDER flags); resume flag vars; help target lines |
| `scripts/stop.sh` | Print `make resume SESSION_ID=<id>` on teardown when SESSION_ID known (finding-1/L152) |
| `tests/test_resume.sh` | NEW — 6 command-shape tests: `--list` filenames, bare→help, unknown→help, `--interactive`/`--provider` not-implemented, missing-record error |

## What's Next
- Resume `--session-id` + `--list` + routing + stop-print implemented this iteration; review-driven refactor (shared `session_env` prelude, `set -e`, no-build preflight) applied (suite 465/465).
- After resume is confirmed clean: strip `--resume`/`_auto_resume_or_new` from `start` (ID 04).
- Later: `PROVIDER=` filter + `--interactive` picker (shared parser, ID 03); `make start` new-only config wizard (D11).