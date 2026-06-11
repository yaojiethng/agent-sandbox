# Spec: Path Resolution Convention

**Date:** 2026-05-26
**Session:** `20260526-04-spec-path_resolution_convention`
**Milestone:** M2.7 — Session Identity and Harness Versioning

---

## Interface Seam

The path resolution convention defines a **three-layer interface seam** between host-side orchestration, cross-context shared libraries, and container-only code.

```
Host-only                           Cross-context                       Container-only
───────────                         ─────────────                       ──────────────
                                    │
$AGENT_SANDBOX_REPO                 │  Self-resolution ($_SELF_DIR)     /opt/sandbox/lib/
  ↓                                 │    ↓
agent-sandbox.sh  ───── sources ──► session.sh, routing.sh,             ◄── sourced by ── sandbox-entrypoint.sh
(draft_workflow.sh,                 │  diff.sh, package_branch.sh,         provider-entrypoint.sh
 diff_workflow.sh,                  │  package_diff.sh, dirs.sh
 interactive.sh)                    │
                                    │
$REPO_ROOT                          │
  ↓                                 │
start_agent.sh, run_agent.sh,  ──► (same cross-context libs)
onboard.sh                          │
                                    │
test_*.sh ─────────────── sources ──► (same cross-context libs)
```

Each layer uses a different path resolution strategy, dictated by its deployment and invocation constraints.

---

## Layer 1 — Container-only

**Files:** `sandbox-entrypoint.sh`, `provider-entrypoint.sh`, `snapshot.sh`
**Deployment:** Baked into container images via Dockerfile COPY.
**Path resolution:** Hardcoded absolute paths under `/opt/sandbox/lib/`.
**Change scope:** No changes this session. Container paths are updated as part of the container image build (Dockerfile COPY instructions and entrypoint source lines), which is a separate concern from the host-side file reorganisation.

**Constraint:** `/opt/sandbox/lib/` is fixed at image build time by the Dockerfile. At container runtime, these paths are immutable.

---

## Layer 2 — Cross-context (shared libs)

**Files:** `session.sh` → `session_state.sh`, `routing.sh`, `diff.sh` → `diff.sh` + `diff_export.sh`, `package_branch.sh`, `package_diff.sh`, `dirs.sh`
**Deployment:** Deployed to both host filesystem (via repo checkout) AND both container images (via Dockerfile COPY).
**Path resolution:** **Self-resolution** — each file computes its own directory at source time, then sources siblings relative to that directory.

```
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SCRIPT_DIR/session_state.sh"
source "$_SCRIPT_DIR/routing.sh"
```

**Why self-resolution?** Because these files are sourced from both contexts:
- Inside containers: `source /opt/sandbox/lib/diff.sh` → self-resolution resolves to `/opt/sandbox/lib/`
- On the host: `source $AGENT_SANDBOX_REPO/src/libs/diff.sh` → self-resolution resolves to `$AGENT_SANDBOX_REPO/src/libs/`

Using `$AGENT_SANDBOX_REPO` or `$REPO_ROOT` inside these files would break container-side loading because those variables are not set inside containers.

### Naming standard

All cross-context libs use a **canonical self-resolution variable name**:

```bash
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

No more `_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, `_PD_SCRIPT_DIR`, `_DW_SCRIPT_DIR`, `_ISS_SCRIPT_DIR`, or inline repeated `$(cd ...)` — all standardised to `_SCRIPT_DIR`.

---

## Layer 3 — Host-only

Three sub-categories within the host layer, each with its own convention.

### 3a — Installed CLI: `$AGENT_SANDBOX_REPO`

**Files:** `agent-sandbox.sh`
**Deployment:** Installed to `/usr/local/bin/agent-sandbox` via `make install`.
**Path resolution:** Build-time macro `@@AGENT_SANDBOX_REPO@@`, replaced by `sed` at install time with the repo checkout path.

```bash
# Makefile:
sed 's|@@AGENT_SANDBOX_REPO@@|$(CURDIR)|g' scripts/agent-sandbox.sh > /usr/local/bin/agent-sandbox

# In agent-sandbox.sh:
AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"
source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
```

