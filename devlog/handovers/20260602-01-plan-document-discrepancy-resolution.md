# Agent Handover

**Date:** 2026-06-02
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Plan
**Status:** Active

## Objective

Resolve the document discrepancy between the three-layer identity spec (`spec_identity_three_layer_model.md`), the roadmap, and the missing `design_session_identity_hash_based.md` document. Determine canonical document placement, supersession relationships, and produce an agreed plan for Track A implementation that is consistent across all three sources.

## Recovery checks

| Check | Result |
|---|---|
| Roadmap reflects prior handover state | ✅ Pass — M2.7 is Active; prior handover closed cleanly with no Trigger B |
| Trigger B pending | ✅ None pending |

## Scope

This session targets M2.7 Track A's document layer: resolving the specification sources before any implementation begins. No implementation code.

## Hot files

| File | Reason |
|---|---|
| `docs/architecture/spec_identity_three_layer_model.md` | Moved from `docs/discussions/` by subagent; needs placement validation |
| `devlog/roadmap.md` (M2.7 section) | Track A task list may diverge from spec |
| `docs/discussions/design_session_identity_hash_based.md` | Documented in handover chain as existing but never on mainline; references now rewritten |
| `docs/concepts/sandbox_host_correspondence_model.md` | Identity table references WORKTREE_ID — needs update |

## Completed this session

*(No files changed yet — placeholder.)*

## Carried forward

| Item | Source |
|---|---|
| package-branch and package-diff working-context variable unification | 20260530-04 mid-session finding — deferred (needs design) |

## Decisions

Decisions reached via grill-me — see chat log for full reasoning.

| # | Decision | Rationale |
|---|---|---|
| A | Adopt tiered identity model: `SANDBOX_ID = sha256(SANDBOX_DIR:HOST_HEAD_SHA)[:8]`, `RUN_ID = sha256(SESSION_TS:SANDBOX_ID)[:6]` | Supersedes flat `REPO_COMMIT:WORKTREE_ID` model |
| B | Rename `REPO_COMMIT` → `HOST_HEAD_SHA` | Clearer name, same value |
| C | Include image naming in design doc (`sandbox-<project>-<SANDBOX_ID>`, `<provider>-agent-<project>-<SANDBOX_ID>`) | Closes image collision gap |
| D | Label keys: `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir` | Aligned with tiered model; uses `SANDBOX_DIR` as identity factor |
| E1 | Session export paths: `<SESSION_TS>-<BRANCH>-<RUN_ID>` | `SESSION_TS` as sort key, `RUN_ID` for identity |
| E2 | Output export paths: replace optional `SESSION_TS` suffix with `RUN_ID` | `EXPORT_TIME` already serves as sort key |
| E3 | Draft branch name: `draft/<RUN_ID>-<BRANCH_SLUG>-<FROM_SHA:0:6>` | `RUN_ID` uniquely identifies session; `FROM_SHA` for operator override disambiguation |
| F | `make stop` filter: `project-name` + `sandbox-dir` labels | Aligned with adopted label schema |
| G | `make prune` filter: same as `make stop` | Consistent; revisit during implementation |
| H | Container-sig: mark as `POTENTIALLY_SUPERSEDED` | Independent of tiered model; may need adjustment after label schema changes |

## Mid-session findings

| Finding | Description | Triaged to |
|---|---|---|
| HOST_HEAD_SHA and BRANCH_FROM_ARG should be unified when HOST_HEAD_SHA is implemented | At draft time, `BRANCH_FROM_ARG` defaults to `HEAD` which may differ from `HOST_HEAD_SHA` (session-start HEAD) if the operator advanced the host repo between session end and draft creation. When `HOST_HEAD_SHA` is written to SESSION_STATE, `draft_run` should use it as the default for `BRANCH_FROM_ARG` instead of bare `HEAD`, so the draft branches from the correct session baseline by default. Operator override via `--branch-from` still permitted for advanced use. | M2.7 Track A — run_id derivation implementation |

## Next session

*(None yet — plan output pending.)*
