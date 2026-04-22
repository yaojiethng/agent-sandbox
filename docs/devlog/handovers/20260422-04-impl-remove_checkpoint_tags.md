# Agent Handover

**Session date:** 2026-04-22
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Implement Unit B of M2.3 diff packaging unification: remove checkpoint git tag creation and pruning from the harness.

## Scope

Unit B from the M2.3 pending task list:

- Remove checkpoint git tag creation and pruning from `start_agent.sh`
- Remove tag creation, pruning, and lookup from `scripts/checkpoint.sh`; retain `WORKTREE_ID` derivation
- Remove `agent-sandbox.checkpoint-tag` from container labels
- Update `scripts/apply_workspace.sh` to use `HEAD` as default (FROM argument added in Unit E)

**Confirmed:** Aliases `checkpoint_worktree_id` and `checkpoint_latest` are unused and will be removed. `apply_workspace.sh` will default to `HEAD` when no checkpoint tag is available (FROM argument deferred to Unit E).

## Carried forward

None.

## Acceptance criteria

1. **No checkpoint tags created on session start** — Run `start_agent.sh` and verify no new `agent-checkpoint/*` tags are created. ✓ Accepted
2. **`checkpoint.sh` only contains `worktree_id_derive`** — Verify the file only has the worktree function. ✓ Accepted
3. **No checkpoint-tag label in docker-compose.yml** — Verify the label is removed. ✓ Accepted
4. **`make draft` uses HEAD as default** — Verify the script defaults to HEAD. ✓ Accepted

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | Remove checkpoint tag creation and CHECKPOINT_TAG export | ✓ Complete |
| [`scripts/checkpoint.sh`](scripts/checkpoint.sh) | Remove checkpoint_create, checkpoint_prune, checkpoint_lookup; retain worktree_id_derive | ✓ Complete |
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | Remove checkpoint tag lookup; default to HEAD | ✓ Complete |
| [`libs/compose.sh`](libs/compose.sh) | Remove CHECKPOINT_TAG template replacement | ✓ Complete |
| [`libs/docker-compose.yml`](libs/docker-compose.yml) | Remove agent-sandbox.checkpoint-tag label | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Aliases removed entirely | `checkpoint_worktree_id` and `checkpoint_latest` were unused | N/A — investigation finding |
| `make draft` defaults to HEAD | Checkpoint tag lookup removed; FROM argument deferred to Unit E | `scripts/apply_workspace.sh` |

## Completed this session

| File | Change summary |
|---|---|
| `scripts/start_agent.sh` | Removed CHECKPOINT_TAG export and checkpoint_create call |
| `scripts/checkpoint.sh` | Removed checkpoint_create, checkpoint_prune, checkpoint_lookup, and aliases; retained worktree_id_derive |
| `scripts/apply_workspace.sh` | Removed checkpoint tag lookup; defaults to HEAD for draft branch |
| `libs/compose.sh` | Removed {{CHECKPOINT_TAG}} template replacement |
| `libs/docker-compose.yml` | Removed agent-sandbox.checkpoint-tag label |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation.
**Trigger B:** Not pending — mid-milestone.

Next task is Unit C (`package-branch` function). Read the roadmap M2.3 pending section for the full unit list and dependency order. Implement Unit C only.

**Watch-outs:**
- Unit C depends on Unit A (INIT_SHA) — already complete
- `package_branch` iterates commits since INIT_SHA
- `package_diff` produces single diff to `workspace/output/changes.diff`
- Update `diff_on_exit` to call `package_branch`

Context handover: [`20260422-03-impl-init_sha_at_container_init.md`](handovers/20260422-03-impl-init_sha_at_container_init.md)
