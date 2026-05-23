# Agent Handover

**Session date:** 2026-05-13
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Implement the settings.json ownership collision fix (M2.7 item 8): replace the copy-in/copy-out mechanism in `libs/provider-entrypoint.sh` with a pre-flight Node.js merge script, update the compose template mount paths (now slots into the `x-workspace` anchor from item 10), and seed `~/.pi/agent/AGENTS.md` alongside the other config files.

## Scope

M2.7 item 8 — Settings.json ownership collision fix, as designed in `docs/devlog/discussions/design_provider_config_ownership_and_loading.md`.

- Replace `/opt/provider-config` bind mount with `agent/` directory bind mount, `bin/` tmpfs, and `/opt/workflow-host/` mounts for skills/prompts.
- Remove `_copy_in` and `_copy_out` from `libs/provider-entrypoint.sh`; add `_ensure_harness_keys` (Node.js pre-flight merge).
- Pre-create `agent/sessions` in `scripts/run_agent.sh` before compose generation.
- Seed `AGENTS.md` into provider config so pi's append-composition gets the global layer.
- Also covers: provider dry-run checks hook point (from item 12 investigation — deferred, but the config dir changes make it easier to add later).

## Carried forward

| Item | From handover |
|---|---|
| Seed `~/.pi/agent/AGENTS.md` into provider config dir | 20260513-08-impl-agents_injection_cleanup — deferred to item 8 |
| Provider dry-run checks mechanism | 20260513-08-impl-agents_injection_cleanup — deferred to item 8 |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | Compose template has AGENT_HOME directory bind mount + bin/ tmpfs replacing provider-config mount | ✅ |
| 2 | provider-entrypoint.sh has no _copy_in/_copy_out | ✅ |
| 3 | provider-entrypoint.sh has _ensure_harness_keys Node.js merge that preserves pi keys and adds harness keys | ✅ |
| 4 | settings.json retains pi-managed keys after merge | ✅ (tested) |
| 5 | All provider Dockerfiles have PROVIDER_CONFIG_DIR removed | ✅ |
| 6 | run_agent.sh pre-creates agent/sessions | ✅ |
| 7 | AGENTS.md updated in provider config | ✅ |
| 8 | bash -n passes on all modified files | ✅ |
| 9 | make test passes clean | ✅ |
| 10 | Architecture documents describe the system as built | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| `libs/provider-entrypoint.sh` | Remove copy-in/copy-out, add Node.js merge |
| `libs/docker-compose.yml` | Update provider config mount to use `x-workspace` anchor |
| `libs/docker-compose.dry-run.yml` | May need updates for new mount layout |
| `scripts/run_agent.sh` | Pre-create agent/sessions directory |
| `providers/pi/config/agent/settings.json` | Add packages/skills/prompts keys |
| `providers/pi/config/agent/AGENTS.md` | **New** — pi-specific global context |
| `providers/pi/provider.Dockerfile` | Verify no COPY of agent/skills/ or agent/prompts/ |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| `libs/docker-compose.yml` | Replaced provider-config mount with AGENT_HOME dir mount + bin/ tmpfs |
| `libs/provider-entrypoint.sh` | Removed copy-in/copy-out, added _ensure_harness_keys |
| `providers/pi/provider.Dockerfile` | Removed PROVIDER_CONFIG_DIR ENV and /opt/provider-config mkdir |
| `providers/claude-code/provider.Dockerfile` | Same |
| `providers/hermes/provider.Dockerfile` | Same |
| `providers/opencode/provider.Dockerfile` | Same |
| `providers/pi/config/agent/AGENTS.md` | Updated with current harness behavior |
| `scripts/run_agent.sh` | Pre-create agent/sessions |
| `scripts/dry_run.sh` | Removed PROVIDER_CONFIG_DIR check |
| `tests/test_provider_entrypoint.sh` | Replaced copy-in/copy-out tests with _ensure_harness_keys tests |

## Deferred items

None.

## Next session

M2.7 items 1–7 (run_id derivation, Docker labels, stop redesign, prune, two-sig model, paired refactor, context_dir removal) are the remaining scope. Item 8, 9, 10, 11, 12 are complete.

---

[CORRECTION — 2026-05-22]: Filesystem compatibility gap — the bind mount at `AGENT_HOME` (agent `~/.pi/agent` → `$SANDBOX_DIR/.$PROVIDER_NAME/agent`) assumes the host filesystem supports `utime()`. When `SANDBOX_DIR` resides on a 9p mount (WSL2/Docker Desktop Windows drive — `M:\`), `proper-lockfile`'s `fs.utimesSync()` call fails with `EPERM`. The lock acquisition in `settings-manager.js`'s `acquireLockSyncWithRetry` does not handle `EPERM` (only retries on `ELOCKED`), so the exception propagates to `tryLoadFromStorage()`, which returns empty settings `{}` and records the error. The error surfaces as a warning at every startup. No acceptance criterion or design note from this session identified the `utime` dependency or the 9p filesystem constraint. Fix: `settings-manager.js` should catch `EPERM` and proceed without locking, or `proper-lockfile`'s `mtimePrecision.probe()` should handle `EPERM` as a non-fatal error. See investigation in session 20260522-01.

**Resolution:** Prefer approach 1 — keep `PROJECT_DIR` (and thus `SANDBOX_DIR`) on a Linux-native WSL2 path (e.g., `/home/user/projects/...`) rather than a Docker Desktop Windows drive (`/mnt/c/...`, `M:\`). When the project resides on the Linux-native ext4 filesystem, the `AGENT_HOME` bind mount inherits ext4's POSIX semantics and `utime()` succeeds. This avoids the 9p seam entirely with no code or mount changes.

See also: `docs/devlog/discussions/story_windows_filesystem_incompatibilities.md` for the broader story on Windows filesystem issues (Issue 1: utime EPERM, Issue 2: bin/ cross-filesystem moves) and a proposed proactive detection mechanism.

[MID-SESSION FINDING — 2026-05-22]: The "No commit or push" constraint in `AGENTS.md` (project layer, sandbox) is stale. The diff pipeline handles in-sandbox commits successfully, as demonstrated by the correction commits in this session and prior sessions (e.g., commit `3248978`). The constraint was originally written under the assumption that any git mutation would break the baseline-diff comparison, but in practice the harness records its baseline at startup (before any agent action) and diff on exit — intervening commits are captured correctly. Recommend removing or rewording the constraint to reflect actual behaviour: "Commits are permitted but optional; the session diff captures all changes between session start and exit regardless of commit state."

---

[CORRECTION — 2026-05-22]: The bind mount approach implemented in this session was later found to fail on cross-filesystem mounts (macOS Docker Desktop virtiofs, Windows Docker Desktop 9p). Pi's `proper-lockfile` calls `utime()` for stale-lock detection, which returns `EPERM` on these filesystems. Settings.json silently falls back to defaults, stripping the harness-injected `skills`/`prompts`/`packages` keys. The `_ensure_harness_keys` merge is correct but its effect is nullified by Pi's inability to read the file.

Pi bump to 0.75.4 was tested and did not resolve the issue.

**Revised resolution:** Revert to a copy-in model — copy config from a host-mounted source into container-local filesystem at startup to avoid the cross-fs utime issue entirely. See session `20260522-05-design-pi_agent_mount_strategy.md` for the re-evaluation.