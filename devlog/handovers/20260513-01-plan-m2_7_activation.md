# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Planning
**Status:** Closed

## Objective

Transition M2.5 (Vault Capability Layer Prototype) to deferred, promote M2.7 (Session Identity and Harness Versioning) to active, and document the audit findings that drove the decision.

## Scope

- Mark M2.5 as Deferred in roadmmap.md and summary table
- Promote M2.7 to Active in roadmmap.md and summary table
- Add settings.json ownership collision fix as a new work group (item 8) under M2.7
- Add open questions (test count baseline, chat history as single point of failure) to recovery_protocol.md
- Verify the `make package-branch` Makefile reference gap from prior handover
- Create this planning handover documenting the transition

## Carried forward

| Item | From handover |
|---|---|
| Flesh out recovery process section in recovery_protocol.md | 20260512-07-workflow — carried forward from that session, now handled |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | M2.5 summary row: `In progress` → `Deferred — see M2.5 section` | ✅ |
| 2 | M2.5 section body: `Status: Deferred`, tasks shelved | ✅ |
| 3 | M2.7 summary row added as `Active` | ✅ |
| 4 | M2.7 section body: `Status: Active` | ✅ |
| 5 | Settings.json ownership collision fix (item 8) added under M2.7 scope | ✅ |
| 6 | Open questions section added to recovery_protocol.md with both items | ✅ |
| 7 | `package-branch.md` Makefile reference verified (target exists — prior finding was incorrect) | ✅ |
| 8 | Planning handover created | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `docs/devlog/roadmap.md` | Milestone status changes, new work group added to M2.7 |
| `docs/operations/recovery_protocol.md` | Added open questions section |
| `agent/prompts/package-branch.md` | Verified Makefile reference (no change needed) |
| `docs/devlog/handovers/20260512-07-workflow-recovery_verification_audit.md` | Source of deferred items and mid-session findings verified this session |
| `docs/operations/handover_policy.md` | Format reference for this handover |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| M2.5 tasks shelved, not removed | Tasks remain valid; re-activate when KV5 timeline demands it | roadmmap.md M2.5 section |
| settings.json fix goes under M2.7 as item 8 | Design is complete, implementation belongs with the active milestone, and M2.7 already touches config lifecycle (docker-compose.yml, entrypoint.sh) | roadmmap.md M2.7 item 8 |
| Recovery open questions documented but not assigned to a milestone | Neither item is a code change — both are procedural gaps for future recovery sessions | recovery_protocol.md Open questions |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `make package-branch` Makefile target already exists in baseline — 20260512-07 handover finding was incorrect | contradiction | No action needed; resolved by verification this session |
| **session-diffs not persisted properly between sessions** — diffs committed inside the agent container are written to `workspace/session-diffs/` (bind-mounted from `SANDBOX_DIR/.workspace/session-diffs/`), but the bind mount destination path differs between the compose template and the entrypoint. The compose template mounts at `workspace/session-diffs`, but `dirs.sh` resolves to `workspace/session-diffs`. The mismatch causes diffs written by sandbox-entrypoint to land in a different tree from where routing.sh reads them. | bug | Next session — fix path resolution alignment, then add a test in `scripts/dry_run.sh` to assert the session-diffs path round-trips correctly |
| **Git commit messages not captured by packaging tools** — `package_branch.sh` outputs per-commit diffs and `session-diffs` records the diff content, but neither captures the commit message. When reviewing a session, the operator sees what changed but not why. `package_branch` could embed the commit subject into the diff filename or a companion manifest; `session-diffs` could store the message alongside each diff. | scope change | Next session — add commit message capture to both `package_branch.sh` and the session-diffs pipeline |

## Completed this session

| File | Change |
|---|---|
| `docs/devlog/roadmap.md` | M2.5: `In progress` → `Deferred` in summary + section; M2.7: added summary row `Active`, section `Active`; added item 8 (settings.json fix) to M2.7 scope |
| `docs/operations/recovery_protocol.md` | Added `## Open questions` section with test count baseline and chat history single-point-of-failure items |
| `docs/devlog/handovers/20260513-01-plan-m2_7_activation.md` | **New** — this handover |

## Deferred items

None.

## Next session

M2.7 — Session Identity and Harness Versioning. The active milestone has 8 work groups:

1. run_id derivation
2. Docker labels
3. make stop redesign
4. make prune implementation
5. Two-sig model (container-sig + harness-sig)
6. Paired refactor (compose files into providers/)
7. Context_dir removal
8. Settings.json ownership collision fix (design settled, needs implementation)

The next session should enter at investigation/design for the session-diffs persistence bug (finding 1 above) before advancing to item 1. Blocking: until session-diffs is reliable, none of the apply-workflow or packaging tools can be trusted.

**Open questions from recovery protocol** (documented, not blocking):
- No canonical test count baseline recorded for recovery verification
- Chat history is the only complete change record; no standardised machine-parseable alternative

**Watch-out items:**
- The compose template uses `{{VAR}}` (generation-time) and `${VAR}` (runtime) — ensure correct syntax when modifying mounts for item 8
- Item 6 (paired refactor) has a prerequisite: verify `agents.md` is not COPY-ed in any provider Dockerfile before moving compose files into providers/
- Item 7 (context_dir removal) has ~47 tests in `test_build_context.sh` that must be rewritten or deleted
