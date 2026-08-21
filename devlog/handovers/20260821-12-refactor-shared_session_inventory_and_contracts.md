# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Land the second thermo-nuclear review pass findings (P1–P5) from the fresh-subagent review of the full session branch (`ed1c384..HEAD`). The prior review's F1–F8 were independently re-validated as genuinely fixed; this iteration addresses the five new findings. Behavior-preserving (except P5, which adds a previously-missing test). Operator: "yes" (Gate 2 settled).

## Findings being fixed (all triaged/verified)
- **P1 (defect):** `record_image_stale` lives in `src/libs/container_sig.sh` but calls `record_image` from `session_inventory.sh` without sourcing it — works only because every caller sources both; latent landmine (verified: sourcing container_sig alone → "record_image: command not found" → unknown). Also `resume_agent.sh:92` comment falsely claims the criterion is "shared with build.sh" (build.sh never calls it).
- **P2 (defect):** dispatcher `agent-sandbox resume` forces `require_base_args` (name+project+sandbox), but the leaf only enforces all-three at `resume_agent.sh:211` *after* `--list`/`--interactive` exit — so `resume --list --sandbox=<d>` fails on a spurious `--name`. CLI and leaf disagree; inventory modes need only `--sandbox`.
- **P3 (missed simplification):** record enumeration (glob→sid→provider→filter→ts/branch) duplicated in `prune.sh rule1_selected_records` and `resume_agent.sh build_inventory`; project HEAD SHA derived in both **and** in `session_stale`'s fallback (`session_inventory.sh`). The "canonical session-inventory home" is mid-promise.
- **P4 (low):** resume `--interactive` re-parses the chosen record (`record_provider` + `record_label`×2) for the confirm display, though the data is already in `RESUME_INVENTORY`.
- **P5 (test hygiene):** `tests/test_dispatch.sh:736` `run_test test_build_default_all_asserts_targets` — function **never defined**, `run_test` swallows the 127 → suite "passes" while testing nothing. build.sh's default-target (`--targets`→all) routing is a genuine untested gap.

## Implementation plan
1. **P1 — move `record_image_stale` into `src/libs/session_inventory.sh`** (its record siblings: `record_provider`/`record_label`/`session_stale`); `session_inventory.sh` sources `src/libs/container_sig.sh` for `image_is_stale`/`current_sig` (unidirectional record→sig layering; sig lib stays pure). Callers (prune, resume) already source both — remove the now-redundant note. Fix `resume_agent.sh:92` comment. Update lib headers.
2. **P3 — promote enumeration to the inventory lib:** add `enumerate_records` (prints `sid|provider|ts|branch`, PROVIDER_FILTER-optional) and `project_current_sha [dir]` to `session_inventory.sh`; `session_stale` uses `project_current_sha` in its fallback. Rewrite `resume_agent.sh build_inventory` and `prune.sh rule1_selected_records` to layer their per-record work on `enumerate_records` (drop their inline glob/provider/ts/branch + `git rev-parse`).
3. **P2 — dispatcher:** add a `require_sandbox` helper; `resume)` branch uses it (not `require_base_args`). Leaf keeps full name/project/sandbox enforcement on the actual resume path.
4. **P4 — resume interactive:** read `provider`/`ts`/`branch` for the chosen sid from `RESUME_INVENTORY` instead of re-parsing the record file.
5. **P5 — tests:** remove the dangling `run_test test_build_default_all_asserts_targets` from `test_dispatch.sh`; add `test_build_default_targets_all` to `test_trace_build.sh` (invoke build.sh with no `--targets` → assert `docker build` count == 1 (sandbox) + number of provider base.dockerfiles; deterministic: 3 providers, expect 4).
6. Cross-check: full suite deterministic ×3; shellcheck clean; `make install` re-run (dispatcher touched — `Valid subcommands`/usage heuristic).

## Verification
- Baseline 503/503 at `55b6bb8`. After: expect 503 (P5 replaces one dead no-op with two real tests → net +1 → 504; P1/P2/P3/P4 behavior-preserving).
- Classification/selection behavior unchanged (prune + resume tests re-validate through the moved `record_image_stale` + shared `enumerate_records`).

## Completed (pre-close record)

| Finding | Fix |
|---|---|
| **P1** | `record_image_stale` moved from `src/libs/container_sig.sh` into `src/libs/session_inventory.sh` (its record siblings); session_inventory now sources container_sig.sh. Layering one-directional (record lib → pure sig lib); build.sh still sources container_sig directly (needs `image_is_stale` only). Fixed the false "shared with build.sh" comment in resume_agent.sh; dropped the now-redundant direct `container_sig` source from resume + prune (session_inventory brings it). Verified: sourcing session_inventory alone yields `record_image_stale`. |
| **P2** | New `require_sandbox` helper; dispatcher `resume)` branch uses it instead of `require_base_args`. `agent-sandbox resume --list --sandbox=<d>` now lists without a spurious `--name`/`--project`; missing `--sandbox` gives a clear error. Leaf keeps full name/project/sandbox enforcement on the actual resume path. |
| **P3** | `enumerate_records` (prints `sid|provider|ts|branch`, PROVIDER_FILTER-optional) + `project_current_sha` promoted to session_inventory.sh; `session_stale` fallback uses `project_current_sha`. `build_inventory` and `rule1_selected_records` rewritten to layer on `enumerate_records` + `project_current_sha` (inline glob/parse/filter/HEAD gone). |
| **P4** | Resume `--interactive` confirm reads `provider`/`ts`/`branch` for the chosen sid from in-memory `RESUME_INVENTORY` instead of re-parsing the record file. |
| **P5** | Removed the dangling `run_test test_build_default_all_asserts_targets` (never-defined fn, silently swallowed); added real `test_build_default_targets_all` in test_trace_build (no `--targets` → sandbox + each provider base.dockerfile; stub ` build ` count == 1 + provider count, deterministic 4 for 3 providers). |

**New tests:** `test_build_default_targets_all` (default-target routing — previously a no-op hole). Existing prune/resume/build suites re-validate classification/selection through the moved `record_image_stale` + shared `enumerate_records`.

**Findings (new this iteration):**
- F-B1: the stub logs `build $*` (not `docker build`) — my first default-target assertion grepped the wrong token; matched `" build "` (the existing test's convention).
- F-B2: `project_current_sha`'s speculative `[dir]` param was unused by every caller (YAGNI) and tripped SC2120 — simplified to a no-arg `PROJECT_DIR`-scoped function.
- F-B3: edit tooling — a mis-scoped edit targeted a nonexistent contact comment in test_trace_build (no-op), then an overlapping-payload edit; re-done with disjoint regions.

## What's Next
- Pre-close review (Gate 3): present AC status + full-suite output. Suite **504/504**, deterministic across 3 runs.
- `make install` re-run (dispatcher `scripts/agent-sandbox.sh` changed — resume dispatch contract + new `require_sandbox`).
- Set Status `Closed` and commit after release.

## Deferred / not in scope
- N3 mount-point lock.
- Restoring baked/current hex detail in the preflight warning (deliberate).
