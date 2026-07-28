# Design — Provider Config Ownership and Loading

**Target milestone:** W1 — Vault Capability Layer Prototype

**Status:** Design record — enumerates the problem, constraints, and candidate solutions for the settings.json ownership collision and skills/prompts loading architecture. Implemented in M2.7 item 8 (see handover 20260513-10). [CORRECTION — 2026-05-22]: Filesystem compatibility gap — see CORRECTION block below.

**Related:**
- [`libs/provider-entrypoint.sh`](../../libs/provider-entrypoint.sh) — current copy-in/copy-out mechanism
- [`libs/docker-compose.yml`](../../libs/docker-compose.yml) — current bind-mount structure
- [`providers/pi/config/agent/settings.json`](../../providers/pi/config/agent/settings.json) — onboard settings template
- [`docs/architecture/provider_lifecycle.md`](../../docs/architecture/provider_lifecycle.md) — current lifecycle documentation including fragility notes
- [`docs/concepts/agent_workflow.md`](../../docs/concepts/agent_workflow.md) — three-layer skills/prompts model
- [`tests/knowledge/knowledge_provider_config_cycle.sh`](../../tests/knowledge/knowledge_provider_config_cycle.sh) — knowledge test for config cycle

---

## 1. Problem

`settings.json` has two simultaneous owners:

- **Agent (pi).** Pi reads, modifies, and writes `settings.json`. When pi saves, it writes only keys it manages (model, provider, theme, compaction, etc.). Custom keys that are not part of pi's known set may be dropped.
- **Agent-sandbox.** The harness seeds `settings.json` with additional keys (`"skills"`, `"prompts"`) that reference image-baked paths at `/opt/workflow/`. These keys tell pi where to find sandbox-layer workflow files (skills and prompts under `agent/` in the repo).

Both owners share a single file, but only pi writes it back. The copy-out cycle (`AGENT_HOME` → bind-mount) propagates pi's runtime version to the host, overwriting the seeded version. Once the custom keys are lost, every subsequent session copies-in the stripped version.

**What happened in practice:** The `settings.json` at the bind-mount was stripped of its `"skills"`/`"prompts"` keys by a prior session's copy-out. Subsequent sessions lost access to the sandbox-layer skills and prompts even though the files existed in the image at `/opt/workflow/`. Recovery required manually re-seeding the bind-mount from the onboard source.

---

## 2. Constraints

These are system invariants and design decisions that any solution must satisfy:

1. **Image-baking of sandbox-layer files is intentional and must remain.** The `build_context_agent()` → `provider.Dockerfile COPY` chain that bakes `agent/skills/` and `agent/prompts/` into the image at `/opt/workflow/` provides a stable baseline independent of the working tree. When dogfooding, the working tree may be in a broken state during development — the image-baked files ensure core sandbox workflow (session startup, diff/branch packaging, sandbox-awareness) remains functional. This also ensures portability across projects: a project using agent-sandbox as a harness inherits these workflow files regardless of what the project's working tree contains.

2. **`AGENT_HOME`/`~/.pi/agent/` cannot be bind-mounted as a whole directory.** Pi downloads platform-specific binaries (fd, rg) to `~/.pi/agent/bin/` using a cross-device `mv` from `/tmp/`. On a bind mount, this would be a cross-filesystem move and would fail. The `bin/` subdirectory must remain container-local.

3. **Pi's auto-discovery paths work for provider-layer and user-layer content.** Pi auto-discovers prompts from `~/.pi/agent/prompts/` and skills from `~/.pi/agent/skills/` by default. The provider-layer `pi-agent.md` prompt already uses this mechanism — it's seeded into `~/.pi/agent/prompts/` via copy-in and discovered without any `settings.json` key. The sandbox-layer files at `/opt/workflow/` are NOT at auto-discovery paths — they rely on custom `settings.json` keys.

4. **The copy-out cycle must not overwrite harness-owned config.** Whatever replaces the current mechanism must prevent pi's runtime state from permanently overwriting the seeded configuration.

5. **User-provided packages, skills, and prompts must continue to work.** The solution must not prevent users from installing their own pi packages or placing custom skills/prompts into the auto-discovery directories.

---

## 3. Three-layer loading model

The skills and prompts follow a three-layer model, each with a distinct loading mechanism:

| Layer | Source | Loaded via | Update mechanism |
|---|---|---|---|
| **Provider layer** | `providers/<n>/config/agent/skills&#124;prompts/` | Pi auto-discovery from `~/.pi/agent/skills&#124;prompts/` (config-seeded, survives image rebuild) | `onboard.sh --refresh` or edit `$SANDBOX_DIR/.<provider>/` |
| **Sandbox (workflow) layer** | `agent/skills/`, `agent/prompts/` | Image-baked at `/opt/workflow/agent/skills&#124;prompts/`, referenced by `settings.json` keys | Image rebuild (`make build`) — stable baseline independent of working tree |
| **User layer** | `$SANDBOX_DIR/.<provider>/agent/skills&#124;prompts/` | Pi auto-discovery from `~/.pi/agent/skills&#124;prompts/` | Direct filesystem placement by operator |

