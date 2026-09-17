# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2.6 - Session Persistence (general-track; future clone strategy)
**Type:** Feature
**Status:** Closed

## Objective

Consolidate the shared delivery first step across copy and mount, and add a `--flatten` flag that switches between full-history (native `.git` copy, the default) and flattened-history (git-init baseline) delivery for both modes.

## Scope

- `src/capability/snapshot.sh` -- shared enumeration + a delivery dispatcher.
- `src/capability/seed_volume.sh` -- flatten branch in the copy seeder.
- `scripts/run_agent.sh`, `scripts/start_agent.sh`, `scripts/resume_agent.sh` -- `--flatten` ingestion, forwarding, and resume recovery.
- `src/build/compose.sh`, `docker-compose.copy.yml`, `docker-compose.mount.yml` -- FLATTEN record stamping.
- `src/capability/entrypoint.sh` -- mount validation branches on FLATTEN.
- `scripts/templates/Makefile.template` -- `FLATTEN` variable.
- Judgment-language strip in `docs/adr/sandbox_delivery_model.md`, `docs/concepts/mount_delivery.md`, `devlog/roadmap.md`.
- Tests for the new primitives, seeder flatten, resume recovery, overlay stamping, and flag acceptance.

## Carried forward

| Item | From handover |
|---|---|
| None. | |

## Acceptance criteria

1. `snapshot.sh` exposes `snapshot_enumerate_worktree`, `snapshot_copy_git`, `snapshot_baseline_init`, and `snapshot_deliver`, with `snapshot_copy_worktree` consuming the shared enumeration.
2. The duplicated enumeration in `seed_volume.sh` is removed.
3. `--flatten` is a real flag on both start and run_agent, forwarded explicitly, never read from ambient env downstream.
4. Resume recovers FLATTEN from the session record (invalid literals fail closed).
5. Mount materialization uses `snapshot_deliver`; a reused worktree refuses a delivery-history-mode mismatch.
6. Mount and copy both default to full history; `--flatten` is the opt-out.
7. The ADR/mount-concept big-repo judgment language is stripped, replaced by a neutral caveat.
8. All tests pass.

## Hot files

| File | Why in scope |
|---|---|
| [`src/capability/snapshot.sh`](../../src/capability/snapshot.sh) | shared enumeration + delivery dispatcher |
| [`src/capability/seed_volume.sh`](../../src/capability/seed_volume.sh) | flatten seed branch |
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | `--flatten` flag + forward |
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | ingestion + mount materialization branch |
| [`scripts/resume_agent.sh`](../../scripts/resume_agent.sh) | FLATTEN recovery from record |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | mount validation branches on FLATTEN |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Both copy and mount default to full history; `--flatten` is the opt-out | a flatten default would make mount-big-repo the implicit rule; the operator chose full-by-default with a caveat, not a prescription about what large repos can do | run_agent.sh, ADR |
| `--flatten` is ingested once at the boundary and forwarded as an argument | same rule as DELIVERY: internal functions take an argument; ambient env is never a source | run_agent.sh, resume_agent.sh |
| FLATTEN is recovered from the session record on resume | persist and re-consume, identical to delivery; records before the contract default to full | resume_agent.sh |
| The mount worktree records its delivery-history mode in `.git/config` (`agent-sandbox.flatten`) | reuse must detect a later mode mismatch deterministically, not infer from commit count | start_agent.sh |
| Full-history primitives are named copy/sync, never "clone" | `git clone` was rejected in the ADR (drops reflogs/stashes, autocrlf); the full path is `cp -a .git`. The dispatcher is a delivery dispatcher, not a clone | snapshot.sh |
| The seed routes both modes through the shared delivery dispatcher (`snapshot_deliver`); the tar transport is deleted | one enumerated list, two sinks was the duplication the consolidation removes; rsync no-ops on an empty enumeration | seed_volume.sh, ADR 2026-09-12 entry |
| Unborn-HEAD is a universal refusal, not a flatten tolerance | the harness session-env gate requires commits for every session before delivery dispatch; the seed and mount guards are the delivery-layer statement of the same invariant | ADR 2026-09-12 entry |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The `post-close bookkeeping` big-repo judgment ("mount is the designed answer for repos where copying is the problem -- no copy at all") became wrong once mount copies `.git` by default | contradiction | stripped; replaced with a neutral slow-by-construction caveat |
| `test_runner_selftest.sh` emits a FATAL ("run_test registered after test_done") that is pre-existing on a clean tree and unrelated to this change | bug (pre-existing, flagged) | not fixed this iteration; separate investigation |
| The ADR tree, architecture docs, and several test comments pinned the deleted tar/docker-cp transport as current mechanism | doc-contract drift (found by the review pass, rounds 1-8) | all current-write pins updated to the dispatcher/helper-seeder mechanism; historical ADR records retain the old text as decision history |

## Review pass outcome

Autonomous review pass per `review-pass-run.md`: 8 rounds, converged to APPROVE at round 8. Fresh subagent per round over `86ed60d..HEAD`. Blocker history (all closed by fixes in the diff):

