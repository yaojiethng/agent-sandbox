# Agent Handover

**Date:** 2026-06-22
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Study — repo preconditions audit
**Status:** Closed

## Objective

Audit the codebase for pre-existing conditions that would make Phase 2 (mount model implementation) harder: hardcoded paths, snapshot-only lifecycle assumptions, anonymous volume assumptions, and compose template structures that assume the current copy+tar model.

## Methodology

Systematic search across `scripts/`, `src/`, and `src/build/docker-compose.yml` for patterns that implicitly depend on the snapshot copy model rather than a mount-based model.

## Findings

### Finding 1 — `snapshot_init_git` embeds the copy-from-baseline.tar lifecycle

**File:** `src/capability/snapshot.sh` (lines 259–340)

**What:** `snapshot_init_git()` hardcodes the two-step copy pipeline:
1. Unpack `baseline.tar` from `SNAPSHOT_DIR` into `SANDBOX_DIR`
2. Rsync working tree overlay on top

**Why it matters for Phase 2:**
- Under Tier 2 (mount + tar), `SNAPSHOT_DIR` IS `SANDBOX_DIR` — the git init needs to happen in-place, not from a tar extract to a separate directory.
- Under Tier 3 (mount + worktree), there's no `baseline.tar` at all — the worktree already has git history. `snapshot_init_git` is entirely the wrong function.

**The function has no conditional path for mount mode.** Phase 2 must either parameterise it or write a separate `snapshot_init_mount()` / `snapshot_init_worktree()`.

---

### Finding 2 — `start_agent.sh` always executes the copy pipeline

**File:** `scripts/start_agent.sh` (lines 229–244)

```bash
rm -rf "$SNAPSHOT_DIR"
mkdir -p "$SNAPSHOT_DIR"
snapshot_copy_worktree "$PROJECT_DIR" "$SNAPSHOT_DIR"
snapshot_archive_head "$PROJECT_DIR" "$SNAPSHOT_DIR"
snapshot_validate "$SNAPSHOT_DIR"
```

**Why it matters:** Under Tier 2 (mount), `SNAPSHOT_DIR` is inside `SANDBOX_DIR` which is a host bind mount — `rm -rf "$SNAPSHOT_DIR"` would delete the entire working tree. Under Tier 3 (worktree), the snapshot is a `git worktree add`, not an rsync copy. Phase 2 needs to gate this block behind a mount-model flag.

---

### Finding 3 — Compose template bakes snapshot as `read_only` bind mount

**File:** `src/build/docker-compose.yml` (lines 51–56)

```yaml
volumes:
  - type: bind
    source: ${SNAPSHOT_DIR}
    target: /home/agentuser/.snapshot
    read_only: true
```

**Why it matters:** Under Tier 2/3, the snapshot IS the sandbox working tree — it must be **read-write**, not read-only. The compose template currently has no conditional for this. The `target` path (`/home/agentuser/.snapshot`) is also hardcoded rather than parameterised.

---

### Finding 4 — `volumes_from` shares an anonymous volume between sandbox and agent

**File:** `src/build/docker-compose.yml` (line 85)

```yaml
volumes_from:
  - sandbox
```

**What:** The agent container inherits all volumes from the sandbox container. Currently this includes the anonymous Docker volume where `sandbox/` lives.

**Why it matters:** Under Tier 2/3, `sandbox/` is a bind mount from the host (via `.snapshot/`). The `volumes_from` mechanism still works for bind mounts, but the semantics change:
- Currently: anonymous volume created by Docker, populated by the entrypoint, destroyed on `down -v`
- Under mount model: bind mount to host path, data persists, `down -v` does not destroy it

The `down -v` in `compose_teardown()`, `run_agent.sh`, and `compose.sh` would need to stop using `-v` for the sandbox volume in mount mode, or the volume cleanup logic in `stop.sh` would need a mount-mode flag to skip anonymous volume removal.

---

### Finding 5 — `stop.sh` and `prune.sh` always remove anonymous volumes

**Files:** `scripts/stop.sh` (lines 96–112), `scripts/prune.sh` (lines 53–55)

**What:** `stop.sh` removes Docker volumes labelled with `agent-sandbox.project-name` and `agent-sandbox.sandbox-dir`. `prune.sh` runs `docker volume prune --force --filter "label!=agent-sandbox.project-name"` to catch any orphaned anonymous volumes.

