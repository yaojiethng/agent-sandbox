# Agent Handover

**Session date:** 2026-06-09
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Implement M2.7 Track A item 2 — Image naming with SANDBOX_ID. Update image naming functions to accept optional `sandbox_id`, propagate through build pipeline, remove superseded `worktree_id_derive()`.

## Recovery checks

| Check | Result |
|---|---|
| Roadmap reflects prior handover state | ✅ Prior handover (20260609-01) is Closed; item 1 marked `[x]` in roadmap |
| Trigger B pending | ✅ None pending |

## Scope

**In scope — this session:**

1. **`src/build/image.sh`** — `sandbox_image_name()` and `agent_image_name()` accept optional `sandbox_id` arg; when present return names with `-<sandbox_id>` suffix. Remove `worktree_id_derive()`.
2. **`scripts/start_agent.sh`** — Pass `$SANDBOX_ID` to image name calls.
3. **`scripts/build.sh`** — Propagate `SANDBOX_ID` through `build_sandbox`, `build_agent`, `preflight`.
4. **Tests** — Replace `worktree_id_derive` tests with SANDBOX_ID tests in `test_start_agent.sh` and `test_checkpoint.sh`.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| A | Optional `sandbox_id` arg — backward-compatible when omitted | Existing callers (dry-run, tests) that don't pass `sandbox_id` continue to work unchanged |
| B | `SANDBOX_ID` export in `start_agent.sh` already present from item 1 | No additional export needed; just pass it as argument |

## Completed this session

| File | Change |
|---|---|
| `src/build/image.sh` | `sandbox_image_name()` and `agent_image_name()` accept optional `sandbox_id` arg; removed `worktree_id_derive()`. |
| `scripts/start_agent.sh` | Pass `$SANDBOX_ID` to `sandbox_image_name` and `agent_image_name`; pass `--sandbox-id` flag to `build_sandbox`, `build_agent`, `preflight`. |
| `scripts/build.sh` | `build_agent`, `build_sandbox` switched to named flags (`--uid`, `--gid`, `--sandbox-id`). `preflight` accepts `--sandbox-id` arg. `main()` derives SANDBOX_ID from SANDBOX_DIR and HOST_HEAD_SHA. |
| `tests/test_checkpoint.sh` | Replaced `worktree_id_derive` tests with SANDBOX_ID derivation tests (5 tests, including different-commits). |
| `tests/test_start_agent.sh` | Replaced WORKTREE_ID tests with SANDBOX_ID derivation tests (3 tests). |

## Deferred items

| Item | Why deferred | Next session |
|---|---|---|
| Track A item 3: Container naming with RUN_ID | One item per session | Next implementation session |
| Track A item 4: Docker labels | One item per session | After item 3 |
| Track A item 5: SESSION_STATE host_head_sha | One item per session | After item 4 |
| Track A items 6–8 | One item per session | Sequential |
| BRANCH_FROM_ARG default unification | Needs design | After Track A |
| package-branch/package-diff variable unification | Needs design | Unscheduled |
