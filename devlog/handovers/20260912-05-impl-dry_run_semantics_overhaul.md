# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general cross-cutting track)
**Type:** Impl
**Status:** Closed

## Objective
Implement the dry-run semantics overhaul (roadmap M2.6 general track, raised `20260901-02`): dry-run always builds and runs current source; a stale container after a fresh build is an error, not a warning.

## Scope
Current-state survey (this iteration's findings): the digest roundtrip gate already exists and fails closed (`dry_run_image_verify`, `src/libs/dry_run_record.sh`, wired in `compose_dry_run`); `[IMAGE_STALE]` is fully retired. The remaining gap is build policy: dry-run accepted `--refresh`/`--rebuild` passthrough but did not require them -- it ran whatever images existed. Final scope, after operator decisions during the iteration:

1. Build-before-run: dry-run always rebuilds sandbox + provider images before running, unless `--fast` is given (skip build, run existing images; missing images then fail with the preflight remediation error, not a silent build).
2. Keep the digest roundtrip gate as the post-build truth check (it compares build-time stamp vs running image; a rebuild mid-run fails).
3. `--fast` semantics: skip-build only (looser invocation, dry-run only); documented as the place future time-check carveouts land. Not "headless". `--refresh` rejected as redundant; `--rebuild` retained as the `--no-cache` stronger form.
4. `dryrun-` session-id prefix as diagnostic labeling (not routing): flows into compose project, containers, network, volume, registry record. Canonical definition in `session_inventory.sh` (`DRYRUN_SID_PREFIX` + `session_is_dry_run`).
5. Resume testbed: the dry-run runs TWO passes against one seeded volume -- fresh (verify) -> stop with volume kept (= `make stop`) -> resume without re-seed (= `make resume`) -> verify -> full teardown (`down -v`). Teardown at the end of every dry-run, failure paths included.
6. Trap + cleanup instead of a namespace carveout: the prefix is labeling; the EXIT trap (`TEARDOWN_NEEDED`) covers abnormal exits; `.compose` records kept for diagnosis. Dry-run records stay in the shared inventory (prune Rule 1 must reach them); the resume listing filters them out (consumer-side, `session_is_dry_run`).
7. Update `scripts/templates/Makefile.template` dry-run docs and any roadmap-facing flag documentation.

Design decisions (operator, Gate 1):
- Default build policy: always rebuild using cache layers. `--fast` = looser invocation that skips the rebuild; not "headless" -- different semantics. Name stays `--fast`; future time-consuming-check carveouts also live under fast mode.
- Labeling, not routing: keep the `dryrun-` prefix (identification of missed-scope residue, workspace tidiness), use `.compose` records, add trap + cleanup for residue. Avoid customizing paths dry-run exists to test.
## Completed

| File | Change |
|---|---|
| `scripts/start_agent.sh` | `--fast` flag (dry-run only, skip build); dry-run default = always-rebuild (maps to the cache-preserving refresh path); `--refresh` rejected as redundant for dry-run; `--fast` + `--rebuild` rejected as opposite policies; `--fast` rejected for standard start (no silent no-op flags); `--fast` passes `build_missing=false` to preflight so missing images fail with the remediation error instead of a silent build; dry-run session id prefixed `DRYRUN_SID_PREFIX`; usage text updated |
| `scripts/run_agent.sh` | Dry-run path arms `TEARDOWN_NEEDED` before `compose_dry_run` so the EXIT trap covers abnormal exits; activity log guard uses `session_is_dry_run` |
| `src/build/compose.sh` | `compose_dry_run` restructured into a reusable `_dry_run_pass` (up + wait + record verify + roundtrip) run TWICE: pass 1 fresh on the just-seeded volume, then `session_teardown` (down, volume kept = `make stop`), pass 2 resume on the kept volume with no re-seed (= `make resume`), then `session_destroy` (down -v) -- teardown at the end of every dry-run, and BOTH pass failures destroy the volume before returning; `compose up` failure no longer swallowed (pipe previously ate the exit status; a failed up surfaced only as a record timeout) -- now fails loudly with the up exit code; `remove_volumes` parameter dropped (teardown is always full); stale "Phase 3" output vocabulary retired ("record verification (X pass)") |
| `src/libs/session_inventory.sh` | Canonical dry-run id labeling (`DRYRUN_SID_PREFIX` + `session_is_dry_run`, defined once beside the record helpers); `enumerate_records` stays unfiltered (prune Rule 1 must reach dry-run records; Rule 2 sweeps their resources once the record is gone) |
| `scripts/resume_agent.sh` | Resume inventory (`build_inventory`) filters dry-run records out of the listing (not resumable); prune consumes them unfiltered |
| `scripts/templates/Makefile.template` | dry-run target: `FAST=1` variable, no REFRESH/REBUILD passthrough; help text updated |
| `scripts/agent-sandbox.sh` | dry-run usage line shows `[--fast]` |
| `docs/architecture/tool_interface.md` | dry-run section rewritten: always-rebuild semantics, `FAST=1`, `dryrun-` labeling, roundtrip gate added to guarantees |
| `tests/stubs/docker` | stub `compose up` writes the two diagnostics records when dry-run is active (simulates bearer probes; gated on `DRY_RUN_SCRIPT`) |
| `tests/test_start_agent.sh` | +6: default dry-run rebuilds (cache-preserving), `--fast` skips build, `--refresh` rejected, `--fast`+`--rebuild` rejected, `--fast` rejected for standard start, `dryrun-` prefix in record + container names |
| `tests/test_trace_dry_run.sh` | +3/-2: up-failure destroys the volume and exits nonzero; always-full-teardown asserted; two-pass fresh+resume sequence asserted (2 ups, kept-volume stop between, final down -v); retired the reset-flag teardown tests |
| `tests/test_run_agent.sh` (campaign) | rewritten: 12 source-grep noise tests -> 8 behavioural docker-stub tests (provider setup hook absent/present/failure, provider overlay merge, SERVE_PORT fallback) |
| `tests/test_provider_entrypoint.sh` (campaign) | inlined production copy replaced by live extraction + prerequisite gate + drift guard |
| `tests/test_dry_run_record.sh` (campaign) | structure repaired: single registration block, one test_done; dead mid-file exit gate and dead helper removed |
| `tests/test_build_context.sh` (campaign) | dead-logic test deleted |
| `tests/test_session_inventory.sh` | `enumerate_records` emits dry-run records (shared core); resume-side skip asserted |

## Decisions

| Decision | Rationale |
|---|---|
| Namespace carveout replaced by trap + cleanup + labeling | Operator: prefix stays as labeling/sanity check (identification of missed-scope residue), not routing; cleanup via the existing EXIT trap; `.compose` records kept for diagnosis. Avoids customizing paths dry-run exists to test. |
| `dryrun-` session-id prefix | Flows into every derived name (compose project, containers, network, volume, record filename). Unique per-run id prevents collisions; prefix is for diagnosis and workspace tidiness. |
| Default = always-rebuild using cache layers; `--rebuild` stays valid (the `--no-cache` stronger form); `--refresh` rejected (redundant); `--fast` = skip build | Operator correction: `--rebuild` means `--no-cache`, the stronger form of the default -- not an invalid flag. |
| Dry-run is its own resume testbed: two passes (fresh -> verify -> stop w/ volume kept -> resume -> verify -> down -v) | Operator direction: resume the very same dry-run volume -- the dry-run is a longer version of the same start/diagnose/stop cycle, teardown still at the end. Pass 2 mirrors `make stop` + `make resume` exactly (down then up, no re-seed) and re-runs the readiness probes against already-initialized session state. |
| Dry-run teardown uses volumes-destroying path on failure; trap is the safety net, inline cleanup still runs first (double teardown harmless) | Covers the previously-uncovered abnormal-exit leak (running sandbox container + volume). |
| Resume listing filters dry-run records; `enumerate_records` stays unfiltered | A dry-run record's volume is destroyed at teardown, so it is not resumable; leaving it listed offered phantom sessions in `resume --list`. The skip initially lived inside `enumerate_records`, which made dry-run records unprunable (prune Rule 1 shares the core); moved to the resume consumer so prune reaches them and Rule 2 sweeps their resources. |
| Test-quality campaign proposal accepted + folded into this iteration's delivery | Operator decision; suite at delivery: 745/0/0 (net -4: noise deletions outweigh additions). Campaign's 5 testing-conventions rule proposals deferred to a follow-up iteration (policy proposals, one section at a time). |

## Findings

- F1: `compose_dry_run`'s `up -d | grep || true` silently swallowed `compose up` failure; a failed up surfaced only as a record-verification timeout. Fixed: exit code captured before filtering.
- F2: the docker stub never simulated the bearer probes' diagnostics records, so every stubbed dry-run "failed" Phase 3; trace tests masked this by swallowing the exit code. Stub now writes the records (gated on `DRY_RUN_SCRIPT`).
- F3: pre-overhaul dry-run left a resumable-looking record in `.compose/` per run -- registry pollution for `resume --list` and prune. Fixed by the consumer-side skip in `resume_agent.sh` plus the log guard in `run_agent.sh`; `enumerate_records` deliberately stays unfiltered so prune Rule 1 can reclaim stale dry-run records.
- F4: residue after a SIGKILL'd dry-run cannot be trapped; such resources are orphans by prune Rule 2's existing definition, so `make prune` sweeps them. Documented, no new machinery.
- F5: live-run risk points for the resume pass (offline stubs cannot catch these): (a) the capability probe runs as a start-up prelude then the sandbox container stays alive -- on pass 2 the container is recreated, so the probe must tolerate an already-initialized workspace (same path a real resume takes; expected fine, unproven offline); (b) the seeder's first-mount ownership initialization applies to pass 1 only -- pass 2 must not need it (volume already owned); (c) `DRY_RUN_RECORD_TIMEOUT` now bounds each pass separately, so total wall time roughly doubles. ALL CLEARED by the operator's live run (fresh + resume passes green, roundtrip gates green, full teardown).
- F6: thermo-nuclear review ran 8 rounds (fresh subagents). Blockers found and fixed across rounds: pass-1 failure leaked the seeded volume (now `session_destroy` on both pass-failure paths and the trap); `--fast` silently auto-built missing images and was silently accepted in standard mode (now preflight `build_missing=false` remediation error + explicit rejection); `dryrun-` prefix scattered as literals (now canonical `DRYRUN_SID_PREFIX` + `session_is_dry_run` in session_inventory.sh); putting the dry-run skip inside `enumerate_records` made records unprunable (now unfiltered core + consumer-side resume filter); EXIT trap kept the volume on abnormal dry-run exit (trap now destroys for dry-run sessions); e2e doc output-contract drift (Phase A/B/D, E2E-5, teardown semantics rewritten to the two-pass contract; image identity check reads the image Id); STALE=image|all template propagation gap fixed; vocabulary swept. Final verdict: APPROVE.
- F7: test-quality campaign ran (fresh subagent, report in the session output mount, `FINAL_REVIEW.md`): suite started 749/0/0 with zero tautologies/dead tests; 4 test files rewritten/repaired (test_run_agent.sh noise -> behavioural, test_provider_entrypoint.sh inline-copy -> live extraction, test_dry_run_record.sh structure, test_build_context.sh dead test); two untested code paths closed (provider setup hook contract, SERVE_PORT fallback); proposal left uncommitted for operator decision; conventions rule proposals (Anti-Pattern 7 "test-the-copy", structural template mandatory, known-gaps record) are pending operator review.

## Deferred items

- **Live docker verification of AC1/AC3/AC4**: offline tests cover the logic through stubs (build policy trace, prefix in record, trap teardown, two-pass sequence); the operator's live `make dry-run` run passed (fresh + resume passes, roundtrip gates, full teardown) and cleared the F5 risk points. A live `make start` run on docker remains pending (operator's environment).

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | Dry-run with no flags always rebuilds current source before running; `--fast` skips the build and is documented as such | needs docker (offline for flag parsing) | offline: stub trace shows build on default, none on `--fast`; live run pending (see Deferred) |
| AC2 | Digest roundtrip gate still fails closed on identity mismatch | offline unit test | pass (`tests/test_dry_run_record.sh`, 749/749 suite) |
| AC3 | Dry-run containers/networks/volumes use a dry-run-specific namespace and cannot collide with a live `make start` session | needs docker (offline for name derivation) | revised by operator decision: unique per-run id already prevents collisions (pre-existing); `dryrun-` prefix added as labeling, verified offline in record + container names; live run pending |
| AC4 | Resume semantics exercised via dry-run-controlled container | needs docker | implemented offline (two-pass fresh+resume in `compose_dry_run`; trace tests verify up/stop/up/teardown sequence + record re-verification); live run pending with operator |
| AC5 | Full test suite passes | suite | pass: 749/749 pre-campaign; 745/0/0 with the folded campaign proposal (delivery state) |