**Rationale:** After install, the script lives outside the repo checkout. It cannot use `$REPO_ROOT` derived from `$SCRIPT_DIR/..` because `$SCRIPT_DIR` would be `/usr/local/bin/`. The macro gives it a fixed pointer to the checkout.

### 3b — Host libs sourced by agent-sandbox: `$AGENT_SANDBOX_REPO`

**Files:** `draft_workflow.sh` → `src/scripts/workflows/draft.sh` (and confirm.sh, reject.sh), `diff_workflow.sh` → `src/scripts/workflows/apply.sh`, `interactive_session_select.sh` → `src/scripts/workflows/interactive.sh`, `guards.sh` (extracted from session.sh)
**Deployment:** Sourced exclusively by `agent-sandbox.sh` (which sets `$AGENT_SANDBOX_REPO`).
**Path resolution:** Use `$AGENT_SANDBOX_REPO` to source dependencies.

```bash
# Before (self-resolution):
_DW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_DW_SCRIPT_DIR/session.sh"

# After (uses parent's variable):
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
```

**Rationale:** These files are only ever sourced by `agent-sandbox.sh`, which sets `$AGENT_SANDBOX_REPO` before sourcing them. Using this variable eliminates the self-resolution variables and their naming inconsistencies. The source paths become self-documenting (they spell out the full target path).

**Note on guards.sh:** Extracted from `session.sh`. It validates the repo and clears stale locks — purely host-side operations. It belongs in this category, sourced by `agent-sandbox.sh` along with the workflow files.

### 3c — Host scripts sourced from repo: `$REPO_ROOT`

