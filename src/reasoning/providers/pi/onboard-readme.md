# Pi Provider Onboard Reference

Provider-specific quirks and conventions discovered during integration.
Add entries as they surface; periodic cleanup/refactoring expected once
enough patterns emerge.

---

## Directory Convention

**`AGENT_HOME` is the dot-directory in the agent's root:**

- `AGENT_HOME=/home/agentuser/.pi`
- Pi nests all working config in an **`agent/` subdirectory** underneath it
- All provider-specialized code references paths as **absolute paths generated relative from `$AGENT_HOME`**

| Reference | Path | Where defined |
|---|---|---|
| Config dir (Pi convention) | `$AGENT_HOME/agent/` | `providers/pi/preflight.sh` |
| Template (baked into image) | `/opt/workflow/agent/config/agent/` | Build context (`containers.sh`) + Dockerfile COPY |
| Bind mounts (host → container) | `$SANDBOX_DIR/.pi/agent/{prompts,sessions,skills}` | `providers/pi/docker-compose.pi.yml` |

Pi-specific volumes live in the Pi compose overlay (`docker-compose.pi.yml`),
not the generic `docker-compose.yml`. This keeps provider isolation clean:
the generic compose has only sandbox-level mounts (snapshot, changes, input,
output); each provider overlays its own config mounts.

## Ephemeral vs Mounted

Only **`prompts/`**, **`sessions/`**, and **`skills/`** are RW bind-mounted from the host.
Everything else is ephemeral (copy-in from image template at startup) — including
`settings.json`, `auth.json`, `models.json`, and `AGENTS.md`.

This avoids `utime()`/`EPERM` on cross-filesystem mounts (macOS virtiofs, Windows 9p)
where Pi's `proper-lockfile` would fail silently, falling back to default settings.

### Root cause: Docker auto-provisioned mount points

When a bind mount target path doesn't exist in the image, the Docker Daemon
(running as **root**) creates it at container start. These auto-created
directories are owned by `root:root`. When the entrypoint runs as `agentuser`
(uid 1001), any `mkdir` or `cp` into those paths fails with "Permission denied".

### Why `rsync -av` and `cp -a` don't work

Standard copy commands in "archive" mode try to preserve file metadata:
ownership (UID/GID) and timestamps (mtime/atime). On cross-filesystem mounts
(macOS virtiofs, Linux bind mounts), a non-privileged user cannot set these
attributes even on files they own — resulting in `Operation not permitted`.

### Solution: pre-emptive path claiming + metadata-agnostic copy

**A. Image-level ownership.** The Dockerfile `mkdir -p`s every bind mount
target (`prompts/`, `sessions/`, `skills/`, `bin/`) before the `USER` switch.
Since the paths already exist, Docker doesn't auto-create them as root at
runtime. A follow-up `chown -R agentuser:agentuser` on the entire `.pi/` tree
ensures everything is writable by the non-root user.

```dockerfile
RUN useradd -m -u 1001 -s /bin/bash agentuser
RUN mkdir -p /home/agentuser/.pi/agent/prompts \
             /home/agentuser/.pi/agent/sessions \
             /home/agentuser/.pi/agent/skills \
             /home/agentuser/.pi/agent/bin
RUN chown -R agentuser:agentuser /home/agentuser/.pi
USER agentuser
```

**B. Metadata-agnostic provisioning.** `_provision_agent_home` uses
`cp -RT --no-preserve=all` to copy the template into `$AGENT_HOME`.
`--no-preserve=all` skips ownership AND timestamps — files are created as
"new" files owned by agentuser, avoiding EPERM on any metadata operations.
The `-T` flag treats the destination as the target directory (not a subdir
inside it), which prevents double-nesting when the target already exists.

```bash
# In provider-entrypoint.sh:
cp -RT --no-preserve=all "$PROVISION_TEMPLATE/" "$AGENT_HOME/"
```

**Key principle:** In a non-root Docker environment, the image must be
"volume-ready" before the container starts — the image skeleton claims the
paths with correct ownership, and the volumes flesh them out without
breaking permissions.

## Binary Downloads

Pi auto-downloads `fd` and `rg` (ripgrep) to `$AGENT_HOME/agent/bin/`.

**Problem (historical):** When `bin/` was on a bind-mounted filesystem, Pi's
`mv` from `/tmp/` (container overlayfs) to `bin/` (host fs) crossed filesystem
boundaries and failed. Adding a tmpfs made `bin/` a separate in-memory
filesystem, but it was still cross-device from `/tmp/` (overlayfs) — and
on some Docker configurations the tmpfs was mounted `noexec`, silently
breaking the `@` file reference popup.

**Current solution:** `bin/` is a regular directory created in the Dockerfile
before the `USER` switch — same overlayfs as `/tmp/`. `mv` uses native
`rename()` (no cross-device fallback). `fd-find` and `ripgrep` are installed
via `apt` in `base.dockerfile`, so Pi's `getToolPath` picks them up from
system PATH without needing auto-downloads at all.

The tmpfs was removed for simplicity. If future tools add binaries that need
a separate writable space, a tmpfs with explicit `uid`/`gid`/`mode` can be
added back in `docker-compose.pi.yml`:

```yaml
- type: tmpfs
  target: /home/agentuser/.pi/agent/bin
  tmpfs:
    mode: 0755
    uid: 1001
    gid: 1001
```

## auth.json — Ephemeral by Design

`auth.json` stores env var **references** (e.g. `DEEPSEEK_API_KEY`), not actual
secret values. Real API keys are injected as container environment variables.
Keeping `auth.json` ephemeral prevents write-back of env var values to the host —
a **security feature**, not an implementation gap.

Adding a new provider key requires a chore commit to update the template
`auth.json` in `providers/pi/config/agent/auth.json`.