The sandbox layer is the only one that depends on `settings.json` keys — it is not at an auto-discovery path. This makes it the single point of failure.

---

## 4. Settled design: directory bind mount + tmpfs overlay

### 4.1 Mount layout

Eliminate the `/opt/provider-config` path, the copy-in/copy-out cycle, and the `provider-entrypoint.sh` config logic. Mount the config directory directly at `AGENT_HOME` with a tmpfs overlay at `bin/`:

**In `libs/docker-compose.yml`:**
```yaml
services:
  agent:
    volumes:
      # Existing (unchanged)
      - type: bind
        source: ${INPUT_DIR}
        target: /home/agentuser/workspace/input
        read_only: true
      - type: bind
        source: ${OUTPUT_DIR}
        target: /home/agentuser/workspace/output

      # NEW: Mount the entire agent config directory directly at AGENT_HOME
      # Replaces the old /opt/provider-config mount + copy-in/copy-out cycle.
      # All writes (settings.json, auth.json, sessions/) go directly to host.
      - type: bind
        source: ${SANDBOX_DIR}/.{{PROVIDER_NAME}}/agent
        target: /home/agentuser/.pi/agent

      # NEW: tmpfs overlay at bin/ — keeps binary downloads container-local
      # so pi's cross-device mv from /tmp does not cross filesystem boundaries.
      - type: tmpfs
        target: /home/agentuser/.pi/agent/bin

      # NEW: Live sandbox-layer workflow files (read-only, real-time sync)
      - type: bind
        source: {{REPO_ROOT}}/agent/skills
        target: /opt/workflow-host/skills
        read_only: true
      - type: bind
        source: {{REPO_ROOT}}/agent/prompts
        target: /opt/workflow-host/prompts
        read_only: true
```

No `/opt/provider-config` mount. No copy-in function. No copy-out function. The entrypoint becomes `exec "$@"` after env-var validation.

### 4.2 Settings changes

`providers/pi/config/agent/settings.json` references both the image-baked fallback and the live host path:

```json
{
  "skills": ["/opt/workflow/agent/skills", "/opt/workflow-host/skills"],
  "prompts": ["/opt/workflow/agent/prompts", "/opt/workflow-host/prompts"],
  "packages": ["/opt/workflow/agent"]
}
```

Pi loads from all paths in the array. The image-baked paths (`/opt/workflow/`) are the stable fallback — always present, independent of the working tree. The host-mounted paths (`/opt/workflow-host/`) reflect the current working tree for real-time hot-reload via `pi /reload`.

### 4.3 Pre-flight merge (ownership protection)

`provider-entrypoint.sh` loses `_copy_in` and `_copy_out`. Before exec-ing pi, it runs a targeted JSON merge to ensure harness-owned keys survive:

```bash
_ensure_harness_keys() {
  local settings="$AGENT_HOME/agent/settings.json"
  if [[ -f "$settings" ]]; then
    local tmp
    tmp=$(mktemp)
    node -e "
      const fs = require('fs');
      const p = process.argv[1];
      const o = JSON.parse(fs.readFileSync(p, 'utf8'));
      o.packages = [...new Set([...(o.packages||[]), '/opt/workflow/agent'])];
      o.skills = ['/opt/workflow/agent/skills', '/opt/workflow-host/skills'];
      o.prompts = ['/opt/workflow/agent/prompts', '/opt/workflow-host/prompts'];
      fs.writeFileSync(p, JSON.stringify(o, null, 2) + '\n');
    " "$settings"
    rm -f "$tmp"
  fi
}
```

Since `settings.json` is bind-mounted, the write goes directly to the host. The merge is additive — pi's runtime values for pi-managed keys (model, provider, theme) are preserved.

### 4.4 Pre-creation in run_agent.sh

`scripts/run_agent.sh` already does `mkdir -p "$SANDBOX_DIR/.$PROVIDER_NAME"`. Extended to:
```bash
mkdir -p "$SANDBOX_DIR/.$PROVIDER_NAME/agent/sessions"
```

The `sessions/` subdirectory must exist on the host before the bind mount is created, otherwise Docker creates it as root-owned.

### 4.5 File-by-file resolution

| File | Before | After |
|---|---|---|
| `settings.json` | Copy-in/copy-out (lost keys on cycle) | RW bind mount via agent/ dir mount. Pre-flight merge ensures keys. Real-time sync. |
| `models.json` | Copy-in/copy-out | RW bind mount via agent/ dir mount. Real-time sync. |
| `auth.json` | Copy-in/copy-out | RW bind mount via agent/ dir mount. Pi writes auth tokens in-place — no cross-device issue. |
| `AGENTS.md` | Copy-in/copy-out | RW bind mount via agent/ dir mount. Never modified by pi (effectively RO). |
| `sessions/` | Copy-in/copy-out | RW bind mount via agent/ dir mount. Pi writes session files. Pre-created by run_agent.sh. |
| `bin/` | Copy-in/copy-out (wasteful) | **tmpfs** — container-local, ephemeral. Pi re-downloads fd/rg each session. |
| `prompts/` (pi-agent.md) | Copy-in/copy-out of seed | RW bind mount via agent/ dir mount (effectively RO — only read by pi). |
| `skills/`, `prompts/` (sandbox layer) | Image-baked at `/opt/workflow/` | Image-baked + RO bind mount at `/opt/workflow-host/`. Real-time sync for development. |

