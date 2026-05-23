# Story — Agent State Persistence Under AGENT_HOME

**Status:** Investigation in progress (raised 2026-05-22)

## Context

Each provider container has an `AGENT_HOME` directory where the agent stores its runtime state — config, auth, session history, downloaded binaries. This state must survive across container restarts so the agent resumes where it left off.

| Provider | AGENT_HOME | Contents | Persistence need |
|---|---|---|---|
| Pi | `~/.pi/agent/` | `settings.json`, `models.json`, `auth.json`, `sessions/`, `AGENTS.md`, `prompts/`, `skills/` | Session history, auth tokens, config preferences |
| OpenCode | `~/.opencode/` | Config, sessions | Session resumption, provider config |
| Claude Code | `~/.claude/` | Config, sessions | Session resumption, auth |
| Hermes | `~/.hermes/` | Config, memories, sessions | Memory persistence, session resumption |

The current mechanism (from M2.7) is a **directory bind mount** at `AGENT_HOME/agent` with a **tmpfs overlay** at `bin/`. This was intended to replace the earlier copy-in/copy-out cycle, providing live write-through for real-time sync.

## Pain Points

### 1. utime/EPERM on cross-filesystem mounts (confirmed)

Pi's `settings-manager.js` uses `proper-lockfile` which calls `fs.utimesSync()` for stale-lock detection. On cross-filesystem bind mounts (9p on Windows Docker Desktop, virtiofs on macOS Docker Desktop), `utime()` returns `EPERM`. The lock acquisition throws and settings.json silently falls back to defaults.

**Affects:** Pi only (`settings.json` on bind mount). Other providers may have similar issues with filesystem-sensitive operations.

**Root cause:** Docker Desktop for non-Linux hosts surfaces host directories through a FUSE layer that doesn't support POSIX timestamp modification. The `AGENT_HOME` bind mount inherits these semantics.

**Resolution attempts:**
- M2.7 bind mount approach: failed (utime/EPERM)
- Pi bump to 0.75.4: did not resolve
- WSL2 Linux-native path: works for Windows only, not macOS
- See session `20260522-05-design-pi_agent_mount_strategy.md` for full options evaluation

### 2. Cross-filesystem binary downloads (resolved)

Pi downloads `fd`/`rg` to `/tmp/` then moves to `~/.pi/agent/bin/`. When `bin/` is on a bind mount, the move crosses filesystem boundaries and fails. **Resolved** by tmpfs overlay at `bin/` (existing mechanism, works correctly).

### 3. AGENT_HOME path is Pi-specific in compose template

The compose template at `libs/docker-compose.yml` line 102 hardcodes `target: /home/agentuser/.pi/agent`. For other providers, the target should be `/home/agentuser/.opencode/agent`, `/home/agentuser/.claude/agent`, or `/home/agentuser/.hermes/agent`. This was flagged in the shared reasoning layer audit (session `20260522-04`) but not addressed.

## Constraints

1. **Must work across all host OSes.** Linux native, macOS (virtiofs), Windows (9p/WSL2). No solution that only works on Linux is acceptable.
2. **Must work across all providers.** Pi, OpenCode, Claude Code, Hermes each have different AGENT_HOME structures and different persistence requirements.
3. **Session history must survive.** `/resume` and session continuity are non-negotiable across all providers.
4. **Auth state must survive.** `/login` stores tokens that must persist — re-authenticating every session is unacceptable.
5. **Binary downloads must not cross filesystems.** `bin/` must remain container-local (already resolved via tmpfs).
6. **Host-mounted content must remain editable.** Provider-layer prompts/skills and AGENTS.md should be editable on the host and visible to the agent without image rebuild.

## Design Rationale — auth.json should be ephemeral

**auth.json stores env var references (`DEEPSEEK_API_KEY`), not actual secret values.** The real API keys are injected as container environment variables. Keeping auth.json ephemeral (copy-in from template each session, never written back to host) prevents write-back of env var values — a **security feature**.

**Trade-off:** Adding a new provider API key requires a chore commit to update the template `auth.json` in `providers/<n>/config/agent/`. This is acceptable — it means new credentials are explicitly version-controlled and reviewed.

## Open Questions

1. **Which AGENT_HOME files need write-through persistence (host sees changes) vs. session-only (regenerated each start)?** The answer differs per provider and per file type.
2. **Should the persistence model be provider-agnostic or provider-specific?** A single mechanism (e.g., per-file tmpfs overlay + copy-out) could cover all providers, or each provider could define its own.
3. **What is the copy-out trigger?** On clean exit only (SIGTERM → EXIT trap), or also on periodic autosave?
4. **Does the compose template's hardcoded Pi path block non-Pi providers from starting?** If another provider is used, does the bind mount silently no-op, or does the container fail to start?

## Prioritization

This story is filed under M2.6 (Session Resume Across Provider Implementations) because session persistence (M2.4 scope) and session resume (M2.6 scope) share the same underlying mechanism — what state survives between containers and how it's loaded back on start. The mount strategy redesign resolved in parallel with M2.6 investigation.
