# Agent Handover

**Session date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Impl
**Status:** Closed

## Objective

Resolve the `require_run_args` naming inconsistency. Split the function into two smaller validators (`require_base_args`, `require_provider_args`) so `build` can reuse the base check without triggering a spurious `--provider` error. All subcommands use the same validation pattern.

## Scope

- `scripts/agent-sandbox.sh`: split `require_run_args()` into `require_base_args()` and `require_provider_args()`

## Carried forward

- `require_run_args` naming consistency (from handover 07)

## Hot files

- `scripts/agent-sandbox.sh`

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `require_run_args` no longer exists | `grep -c "^require_run_args" scripts/agent-sandbox.sh` = 0 | Agent |
| 2 | `require_base_args` defined and used by build, start, serve, dry-run | `grep -c "require_base_args" scripts/agent-sandbox.sh` ≥ 4 | Agent |
| 3 | `require_provider_args` used by start, serve, dry-run | `grep -c "require_provider_args" scripts/agent-sandbox.sh` ≥ 3 | Agent |
| 4 | Syntax checks pass | `bash -n scripts/agent-sandbox.sh` — OK | Agent |
| 5 | Full suite passes | `bash scripts/run_tests.sh` — 0 failed | Agent ✅ |

## Completed this session

| File | Change summary |
|---|---|
| `scripts/agent-sandbox.sh` | Split `require_run_args()` into `require_base_args()` and `require_provider_args()`. `build` now uses `require_base_args` instead of inline validation. `start`/`serve`/`dry-run` call both. |

## Deferred items

None.

## Next session

M2.7 — remaining items from thermo-nuclear review (code-judo, skill placement)

## Post-close findings — Process Learnings

Reflection on the multi-session workflow across the dispatch refactoring produced these findings:

| Finding | Description | Triaged to |
|---|---|---|
| Gate 1 + Gate 2 two-step overhead for mechanical sessions | For purely mechanical changes (guard pattern hardening, `set -euo pipefail` cleanup), both gates confirm what is already obvious from the scope. The pair adds ~2 turns of overhead before any code changes. A fast-track option for chore/mechanical sessions that collapses or skips Gate 2 would reduce overhead. | `docs/operations/iteration_policy.md` — consider fast-track criteria |
| Decision rationale captured at close, not inline | Design decisions made during grilling (e.g. exec dispatch design, build.sh dual-caller semantics) were recorded in the Decisions table only at session close. During the session, chat history was the only record. By the next session's orient step, the rationale was accessible only by re-reading chat. Updating the Decisions table inline as decisions are made would improve context handover for the next agent. | `docs/operations/handover_policy.md` — consider inline-update recommendation |
| `improve-codebase-architecture` skill references `subagent_type=Explore` tool that does not exist | The skill's process step says "use the Agent tool with `subagent_type=Explore`". No such tool exists in this harness. The exploration was done manually with grep/wc/read, which was adequate but the skill describes a capability that does not exist. | `src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md` — update or remove the reference |
