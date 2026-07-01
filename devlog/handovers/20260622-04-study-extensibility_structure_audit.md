# Agent Handover

**Session date:** 2026-06-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Study — extensibility structure audit
**Status:** Closed

## Objective

Audit where provider-specific paths leak into shared harness code, and where shared assumptions are hardcoded into provider overlays. Produce a documented boundary: what should live in shared code vs. provider hooks.

## Scope

P2-INV1 — extensibility structure audit per roadmap §Pre-design investigations.

## Files Examined

| File | Role |
|---|---|
| `src/build/docker-compose.yml` | Base compose template (shared) |
| `src/build/compose.sh` | Compose file generation and lifecycle |
| `scripts/start_agent.sh` | Host-side session setup |
| `scripts/run_agent.sh` | Provider container lifecycle |
| `scripts/onboard.sh` | Project onboarding |
| `scripts/build.sh` | Image build pipeline |
| `src/reasoning/providers/pi/docker-compose.pi.yml` | Pi compose overlay |
| `src/reasoning/providers/hermes/docker-compose.hermes.yml` | Hermes compose overlay |
| `src/reasoning/providers/pi/setup.sh` | Pi pre-run setup hook |
| `src/reasoning/providers/pi/onboard.sh` | Pi onboarding hook |
| `src/reasoning/providers/pi/preflight.sh` | Pi container preflight |
| `src/reasoning/entrypoint.sh` | Shared provider entrypoint |

## Findings

### Finding E1 — AGENT_HOME bind mounts live in the Pi overlay only, not in shared compose template

**File:** `src/reasoning/providers/pi/docker-compose.pi.yml` (lines 26–34)

```yaml
volumes:
  - type: bind
    source: ${SANDBOX_DIR}/.{{PROVIDER_NAME}}/agent/prompts
    target: /home/agentuser/.pi/agent/prompts
  - type: bind
    source: ${SANDBOX_DIR}/.{{PROVIDER_NAME}}/agent/sessions
    target: /home/agentuser/.pi/agent/sessions
  - type: bind
    source: ${SANDBOX_DIR}/.{{PROVIDER_NAME}}/agent/skills
    target: /home/agentuser/.pi/agent/skills
```

**Why it matters:** These bind mounts hardcode the Pi AGENT_HOME path (`/home/agentuser/.pi/agent/...`). Hermes and OpenCode have no analogous bind mounts — they have no AGENT_HOME persistence at all via compose. Under Phase 2 (worktree model), AGENT_HOME persistence becomes critical because session resume depends on it. Every provider needs an equivalent block, but the path and subdirectory structure differ per provider.

**Recommended boundary:**
- **Shared:** The pattern of selective AGENT_HOME bind mounts (write-through subdirs + ephemeral config) should be documented in the shared compose template as a conditional or commented block.
- **Provider hook:** The specific paths, subdirectory list, and target mapping should live in a provider overlay or a provider config file that the compose template references.

---

### Finding E2 — Compose template's `x-workspace` documents a `provider_config` mount that doesn't exist

**File:** `src/build/docker-compose.yml` (line 42)

```yaml
provider_config_host: "${SANDBOX_DIR}/.{{PROVIDER_NAME}}" # → "/opt/provider-config"
```

**Why it matters:** This line documents a mount mapping (`SANDBOX_DIR/.<provider>` → `/opt/provider-config`) that is never actually mounted in the compose template or any overlay. The comment in `run_agent.sh` (lines 16–20) also references `/opt/provider-config` as the copy-in/copy-out mechanism, but the actual implementation copies from the baked image template (`/opt/workflow/agent/config/`) instead. This is stale documentation — if someone adds a new provider following the comments, they'll expect a `/opt/provider-config` mount that doesn't exist.

**Recommended boundary:** Remove the stale `x-workspace` reference or add the actual mount. Update `run_agent.sh` header comments to match the real copy-in mechanism.

---

### Finding E3 — Provider setup hooks are free-form with no contract

**Files:**
- `src/reasoning/providers/pi/setup.sh` — pre-creates `SANDBOX_DIR/.pi/` for Pi
- `src/reasoning/providers/pi/onboard.sh` — pre-creates AGENT_HOME subdirs for Pi
- No Hermes or OpenCode setup/onboard hooks exist

**Why it matters:** The contract for `setup.sh` is undocumented — it's just "sourced if exists" (`run_agent.sh` line 96). There's no defined interface (what variables it can set, what side effects are allowed, what must happen before it runs). Adding a new provider requires reading the Pi hook to reverse-engineer the pattern. Under Phase 2, these hooks will need to set up mount-mode-specific state (e.g., pre-creating the worktree directory, configuring `PROJECT_DIR/.git` permissions).