**Files:** `start_agent.sh`, `run_agent.sh`, `onboard.sh`
**Deployment:** Run from the repo checkout (never installed system-wide).
**Path resolution:** Derive `$REPO_ROOT` from `$(cd "$SCRIPT_DIR/.." && pwd)`, then source relative to that.

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/src/libs/routing.sh"
source "$REPO_ROOT/src/capability/snapshot.sh"
```

**Rationale:** These scripts already use this pattern. Since they always run from the repo checkout, `$REPO_ROOT` reliably resolves to the checkout root. No macro or self-resolution needed.

### 3d — Test files: `$REPO_ROOT`

**Files:** All `tests/test_*.sh` that source libs directly.
**Deployment:** Run from the repo checkout during `make test`.
**Path resolution:** Use `$REPO_ROOT` (derived via the test's own setup), source relative to that.

```bash
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/src/libs/diff.sh"
source "$REPO_ROOT/src/scripts/workflows/apply.sh"
```

**Rationale:** Tests always run from the repo checkout. Using `$REPO_ROOT` is consistent with host scripts and avoids fragile relative paths (`../libs/` breaks when files move).

Some tests currently use inline `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../libs/...`. These should switch to `$REPO_ROOT` for consistency.

---

## Summary of source path updates

Every source path that references a file that will move (per the libs/ refactor design) must be updated. The table below lists each source path occurrence, its current pattern, and the convention it should use after the move.

| File | Current source path | New pattern | Convention |
|---|---|---|---|
| `scripts/agent-sandbox.sh` | `$AGENT_SANDBOX_REPO/libs/containers.sh` | `$AGENT_SANDBOX_REPO/build/image.sh` + `$AGENT_SANDBOX_REPO/build/context.sh` + `$AGENT_SANDBOX_REPO/scripts/build.sh` | `$AGENT_SANDBOX_REPO` |
| | `$AGENT_SANDBOX_REPO/libs/draft_workflow.sh` | `$AGENT_SANDBOX_REPO/src/scripts/workflows/draft.sh` | |
| | `$AGENT_SANDBOX_REPO/libs/diff_workflow.sh` | `$AGENT_SANDBOX_REPO/src/scripts/workflows/apply.sh` | |
| | `$AGENT_SANDBOX_REPO/libs/routing.sh` | `$AGENT_SANDBOX_REPO/src/libs/routing.sh` | |
| | `$AGENT_SANDBOX_REPO/libs/interactive_session_select.sh` | `$AGENT_SANDBOX_REPO/src/scripts/workflows/interactive.sh` | |
| | `$AGENT_SANDBOX_REPO/libs/dirs.sh` | `$AGENT_SANDBOX_REPO/src/libs/dirs.sh` | |
| | `$AGENT_SANDBOX_REPO/libs/package_diff.sh` | `$AGENT_SANDBOX_REPO/src/libs/package_diff.sh` | |
| | `$AGENT_SANDBOX_REPO/libs/package_branch.sh` | `$AGENT_SANDBOX_REPO/src/libs/package_branch.sh` | |
| `scripts/start_agent.sh` | `$REPO_ROOT/libs/containers.sh` | `$REPO_ROOT/scripts/build.sh` (or `$REPO_ROOT/build/*`) | `$REPO_ROOT` |
| | `$REPO_ROOT/libs/snapshot.sh` | `$REPO_ROOT/src/capability/snapshot.sh` | |
| `scripts/run_agent.sh` | `$REPO_ROOT/libs/containers.sh` | `$REPO_ROOT/scripts/build.sh` (or `$REPO_ROOT/build/*`) | `$REPO_ROOT` |
| | `$REPO_ROOT/libs/compose.sh` | `$REPO_ROOT/build/compose.sh` | |
| `libs/diff_workflow.sh → src/scripts/workflows/apply.sh` | `$_DW_SCRIPT_DIR/session.sh` | `$AGENT_SANDBOX_REPO/src/libs/session_state.sh` | `$AGENT_SANDBOX_REPO` |
| | `$_DW_SCRIPT_DIR/diff.sh` | `$AGENT_SANDBOX_REPO/src/libs/diff.sh` | |
| `libs/draft_workflow.sh → src/scripts/workflows/draft.sh` | `$(cd...)/session.sh` | `$AGENT_SANDBOX_REPO/src/libs/session_state.sh` | `$AGENT_SANDBOX_REPO` |
| | `$(cd...)/routing.sh` | `$AGENT_SANDBOX_REPO/src/libs/routing.sh` | |
| | `$(cd...)/diff.sh` | `$AGENT_SANDBOX_REPO/src/libs/diff.sh` | |
| `libs/interactive_session_select.sh → src/scripts/workflows/interactive.sh` | `$_ISS_SCRIPT_DIR/routing.sh` | `$AGENT_SANDBOX_REPO/src/libs/routing.sh` | `$AGENT_SANDBOX_REPO` |
| `libs/diff.sh → src/libs/diff.sh` | `$_DIFF_SH_DIR/session.sh` | `$_SCRIPT_DIR/session_state.sh` | Self-resolution (standardised) |
| | `$_DIFF_SH_DIR/routing.sh` | `$_SCRIPT_DIR/routing.sh` | |
| `libs/package_branch.sh → src/libs/package_branch.sh` | `$_PB_SCRIPT_DIR/session.sh` | `$_SCRIPT_DIR/session_state.sh` | Self-resolution (standardised) |
| | `$_PB_SCRIPT_DIR/diff.sh` | `$_SCRIPT_DIR/diff.sh` | |
| | `$_PB_SCRIPT_DIR/routing.sh` | `$_SCRIPT_DIR/routing.sh` | |
| `libs/package_diff.sh → src/libs/package_diff.sh` | `$_PD_SCRIPT_DIR/session.sh` | `$_SCRIPT_DIR/session_state.sh` | Self-resolution (standardised) |
| | `$_PD_SCRIPT_DIR/diff.sh` | `$_SCRIPT_DIR/diff.sh` | |
| | `$_PD_SCRIPT_DIR/routing.sh` | `$_SCRIPT_DIR/routing.sh` | |
| `libs/routing.sh → src/libs/routing.sh` | (sources session.sh, dirs.sh via internal self-resolution) | `$_SCRIPT_DIR/session_state.sh`, `$_SCRIPT_DIR/dirs.sh` | Self-resolution (standardised) |
| `libs/containers.sh → (split across build/* + scripts/build.sh)` | `$repo_root/libs/...` (build_context functions) | `$repo_root/build/...`, `$repo_root/src/libs/...`, `$repo_root/src/capability/...` | `$repo_root` (internal variable) |
| `libs/sandbox.Dockerfile → src/capability/Dockerfile` | `COPY dirs.sh /opt/sandbox/lib/dirs.sh` | `COPY src/libs/dirs.sh /opt/sandbox/lib/dirs.sh` | Dockerfile COPY (container) |
| `providers/pi/provider.Dockerfile` | `COPY dirs.sh /opt/sandbox/lib/dirs.sh` | `COPY src/libs/dirs.sh /opt/sandbox/lib/dirs.sh` | Dockerfile COPY (container) |
| All `tests/test_*.sh` | `$SCRIPT_DIR/../libs/...` or `$REPO_ROOT/libs/...` | `$REPO_ROOT/src/libs/...`, `$REPO_ROOT/src/scripts/workflows/...`, etc. | `$REPO_ROOT` |

---

## Changes to the libs files themselves

Aside from source path updates, the libs files being moved need the following internal changes:

1. **Self-resolution standardisation** — every cross-context lib that currently defines a custom `_*_DIR` variable replaces it with `_SCRIPT_DIR`:
   - `_DIFF_SH_DIR` → `_SCRIPT_DIR`
   - `_PB_SCRIPT_DIR` → `_SCRIPT_DIR`
   - `_PD_SCRIPT_DIR` → `_SCRIPT_DIR`
   - `_DW_SCRIPT_DIR` → removed (switched to `$AGENT_SANDBOX_REPO`)
   - `_ISS_SCRIPT_DIR` → removed (switched to `$AGENT_SANDBOX_REPO`)
   - `draft_workflow.sh` inline `$(cd ...)` (×3) → removed (switched to `$AGENT_SANDBOX_REPO`)

2. **guards.sh (new file)** — extracted from `session.sh`. `validate_project_dir` + `draft_clear_stale_lock`. Sources: none (it's self-contained). Sourced by: host-side workflows and agent-sandbox.sh via `$AGENT_SANDBOX_REPO`.

3. **session_state.sh (new file)** — extracted from `session.sh`. `session_state_read` + `session_state_write`. Self-resolution for cross-context sourcing.

---

## Control Flow Constraints

The dependency graph must follow these directional rules:

```
scripts/  ──→ libs/shared/        (host scripts source shared libs)
scripts/  ──→ scripts/            (host scripts may source other host
            only if the target is    scripts if the target is logically
            logically a library)      a library, e.g. checkpoint.sh)
libs/*    ──→ libs/shared/ only   (libs never source scripts)
tests/*   ──→ anything             (tests can source everything)
☐ nothing ──→ tests/              (nothing sources tests)
containers ──→ libs/shared/ only  (entrypoints only source shared libs)
```

### Current violations

| Violation | Type | Fix |
|---|---|---|
| `checkpoint.sh` lives in `scripts/` but is a library (defines `worktree_id_derive()`, sourced by `start_agent.sh`) | Misplaced file | Move to `libs/host/checkpoint.sh` (or keep but document as exception) |

No structural violations exist — the graph already respects the directional rules. The only issue is file placement (`checkpoint.sh` in wrong directory).

---

## Findings

| Finding | Impact |
|---|---|
| Six different self-resolution variable names across the codebase (`_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, `_PD_SCRIPT_DIR`, `_DW_SCRIPT_DIR`, `_ISS_SCRIPT_DIR`, plus inline `$(cd...)` in draft_workflow.sh) | Standardise to `_SCRIPT_DIR` — reduces cognitive load and makes the convention obvious |
| `draft_workflow.sh` calls `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` three times in the same file | Store once in a variable — minor perf, major readability |
| `sandbox.Dockerfile` and `providers/pi/provider.Dockerfile` use hardcoded COPY paths like `COPY dirs.sh /opt/sandbox/lib/dirs.sh` — these will break when the source files move | Update COPY source paths to match new directory layout. Container-side target paths (`/opt/sandbox/lib/`) stay unchanged |
| Hardcoded `/opt/sandbox/lib/` in entrypoints is fragile but not broken — it's a single source of truth per image | Could be replaced by a variable set in the Dockerfile ENV, but that's a simplification opportunity outside current scope |
