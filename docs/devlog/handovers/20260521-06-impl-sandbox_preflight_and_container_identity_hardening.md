# Agent Handover

**Session date:** 2026-05-21
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Add preflight library integrity checks to the capability layer entrypoint (`sandbox-entrypoint.sh`) and diagnostic, then propagate the same hardening to the reasoning layer: AGENTS.md container identity clarification (root cause fix for the "missing files" confusion), preflight checks in `provider-entrypoint.sh`, and diagnostic expansion.

[see correction below]

All scripts referencing `/opt/sandbox/lib/` should resolve their dependencies without fallbacks.

## Scope

Per the bugfix protocol (`docs/operations/bugfix_protocol.md`):

1. **Replicate** — done: `bash /opt/sandbox/lib/package_diff.sh` fails with `diff.sh: No such file or directory`
2. **Trace** — done: `/opt/sandbox/lib/` is missing 3 of 6 expected files, has 1 unexpected file
3. **Diagnose** — write diagnostic check(s) for `/opt/sandbox/lib/` completeness
4. **Fix** — ensure the build produces images with all required files
5. **Record** — diagnostic script + handover correction
6. **Close** — verify fix

**Correction-prescribed work (completed post-session):**
- Harden provider-layer AGENTS.md files with two-layer architecture context so the agent knows which container it is in
- Propagate preflight library completeness check to reasoning layer entrypoint (`provider-entrypoint.sh`)
- Expand reasoning-layer diagnostic (`diagnose_dry_run_reasoning.sh`) with severity-labeled library check
- Remove replicated two-layer content from root `AGENTS.md`

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Preflight check in sandbox-entrypoint.sh warns on missing WARN files, aborts on missing CRITICAL files | ✅ (syntax check + manual review) |
| 2 | diagnose_dry_run_capability.sh checks all 7 expected library files with severity labels | ✅ (verified by running diagnostic) |
| 3 | All tests pass | ✅ (full suite, 0 failures) |

## Hot files

| File | Why in scope |
|---|---|
| `libs/sandbox.Dockerfile` | Specifies which files go into `/opt/sandbox/lib/` — verify correct |
| `libs/containers.sh` | `build_context_sandbox` populates build context — verify correct |
| `tests/knowledge/diagnose_*.sh` | Existing diagnostics that check `/opt/sandbox/lib/` files |
| `libs/package_diff.sh` | Script that failed due to missing dependency |
| `libs/sandbox-entrypoint.sh` | Sources from `/opt/sandbox/lib/` |
| `libs/provider-entrypoint.sh` | Reasoning layer entrypoint — needs symmetric preflight checks |
| `providers/AGENTS.template.md` | Template for provider-layer AGENTS.md files |
| `providers/pi/config/agent/AGENTS.md` | Pi provider AGENTS.md — needs two-layer architecture context |
| `providers/claude-code/AGENTS.md` | Claude Code provider AGENTS.md — needs two-layer architecture context |
| `AGENTS.md` (root) | Had duplicate two-layer section — removed on propagation |
| `tests/knowledge/diagnose_dry_run_reasoning.sh` | Needs severity-labeled library check matching capability layer |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `lib/` vs `libs/` naming is intentional | `lib/` is a protected dirname; container uses it correctly | Chat |
| No fallback to `~/sandbox/libs/` | Project may not be dogfooding itself; fallback would break in non-dogfood setups | Chat |
| Preflight in entrypoint, not new diagnostic | Existing `diagnose_dry_run_capability.sh` already covers the relevant check surface | Chat |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `libs/sandbox-entrypoint.sh` | Added preflight check: 3 CRITICAL (dirs.sh, session.sh, snapshot.sh), 4 WARN (diff.sh, routing.sh, package_branch.sh, package_diff.sh) |
| `tests/knowledge/diagnose_dry_run_capability.sh` | Expanded library check from 3 files to all 7 with severity labels |
| `libs/provider-entrypoint.sh` | Added library completeness check (session.sh:CRITICAL, dirs.sh/routing.sh/package_diff.sh:WARN) and AGENTS.md presence preflight WARN |
| `tests/knowledge/diagnose_dry_run_reasoning.sh` | Expanded library check from 2 files to all 4 with severity labels |
| `providers/AGENTS.template.md` | Added two-layer architecture context to Sandbox Context section |
| `providers/pi/config/agent/AGENTS.md` | Added two-layer architecture context to Agent Harness section |
| `providers/claude-code/AGENTS.md` | Added two-layer architecture context to Sandbox Context section |
| `AGENTS.md` (root) | Removed "Two-layer container architecture" subsection (moved to provider layer) |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.7 — Session Identity and Harness Versioning

**Next task:** Continue M2.7 Track A or Track B items.

---
[CORRECTION — 2026-05-22]: The original Objective stated "Fix the container image library regression" — this was incorrect. There was no regression; the confusion arose because the agent did not know which container it was in (reasoning vs capability layer), and each layer has a different `/opt/sandbox/lib/` file set. The Objective, Scope, and filename have been corrected to reflect the real scope: preflight hardening + container identity clarification. The originally completed work (capability-layer preflight checks and diagnostic) remains correct. The correction-prescribed AGENTS.md hardening and reasoning-layer propagation have been completed and added to the Completed this session table.