**Recommended boundary:**
- **Shared:** Define a documented `setup.sh` contract in `provider_onboarding_guide.md` — required exports, allowed side effects, execution environment.
- **Provider hook:** Per-provider setup.sh implements the contract. Empty/missing = no setup needed.

---

### Finding E4 — Provider compose overlays are inconsistent in structure

**Files:**
- `pi/docker-compose.pi.yml` — adds environment variables + AGENT_HOME volume binds + no serve mode
- `hermes/docker-compose.hermes.yml` — adds environment variables only
- `opencode/docker-compose.serve.yml` — serve mode only, no base overlay exists

**Why it matters:** OpenCode has no `docker-compose.opencode.yml` overlay at all — it relies entirely on the base compose template for all modes. Hermes has a base overlay for env vars only. Pi has the most elaborate overlay with bind mounts. This inconsistency means adding a new provider requires guessing which parts of the compose configuration should go in an overlay vs. being handled by the base template.

Under Phase 2, mount-mode-specific compose changes (e.g., conditional `read_only: false` on `.snapshot/`, additional worktree mounts) will need to be consistent across all providers. The current ad-hoc overlay structure makes this risky.

**Recommended boundary:** A provider overlay contract should specify:
- **Required:** Base mode overlay (always merged)
- **Optional:** Serve mode overlay (merged in serve mode)
- **Standard env vars** that every provider overlay should set (PROVIDER_NAME, API key injection via .env)
- **AGENT_HOME persistence** — either via the shared template or a documented per-overlay pattern

---

### Finding E5 — Provider entrypoint (`entrypoint.sh`) is genuinely shared — good

**File:** `src/reasoning/entrypoint.sh`

The shared entrypoint is provider-agnostic: it references `$AGENT_HOME`, `$PROVIDER_NAME`, and `/opt/workflow/agent/config/` which are all set per-provider via Dockerfile `ENV` and image layers. The provider-specific `preflight.sh` hook is sourced only if present. **No changes needed** for Phase 2 — this is a well-designed boundary.

---

### Finding E6 — Provider preflight hooks (pi/preflight.sh) are provider-scoped — good

**File:** `src/reasoning/providers/pi/preflight.sh`

Pi's preflight hook validates Pi-specific state (AGENTS.md location, `settings.json` key merge). It's sourced by the shared entrypoint only if the file exists. Other providers have no preflight hook — the entrypoint works without one. **No changes needed** for Phase 2.

---

### Finding E7 — `onboard.sh` discovers providers by scanning `src/reasoning/providers/` — good

**File:** `scripts/onboard.sh` (lines 213–214)

```bash
for PROVIDER_DIR in "$REPO_ROOT/src/reasoning/providers/"*/; do
```

This is clean — adding a new provider means adding a directory. No shared code changes needed for discovery. The provider-specific onboard hook (`providers/<n>/onboard.sh`) is sourced if present. **No changes needed** for Phase 2.

---

### Finding E8 — `build.sh` discovers provider configs for container-sig — good

**File:** `scripts/build.sh` (line 40)

```bash
if [[ -d "$repo_root/src/reasoning/providers/$provider/config" ]]; then
    sources="$sources src/reasoning/providers/$provider/config"
```

Container-sig computation includes provider-specific config. Clean. **No changes needed.**

---

### Finding E9 — `run_agent.sh` compose assembly is provider-aware but uses hardcoded overlay file names

**File:** `scripts/run_agent.sh` (lines 127–130)

```bash
PROVIDER_OVERLAY="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/docker-compose.${PROVIDER_NAME}.yml"
SERVE_OVERLAY="$REPO_ROOT/src/reasoning/providers/$PROVIDER_NAME/docker-compose.serve.yml"
```

The overlay file name pattern is `docker-compose.<provider>.yml`. If a provider doesn't have one (OpenCode), the file isn't found and simply skipped. This is flexible but undocumented — a new provider author won't know whether they need to create an overlay or not.

**Recommended boundary:** Document the overlay naming convention and contract in `provider_onboarding_guide.md`. Under Phase 2, the overlay may need additional keys (e.g., mount-mode-specific volume definitions).

---

### Finding E10 — Pi AGENT_HOME paths are hardcoded across Pi overlay, setup, and preflight

