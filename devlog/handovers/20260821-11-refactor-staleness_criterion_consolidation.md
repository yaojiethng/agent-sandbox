# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Land the thermo-nuclear review findings (F1–F8) from the fresh-subagent review of `8e09e32..HEAD` (iterations `20260821-09`/`20260821-10`). Behavior-preserving cleanup; suite stays green. Operator: "fix all" (Gate 2 settled).

## Findings being fixed (review of 09/10, all verified by triage)
- **F1 (bar):** `record_image_stale` recomputes the identical full-tree `container_sig` per record (pure fn of `type,provider`) → O(2N) tree hashes on `--list`/prune (5 records = 10 docker-inspects + 10 full hashes, measured).
- **F2 (bar):** divergent second parser of the `image:` line (`record_image_stale`'s unanchored grep ≠ canonical `record_provider` regex) + `sandbox-<proj>` naming reconstruction — but the record already carries both image lines (`docker-compose.yml` L64 sandbox, L91 agent; verified).
- **F3 (bar):** "one shared constant" not delivered — `RESUME_LIST_PAGE_SIZE=10` is a second literal; only a comment links it to `INTERACTIVE_MAX_ENTRIES=10`.
- **F4:** counter-stateful `shown`/`remaining` cap loop in `--list`; duplicated no-sessions error block in both top-level branches.
- **F5:** 3 copies of test sig helpers (`sandbox_sig`/`agent_sig`/`fresh_sig_map` in test_prune, test_resume, inline in test_trace_build).
- **F6:** `case "$(image_is_stale ...) " in stale*` — trailing-space hack (fn can't print empty) + weak prefix match; use exact match.
- **F7:** picker renders `[img-ok]` for `unknown` — an uninspectable image displayed as ok (verified: stub-less record shows `[status] [img-ok]`); `--list` honestly says `unknown`.
- **F8:** dead `stale` literal field in prune Rule-1 pipe contract (selection IS staleness); `container_sig.sh` missing trailing newline; tool_interface Rule-1 paragraph still describes selection as host-head-sha-only (default `STALE` now selects sandbox OR image).

## Implementation plan
1. **`src/libs/session_inventory.sh`**: add `record_image FILE SERVICE` — awk service-block parser for a named service's `image:` value (anchored, block-aware). Rewrite `record_provider` as a wrapper: `record_image "$1" agent` + `%%-agent-*` provider strip (deletes the divergent regex).
2. **`src/libs/container_sig.sh`**: add `current_sig <type> <repo_root> [provider]` — memoized per `(type,provider)` (module-level cache in the sourced lib; one source of truth for the current sig). Refactor `image_is_stale` to delegate its recompute to `current_sig` (all callers benefit — `_check_container_sig`, `record_image_stale` — without caller changes). Rewrite `record_image_stale` to read BOTH images from the record via `record_image` (agent + sandbox), keeping only the provider strip (`%%-agent-*`) needed for agent sig sources. Add trailing newline.
3. **Constant (F3)**: single home for the picker cap — `src/libs/common.sh` gains `: "${INTERACTIVE_MAX_ENTRIES:=10}"`; `interactive.sh` uses the var (no local literal); resume replaces `RESUME_LIST_PAGE_SIZE=10` with a derivation from `INTERACTIVE_MAX_ENTRIES` (source common.sh if not already sourced there).
4. **`scripts/resume_agent.sh`**: `--list` cap via slice `${RESUME_INVENTORY[@]:0:$RESUME_LIST_PAGE_SIZE}` + `"${#RESUME_INVENTORY[@]}" - PAGE` footer (deletes `shown`/`remaining`); `_no_sessions` helper for the duplicated error block; picker markers honest (F7): only mark stale (`[STALE]`/`[IMG-STALE]`); fresh/unknown → no marker (no more `[img-ok]` lie).
5. **`scripts/build.sh`**: exact-match `case "$st" in stale|unknown|fresh)` in `_check_container_sig` (F6).
6. **`scripts/prune.sh`**: drop the dead `stale` literal field from the Rule-1 pipe contract (emit + read + header) (F8).
7. **Tests**: new `tests/libs/sig_helpers.sh` (`sandbox_sig`/`agent_sig`/`fresh_sig_map`); source from test_prune/test_resume/test_trace_build, delete copies (F5). Fixture records gain `sandbox:` service lines where image classification is exercised (real record shape — `build_fixture` already has them; `write_minimal_record`/prune fixtures need them) (F2).
8. **Docs**: tool_interface Rule-1 paragraph — default `STALE` selects sandbox OR image (F8 doc gap).

## Verification
- Full suite deterministic ×3 (baseline 500/500 at `3ba9cbc`); shellcheck clean (SC1091 tolerated).
- Classification behavior unchanged: existing image-staleness tests (resume columns, prune selection, preflight warning) stay green with the new parser + memoized sig.
- `record_image`/`current_sig` unit coverage: add small tests (service-block parse, provider wrapper, memoized determinism) in test_common_lib or test_trace_build.

## Completed (pre-close record)

| Finding | Fix |
|---|---|
| **F2** | `record_image FILE SERVICE` (awk, service-block scoped) added to `session_inventory.sh`; `record_provider` rewritten as a thin wrapper (agent image + `-agent-` gate). `record_image_stale` now reads BOTH images from the record (no `sandbox-` naming reconstruction; only the provider prefix kept for agent sig sourcing). Test fixtures/test records gained the real `sandbox:` service line. |
| **F1** | `current_sig <type> <repo_root> [provider]` added to `container_sig.sh` — memoized per `(type,provider)` via `declare -A _current_sig_cache`; `image_is_stale` delegates its recompute to it, so all consumers (`_check_container_sig`, `record_image_stale`) compute each current sig once; kills the O(2N) full-tree rehash on `--list`/prune. |
| **F3** | `: "${INTERACTIVE_MAX_ENTRIES:=10}"` in `src/libs/common.sh` (single canonical home); `interactive.sh` sources common.sh, drops its literal; resume derives `RESUME_LIST_PAGE_SIZE="$INTERACTIVE_MAX_ENTRIES"` (sources common.sh). |
| **F4** | `--list` cap via slice `${RESUME_INVENTORY[@]:0:$PAGE}` + subtraction footer (deleted `shown`/`remaining`); `_no_sessions` helper dedupes the empty-inventory error across `--list`/`--interactive`. |
| **F5** | `tests/libs/sig_helpers.sh` (`sandbox_sig`/`agent_sig`/`fresh_sig_map`); sourced by test_prune/test_resume/test_trace_build; three copies deleted. |
| **F6** | `_check_container_sig` uses `local st="$(image_is_stale ...)"` + exact `case "$st" in stale|unknown|fresh)` — trailing-space hack and prefix-match removed. |
| **F7** | Picker marks ONLY stale states (`[STALE]`/`[IMG-STALE]`); fresh/unknown render no marker (no more `[img-ok]` for an uninspectable/unknown image). |
| **F8** | Dropped the dead literal `stale` field from prune Rule-1 pipe contract (emit + read + header); trailing newline added to `container_sig.sh`; tool_interface + sandbox_lifecycle Rule-1 text now state default `STALE` selects sandbox OR image. |

**New tests:** `test_record_image_service_scoped` (comment/shadow + multi-service), `test_current_sig_deterministic` (deterministic + memoized + type-distinct), `test_interactive_max_entries_default` (common.sh constant), plus the existing image-staleness suite re-validating classification through the new parser + memoized sig.

**Findings (new this iteration):**
- F-B1: my `edit`-tool call on test_common_lib replaced a `run_test` line instead of inserting after it — swallowed `run_test test_check_base_flags_rejects_empty_sandbox`; restored. (Verify run_test lines are preserved after edits.)
- F-B2: `current_sig` cache must be `declare -A` (string keys) — indexed array assignment with a non-integer key would abort under `set -e`.
- F-B3: `export VAR="$(cmd)"` triggers SC2155 — split export + assign in test_prune.

## What's Next
- Pre-close review (Gate 3): present AC status + full-suite output. Suite **503/503**, deterministic across 3 runs.
- Set Status `Closed` and commit after release.

## Deferred / not in scope
- N3 mount-point lock.
- Restoring baked/current hex detail in the preflight warning (deliberate 09 call; reviewer flagged optional — not restored).
