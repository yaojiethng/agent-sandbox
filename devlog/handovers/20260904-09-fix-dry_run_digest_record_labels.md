# Handover 20260904-09 — fix dry-run digest record labels

**Milestone:** M2.6 - Session Persistence (M2.7 harness versioning follow-up)
**Type:** fix
**Status:** Closed
**Date:** 2026-09-04

## Objective

Fix `make dry-run` Phase 3 failure: both probe records carry no image-digest label, so the digest roundtrip gate cannot run.

## Diagnosis

`dry_run_image_verify` (src/libs/dry_run_record.sh:75) greps for `agent-sandbox.<type>-image-digest:` in the *probe record*, but the probes never write a digest line -- and should not: the record is a readiness artifact (identity echo + layer status), while the digest is content identity. `compose_generate` already stamps the digests as compose labels (`agent-sandbox.agent-image-digest` / `agent-sandbox.sandbox-image-digest`, src/build/docker-compose.yml:52) into the generated compose file, post-build -- the same labels and file `make start`/`resume --list` consume. The dry-run runs against that same generated file via `COMPOSE_ARGS`.

## Scope

| # | Item | Status |
|---|---|---|
| 1 | `compose_dry_run` passes the generated compose file to `dry_run_image_verify` (generation-time label stamp vs daemon digest at run time) | done |
| 2 | Probe records stay readiness-only -- no digest echo, no new env vars | done |
| 3 | Tests updated/added; suite green; lint clean | done |

## Deferred

- Draft-rollback branch deletion (failed `make draft` leaves the `draft/*` branch) -- operator directed a separate iteration; new handover to follow.
- `make install` / `make refresh` question -- answered in chat (install is symlink-based and landed; refresh regenerates sandbox-dir templates and remains functional). No change.

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | Gate failures must not skip teardown: `compose_dry_run` runs cleanup after verification regardless of outcome (verified: the stub trace shows `compose down -v` after a failed gate). An interim defect in `compose_file_from_args` (invalid substitution under `set -u`) aborted the run before cleanup -- fixed and covered by the existing teardown trace test. | Resolved |
| F2 | The roundtrip-gate unit fixtures were already compose-file-shaped, so the gate's grep needed no behavioural change -- only its input source (probe record -> generated compose file) and message wording changed. | Resolved |

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1 | The digest roundtrip gate reads the generated compose file, not the probe records. | Same label source as `make start`/`resume --list` (compose labels stamped by `compose_generate` post-build); no DRY_RUN_-prefixed special casing; the digest is content identity, not a readiness layer, so probe records stay readiness-only. Operator-directed. | This iteration |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | `dry_run_image_verify` passes against the generated compose file (label present and matching the daemon digest) | done |
| AC2 | Tests cover the gate's compose-file input and `compose_file_from_args`; suite green; lint clean | done -- suite 730/730 (two new `compose_file_from_args` tests added), ShellCheck 0 warnings |
