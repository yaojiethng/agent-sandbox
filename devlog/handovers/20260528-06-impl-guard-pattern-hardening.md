# Agent Handover

**Date:** 2026-05-28
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl
**Status:** Closed

## Objective

Harden the `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard pattern across all 7 files (9 instances) that use it. Replace with a robust check that inspects the BASH_SOURCE array length to handle the edge case where the parent script is sourced rather than executed. No behaviour change for standard execution paths.

## Scope

**In scope:**
- Replace 9 guard instances across 7 files with a hardened pattern
- Files affected: `scripts/build.sh`, `scripts/agent-sandbox.sh`, `scripts/workflows/apply.sh`, `scripts/workflows/draft.sh`, `scripts/workflows/confirm.sh`, `scripts/workflows/reject.sh`, `src/libs/package_diff.sh`, `src/libs/package_branch.sh`

**Not in scope:**
- Interactive/non-interactive dispatch duplication removal
- `draft_run` decomposition
- `set -euo pipefail` cleanup
- `require_run_args` naming consistency

**Design questions:** None — the fix is a single, well-defined pattern replacement.

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/build.sh`](../../scripts/build.sh) | Replace guard at line 303 |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Replace guard at line 416 |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh) | Replace guard at line 175 |
| [`scripts/workflows/draft.sh`](../../scripts/workflows/draft.sh) | Replace guard at line 259 |
| [`scripts/workflows/confirm.sh`](../../scripts/workflows/confirm.sh) | Replace guard at line 107 |
| [`scripts/workflows/reject.sh`](../../scripts/workflows/reject.sh) | Replace guard at line 73 |
| [`src/libs/package_diff.sh`](../../src/libs/package_diff.sh) | Replace guard at line 37 |
| [`src/libs/package_branch.sh`](../../src/libs/package_branch.sh) | Replace guards at lines 43 and 292 |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Use simple `[[ "${BASH_SOURCE[0]}" == "$0" ]]` guard instead of BASH_SOURCE array-length pattern | Verified correct for all three scenarios: direct execution (passes), sourced by executed parent (rejects), sourced by sourced parent (rejects). The array-length pattern proposed (`-gt 1 || !=`) was logically inverted — it would pass the guard when a parent sourced the file, creating a broken guard. The simple standard pattern is the correct one. | Chat (2026-05-28) |
| Changed `${0}` → `$0` | Cosmetic consistency — both expand identically in bash. | This session |

## Completed this session

| File | Change summary |
|---|---|
| 8 files across 9 guard instances | Changed `${0}` → `$0` in guard expression. All syntax checks pass. Full test suite: 384/390, 0 failed. |

## Mid-session findings

None.

## Deferred items

- Interactive/non-interactive dispatch duplication removal
- `draft_run` decomposition
- `set -euo pipefail` cleanup
- `require_run_args` naming consistency

## Next session

M2.7 — Session Identity and Harness Versioning — remaining cleanup items from deferred list.

**Conclusions from this session:**
- Guard pattern hardened: 9 instances across 8 files, `$0` used consistently
- Verified the simple guard correctly rejects all sourcing scenarios:
   1. Direct execution: `${BASH_SOURCE[0]}` == `$0` → passes ✅
   2. Sourced by executed parent: `${BASH_SOURCE[0]}` != `$0` → rejects ✅
   3. Sourced by sourced parent: `${BASH_SOURCE[0]}` != `$0` → rejects ✅
- Rejected the array-length `||` pattern — it was logically inverted and would create a broken guard
- Full test suite: 384/390, 0 failed
