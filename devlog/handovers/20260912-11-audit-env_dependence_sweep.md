# Handover 20260912-11: audit -- env-dependence sweep

## Status

Closed

## Type

audit

## Milestone

M2.6.6 (post-list close) -- operator-directed audit iteration

## Scope

The codebase audit registered in handover `20260912-10` (Finding: env-dependence defect class). Sweep six variables for ambient-environment reads that should be command inputs, persisted config, or safe defaults: `RESET_VOLUME`, `WORKTREE_DIR`, `INTERACTIVE_MAX_ENTRIES`, `SERVE_PORT`, `AGENT_CMD`, `AUTOSAVE_INTERVAL`.

Operator-directed procedure (three steps):

1. Offline audit; ephemeral report file listing every occurrence site with a classification (command input / persisted config / safe default / defect).
2. Candidate change fixing the defects found.
3. Review-pass-run (fresh subagent, thermo-nuclear standard) validating the changes.

Housekeeping directed by the operator:

- A leftover-session reference in the durable records is operator-owned housekeeping; the reference was removed from the past handover text. Do not act on any operator-host session.
- This is the last task of the day; the iteration must end on a clean slate (single typed commit, tree clean, roadmap current).

## Out of scope

- Any session cleanup on the operator's host.
- Anything beyond the six variables under audit.
- Broader config-surface redesign.

## Plan

| # | Step | Status |
|---|---|---|
| 1 | Remove the leftover-session reference from the durable records | done -- past handover amended (roadmap had none) |
| 2 | Grep sweep; ephemeral report `env_dependence_audit_report.md` (untracked) with per-site classification | done -- 6 variables classified, no hard defects, 2 fixable findings |
| 3 | Candidate fixes (defect sites only) + tests | done -- SERVE_PORT warning gated to serve mode; default 46553 documented; test split into standard-quiet + serve-warns |
| 4 | Review-pass-run to APPROVE | done -- APPROVE round 1; 2 comment nits folded |
| 5 | Roadmap write-back, handover close, single typed commit | done |

## Completed

| Task | Result |
|---|---|
| Leftover-session reference removal | Handover `20260912-10` defect-table row amended to operator-owned housekeeping without the session id; roadmap had no mention |
| Audit sweep | All six variables classified; every ordering claim verified (session_env before WORKTREE_DIR use, common.sh before INTERACTIVE_MAX_ENTRIES read, RESET_VOLUME ambient-free) |
| SERVE_PORT fixes | Warning gated to serve mode (resolution stays -- the serve echo needs the value); tool_interface env table documents default 46553 (gap known since handover `20260912-09`) |
| Review pass | 1 round, APPROVE; test-comment narration trimmed, "non-serve modes" wording adopted |
| Roadmap | New completed row for the env-dependence audit adjacent to the mount-runnability row |

## Decisions

| Decision | Rationale |
|---|---|
| Report is ephemeral (untracked, removed before the delivery commit) | Same pattern as the Pass A readiness report in iteration `20260912-10`; durable results live in this handover. |
| Gate the SERVE_PORT warning, keep unconditional resolution | The serve-mode echo needs a resolved value; moving resolution into the serve branch would trade an invariant for a nested-if, for zero behavior change (reviewer-concurred). |
| Split the SERVE_PORT test instead of parameterizing the mode | One behavior per test; the serve path was already proven runnable under the docker stub by test_trace_start. |

## Findings

- The defect class the audit hunted (ambient env deciding mode/config downstream, per bash-conventions 1.13) is absent from all six surfaces. Iteration `20260912-10` had already removed the one real instance (`SANDBOX_TYPE`).
- Classifications: RESET_VOLUME command input (compose-literal transport); WORKTREE_DIR persisted config (`.env` / make var / default, three documented sources); INTERACTIVE_MAX_ENTRIES safe default (internal paging tunable); SERVE_PORT persisted config; AGENT_CMD container-boundary override hook with provider-table-derived default; AUTOSAVE_INTERVAL persisted config.
- Minor (deferred): the `<sandbox>/.worktree` default string is duplicated (session_env l.113, run_agent l.185); the 46553 cross-file equality (run_agent default == provider serve overlay fallbacks) is documented but pinned by only one side of the pair.
- Pre-existing convention validated: `env_field`-style record parsing and the `.env` wholesale loader (session_env) keep ambient reads confined to documented config channels.

## Deferred items

- One-line grep test pinning that every `docker-compose.serve.yml` fallback equals `SERVE_PORT_DEFAULT` (reviewer item 4; closes the documented-but-half-pinned invariant).
- Consolidate the duplicated `WORKTREE_DIR` default string into one definition (cosmetic; two sites, same value).
- SERVE_PORT resolution consolidation with the serve-branch: rejected this round (reviewer structural assessment); revisit only if the serve path grows more SERVE_PORT consumers.
