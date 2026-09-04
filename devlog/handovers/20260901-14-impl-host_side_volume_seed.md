# Handover 20260901-14 — impl host-side volume seed: git-enumerated tar, .snapshot/ retirement

**Milestone:** M2.6 - Session Persistence
**Type:** impl
**Status:** Closed
**Date:** 2026-09-01

## Objective

Implement the settled copy-delivery pipeline replacement (roadmap "Host-side volume seed +
git-enumerated tar"; discovery validated in handover `20260901-13`): seed the sandbox volume
host-side before the sandbox container starts, remove the `.snapshot/` RO mount, gate 2, and the
`.snapshot/` staging directory, and delete the deprecated snapshot functions. Also relocate the
discovery scripts to `tests/knowledge/` (operator direction).

## Design (settled in-iteration from `20260901-13` findings + code walk)

- **Seed trigger:** `RESET_VOLUME=true` + `SANDBOX_TYPE=copy` in `run_agent.sh` (start always
  resets; resume never does — exact correspondence with fresh-init).
- **Serialization:** `snapshot_seed_tar PROJECT_DIR OUT.tar` in `src/capability/snapshot.sh`:
  git-enumerated worktree (`git ls-files --cached` present-on-disk + `--others
  --exclude-standard`, packed via `tar --null -T` with `--transform` to `worktree/` prefix),
  then `baseline.tar` (`git archive HEAD`) appended as a member. One tar, no persistent staging.
- **Transport:** `docker compose create sandbox` (creates volume + container, no start) →
  `docker cp - <container>:/home/agentuser/sandbox < seed.tar` (writes through the volume mount)
  → subsequent `up -d` starts the seeded container. No volume-name computation, no separate
  volume create, labels/locking untouched.
- **Container init:** entrypoint fresh-init path drops gate 2; `snapshot_init_git` reads
  `baseline.tar` and `worktree/` from inside the volume (call: `SNAPSHOT_DIR="$SANDBOX_DIR"`),
  same baseline-commit + rsync-overlay sequence, then removes the seed members. Index=HEAD,
  worktree=disk invariant unchanged.
- **Removals:** `.snapshot/` mount + `SNAPSHOT_DIR` env from `docker-compose.copy.yml`;
  `snapshot_validate` gates 1+2; `session_state_write snapshot_dir`; deprecated
  `snapshot_copy_files` / `snapshot_enumerate_files`; `.snapshot/` staging block in
  `start_agent.sh`.
- **Staging:** seed tar built to a per-run mktemp inside `run_agent.sh`, deleted after `docker cp`.

## Acceptance Criteria

- AC1: `snapshot_seed_tar` produces a seed tar whose extraction reproduces the working tree
  (list/hashes/modes/symlinks) plus `baseline.tar` (unit tests).
- AC2: `make start` (copy delivery) seeds the volume host-side; sandbox init yields the same
  `git status` parity as before; no `.snapshot/` mount in the generated compose file (tests:
  trace tests updated, compose-gen test asserts absence of the snapshot mount).
- AC3: Resume path unchanged (no seeding, no snapshot references).
- AC4: Deprecated functions, gates, `snapshot_dir` session-state writes, and `.snapshot/`
  staging removed; no stale references (grep sweep).
- AC5: Docs swept: `copy_delivery.md` (pipeline now implemented), `sandbox_lifecycle.md`,
  `execution_model.md`, `tool_interface.md`, `security.md` — no current-tense `.snapshot/` RO
  mount claims.
- AC6: Discovery scripts relocated to `tests/knowledge/` (operator direction).
- AC7: Test suite green vs baseline in this environment (docker-dependent failures unchanged);
  ShellCheck clean on changed scripts.

## Out of scope

- Mount delivery runnability (M2.6.6 separate).
- Harness version identity impl (separate roadmap item).
- The rsync negation-leak fix note: resolved by construction (git enumeration) — no backport.

## Completed

| Task | Evidence |
|---|---|
| Discovery scripts relocated to `tests/knowledge/` (AC6) | `git mv scripts/manual/discovery_tar_*.sh tests/knowledge/`; same `../../` depth, REPO_ROOT resolves |
| `snapshot_seed_tar` implemented + unit-tested (AC1) | `src/capability/snapshot.sh`; `tests/test_snapshot_container.sh` 32/0: round-trip lossless, gitignored exclusion, negation honored, submodule + no-commit rejection |
| `snapshot_init_git` reworked to SEED_DIR interface (AC2) | baseline commit from `SEED_DIR/baseline.tar`; overlay from `SEED_DIR/worktree/`; sentinel symlink-target repair; seed cleanup (unit-tested) |
| Seed step in `run_agent.sh` (AC2) | `seed_sandbox_volume`: `docker compose create sandbox` + `docker cp` tar into volume; gated on `RESET_VOLUME=true && SANDBOX_TYPE=copy`; fail-closed before containers run |
| Entry point updated (AC2/AC3) | `entrypoint.sh` fresh-init calls init from `$SANDBOX_DIR/.agent-sandbox-seed`; gate 2 + `SNAPSHOT_DIR` requirement + preflight check removed; resume path untouched |
| Compose overlay cleaned (AC2) | `docker-compose.copy.yml`: volume only, no snapshot mount/env; `compose.sh` substitution dropped |
| `.snapshot/` retirement sweep (AC4) | `dirs.sh` `SNAPSHOT_DIR`/`SNAPSHOT_DIR_NAME` removed (prod + stub); `snapshot_validate` deleted; `snapshot_dir` session-state writes removed; knowledge diagnostics swept |
| Docs sweep (AC5) | `copy_delivery.md` (implemented-record rewrite), `sandbox_lifecycle.md` Phase 1 rewritten, `execution_model.md`, `tool_interface.md`, `security.md`, `system_overview.md`, correspondence model, `project_index.md` rows |
| Verification (AC7) | Full suite: 705 passed / 67 failed / 0 skipped — failure set identical to HEAD baseline (verified via `git stash` before/after diff; 67 pre-existing docker-dependent failures, remaining diffs are hash/path cosmetics). Net −1 test: 4 obsolete validate tests removed, seed tests added. ShellCheck clean on all changed scripts (one pre-existing SC2034 in start_agent.sh matches baseline) |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Seed via `docker compose create` + `docker cp`, not `docker volume create` | volume name is compose-prefixed (`<project>_<key>`); `create`+`cp` avoids computing it and keeps labels/compose ownership intact |
| D2 | Seed tar carries `worktree/` + `baseline.tar` members; init stays in the entrypoint | keeps git-init logic in one place (container), minimal divergence from the proven baseline+overlay sequence |
| D3 | `snapshot_validate` deleted, not retained | both gates disappear with the mount; mktemp staging needs no structural gate; git history retains the function |
| D4 | Discovery scripts to `tests/knowledge/` | operator direction; external-seam classification (rsync/tar/git behavior probes) |
| D5 | Sentinel prefix `.agent-sandbox-seed/` + post-overlay symlink repair | tar's `--transform` rewrites symlink targets as well as member names (no flag prevents it); repair strips the sentinel prefix, which no project path can collide with |
| D6 | Seed members extracted into the volume root (not a `.seed/` subdir via docker cp) | avoids relying on docker cp creating a missing destination dir; members are git-ignored via `.git/info/exclude` for the duration of init and removed after the overlay |

## Findings

**F1 -- tar `--transform` rewrites symlink targets.** No tar flag prevents it (tested '' / r /
b / h / s / B / H on this tar). Consequence: the pack uses the unique sentinel prefix and
`snapshot_init_git` strips it from link targets after the overlay. Relative, absolute, and
dot-dot targets all repair correctly (covered by `test_init_git_symlink_target_repaired`).

**F2 -- git-enumeration must anchor existence checks to SOURCE_DIR.** The enumeration subshell
runs from the harness CWD; `-e "$f"` silently produced an empty list (caught by the unit suite:
"seed tar ready: 1 member"). Fixed to `-e "$SOURCE_DIR/$f"`. A silent-empty list is the dangerous
failure mode here -- consider a fail-closed guard if the list is empty but the repo has files.

**F3 -- seed gating maps exactly onto RESET_VOLUME.** `start_agent.sh` always passes
`--reset-volume` (fresh session by definition); resume never does. So `RESET_VOLUME=true &&
SANDBOX_TYPE=copy` is a complete and exact fresh-init condition for all modes (standard, serve,
dry-run) with no resume-detection machinery needed.

**F4 -- the 67 baseline failures were the stub exec bit, not the environment.** The committed
tree carried `test/stubs/docker` as mode 100644, so every docker-shimmed test failed with rc=126
(found-but-not-executable) in this container. Misdiagnosed initially as "docker unavailable"
(baseline-vs-change parity made it look environmental). Root cause: the exec bit was lost before
the baseline commit (host checkout / session-save apply wrote contents without modes). With the
bit restored the entire suite passes under stub coverage: **758/758/0**, no docker needed.
Correction to the AC7 evidence below accordingly.

**F5 -- `test/stubs/` (singular) was a directory-naming inconsistency, consolidated.** The docker
shim lived in `test/stubs/` while the lib stubs live in `tests/stubs/libs/`; 12 test files + 5
stub header comments referenced the singular path. Consolidated: `git mv test/stubs/docker
tests/stubs/docker` (mode fixed to 100755 via `git update-index --chmod=+x` so the bit survives
the snapshot pipeline), `test/` removed, all references swept (17 files), zero stale references.
Also fixed the last blocking lint warning: `scripts/manual/fix_exec_bits.sh` had a whitespace-
corrupted shebang (pre-existing since baseline; thematically on-point). `check_lint.sh` is Clean
(0 warnings) for the first time, and its `find` no longer references the removed `test/` dir.

**F5b -- dry-run trace fixture needed a seedable project.** With seeding active on
`--reset-volume`, the dry-run trace fixture (which calls `run_agent.sh` directly) had no
`PROJECT_DIR` git repo, so the seed's fail-closed guard aborted before `compose_dry_run` and the
`down -v` assertion saw an empty trace. The fixture now builds a one-commit git repo and exports
`PROJECT_DIR` -- the seed path is exercised through the stub in the trace test.

**F5 -- stale `.bootstrap/` reference removed from `security.md`.** The mount-shape invariant and
invariant 2 referenced a `.bootstrap/` mount with no implementation in `src/`/`scripts/`. Line
dropped (and the snapshot-mount clause with it); container host-path access invariant now
guards `.workspace/` only.

**F6 -- knowledge diagnostics swept.** The four container-side `diagnose_*.sh` scripts asserted
the old SNAPSHOT_DIR mount and would now report false failures; snapshot checks removed.

**F7 -- field bug (operator, docker env): `docker compose ps -q` does not list created-but-never-
started containers.** `seed_sandbox_volume` looked up the container with `ps -q sandbox` after
`docker compose create` -- always empty, so every fresh start failed with "sandbox container not
found after create". Fixed: use the deterministic `container_name` (`SANDBOX_CONTAINER_NAME`,
baked into the template), with a `ps -aq` fallback and an existence check that names the expected
container in the error.