**Why it matters:** Under Tier 2/3, there are no anonymous volumes to remove — the sandbox working tree lives on a host bind mount. `stop.sh` would either find no volumes (harmless) or attempt to remove the bind mount's host path (harmless since Docker volumes CLI ignores bind mounts). The `prune.sh` catch-all is also harmless. **Low risk** — Docker silently skips bind mounts in volume operations. But the code implies a lifecycle that no longer applies.

---

### Finding 6 — `compose.sh` and `run_agent.sh` use `down -v` unconditionally

**Files:**
- `src/build/compose.sh` (lines 200, 216, 281, 294) — `docker compose ... down -v`
- `scripts/run_agent.sh` (lines 227, 240) — `docker compose ... down -v`

**Why it matters:** `docker compose down -v` removes anonymous volumes referenced by `volumes_from`. Under the mount model, if `sandbox/` is a bind mount via `.snapshot/` rather than an anonymous volume, `-v` is a no-op for that mount. **No breakage expected**, but the `-v` flag suggests the wrong mental model. Phase 2 should consider whether to keep `-v` for the session-diffs volume (still an anonymous volume?) or make it conditional.

---

### Finding 7 — `snapshot_copy_worktree()` and `snapshot_archive_head()` are host-side only

**Files:** `src/capability/snapshot.sh` (lines 38, 144)

**What:** These two functions run on the host to populate `SNAPSHOT_DIR` before the container starts. They are not called inside the container — the container only calls `snapshot_validate()` and `snapshot_init_git()`.

**Why it matters:** Under Tier 2, the host-side copy is replaced by the mount — but `snapshot_archive_head()` is still needed to produce `baseline.tar` for `snapshot_init_git()`. Under Tier 3, both functions are replaced by `git worktree add`. Phase 2 needs to decide whether to:
- Keep `snapshot_archive_head()` for Tier 1/2 backward compatibility
- Replace with `git worktree add` for Tier 3

---

### Finding 8 — `SNAPSHOT_DIR` is hardcoded as `SANDBOX_DIR/.snapshot` in start_agent

**File:** `scripts/start_agent.sh` (line 141)

```bash
export SNAPSHOT_DIR="${SANDBOX_DIR}/.snapshot"
```

**Why it matters:** Under Tier 2 (mount + tar), `SNAPSHOT_DIR` is the **source** of the mount, not a child of `SANDBOX_DIR`. The relationship inverts: instead of `.snapshot/` being inside `SANDBOX_DIR` for copying, `SANDBOX_DIR` is set to the mounted path and `.snapshot/` is... nothing (the mount is the working tree). Phase 2 must re-derive this path for each tier.

---

### Finding 9 — Capability entrypoint preflight checks `baseline.tar` existence

**File:** `src/capability/entrypoint.sh` (line 151)

```bash
_preflight_crit "SNAPSHOT_DIR is readable (snapshot mount)" test -f "$SNAPSHOT_DIR/baseline.tar"
```

**Why it matters:** Under Tier 3 (worktree), there is no `baseline.tar` — the worktree IS the git checkout. This preflight check would fail. Phase 2 needs to make this check conditional on the mount model.

---

### Finding 10 — `snapshot_init_git` preflight checks `baseline.tar` and aborts if missing

**File:** `src/capability/snapshot.sh` (lines 305–308)

```bash
if [[ ! -f "$SNAPSHOT_DIR/baseline.tar" ]]; then
    echo "Error: baseline.tar not found in SNAPSHOT_DIR: $SNAPSHOT_DIR" >&2
    return 1
```

**Why it matters:** Same as Finding 9 — hard abort if `baseline.tar` is absent. Under Tier 3, init needs to use the worktree's existing git state instead. Phase 2 must either conditionalise this check or branch to a separate worktree init function.

---

### Finding 11 — Agent container healthcheck depends on `sandbox/.git`

**Files:**
- `src/build/docker-compose.yml` (healthcheck: `test -d /home/agentuser/sandbox/.git`)
- All 3 provider Dockerfiles (identical healthcheck in pi, opencode, hermes provider.dockerfiles)

**Why it matters:** Under Tier 3, `sandbox/` is a worktree — it has `.git` (a file pointing to `PROJECT_DIR/.git`). The healthcheck still works. **No change needed.**