- R1 (BLOCK): flatten seed verification compared only a clean worktree, not the committed set vs source enumeration (B1); seed main carried two delivery pipelines with a duplicated SESSION_STATE block (B2); unborn-HEAD full mount silently wrote an empty init_sha (B3).
- R2 (BLOCK): docs pinned the deleted tar pipeline; mount_delivery contradicted itself on who places `.git`; the rejected "clone" word described the dispatcher in six places; an unmarried "flatten tolerates" claim.
- R3 (BLOCK): two "clone" labels survived; "flatten tolerates" residue; orphaned "wired, not runnable" pins in three files.
- R4 (BLOCK): project_index pinned the tar pipeline.
- R5 (BLOCK): snapshot.sh enum comment said "copy seed tar".
- R6 (BLOCK): five stale transport comments (start_agent mount block, compose overlay SEED_TRANSPORT claim, and three test comments).
- R7 (BLOCK): dead docker-cp stub case.
- R8 (APPROVE): all blockers verified closed; mechanism sound end-to-end; suite 800/800 green.

Non-blocking observations folded during the pass: run_agent seed message genericized (parity phrasing is full-mode-only); the docker-cp stub case removed; grammar and index-warmth fixes. Remaining observations for operator triage: the start_agent mode-mismatch message mislabels a corrupt (non-boolean) recorded key as "full" (refusal still fires); entrypoint/execution_model keep the file's pre-existing em-dash style; resume does not cross-check FLATTEN against the worktree's recorded mode (behaviorally benign).

## Completed

| File | Change |
|---|---|
| `src/capability/snapshot.sh` | `snapshot_enumerate_worktree`, `snapshot_copy_git`, `snapshot_baseline_init`, `snapshot_deliver` added; `snapshot_copy_worktree` refactored onto the shared enumeration |
| `src/capability/seed_volume.sh` | `enumerate()` duplicate removed; both modes route through `snapshot_deliver`; `verify_baseline` compares committed set vs source enumeration; `session_state_write_set` shared; tar/cp-a layer blocks deleted; universal unborn-HEAD guard; empty-enumeration no-op |
| `scripts/run_agent.sh` | `--flatten` flag; FLATTEN exported for record stamping; genericized seed message |
| `scripts/start_agent.sh` | `--flatten` ingestion + forward; mount materialization via `snapshot_deliver` without commit-count inference; worktree flatten-config marker + mismatch/legacy refusal; unborn-HEAD guard |
| `scripts/resume_agent.sh` | FLATTEN recovered from record; invalid literal rejected; forwarded |
| `scripts/templates/Makefile.template` | `FLATTEN_FLAG` (truthy-value check); help text |
| `src/build/compose.sh` | `{{FLATTEN}}` stamping |
| `src/build/docker-compose.copy.yml` | `FLATTEN` env on sandbox + `SEED_FLATTEN` on seeder; SEED_TRANSPORT claim removed |
| `src/build/docker-compose.mount.yml` | `FLATTEN` env on sandbox |
| `src/capability/entrypoint.sh` | mount init_sha branches on FLATTEN (full = host HEAD; flatten = baseline root); fail-closed on empty init_sha; dispatcher comment |
| `docs/architecture/sandbox_lifecycle.md`, `execution_model.md`, `security.md`, `docs/concepts/mount_delivery.md`, `docs/development/project_index.md` | judgment strip; dispatcher mechanism; runnable status; "wired, not runnable" pins retired; transport-neutral wording |
| `docs/adr/sandbox_delivery_model.md` | 2026-09-12 entry (dispatcher, flatten, universal unborn-HEAD); judgment stripped; tar edge marked superseded |
| `devlog/roadmap.md` | M2.6.6 path description neutralized; thread notes the mechanism landed |
| `workflow/coding-agent/prompts/review-pass-run.md` | 20-minute default timeout + resume-interrupted-command note |
| tests | 13 new registrations: deliver full/flatten primitives (3), flatten seeder baseline + dropped-file detection (2), resume invalid/valid FLATTEN (2), overlay FLATTEN stamp (1), start_agent flatten/materialization/mismatch/legacy/unborn (4), run_agent flag acceptance (1) |

## Deferred items

None.

## What's Next

M2.6 - Session Persistence (general-track).

Roadmap maintenance: not applicable this iteration (general-track item; no submilestone closed).

Blocking design questions the next agent must resolve before advancing:

- None in this iteration. The deferred clone-strategy thread's next step is git-based port-back (common ancestor with PROJECT_DIR) using the full-history worktree that now crosses by default -- not active delivery.

**Conclusions from this iteration:** the copy and mount delivery paths shared a git-enumeration primitive that was written twice; consolidating it behind a `snapshot_enumerate_worktree` single owner and a `snapshot_deliver` delivery dispatcher removed the duplication and let a single `--flatten` switch serve both modes. Full history is now the default for both; flatten is the documented opt-out for the large-repo case, stated as a caveat rather than a rule. The autonomous review pass took 8 rounds to converge; every blocker was a mechanism or text-consistency defect closed by a fix in the diff.