**F8 -- field bug (operator, docker env): resume stall = old-image/new-compose version mismatch.**
`make resume` of a pre-change session ran the NEW compose file (no snapshot mount/env) against
the OLD sandbox image (resume never rebuilds by design). The old entrypoint's preflight CRIT
(`SNAPSHOT_DIR/baseline.tar` readable) failed, the container exited, and the session sat in the
health-wait window (bounded at 120s, but effectively a stall; `make stop` from another terminal
did not return the terminal). Not a defect in the new pipeline itself -- it is the version-skew
class tracked by the harness-version-identity roadmap item. **One-time migration:** after
applying this change, run `make start REBUILD=1` once so both images match the source; resume
then works (the new entrypoint's resume path needs nothing from the retired mount).

**F9 -- re-application method.** The operator rolled back the first delivery; this iteration's
changes were reconstructed by replaying the successful write/edit tool calls from the pi session
save (matching each toolCall to its toolResult to skip rejected calls), then re-applying the
bash-driven `sed` steps manually. Verified by full-suite parity (773/706/67 = exact baseline
counts) and syntax/shellcheck checks.

## Pre-close AC table

| AC | Criterion | Status | Evidence |
|---|---|---|---|
| AC1 | `snapshot_seed_tar` unit tests | ✅ | `test_snapshot_container.sh` 32/0: round-trip (list/hash/mode), gitignored exclusion, negation honored, submodule + no-commit rejection |
| AC2 | Seeded start; compose has no snapshot mount | ✅ | `run_agent.sh` `seed_sandbox_volume`; `test_trace_compose_gen.sh` copy-overlay assertion (no SNAPSHOT_DIR / no .snapshot); entrypoint init from seeded members |
| AC3 | Resume unchanged | ✅ | resume path in entrypoint untouched; seed gated on `RESET_VOLUME=true && SANDBOX_TYPE=copy`; `test_trace_resume.sh` failure-set parity |
| AC4 | Deprecated code, gates, snapshot_dir writes, `.snapshot/` staging removed | ✅ | grep sweep: zero production `.snapshot`/`SNAPSHOT_DIR` references remain outside `snapshot.sh` internals and `copy_delivery.md` historical record |
| AC5 | Docs swept | ✅ | 9 docs updated (sandbox_lifecycle, execution_model, tool_interface, security, system_overview, correspondence model, copy_delivery, mount_delivery n/a, project_index) |
| AC6 | Discovery scripts in `tests/knowledge/` | ✅ | moved via `git mv`; paths verified |
| AC7 | Suite fully green under stub coverage | ✅ | **758 tests / 758 passed / 0 failed / 0 skipped** after stub consolidation; ShellCheck clean, one pre-existing warning matches baseline |
| AC8 | Field bug fixes verified | ✅ | F7: seed lookup uses deterministic container name (code review + stub trace); F8: migration documented, no code change needed; F5b: dry-run trace exercises the seed path end-to-end through the stub |

## Deferred

- `make prune` staleness-criteria restoration subtask (compose-record as source of truth) — unchanged, separate roadmap item.
- Empty-directory support (F3, `20260901-13`): git cannot represent them; accepted behavior change.