---

### Finding 12 — Dry-run scripts assume `SANDBOX_DIR` is a local directory

**Files:** `scripts/dry_run_capability.sh` (line 37), `scripts/dry_run_reasoning.sh` (line 32)

```bash
SANDBOX_DIR="$ROOT/${SANDBOX_DIR_NAME:-sandbox}"
```

**Why it matters:** Under Tier 2/3, `SANDBOX_DIR` is a mounted host path — not a local directory under the dry-run root. The dry-run scripts would need a mode where they skip the `SANDBOX_DIR` creation and instead validate the mount path. **Low risk** — dry-run already handles missing paths gracefully (checks are WARN/CRITICAL, not hard requirements).

---

## Risk Summary

| # | Finding | Severity | Impact if not addressed before Phase 2 |
|---|---|---|---|
| 1 | `snapshot_init_git` embeds copy lifecycle | **HIGH** | Container fails to start under Tier 3 |
| 2 | `start_agent.sh` always runs copy pipeline | **HIGH** | Deletes mounted working tree under Tier 2 |
| 3 | Compose template bakes `read_only` snapshot mount | **HIGH** | Sandbox working tree is read-only under Tier 2/3 |
| 4 | `volumes_from` shares anonymous volume | **MEDIUM** | `down -v` semantics change; stop.sh removes wrong thing |
| 5 | `stop.sh`/`prune.sh` remove anonymous volumes | **LOW** | No-op on bind mounts; mental model mismatch |
| 6 | `down -v` used unconditionally | **LOW** | Harmless for bind mounts; suggests wrong model |
| 7 | Host-side copy functions not mount-aware | **HIGH** | `start_agent.sh` must branch per tier |
| 8 | `SNAPSHOT_DIR` path hardcoded | **HIGH** | Path derivation wrong for Tier 2/3 |
| 9 | Entrypoint checks for `baseline.tar` | **HIGH** | Preflight fails under Tier 3 |
| 10 | `snapshot_init_git` aborts if `baseline.tar` missing | **HIGH** | Init fails under Tier 3 |
| 11 | Agent healthcheck depends on `sandbox/.git` | **NONE** | Works for all tiers |
| 12 | Dry-run assumes local `SANDBOX_DIR` | **LOW** | Graceful degradation |

## Recommendations for Phase 2 Design Session

1. **Introduce a `MOUNT_MODE` variable** (e.g. `copy`, `mount-tar`, `mount-worktree`) set at session start. Gate all conditional paths on it.

2. **Refactor `snapshot_init_git()`** into three paths:
   - `_init_from_tar()` — current behaviour (Tier 1)
   - `_init_from_mount()` — git init on the mounted `.snapshot/` directly, using `baseline.tar` for the baseline commit (Tier 2)
   - `_init_from_worktree()` — no init needed; the worktree already has git state (Tier 3)

3. **Make `start_agent.sh` mount-model-aware** — gate the `rm -rf "$SNAPSHOT_DIR"` and copy calls behind a `case $MOUNT_MODE` block.

4. **Parameterise the compose template** — conditionally set `read_only: false` and derive `SNAPSHOT_DIR`/`SANDBOX_DIR` paths per tier.

5. **Keep `down -v`** for now — it's harmless for bind mounts. But document that `-v` is a no-op under mount models.

## Files Examined

| File | Relevance |
|---|---|
| `scripts/start_agent.sh` | Host-side session setup; copy pipeline gate |
| `src/capability/entrypoint.sh` | Container init; preflight checks for snapshot |
| `src/capability/snapshot.sh` | Snapshot copy, archive, init, and validate functions |
| `src/build/docker-compose.yml` | Compose template; volume and mount definitions |
| `src/build/compose.sh` | Compose lifecycle; teardown |
| `scripts/run_agent.sh` | Compose up/down; `-v` usage |
| `scripts/stop.sh` | Container/volume cleanup |
| `scripts/prune.sh` | Orphaned volume cleanup |
| `scripts/dry_run_capability.sh` | Dry-run assumptions |
| `scripts/dry_run_reasoning.sh` | Dry-run assumptions |
| `src/reasoning/providers/*/provider.dockerfile` | Healthcheck, user setup |