The Pi string `~/.pi/agent` appears in:
1. `src/reasoning/providers/pi/docker-compose.pi.yml` — `target: /home/agentuser/.pi/agent/...`
2. `src/reasoning/providers/pi/provider.dockerfile` — `ENV AGENT_HOME=/home/agentuser/.pi`
3. `src/reasoning/providers/pi/preflight.sh` — references `$AGENT_HOME/agent/` (note the `agent/` subdirectory)
4. `src/reasoning/providers/pi/onboard.sh` — `mkdir -p "$SANDBOX_DIR/.pi/agent/..."`

**Why it matters:** The `AGENT_HOME` env var is set consistently (`/home/agentuser/.pi`), but Pi's actual config lives in `/home/agentuser/.pi/agent/` — an `agent/` subdirectory within AGENT_HOME. This is Pi-specific: `settings.json`, `prompts/`, `skills/` all sit under `$AGENT_HOME/agent/`. Other providers (Hermes, OpenCode) put config directly in `$AGENT_HOME`. This means the selective bind mount paths in the Pi overlay cannot be generalised without understanding Pi's subdirectory convention.

**Recommended boundary:** Document Pi's `agent/` subdirectory convention in the provider onboarding guide as a provider-specific quirk. The shared compose template should not attempt to abstract this away.

---

## Risk Summary

| # | Finding | Severity | Impact on Phase 2 |
|---|---|---|---|
| E1 | AGENT_HOME bind mounts in Pi overlay only | **HIGH** | Hermes/OpenCode have no AGENT_HOME persistence; session resume won't work for them under mount model |
| E2 | Stale `/opt/provider-config` doc in compose template + run_agent.sh header | **LOW** | Misleads new provider authors; no functional impact |
| E3 | Provider setup hooks have no documented contract | **MEDIUM** | Phase 2 mount wiring will need setup hooks to configure per-provider mount paths |
| E4 | Provider compose overlays are inconsistent | **MEDIUM** | Phase 2 needs a consistent pattern for conditional mounts across all providers |
| E5 | Shared entrypoint is provider-agnostic | **NONE** | Good architecture — no change needed |
| E6 | Preflight hooks are provider-scoped | **NONE** | Good architecture — no change needed |
| E7 | Provider discovery via filesystem scan | **NONE** | Clean — no change needed |
| E8 | Container-sig includes config | **NONE** | Clean — no change needed |
| E9 | Compose overlay naming convention undocumented | **LOW** | Easy to miss during provider onboarding |
| E10 | Pi's `agent/` subdirectory convention is provider-specific | **LOW** | Must be documented; shared code should not abstract it |

## Documented Boundary

**Shared code** (should stay shared):
- `src/build/docker-compose.yml` — base compose template, env var injection
- `src/build/compose.sh` — compose generation and lifecycle
- `scripts/start_agent.sh` — session setup (but needs mount-mode awareness per P1-PF1)
- `scripts/run_agent.sh` — container lifecycle (mounts /opt/provider-config? — needs doc fix)
- `scripts/onboard.sh` — provider discovery via filesystem scan
- `scripts/build.sh` — build pipeline
- `src/reasoning/entrypoint.sh` — shared entrypoint (already clean)

**Provider hooks** (should live in `providers/<n>/`):
- `providers/<n>/onboard.sh` — onboarding hook (Pi creates AGENT_HOME subdirs here)
- `providers/<n>/setup.sh` — pre-run setup (Pi pre-creates SANDBOX_DIR/.pi/)
- `providers/<n>/preflight.sh` — container preflight (Pi validates AGENTS.md, merges settings.json)
- `providers/<n>/docker-compose.<n>.yml` — base compose overlay (env vars, AGENT_HOME binds)
- `providers/<n>/docker-compose.serve.yml` — serve mode overlay
- `providers/<n>/base.dockerfile` — Tier 2 install layer
- `providers/<n>/provider.dockerfile` — Tier 3 final image

**Needs documentation in `provider_onboarding_guide.md`:**
- Setup hook contract (variables, side effects, execution environment)
- Compose overlay naming convention and required sections
- AGENT_HOME path convention (Pi's `agent/` subdirectory is an outlier)
- /opt/provider-config mount (stale — remove or implement)

## Recommendations for Phase 2 Design Session

1. **Define a per-provider AGENT_HOME persistence contract** — shared compose template should support conditional AGENT_HOME bind mounts, with each overlay providing the path list.
2. **Fix stale `/opt/provider-config` documentation** — remove from `x-workspace` and `run_agent.sh` header, or implement the mount.
3. **Document setup.sh contract in `provider_onboarding_guide.md`** — what it can export, what side effects are allowed.
4. **Add OpenCode base compose overlay** — even if empty, to make the pattern consistent and explicit.
5. **Keep the shared entrypoint as-is** — it's the right boundary.