### 4.6 Change surface

| File | What changes |
|---|---|
| `libs/docker-compose.yml` | Remove `/opt/provider-config` mount. Add `agent/` dir mount, `bin/` tmpfs, `skills/` and `prompts/` workflow mounts. |
| `libs/provider-entrypoint.sh` | Remove `_copy_in`, `_copy_out`. Add `_ensure_harness_keys` (Node.js merge). Keep env-var validation + `exec "$@"`. |
| `scripts/run_agent.sh` | Extend `mkdir -p` to pre-create `agent/sessions` subdirectory. |
| `providers/pi/config/agent/settings.json` | Add `packages`, `/opt/workflow-host/` paths. |
| `providers/pi/config/agent/models.json` | No change needed (just benefits from real-time sync). |

No changes needed: `providers/pi/setup.sh`, `scripts/onboard.sh`, `libs/compose.sh`.

---
[CORRECTION — 2026-05-22]: Filesystem compatibility gap — the bind mount at `AGENT_HOME` assumes the host filesystem supports `utime()`. When `SANDBOX_DIR` resides on a 9p mount (WSL2/Docker Desktop Windows drive, macOS virtiofs), `proper-lockfile` (used by Pi's `settings-manager.js`) fails with `EPERM` on `fs.utimesSync()`. The lock acquisition throws before the settings file is read or written, causing all settings to silently fall back to defaults. The design did not account for filesystems that do not support timestamp modification.

**Pi bump (0.75.4) was tested and did not resolve the issue** — Pi still falls back to default settings when settings.json resides on a cross-filesystem bind mount.

**Resolution (original):** Prefer approach 1 — keep `PROJECT_DIR` (and thus `SANDBOX_DIR`) on a Linux-native WSL2 path (e.g., `/home/user/projects/...`) rather than a Docker Desktop Windows drive (`/mnt/c/...`, `M:\`). When the project resides on the Linux-native ext4 filesystem, the `AGENT_HOME` bind mount inherits ext4's POSIX semantics and `utime()` succeeds. This avoids the 9p seam entirely with no code or mount changes. **However, this only works for Windows + WSL2. macOS Docker Desktop uses virtiofs which has the same utime limitation.**

**Resolution (revised, 2026-05-22):** The bind mount approach is invalidated for cross-filesystem hosts. The favoured path is to revert to a copy-in model: copy config from a host-mounted source directory into a container-local filesystem at startup, avoiding the cross-fs utime issue entirely. This re-introduces a copy-out step on clean exit. See session `20260522-05-design-pi_agent_mount_strategy.md`.

Mitigation (if copy-in is not possible): Pi's `settings-manager.js` must catch `EPERM` and proceed without locking, or `proper-lockfile`'s `mtimePrecision.probe()` must handle `EPERM` as a non-fatal error (falling back to second-level precision).

See also: `devlog/discussions/story_windows_filesystem_incompatibilities.md` for the broader story on Windows filesystem issues, and `devlog/handovers/20260522-05-design-pi_agent_mount_strategy.md` for the re-evaluation.

---

## 5. Decision record

| Decision | Status | Rationale |
|---|---|---|
| Copy-in/copy-out cycle eliminated | **Settled** | Replaced by direct bind mount + tmpfs overlay at bin/. Simpler, faster, no ownership collision. |
| `/opt/provider-config` removed | **Settled** | Config directory mounted directly at AGENT_HOME. |
| `bin/` as tmpfs | **Settled** | Shadows the dir mount to keep binary downloads container-local (cross-device mv). |
| Provider config mounted as directory (`agent/`), not individual files | **Settled** | One mount covers AGENTS.md, auth.json, models.json, settings.json, sessions/, prompts/. N-volumes not needed. |
| Sandbox-layer skills/prompts as RO bind mounts at `/opt/workflow-host/` | **Settled** | Real-time sync for development. Image-baked `/opt/workflow/` stays as fallback. |
| `settings.json` paths reference both image-baked and host-mounted | **Settled** | Two-adapter seam: image path is fallback, host path is live. [see correction below] |
| Pre-flight merge via Node.js | **Settled** | Node is already in base image (node:20-slim). No jq dependency needed. |
| Three-layer loading model | Settled (previous session) | See `docs/concepts/agent_workflow.md` |
| Fragility documented in provider_lifecycle.md | Settled (previous session) | See `docs/architecture/provider_lifecycle.md` |
