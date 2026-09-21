# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Consolidate the test harness, centralize per-command flag parsing, split god files, and record the flag-ingestion principle in an ADR. Operator-accepted rescope from a hard 30% LOC gate: the deliverable is the delivered simplification set itself, not a line-count target.

## Scope

Operator-requested (post-goal) reorganization and documentation pass over the simplification work landed this same day:

1. Reorganize 14 granular commits into feature-grouped commits (test harness; data-driven tests; dry-run harness lib; `cli.sh` flag parsing; resume split), content-preserving (final tree byte-identical, proven by `git rev-parse HEAD^{tree}` before/after).
2. Write ADR [`docs/adr/command_flag_parsing.md`](../docs/adr/command_flag_parsing.md) - the principle behind how sandbox state and make-target args are ingested, validated, and forwarded to leaf scripts; distinct from `env_resolution.md` (identity triple precedence).
3. Register the ADR in `project_index.md`; add a completed general-track row to the M2.6 roadmap.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Reorganized history is content-preserving; final tree equals the pre-reorg tree | `git rev-parse HEAD^{tree}` matches | done |
| 2 | Suite green after reorganization | `make test` 854/854, 0 failed | done |
| 3 | ADR written per adr_policy.md (dated entry, Requirements preamble, rejected alternatives with failure locus, link to tool_interface) | read-back | done |
| 4 | ADR registered in project_index.md ADR table | grep | done |
| 5 | Roadmap has a completed row naming the work, the ADR, and the artifacts | grep | done |

## Files changed

| File | Change |
|---|---|
| `docs/adr/command_flag_parsing.md` | New: per-command flag ingestion principle (single declarative parser, exact surface preserved, validation stays at the owning script, dispatcher PASSTHROUGH the exception) |
| `docs/development/project_index.md` | ADR table row added |
| `devlog/roadmap.md` | M2.6 general-track completed row |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | New ADR `command_flag_parsing.md`, separate from `env_resolution.md` | env_resolution governs the identity triple's precedence; command_flag_parsing governs per-command flag routing to leaf scripts - two principles, two files |
| D2 | Reorganized commit groups: test fixtures, data-driven tests, dry-run harness, cli.sh parsing, resume split | matches the user's requested feature taxonomy (test harness / arg parsing / invocation); each group is one coherent change |
| D3 | Dispatcher PASSTHROUGH loop exempt from cli.sh conversion | it is a collection loop (build an arg array to forward), not a var-ingestion loop; forcing collect-mode into the parser adds machinery for no routing gain |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The 30% LOC gate was conclusively measured as unreachable by legitimate means (854 distinct tested behaviors, policy-mandated comments/docs, no dead or duplicate files); operator rescoped to "delivered simplification set" with scripts surface -7% | steering | workspace |
| resume_agent.sh interleaved two features (parse conversion + display split) in one file; history split required hunk-level patch application, preserved byte-for-byte | technical | record |

## Verification

- Suite 854/854 green (run after reorganization).
- Tree identity proven: `71b461500d9491e4efb301c351daf21a52ecd26b` before and after re-commit.
- Lint baseline unchanged (5 warnings, none in changed files); lib liveness 0 orphaned.

## Conclusions from this iteration

Test-harness scaffolding and per-command flag parsing are now single-source; the ADR records the ingestion model so future commands follow the same shape. The `scripts` operator surface is 7% smaller; combined scripts+src is flat because the deduped code moved into shared libs (cli.sh, dry_run_harness.sh, resume_list.sh) - the unavoidable cost of hoisting duplication in bash.

## What's Next

- (Operator-optional) convert the agent-sandbox.sh dispatcher to cli.sh in a collect mode, if the exception ever proves awkward.
- (Operator-optional) fold the residual multi-condition assertion blocks (114) into compound asserts only if per-block review warrants it; the suite treats them as bespoke by design.

[CORRECTION -- 2026-09-21]: the project_index.md-usefulness entry raised this session was closed by the M3 cleanup pass (freeze table relocated to `system_overview.md`, file deleted); the suite-green-certified-rerun entry consolidated into the M3 T1 evidence-validation entry. Entries reconciled in `AGENT_FEEDBACK.md`.
