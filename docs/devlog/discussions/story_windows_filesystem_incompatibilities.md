# Story — Windows Filesystem Incompatibilities (9p Mount Seam)

**Status:** Identified — two active issues, root cause confirmed. Resolution via avoidance (keep project on Linux-native WSL2 path) documented in CORRECTION blocks. A proactive detection mechanism is proposed below.

---

## Context

The agent-sandbox harness runs inside a Docker container. Container paths that are bind-mounted from the host inherit the host filesystem's semantics. When the host is a Windows machine running Docker Desktop via WSL2, the bind mount path crosses a **9p (Plan 9) filesystem** seam — the protocol used by Docker's Windows integration to surface host directories inside the Linux VM.

The 9p implementation in Docker Desktop's WSL2 backend does not support several POSIX filesystem operations that the harness and its tools (notably Pi) rely on. Two distinct issues have been identified, both stemming from this single root cause.

---

## Pain Points

### Issue 1: `utime()` EPERM in Pi's settings.json locking

**Manifestation:** Three warnings on every Pi startup:
```
Warning: (startup session lookup, global settings) EPERM: operation not permitted, utime /home/agentuser/.pi/agent/settings.json.lock
Warning: (runtime creation, global settings) EPERM: operation not permitted, utime ...
```

**Root cause:** Pi's `settings-manager.js` uses `proper-lockfile` (v4.1.2) for file-level locking of `settings.json`. The lock mechanism creates a directory at `settings.json.lock` via `mkdir` (succeeds on 9p), then probes the filesystem's mtime precision by calling `fs.utimesSync()` on the lock directory (fails with `EPERM` on 9p). The lock acquisition throws, `tryLoadFromStorage()` catches the error and returns empty settings `{}`, causing all user configuration to silently fall back to defaults.

**First observed:** 2026-05-22, session investigating EPERM warnings.

**Status:** Investigated and documented. See CORRECTION blocks in:
- `docs/devlog/handovers/20260513-10-impl-settings_json_collision_fix.md`
- `docs/devlog/discussions/design_provider_config_ownership_and_loading.md`
- `libs/docker-compose.yml` (CONSTRAINT comment at the `AGENT_HOME` mount)

---

### Issue 2: Cross-filesystem binary downloads in `~/.pi/agent/bin/`

**Manifestation:** Pi downloads platform-specific binaries (`fd`, `rg`) to `/tmp/` then moves them to `~/.pi/agent/bin/`. When `~/.pi/agent/` is a bind mount from the host (9p) and `/tmp/` is container-local (overlay), the `mv` crosses a filesystem boundary and fails with `EXDEV: cross-device link not permitted`.

**Root cause:** Pi's binary installer uses `rename()` to move the downloaded file from the temp directory to the target. On UNIX, `rename()` fails with `EXDEV` when the source and destination are on different filesystems. The 9p bind mount creates exactly this scenario: `/tmp/` is on the container's overlay/ext4, while `~/.pi/agent/bin/` is on the 9p mount.

**Design response:** The `bin/` subdirectory is mounted as a tmpfs overlay in the compose template:

```yaml
- type: tmpfs
  target: /home/agentuser/.pi/agent/bin
```

This shadows the bind-mount's `bin/` with a container-local tmpfs, so Pi's cross-filesystem `mv` from `/tmp/` to `~/.pi/agent/bin/` stays within the tmpfs (same filesystem). The trade-off is that binaries are re-downloaded every session.

**First observed:** During the design phase of M2.7 item 8 (see `design_provider_config_ownership_and_loading.md`, constraint 2).

**Status:** Mitigated via tmpfs overlay. Acceptable trade-off (binaries are small, downloads are fast).

---

### Root cause shared by both issues

| Aspect | Issue 1 (utime) | Issue 2 (bin mv) |
|--------|-----------------|-------------------|
| Trigger | `fs.utimesSync()` on lock dir | `rename()` from `/tmp/` to bind mount |
| Error | `EPERM` | `EXDEV` |
| 9p root cause | Windows 9p server doesn't implement utime | 9p mount is a different filesystem from overlay |
| Existing mitigation | None (silent settings loss) | tmpfs overlay at `bin/` |
| Ultimate fix | Avoid 9p for `AGENT_HOME` (see Resolution) | Already mitigated |

---

## Constraints

1. **The 9p seam is a constraint of the host environment, not a bug in the harness.** Docker Desktop on Windows uses 9p for all bind mounts from the host. The harness cannot change this.

