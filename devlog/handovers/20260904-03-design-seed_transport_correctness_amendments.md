# Handover 20260904-03 — design seed transport correctness amendments

**Milestone:** M2.6 - Session Persistence
**Type:** design
**Status:** Closed
**Date:** 2026-09-04

## Objective

Harden the seed transport design (helper-container copy, ADR `sandbox_delivery_model.md` 2026-09-04 entry) for correctness before implementation. The operator prioritized correctness over speed for this subcomponent and directed that the documented rsync Known Issue be included in scope.

## Audit context (chat, this iteration)

Re-audit of the committed design surfaced one spec bug and several unrecorded contracts. The mount-path rsync Known Issue was re-located in code: `snapshot_copy_worktree` (`src/capability/snapshot.sh`) silently ignores negation patterns in global gitignore and `.git/info/exclude` — a live R1 leak on the mount-delivery path, not just a historical note.

## Scope (operator-confirmed)

| # | Item | Target |
|---|---|---|
| 1 | Deleted-file tar bug fix: enumeration carries an existence filter (keeps paths where `[[ -e ]] || [[ -L ]]`), so deleted tracked paths are absent from the tar by construction. Adopted from the knowledge probe's validated enumeration; replaces the comm-subtraction idea. | ADR 2026-09-04 entry | done |
| 2 | Self-verifying seed: final seeder step compares `git status --porcelain=v1 -uall` between `/src` and `/dest`; divergence aborts the seed. | ADR 2026-09-04 entry | done |
| 3 | Parity guarantee strengthened: **porcelain-identical**. Reset dropped; index crosses with the repository; staging state preserved. Consumer sweep clean (F5). | ADR (R2 reword + entry) | done |
| 4 | User-identity parity: seeder and agent service run as the same UID; volume file ownership is load-bearing. | ADR entry; compose wiring in impl iteration | recorded |
| 5 | Readiness/error boundary: seeder exit code is the only readiness signal; event-driven wait with hard timeout; timeout or nonzero exit aborts with logs and discards the volume; container create/start failures surface immediately. Resolves the indefinite-stall-on-failure bug. | ADR entry; impl iteration | recorded |
| 6 | Edge-case table: linked-worktree gitfile, unborn HEAD, empty worktree, submodules (fail closed, readable remediation), polluted-repo tripwire, stale index stat cache, absolute `core.hooksPath`. | ADR 2026-09-04 entry | done |
| 7 | Clone rejection rewritten with the real failure locus: checkout filters (autocrlf rewrites, LFS smudge needs network / R6), origin remote, stash and reflog loss. The original "untracked cannot cross" grounds were wrong. | ADR 2026-09-04 entry | done |
| 8 | Mount-path negation leak: new ADR entry (git enumeration via `--from0 --files-from` replaces hand-built rsync exclude lists); implementation scheduled with the seed-transport implementation iteration. | ADR + roadmap | done |

| 9 | Test surface audit appended to the design doc: per-test classification (reuse / rewrite / retire) across `test_snapshot_container.sh`, `test_snapshot_host.sh`, the discovery probes, and the trace tests, with the trust bottom line for implementation | Design doc + handover | done |

## Changes

| File | Change |
|---|---|
| `docs/adr/sandbox_delivery_model.md` | R2 reworded to porcelain-identical parity; 2026-09-04 entry rewritten (existence filter, no reset, porcelain self-check, SESSION_STATE note, completion-signal block); clone rejection corrected; edge-case table extended; new mount-path entry appended |
| `docs/concepts/copy_delivery.md` | Behavioral contracts updated: staged changes stay staged; seed-interface guarantee reworded; reset sentence replaced by self-verification sentence |
| `devlog/roadmap.md` | Seed-transport task gains readiness wiring and the mount-path enumeration fix |

## Deferred

- Implementation itself (seeder wiring, pipeline retirement, trace-test rewrites) — next iteration, against the amended spec.
- Test matrix execution — defined as spec acceptance criteria here, written in the implementation iteration.

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | ADR command 2 hard-fails on deleted tracked files (`ls-files --cached` reads the index; tar errors on the missing path). R2's deletions-visible case is unreachable as written. Resolved: existence filter adopted from the knowledge probe, already validated (deleted-file case reports parity). | Resolved |
| F2 | Mount-delivery path (`snapshot_copy_worktree`) silently ignores negation patterns in global excludes and `.git/info/exclude` — live R1 leak; the Known Issue note understates it as "residual limitation". | Open (fix scheduled; ADR entry recorded) |
| F3 | Seeder/agent UID parity is load-bearing (volume ownership; dubious-ownership refusals) and unrecorded. | Resolved (recorded in ADR) |
| F4 | Seed-completion signal moves to seeder exit code; without an explicit boundary, a half-seeded volume boots silently. | Resolved (recorded in ADR) |
| F5 | Consumer sweep for the porcelain decision: the only `diff --cached` consumer is inside `snapshot_init_git`, which the redesign retires. No index-assuming consumer blocks the reset removal. | Resolved |
| F6 | The knowledge probe empirically confirms the rsync Known Issue: the current pipeline leaks `drop.debug` (negation) and `globalonly.txt` (global exclude) — DIVERGENCE, reproducible. | Resolved (evidence for F2) |
| F7 | A stale `.agent-sandbox-seed/` payload sits in this container's worktree — root-owned, extracted by `docker cp` at provision time, never cleaned up. Not a host-side fossil: the host worktree is clean. | Resolved (diagnosed) |
| F8 | The old pipeline's member cleanup is fail-open by construction: `snapshot_init_git` runs `rm -rf "$SEED_DIR"` as `agentuser` against root-owned 755 directories from the `docker cp` extraction; the rm fails with no error guard, the next command succeeds, and the session starts green with the full payload left in the worktree. The architecture doc states the cleanup as fact. Live demonstration of the R7 failure locus; the redesign retires the cleanup step entirely. Litter masked by a committed `.gitignore` line — pollution reached tracked project content. | Open (retires with the pipeline; doc claim folded into the impl doc sweep) |

## Decisions

| # | Decision | Rationale | Source |
|---|---|---|---|
| D1 | Amend the ADR 2026-09-04 entry in place rather than appending a superseding entry. | The decision has no landed implementation; history lives in git. | Operator confirmed |
| D2 | Porcelain-identical parity; reset dropped. | Stronger guarantee, trivially verifiable (raw porcelain compare), one fewer command; consumer sweep clean (F5); return path is index-agnostic (`git diff HEAD` / `git diff INIT_SHA`). | Operator |
| D3 | Existence filter for the enumeration, adopted from the knowledge probe. | Handles deleted tracked paths by construction; simpler than set subtraction; already validated (probe c3 parity). | This iteration |
| D4 | Readiness = seeder exit code, event-driven wait, hard timeout, fail-fast on create/start failure. | Resolves the indefinite-stall-on-failure bug the operator directed. | Operator |

## Acceptance criteria (pre-close)

| # | Criterion | Status |
|---|---|---|
| AC1 | ADR R2 wording and 2026-09-04 entry carry the porcelain contract, existence filter, self-check, completion signal, and edge-case table | done |
| AC2 | Clone rejection corrected; no false grounds remain | done |
| AC3 | Mount-path rsync fix recorded as an ADR entry and scheduled | done |
| AC4 | Concept doc behavioral contracts match the amended guarantee (staged state preserved, self-verification) | done |
| AC5 | Roadmap seed task reflects readiness wiring and mount-path fix | done |
| AC6 | Lint and test suite green | pending release run |
| AC7 | Test surface audit recorded in the design doc with per-test verdicts and the trust summary | done |
