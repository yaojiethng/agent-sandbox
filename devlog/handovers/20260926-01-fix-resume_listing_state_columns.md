# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Fix the resume session table: under the standard `make resume LIST=1` / `INTERACTIVE=1` contract, every session's STATE cell read `not in tree` and the branch hint read `(absent)`, even for a session started minutes earlier on the current branch at the current HEAD (operator report, 2026-09-26).

## Scope

`scripts/resume_agent.sh` (render-time project-dir resolution) and `tests/test_resume.sh` (regression coverage). No change to the dispatcher: resume stays sandbox-only, per ADR `env_resolution.md` and review correction 8.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| `make resume INTERACTIVE=1` shows the true commit distance for a fresh session and the real branch hint | reproduction against a sandbox-only invocation (only `--sandbox` + `.env`) | Agent [x] - `0 commits ago` and `current branch: main` under the make contract |
| The sandbox-only listing contract holds: `--list` on a sandbox without a `.env` still enumerates records and degrades to `not in tree` | reproduction with the `.env` removed | Agent [x] |
| Explicit `--project` still wins over the `.env` | reproduction passing `--project` | Agent [x] - identical rows via both paths |
| Regression tests cover the .env-only path for `--list` and `--interactive`, and the no-`.env` degradation | `tests/test_resume.sh` | Agent [x] - 3 new units (26 total in the file, 0 failed) |
| Suite green | `bash scripts/run_tests.sh` | Agent [x] - 802 units, 64 files, 0 failed, 0 skipped (11s) |
| Lint clean | `bash scripts/lint.sh` | Agent [x] - 3 gates, 0 findings |
| Roadmap write-back | `devlog/roadmap.md` | none worked this iteration - standalone operator-reported fix with no roadmap row |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/resume_agent.sh`](../../scripts/resume_agent.sh) | sources `env_resolve.sh` and enriches `PROJECT_DIR` from the sandbox `.env` before the list/interactive render |
| [`tests/test_resume.sh`](../../tests/test_resume.sh) | three new units pinning the .env-only path and the no-`.env` degradation |
| [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) | operator-raised entry recording the render-contract finding |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix at the leaf, not the dispatcher | resume is sandbox-only by recorded contract (ADR `env_resolution.md`, review correction 8); the listing must keep working as a registry diagnostic on a bare sandbox dir. The leaf enrichs `PROJECT_DIR` from the `.env` when `--project` was omitted, and degrades to the `not in tree` / `(absent)` cells when the project dir is genuinely unavailable. | this handover |
| Enrichment reuses the canonical resolver primitives | `default_env_file` + `env_resolve_one` keep one precedence (explicit flag, `AGENT_SANDBOX_PROJECT_DIR` env var, `.env` key) instead of a bespoke parse. The resume proper still re-resolves with a hard error via `session_env_common_init` after the picker, so the strict path is unchanged. | `scripts/resume_agent.sh` |
| No capacity change to the dispatcher or the docs table column | the ADR and the sandbox-only contract stay; only the render's inputs changed. | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The STATE/current-branch columns (2026-09-20) landed after resume became sandbox-only (2026-09-18) without re-checking the render's identity inputs; every resume test passed `--project` explicitly, so the make-contract path was never exercised | regression | fixed here; recorded in `devlog/AGENT_FEEDBACK.md` as an `[O]` guidance entry |
| `docs/architecture/tool_interface.md` documents the resume table with the retired columns (`SESSION_ID \| PROVIDER \| STARTED \| BRANCH \| LAST_USED`); the actual table reads `SESSION \| PROVIDER \| BRANCH \| AGE \| WORK \| STATE` | doc drift | out of scope for this fix; surfaced for a docs lane |

## Completed

| File | Change |
|---|---|
| `scripts/resume_agent.sh` | `source env_resolve.sh`; `PROJECT_DIR` enrichment from the sandbox `.env` before the dispatch (list + interactive render), tolerant of a missing `.env` |
| `tests/test_resume.sh` | three units: `test_list_env_resolves_project_dir_when_sandbox_only`, `test_interactive_env_resolved_branch_hint`, `test_list_sandbox_only_without_env_degrades` |
| `devlog/AGENT_FEEDBACK.md` | `[O] 2026-09-26` entry: a render feature must respect its command's identity-resolution contract |

## Deferred items

| Item | Reason | Where it goes |
|---|---|---|
| `docs/architecture/tool_interface.md` resume-table column drift | unrelated to this defect; the table was already stale before this fix | a docs lane |

## What's Next

None from this fix. The roadmap is untouched; the operator's next scheduled step is the M3.1 close review gate.
