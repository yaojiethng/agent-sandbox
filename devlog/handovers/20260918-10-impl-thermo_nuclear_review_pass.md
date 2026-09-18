# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Run a thermo-nuclear code-quality review pass over `61ad078..HEAD` (20260917-01 env-parser hardening through the env-precedence feature delivery `4b88145`), using the `thermo-nuclear-code-quality-review` skill, once each under opencode-go's `glm-5.3-flash` (thinking high) and `deepseek-v4-flash` (thinking xhigh). Consolidate both runs' findings; the consolidated items become this iteration's scope / acceptance gates. Fix the accepted items; land the fixes at Gate 3.

## Scope

Review-then-fix iteration. Phase 1: run both model checks (before any fix work). Phase 2: consolidate findings into the AC table. Phase 3: implement fixes, verify, pre-close. The review is read-only for the subagents; implements land as commits here.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `default_env_file RAW SANDBOX_DIR` is parameterized (no hidden global); `session_env_common_init` and the dispatcher call it; the inline `.env`-path copies are deleted | grep, suite | done |
| 2 | `env_resolve_identity` owns fields-filter + relative-anchoring and exports normalized `ENV_FILE`; `resolve_identity` collapses to one call; `env_resolve_value` deleted; `env_resolve.sh` sourced at module top (test repoint hack removed) | suite, git grep | done |
| 3 | Dispatcher helpers hoisted out of `main()`; shared parsing reconciled with `common.sh` | bash -n, suite | done |
| 4 | One name for the raw `--env` value (`ENV_REL`); `ENV_FILE` = resolved path; `start_agent` usage text and ADR vocabulary correct | grep, suite | done |
| 5 | One parameterized `make_envfile` in `tests/libs/test_common.sh` used by all test files | suite | done |
| 6 | `session_env_common_init` takes `(name, dir, sandbox)`; callers updated | suite | done |
| 7 | Host-requirement lists cross-reference (comment contract) | grep | done |
| 8 | Trailing newlines on `install.sh`, `macos_bootstrap.sh` | bash -n | done |
| 9 | Full suite green; zero new shellcheck warnings vs baseline | run_tests.sh, shellcheck | done (847/847, rc=0) |

## Decision

| Decision | Rationale | Where recorded |
|---|---|---|
| Adopt the consolidated remedies verbatim (both models BLOCKed on the same class) | Two independent models converged; each remedy deletes duplication and sharpens the single contract | this handover |
| `default_env_file RAW SANDBOX_DIR` is the one .env-path rule; `session_env_common_init` and the dispatcher call it | R4-class bugs were born in the three inline copies | ADR `env_resolution.md` |
| The resolver owns the fields-filter and relative-anchoring; `session_env_common_init` takes `(name, dir, sandbox)` | One resolution algorithm; one argument order (name, dir, sandbox) across parser, dispatcher, and resolver | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Thermo-nuclear pass (skill, two models): deepseek-v4-flash xhigh -> BLOCK, glm-5.3-flash high -> BLOCK; consolidated 8 items, both blocking on the duplicated `.env`-path contract and the dispatcher's parallel resolver orchestration. All fixed this iteration | steering | design record |
| The fix surfaced a `shift 4` bug in `env_resolve_identity` (failing shift left empty fields, skipping the all-three default) - caught by the pre-existing suite once the resolver unchanged its shape | bug | fixed this iteration |
| Operator-steered visibility finding (prior iteration) remains open under M3: a `pi -p` run's progress is not observable; both fresh model runs had the same model-startup warnings followed by clean completion | steering | roadmap_future M3 |
| Procedural (operator-directed): run-context items (state the model/thinking level in the brief; capture to a log file; resume needs an explicit continuation prompt; startup warnings are noise) recorded into the seeded pi `AGENTS.md` subagent section; suggested models/thinking (`deepseek-v4-flash` xhigh, `glm-5.3-flash` high) added to `review-pass-run.md` and the thermo-nuclear skill | steering | pi AGENTS.md / skills / AGENT_FEEDBACK.md |
| Procedural (logged to AGENT_FEEDBACK.md): (a) round-cap framing fits correctness reviews, not model-consensus passes; (b) name the base commit/range in review directives; (c) "pi's AGENTS.md" is ambiguous between the runtime copy and the seeded source | steering | AGENT_FEEDBACK.md |

## Decision

Not yet defined.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `src/libs/env_resolve.sh` | `default_env_file RAW SANDBOX_DIR` parameterized (no hidden global); `env_resolve_one` single per-field primitive; `env_resolve_identity` owns fields-filter + relative-anchoring, exports normalized `ENV_FILE`; `env_resolve_value` deleted |
| `src/libs/session_env.sh` | `common_init` takes `(name, dir, sandbox)`, uses the resolver's `ENV_FILE` (inline path copy deleted) |
| `scripts/agent-sandbox.sh` | Top-level sources (no lazy source/test hack); helpers hoisted from `main()`; `parse_flags` reuses `parse_base_flags`; `resolve_identity` collapses to one resolver call; `ENV_PATH` -> `ENV_REL` |
| `scripts/start_agent.sh`, `scripts/resume_agent.sh` | Callers flipped to `(name, dir, sandbox)`; start usage text corrected |
| `tests/libs/test_common.sh` | Shared parameterized `make_envfile` |
| `tests/test_env_resolve.sh`, `tests/test_dispatch.sh`, `tests/test_session_env.sh` | Use the shared helper; harness pre-sets `AGENT_SANDBOX_REPO` (repoint hack and local `make_envfile` duplicates deleted); call order updated |
| `scripts/install.sh`, `scripts/macos_bootstrap.sh` | Trailing newlines; host-requirement cross-reference comments |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | Subagent run-context section: model/thinking-level hint, log-file capture, resume-with-prompt, benign-startup-warnings note |
| `src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md`, `workflow/coding-agent/prompts/review-pass-run.md` | Suggested models/thinking levels (deepseek-v4-flash xhigh; glm-5.3-flash high) |
| `devlog/AGENT_FEEDBACK.md` | Three class-A entries: round-cap framing, base-commit naming, seeded/runtime AGENTS.md terminology |

## Deferred items

None.

## What's Next

<Sub-milestone: M2.6 - Session Persistence>

**Conclusions from this iteration:** pending the two model checks.