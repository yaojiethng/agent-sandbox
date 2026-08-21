# Agent Handover

**Date:** 2026-08-20
**Milestone:** M2.6.6 — Mount Model: Host-backed Sandbox
**Type:** Implementation
**Status:** Closed

## Objective

**F1 — Mount delivery enablement**, with two folded pre-work streams per the operator's direction ("fold (a) into (b)"):
- **(a) M2.6-close housekeeping**: two roadmap checkbox lags (lines 149 outer `Terminology sweep`, 241 `.run-identity`/registry fold — both implemented but not flipped to `[x]`). Changelog M2.4/M2.6 entries already exist (verified), so the remaining housekeeping is just the two checkbox corrections.
- **(a) shellcheck cleanup backlog** from 5A findings: `package_branch.sh` SC2086/SC1003 + test-file sweep (SC2034/SC2015/SC2126/SC2188/SC2181/SC1090).

Make `SANDBOX_TYPE=mount` produce a healthy, validated sandbox working directly on the host worktree.

## Context (verified)

- **Compose side is DONE** (`20260818-03`): `docker-compose.mount.yml` bind-mounts `${WORKTREE_DIR}`→`/home/agentuser/sandbox`; `run_agent.sh` has the `SANDBOX_TYPE` selector (default copy, invalid rejected) + `WORKTREE_DIR` default (`${SANDBOX_DIR}/.worktree`). The `.mount.yml` overlay and base compose exist.
- **Gap 1 — `SANDBOX_TYPE` not in container env**: the selector only chooses the compose file set; it is NOT passed into the sandbox container (base `docker-compose.yml` carries `SESSION_ID` env but no `SANDBOX_TYPE`). Mount validation cannot branch inside the container until this is wired.
- **Gap 2 — entrypoint is copy-only** (`src/capability/entrypoint.sh`): unconditional `snapshot_validate` (line 91) + `snapshot_init_git` (line 97) + a CRITICAL preflight `test -f "$SNAPSHOT_DIR/baseline.tar"` (line 178). Mount mode has no snapshot — all three must become delivery-aware.
- **Gap 3 — start fresh path is copy-only** (`start_agent.sh` lines 484-487): `snapshot_copy_worktree` → `snapshot_archive_head` → `snapshot_validate`. Mount must instead materialize the worktree via `snapshot_copy_worktree` (the shared primitive) **minus** `baseline.tar`, and validate `.git` + init marker.
- **Design decisions to realize** (walk `20260818-02`): Start contract — first mount run materializes the worktree via the shared snapshot primitive minus `baseline.tar`; start validation = `.git` + init marker; no clean-HEAD requirement; work off current branch; port-back stays `package_branch`/`make draft`. SESSION_STATE retained as container-side provenance (mount writes it into the worktree `.git`, doubling as the init marker). **Entrypoint branch-inversion cleanup** (fresh-init primary; carried from `20260818-02`) folded in.
- Snapshot primitives: `snapshot_copy_worktree SOURCE DEST` (rsync), `snapshot_archive_head` (produces baseline.tar — mount does NOT use), `snapshot_validate`, `snapshot_init_git SANDBOX_DIR SNAPSHOT_DIR`.

## Files in scope (proposed)

