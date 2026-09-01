# Agent Handover

**Date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Type:** Implementation — Remove package-diff
**Status:** Active

## Objective

Delete the redundant `package-diff` skill and all associated code, docs, and tests. Consolidate on `package-branch` as the single diff packaging mechanism.

## Scope

Per [`design_remove_package_diff.md`](../../devlog/discussions/design_remove_package_diff.md):

- Delete `package_diff.sh`, `package-diff.md` prompt, `test_package_diff.sh`
- Remove `package-diff` from CLI dispatch, preflights, AGENTS.md, Makefile template
- Remove `diffs` channel from `resolve_channel_base_dir`
- Clean all references from docs and knowledge tests
- Delete superseded discussion docs: `story_diff_pipeline_unification.md`, `design_unified_path_derivation.md`

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `package_diff.sh`, `package-diff.md`, and `test_package_diff.sh` are deleted | `ls` — files absent | |
| 2 | No remaining `package-diff` or `package_diff` references in code or docs | `grep -rn` across repo | |
| 3 | `diffs` channel removed from `resolve_channel_base_dir` | `grep` in routing.sh | |
| 4 | All shell scripts pass `bash -n` | `bash -n` on every changed .sh file | |
| 5 | Existing tests pass: `test_routing.sh`, `test_dispatch.sh`, `test_package_branch.sh`, `test_diff_dispatch.sh` | `bash tests/test_*.sh` | |
| 6 | `make draft` and `make apply` continue to work with `session`, `autosave`, `bundles` channels | Manual | Operator |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/package_diff.sh`](../../src/libs/package_diff.sh) | Delete — redundant |
| [`src/reasoning/agent/prompts/package-diff.md`](../../src/reasoning/agent/prompts/package-diff.md) | Delete — agent prompt |
| [`tests/test_package_diff.sh`](../../tests/test_package_diff.sh) | Delete — tests for removed script |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Remove dispatch case |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | Remove preflight check |
| [`src/reasoning/entrypoint.sh`](../../src/reasoning/entrypoint.sh) | Remove preflight check |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | Remove tool reference |
| [`src/libs/routing.sh`](../../src/libs/routing.sh) | Remove `diffs` channel |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | Remove `package-diff` target |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | Remove dispatch test |
| [`devlog/discussions/story_diff_pipeline_unification.md`](../../devlog/discussions/story_diff_pipeline_unification.md) | Delete — superseded |
| [`devlog/discussions/design_unified_path_derivation.md`](../../devlog/discussions/design_unified_path_derivation.md) | Delete — superseded |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `src/libs/package_diff.sh` | Deleted |
| `src/reasoning/agent/prompts/package-diff.md` | Deleted |
| `tests/test_package_diff.sh` | Deleted |
| `devlog/discussions/story_diff_pipeline_unification.md` | Deleted — superseded |
| `devlog/discussions/design_unified_path_derivation.md` | Deleted — superseded |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Removed `package-diff` dispatch case, help text, validation |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | Removed `package_diff.sh` from preflight |
| [`src/reasoning/entrypoint.sh`](../../src/reasoning/entrypoint.sh) | Removed `package_diff.sh` from preflight |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | Removed `/package-diff` from tool list; updated `/package-branch` description |
| [`src/libs/routing.sh`](../../src/libs/routing.sh) | Removed `diffs` channel from `resolve_channel_base_dir` and comments |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | Removed `package-diff` target; updated channel docs; changed apply default to `session` |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | Removed `package-diff` dispatch tests |
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | Updated apply/resolver tests to use `session` channel instead of `diffs`; removed `diffs` channel test |
| [`tests/knowledge/diagnose_dry_run_reasoning.sh`](../../tests/knowledge/diagnose_dry_run_reasoning.sh) | Removed `package_diff.sh` from lib check |
| [`tests/knowledge/diagnose_dry_run_capability.sh`](../../tests/knowledge/diagnose_dry_run_capability.sh) | Removed `package_diff.sh` from lib check |
| [`tests/knowledge/knowledge_binary_diff_apply.sh`](../../tests/knowledge/knowledge_binary_diff_apply.sh) | Removed `package_diff.sh` reference |
| [`tests/knowledge/knowledge_draft_confirm_lock_trace.sh`](../../tests/knowledge/knowledge_draft_confirm_lock_trace.sh) | Removed mock `package_diff.sh` creation |
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | Replaced `package-diff` references with `package-branch` |
| [`docs/concepts/sandbox_identity.md`](../../docs/concepts/sandbox_identity.md) | Removed `package_diff` from RUN_ID consumer list |
| [`docs/concepts/context_resolution.md`](../../docs/concepts/context_resolution.md) | Removed `package_diff.sh` from layer descriptions |
| [`docs/architecture/system_overview.md`](../../docs/architecture/system_overview.md) | Removed `package-diff` mention |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Replaced `make package-diff` section with `make package-branch` |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Removed `make package-diff` section; consolidated into `make package-branch` |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Removed `package_diff.sh`, `test_package_diff.sh`, `package-diff.md` entries |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | Updated `/package-diff` → `/package-branch` |
| [`devlog/discussions/design_apply_workflow_and_baseline_advancement.md`](../../devlog/discussions/design_apply_workflow_and_baseline_advancement.md) | Updated superseded story link |
| [`scripts/onboard.sh`](../../scripts/onboard.sh) | Updated `package-diff` → `package-branch` in help text |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox (cleanup)

**Blocking design questions:** None.

**Conclusions from this session:** TBD