2. **The `AGENT_HOME` bind mount is intentional and valuable.** It provides direct host persistence for settings, auth, sessions, and skills — eliminating the copy-in/copy-out cycle that was error-prone and slow.

3. **The resolution must not break the existing workflow for users on Linux-native filesystems.** Any detection mechanism or guard added must be opt-in or passive (warn, don't block).

4. **Session identity and isolation must be preserved.** A shared `AGENT_HOME` between concurrent sessions (from the same host path) is a separate concern; this story does not reopen it.

---

## Resolution

### Primary: Keep the project on a Linux-native WSL2 path

The most reliable fix is to avoid the 9p seam entirely. `SANDBOX_DIR` — and by extension `${SANDBOX_DIR}/.{{PROVIDER_NAME}}/agent` — is derived from `PROJECT_DIR`:

```bash
# start_agent.sh
SANDBOX_DIR="$(dirname "$PROJECT_DIR")/$(basename "$PROJECT_DIR")-sandbox"
```

If the user passes `--project` with a Linux-native WSL2 path (e.g., `/home/user/projects/myproject`), both `PROJECT_DIR` and `SANDBOX_DIR` reside on the Linux-native ext4 filesystem. The `AGENT_HOME` bind mount inherits ext4's POSIX semantics — `utime()` works, cross-filesystem moves stay within ext4 — and both issues are avoided.

**Requires:** The user's project must reside under a WSL2 Linux root (e.g., `/home/user/`, `/mnt/wsl/`, or a dedicated ext4 mount), not on a Docker Desktop Windows drive (`/mnt/c/`, `M:\`, etc.).

**Trade-off:** Windows-native editors need the WSL extension (VS Code Remote - WSL, JetBrains Gateway, etc.) to access Linux-native paths. Most WSL2 users already have this set up.

---

### Secondary: Proactive cross-filesystem detection

Even after adopting the primary resolution, the harness should detect when `AGENT_HOME` crosses a filesystem boundary and warn the operator. This prevents future silent failures if the project is inadvertently placed on a Windows drive.

A proposed detection mechanism in `scripts/start_agent.sh` or `libs/provider-entrypoint.sh`:

```bash
_check_filesystem_compat() {
  local test_path="$AGENT_HOME/agent"
  # Create a temporary file and try utime
  local probe_file=$(mktemp -p "$test_path" .compat_probe.XXXXXX)
  if ! touch -c "$probe_file" 2>/dev/null; then
    echo "Warning: AGENT_HOME ($test_path) does not support utime()."
    echo "  This is likely a 9p/Windows mount. Settings locking will fail."
    echo "  Move your project to a Linux-native WSL2 path to resolve."
    echo "  See: docs/devlog/discussions/story_windows_filesystem_incompatibilities.md"
  fi
  rm -f "$probe_file"
}
```

A more robust variant checks both utime and EXDEV:

```bash
_check_filesystem_compat() {
  local test_dir="$AGENT_HOME/agent"
  local probe_src=$(mktemp -p /tmp .compat_src.XXXXXX)
  local probe_dst=$(mktemp -p "$test_dir" .compat_probe.XXXXXX)
  rm -f "$probe_dst"

  # Check cross-device move
  if mv "$probe_src" "$probe_dst" 2>/dev/null; then
    rm -f "$probe_dst"
  else
    echo "Warning: Cross-filesystem move failed (EXDEV) between /tmp and AGENT_HOME."
    echo "  Pi's binary downloads will fail without the tmpfs overlay at bin/."
    rm -f "$probe_src"
  fi
}
```

**Integration point:** `libs/provider-entrypoint.sh` (runs inside the agent container before exec-ing Pi) or `scripts/start_agent.sh` (runs on the host before the container starts).

---

## Open Questions

| Question | Status |
|---|---|
| Should the detection be a hard block or a soft warning? | Suggested: soft warning — the user can still proceed with degraded functionality. |
| Should the check run on the host (start_agent.sh) or in the container (entrypoint)? | Container-side (`entrypoint.sh`) is more accurate because it tests the actual mount point, but host-side catches the problem before Docker starts. Both could run. |
| Does Docker Desktop for Linux also exhibit this issue? | Untested. Docker Desktop on Linux does not use 9p; it uses a bind mount from the host Linux filesystem directly. Likely not affected. |
