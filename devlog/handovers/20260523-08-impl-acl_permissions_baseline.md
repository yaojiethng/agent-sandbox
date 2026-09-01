# Agent Handover

**Date:** 2026-05-23
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Implementation
**Status:** Closed

## Objective

Implement ACL-based bind mount permission fix for host-container UID mismatch. Establish provider-specific onboard hook mechanism for directory setup.

## Scope

- Add `setfacl` commands to `scripts/onboard.sh` for `.workspace/` and all `.<provider>/` directories
- Refactor `providers/pi/provider.Dockerfile` to use `$AGENT_HOME`/`$WORKSPACE_DIR` variables instead of hardcoded paths
- Create `providers/pi/onboard.sh` provider hook to pre-create host-side config dirs
- Remove redundant `mkdir` from `scripts/run_agent.sh` that is now handled by the provider hook

**Out of scope:**
- Replacing ACLs with a more durable solution (deferred — see session 20260523-09)
- Other providers' Dockerfiles (only Pi touched)
- Other M2.7 Track A or Track B tasks

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `.workspace/` directories have ACL entries granting UID 1001 `rwx` with default inheritance | `getfacl $SANDBOX_DIR/.workspace/session-diffs` shows `u:1001:rwx` and `default:u:1001:rwx` | Operator |
| 2 | Provider config directories have ACL entries granting UID 1001 `rwx` with mask forced to `rwx` | `getfacl $SANDBOX_DIR/.pi/agent` shows `u:1001:rwx` and `mask::rwx` | Operator |
| 3 | `provider.Dockerfile` uses `$AGENT_HOME` and `$WORKSPACE_DIR` variables, not hardcoded paths | grep confirms no bare `/home/agentuser/.pi/` paths in RUN commands | Operator |
| 4 | `providers/pi/onboard.sh` creates `sessions/`, `prompts/`, `skills/`, `extensions/` dirs under `$SANDBOX_DIR/.pi/agent/` | Directories exist after `agent-sandbox onboard` | Operator |
| 5 | `run_agent.sh` no longer contains redundant `sessions/` mkdir | grep confirms no `mkdir.*agent/sessions` in `run_agent.sh` | Operator |

## Hot files

| File | Reason | Status |
|---|---|---|
| `scripts/onboard.sh` | Added `setfacl` commands for `.workspace/` and `.<provider>/` dirs | ✅ |
| `providers/pi/provider.Dockerfile` | Refactored to use `$AGENT_HOME`/`$WORKSPACE_DIR`; added `chown` for workspace | ✅ |
| `scripts/run_agent.sh` | Removed redundant `mkdir -p .$PROVIDER_NAME/agent/sessions` | ✅ |
| `providers/pi/onboard.sh` | New file — provider-specific setup hook | ✅ |

## Decisions made this session

| Decision | Rationale |
|---|---|
| Use ACLs (Resolution 1 from story doc) as the interim permission fix | Fastest path to working system. Known limitations (mask throttling, /mnt/c/ incompatibility) accepted as technical debt. |
| Provider onboard hook pattern (`providers/<n>/onboard.sh`) | Allows per-provider setup logic without modifying the generic onboarding script. Called from `scripts/onboard.sh` after provider config is seeded. |

## Mid-session findings

| Finding | Triaged to |
|---|---|
| ACL approach has known failure modes — mask throttling, metadata reset, /mnt/c/ incompatibility | Documented in `story_linux_filesystem_uid_mismatch.md`. Replaced by UID Mapping strategy in session 20260523-09. |

## Completed this session

| File | Change |
|---|---|
| `scripts/onboard.sh` | Added `setfacl -R -m u:1001:rwx` + `setfacl -R -d -m u:1001:rwx` for `.workspace/` dirs. Added `sudo setfacl -R -m u:1001:rwx,m:rwx` + `sudo setfacl -R -d -m u:1001:rwx,m:rwx` for `.<provider>/` dirs. Added provider-specific hook sourcing. |
| `providers/pi/provider.Dockerfile` | Replaced hardcoded paths with `$AGENT_HOME`/`$WORKSPACE_DIR` env vars. Added `$WORKSPACE_DIR/input`, `$WORKSPACE_DIR/output` to mkdir. Added `chown -R agentuser:agentuser $WORKSPACE_DIR`. |
| `scripts/run_agent.sh` | Removed `mkdir -p "$SANDBOX_DIR/.$PROVIDER_NAME/agent/sessions"` (moved to provider onboard hook). |
| `providers/pi/onboard.sh` | New file — pre-creates host-side `sessions/`, `prompts/`, `skills/`, `extensions/` dirs under `$SANDBOX_DIR/.pi/agent/`. |

## Deferred items

None.

## Next session

Design and scope a more durable permission strategy to replace the ACL approach (handled in session 20260523-09).
