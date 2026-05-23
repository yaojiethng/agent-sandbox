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
| Config dir (Pi convention) | `$AGENT_HOME/agent/` | `providers/pi/preflight.sh`, compose template |
| Template (baked into image) | `/opt/workflow/agent/config/agent/` | Build context (`containers.sh`) + Dockerfile COPY |
| Bind mounts | `$SANDBOX_DIR/.pi/agent/{prompts,sessions,skills}` | `libs/docker-compose.yml` |
| tmpfs for binaries | `$AGENT_HOME/agent/bin/` | `libs/docker-compose.yml` (noexec — see Binary Downloads) |

## Ephemeral vs Mounted

Only **`prompts/`**, **`sessions/`**, and **`skills/`** are RW bind-mounted from the host.
Everything else is ephemeral (copy-in from image template at startup) — including
`settings.json`, `auth.json`, `models.json`, and `AGENTS.md`.

This avoids `utime()`/`EPERM` on cross-filesystem mounts (macOS virtiofs, Windows 9p)
where Pi's `proper-lockfile` would fail silently, falling back to default settings.

### Copy-in provisioning

The template at `/opt/workflow/agent/config/agent/` is copied into
`$AGENT_HOME/agent/` at startup by `_provision_agent_home`.

**Why `mkdir -p .pi/agent` in the Dockerfile:** Docker creates parent directories
for bind mount targets at container start. Without the image-owned directory,
`.pi/agent/` is created by Docker as **root**, and the entrypoint (running as
`agentuser`) cannot write into it. The Dockerfile creates it before the user
switch so provisioning can copy in config files.

**Why `cp -r "$item"/. "$target/$name"` for directories:** Docker's bind mount
parent-creation means `.pi/agent/` already exists when `cp` runs. If `cp -r`
copies the `agent/` directory into an already-existing `agent/` directory, the
result is `.pi/agent/agent/` (double nesting). The trailing `/.` copies the
**contents** of the source directory, not the directory itself.

## Binary Downloads

Pi auto-downloads `fd` and `rg` (ripgrep) to `$AGENT_HOME/agent/bin/`.
Two separate issues with this:

1. **cross-device mv:** Pi downloads to `/tmp/`, then moves to `bin/`. When
   `bin/` is a bind mount, the move crosses filesystem boundaries and fails.
   **Fixed:** `bin/` is a tmpfs (container-local), so mv stays on the same filesystem.

2. **noexec tmpfs:** The `bin/` tmpfs is mounted `noexec` on some Docker configurations.
   `fd`/`rg` downloaded by Pi fail to execute with `EACCES`. Pi silently swallows
   the error and the `@` file reference popup stops working.
   **Workaround:** `fd-find` and `ripgrep` are installed via `apt` in `base.Dockerfile`.
   Pi's `getToolPath` checks system PATH first, so apt-installed binaries take
   priority over the tmpfs copies.

## auth.json — Ephemeral by Design

`auth.json` stores env var **references** (e.g. `DEEPSEEK_API_KEY`), not actual
secret values. Real API keys are injected as container environment variables.
Keeping `auth.json` ephemeral prevents write-back of env var values to the host —
a **security feature**, not an implementation gap.

Adding a new provider key requires a chore commit to update the template
`auth.json` in `providers/pi/config/agent/auth.json`.
