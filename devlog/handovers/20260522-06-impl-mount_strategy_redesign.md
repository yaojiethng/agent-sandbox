# Agent Handover

**Session date:** 2026-05-22
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Implementation
**Status:** Closed

## Objective

Implement the selective bind mount approach for `.pi/agent/` — mount only `prompts/`, `sessions/`, `skills/` as RW bind mounts; everything else ephemeral via copy-in from a baked image template — to resolve the cross-filesystem utime/EPERM issue.

## Scope

1. Create story document for agent state persistence (`story_agent_state_persistence.md`).
2. Design and implement generic `_provision_agent_home` helper in the shared entrypoint.
3. Update compose template (`libs/docker-compose.yml`) for selective bind mounts.
4. Update provider Dockerfile to bake config template into image.
5. Add generic AGENT_HOME validation to pre-flight (Proposal 3).
6. Add bind-mounted subdir checks to Pi's preflight.
7. Add M2.6 cross-reference in roadmap.
8. Update M2.4 description to reflect Pi.

## Carried forward

| Item | From handover |
|---|---|
| Mount strategy redesign — selective bind mounts + ephemeral config | `20260522-05` — deferred items |
| Story for agent state persistence | `20260522-05` — deferred items |
| M2.4 description cleanup | `20260522-05` — deferred items |

## Decisions made this session

| Decision | Rationale |
|---|---|
| `_provision_agent_home` runs before pre-flight, ensuring config is ready for checks | Semantic: provision → pre-flight → flight. Config guaranteed before any check runs. |
| Generic pre-flight (Proposal 3) rolled into one block with existing lib check, not a separate hook | Multiple hooks would be over-engineering. One pre-flight block with ordered substeps (lib check → AGENT_HOME check → provider hook) keeps it simple. |
| Cross-fs detection is structurally unnecessary — root AGENT_HOME is always container-local | Only prompts/, sessions/, skills/ are bind-mounted. Pi's proper-lockfile only touches settings.json (ephemeral, never bind-mounted). |
| Build context copies entire provider config dir, no filtering | Filtering would make `build_context_agent` provider-aware. Instead, `_provision_agent_home` receives a skip-list matched to compose template bind mounts — all specialization lives there. |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Generic AGENT_HOME validation at entrypoint level should only check universal invariants (dir exists, writable). Bind-mounted subdir checks are provider-specific. | design clarity | Bind mount checks moved to Pi's preflight, not shared entrypoint. |
| `tests/knowledge/` is excluded from `make test` by design — knowledge tests document external tool behaviour, not system behaviour. Agent mistakenly ran them during verification. `new-session.md` updated to guide agents to use `make test` for AC verification. | doc gap | Updated new-session.md; no code change needed. |

## Completed this session

| File | Change |
|---|---|
| [`libs/containers.sh`](../../libs/containers.sh) | `build_context_agent`: copies entire `prov/<n>/config/` into build context as `agent/config/`. Updated header comment. |
| [`providers/pi/provider.Dockerfile`](../../providers/pi/provider.Dockerfile) | Added `COPY agent/config/ /opt/workflow/agent/config/`. Updated header comments for new architecture. |
| [`libs/provider-entrypoint.sh`](../../libs/provider-entrypoint.sh) | Added `_provision_agent_home()` helper — copies template files to AGENT_HOME, skipping bind-mounted subdirs. Added generic AGENT_HOME validation (writable, exists) in pre-flight block. Updated header comments. |
| [`libs/docker-compose.yml`](../../libs/docker-compose.yml) | Removed Pi-specific bind mounts (moved to `providers/pi/docker-compose.pi.yml`). Generic compose now has only sandbox-level mounts (snapshot, changes, input, output). |
| [`providers/pi/preflight.sh`](../../providers/pi/preflight.sh) | Added `_preflight_check_bind_mounts` — verifies prompts/, sessions/, skills/ are present and writable. Integrated into run sequence. |
| [`docs/devlog/discussions/story_agent_state_persistence.md`](../../docs/devlog/discussions/story_agent_state_persistence.md) | **New** — story document for agent state persistence under AGENT_HOME. |
| [`docs/devlog/roadmap.md`](../../docs/devlog/roadmap.md) | Added M2.6 cross-reference to story. |

## Deferred items

| Item | Reason | Goes to |
|---|---|---|
| M2.4 description cleanup — milestone description references opencode still | Minor doc fix, not blocking mount redesign | Next session |

## Next session

TBD. Rebuild and test after mount strategy change: verify skills/prompts/sessions survive, settings.json/auth.json/models.json regenerate correctly from template, _ensure_harness_keys merge works on fresh copy.

---

## [CORRECTION — 2026-05-23] Volume ownership and metadata-agnostic provisioning

### Root cause

When a bind mount target path doesn't exist in the image, the Docker Daemon
(running as **root**) auto-creates it at container start. These directories are
owned by `root:root`. The entrypoint runs as `agentuser` (uid 1001) — any `cp`
into root-owned paths fails with "Permission denied".

Additionally, standard archive-mode copy commands (`cp -a`, `rsync -av`) try to
preserve ownership and timestamps. On cross-filesystem mounts (virtiofs, 9p),
a non-privileged user cannot set these attributes — resulting in `EPERM`.

The old parent bind mount of the entire `.pi/agent/` tree masked both issues.

### Fixes applied

1. **`providers/pi/provider.Dockerfile`** — pre-emptive path claiming:
   `mkdir -p` each bind mount target (`prompts/`, `sessions/`, `skills/`,
   `bin/`) before the `USER agentuser` switch, followed by
   `chown -R agentuser:agentuser /home/agentuser/.pi`. Docker doesn't
   auto-create paths that already exist, so they stay agentuser-owned.

2. **`libs/provider-entrypoint.sh`** — metadata-agnostic provisioning:
   `_provision_agent_home` uses `cp -RT --no-preserve=all` (single command,
   no per-item loop). `--no-preserve=all` skips ownership and timestamps;
   `-T` prevents double-nesting when the target dir already exists.

3. **Mount isolation:** Pi-specific bind mounts moved from generic
   `libs/docker-compose.yml` to `providers/pi/docker-compose.pi.yml`.
   The generic compose has only sandbox-level mounts (snapshot, changes,
   input, output).

4. **tmpfs removed:** `bin/` is now a regular dir on container overlayfs —
   same filesystem as `/tmp/`, so Pi's `mv` uses native `rename()` without
   cross-device fallback. `fd-find`/`ripgrep` via apt make auto-downloads
   unnecessary anyway.

**Documented in:** `providers/pi/onboard-readme.md`  Ephemeral vs Mounted and
 Binary Downloads.