| File | Change |
|---|---|
| `src/capability/entrypoint.sh` | Delivery-awareness: mount path validates `.git` + init marker, writes SESSION_STATE into worktree `.git` (init marker), skips snapshot gate/init + `baseline.tar` preflight; branch-inversion (fresh-init primary); copy path unchanged |
| `scripts/start_agent.sh` | `SANDBOX_TYPE=mount`: materialize worktree via `snapshot_copy_worktree` minus baseline.tar when absent; validate `.git` + init marker before `up`; copy path unchanged |
| `src/build/docker-compose.copy.yml` | `SANDBOX_TYPE=copy` env literal (co-located with the SNAPSHOT_DIR copy-only wiring, mirroring the established `SNAPSHOT_DIR`-in-overlay pattern) |
| `src/build/docker-compose.mount.yml` | `SANDBOX_TYPE=mount` env literal (co-located with the worktree bind) |
| `scripts/run_agent.sh` | Pass `SANDBOX_TYPE`/`WORKTREE_DIR` through to compose env (if not already) |
| `src/libs/package_branch.sh` | shellcheck: SC2086 (`$GIT_DIFF_OPTS` unquoted), SC1003 (sed `$a\`) |
| `tests/*` (test_dispatch, test_draft_workflow, test_interactive_session_select, workflow_draft_then_confirm) | shellcheck sweep (SC2034/SC2015/SC2126/SC2188/SC2181/SC1090) |
| `tests/*` (new) | Mount entrypoint branch test, start-trace `SANDBOX_TYPE=mount`, preflight conditional; suite green (462 baseline) |
| `docs/architecture/execution_model.md` | Entrypoint/start delivery-aware init, init-marker semantics |
| `devlog/roadmap.md` | Fix checkbox lags (149, 241); mark F1 resolved at close |

## Housekeeping specifics (verified)

- Roadmap **line 149** outer `Terminology sweep` checkbox: all phases DONE in-text but outer `[ ]` → `[x]`.
- Roadmap **line 241** `.run-identity` deprecation (P3): implemented+committed (`20260819-08`), docs correctly say "deprecated, no longer written"; checkbox `[ ]` → `[x]`.
- Changelog M2.4/M2.6 entries: **already present** (verified lines 124, 132) — no extraction needed.
- Close-order roadmap label (line 197): **already RESOLVED** — no action.

## Out of scope (deferred)

- F2 wizard, F5 prune redesign, mount-worktree-with-git-history (F3) — separate later items.
- `snapshot_copy_worktree`-related copy-side vestigial cleanups (always-mounted SNAPSHOT_DIR env, `baseline.tar` preflight re-scope) — parked with volume-seeding.
- SC1090 classification vs SC1091 — confirm during the sweep, but SC1090 in test_dispatch.sh may be justified (non-constant source).

## Verification

- `SANDBOX_TYPE=mount` run: sandbox healthy (`.git` present), worktree validated, no snapshot dependency.
- `SANDBOX_TYPE=copy` (default): unchanged (full suite green).
- Full suite green (462 baseline); `bash -n` clean; no new shellcheck categories beyond SC1091.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | `SANDBOX_TYPE` env goes in **both overlays as literals** (copy.yml=`copy`, mount.yml=`mount`), NOT base | The value is run-wide scalar, but per-overlay literals mirror the established `SNAPSHOT_DIR`-in-copy-overlay pattern and keep base free of delivery wiring; a generated compose self-documents its delivery type. Operator confirmed per-overlay is the right home. |
| 2 | SC1090 (test_dispatch.sh:103) skipped / documented exception, no directive | operator-directed; close sibling of the accepted SC1091, non-constant source is legitimate in the test harness sweep |
| 3 | Entrypoint mount branch writes the SESSION_STATE init marker when absent (does not require it to pre-exist) | Start-contract N4: mount writes SESSION_STATE into the worktree `.git`, doubling as the init marker; host materializes `.git`, container writes the marker |
| 4 | Host-side mount materialization = `snapshot_copy_worktree` (minus baseline.tar) + git-init + baseline commit | Start-contract N1/N4: shared snapshot primitive minus baseline.tar; container writes the init marker |
| 5 | Mount branches flow unchanged through diff export/autosave (SESSION_STATE has init_sha, so `package_branch`/`diff_export` work) | port-back stays the existing diff machinery (design N4) |

## Completed this session

- [x] Roadmap checkbox lags corrected: line 149 outer `Terminology sweep` `[ ]`→`[x]`; line 241 `.run-identity` `[ ]`→`[x]` + resolution note.
- [x] Shellcheck backlog: `package_branch.sh` SC2086 (array-ized `GIT_DIFF_OPTS`) + SC1003 (sed→awk blank append) fixed; test-file SC2188 (`: >`) ×3, SC2181 (`if`), SC1003 (awk) fixed; SC2034/SC2015/SC2126/SC1090 documented as deliberate/skipped.
- [x] Entrypoint delivery-aware: mount branch validates `.git`, writes SESSION_STATE init marker when absent, skips snapshot gate/init; `baseline.tar` preflight gated to copy.
- [x] `start_agent.sh` mount materialization: `SANDBOX_TYPE`/`WORKTREE_DIR` exports; fresh-mount path rsync + git baseline.
- [x] Compose env: `SANDBOX_TYPE=copy` (copy.yml) / `SANDBOX_TYPE=mount` (mount.yml) per-overlay literals.
- [x] Compose tests updated (overlay SANDBOX_TYPE literals); suite green 462/0/0.
- [x] `execution_model.md` delivery-aware init + init-marker semantics documented.

## Acceptance criteria

- [x] Operator confirms scope (F1 + folded housekeeping + shellcheck) — confirmed; decisions 1–2 settled.
- [x] `SANDBOX_TYPE=mount` compose carries the mount overlay env; copy compose carries the copy overlay env — verified statically in compose test.
- [x] Mount-mode entrypoint validates `.git` + writes the SESSION_STATE init marker; copy mode unchanged (suite green).
- [x] `start_agent.sh` materializes the mount worktree (rsync + git baseline) when absent; copy path unchanged.
- [x] Roadmap checkbox lags (149, 241) corrected.
- [x] Shellcheck backlog cleared (production SC2086/SC1003; safe test fixes; deliberate/skipped documented; SC1091-only remains in edited files).

## Next session (after this)

F2 — `start`-command wizard; then F5 — prune-command redesign; then F3 — mount worktree with git history.
