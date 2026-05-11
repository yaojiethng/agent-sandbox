# Unified path derivation

**Purpose:** Consolidate all harness path derivation into a single module, eliminating the derived-path cache in `.env` and unifying host-side and container-side conventions.

**Status:** Implemented. See `20260504-03-impl-documentation_alignment.md` for the full session.

---

## Synthesised breakdown

Both host-side and container-side path derivation follow the same structural pattern — the only difference is a dot prefix on the workspace directory name:

```
Host:       CHANGES_DIR  = SANDBOX_DIR / .workspace / session-diffs
Container:  CHANGES_DIR  = /home/agentuser / workspace / session-diffs
                          ──────┬──────   ────┬────   ───────┬───────
                          BASE_DIR     WORKSPACE_DIR_NAME   CHANGES_DIR_NAME
```

On the host, the workspace directory is hidden (`.workspace`). Inside the container it is visible (`workspace`) because Docker bind mounts don't care about Linux hidden-directory semantics — the mount target is whatever the template says. Every other path component follows the same relative structure from a base directory.

A single function parameterised by `WORKSPACE_DIR_NAME` can express both conventions:

```bash
# Host (WORKSPACE_DIR_NAME defaults to .workspace):
dirs_resolve "/mnt/m/Projects/foo/.sandbox/win"
# → CHANGES_DIR = .../.sandbox/win/.workspace/session-diffs

# Container (override WORKSPACE_DIR_NAME=workspace):
WORKSPACE_DIR_NAME=workspace dirs_resolve "/home/agentuser"
# → CHANGES_DIR = /home/agentuser/workspace/session-diffs
```

**Three drift sources eliminated:**
1. **`.env` cache** — removed entirely. `SANDBOX_DIR` is the only path primitive stored. All derived paths are produced by `dirs_resolve` at point-of-use.
2. **Parallel formula** — `routing.sh`'s inline derivation replaced by the canonical call, and gains `SNAPSHOT_DIR`/`INPUT_DIR` (which it currently omits).
3. **Container/host asymmetry** — controlled by one env override (`WORKSPACE_DIR_NAME`) instead of two separate code paths.

---

## Problem

Harness paths (`SNAPSHOT_DIR`, `CHANGES_DIR`, `INPUT_DIR`, `OUTPUT_DIR`) are derived in **three places** using **two different formulas**:

| Site | Formula | Context |
|---|---|---|
| `scripts/onboard.sh` (lines 264–267) | `SNAPSHOT_DIR=$SANDBOX_DIR/.snapshot`, `CHANGES_DIR=$SANDBOX_DIR/.workspace/session-diffs`, etc. | Host — writes to `.env` |
| `libs/routing.sh` (lines 136–138, 215–217) | `WORKSPACE=$SANDBOX_DIR/.workspace`, `CHANGES_DIR=$WORKSPACE/session-diffs`, `OUTPUT_DIR=$WORKSPACE/output` | Host — derives at call time, no `SNAPSHOT_DIR` or `INPUT_DIR` |
| `libs/sandbox-entrypoint.sh` (line 40, 45) | `SNAPSHOT_DIR=$ROOT/.snapshot`, `CHANGES_DIR=$ROOT/workspace/session-diffs` | Container — `ROOT=/home/agentuser` |

The `.env` file caches derived paths as literals. This cache has no staleness detection — editing `SANDBOX_DIR` in `.env` without re-onboarding silently breaks the workspace layout.

The two derivation formulas differ because inside the container the workspace directory is visible (`workspace/`) while on the host it is hidden (`.workspace/`).

---

## Proposed design

### 1. Single `dirs_resolve` function in `libs/dirs.sh`

```bash
# dirs_resolve — derive all harness paths from a base directory.
#
# Sets SNAPSHOT_DIR, CHANGES_DIR, INPUT_DIR, OUTPUT_DIR, SANDBOX_DIR in the
# caller's scope. All are exported for downstream consumers (compose, routing).
#
# Args:
#   $1  BASE_DIR   — root for derived paths
#                    Host: SANDBOX_DIR (e.g. /mnt/m/Projects/foo/.sandbox/win)
#                    Container: /home/agentuser
#
# Environment overrides (all optional):
#   SNAPSHOT_DIR_NAME    — leaf name under BASE_DIR  (default: .snapshot)
#   WORKSPACE_DIR_NAME   — workspace subdir name     (default: .workspace)
#   CHANGES_DIR_NAME     — leaf name under workspace  (default: session-diffs)
#   INPUT_DIR_NAME       — leaf name under workspace  (default: input)
#   OUTPUT_DIR_NAME      — leaf name under workspace  (default: output)
#   SANDBOX_DIR_NAME     — leaf name under BASE_DIR   (default: sandbox)
#
# Derivation:
#   SNAPSHOT_DIR  = BASE_DIR / SNAPSHOT_DIR_NAME
#   SANDBOX_DIR   = BASE_DIR / SANDBOX_DIR_NAME
#   WORKSPACE     = BASE_DIR / WORKSPACE_DIR_NAME
#   CHANGES_DIR   = WORKSPACE / CHANGES_DIR_NAME
#   INPUT_DIR     = WORKSPACE / INPUT_DIR_NAME
#   OUTPUT_DIR    = WORKSPACE / OUTPUT_DIR_NAME
#
# Examples:
#   Host:   dirs_resolve /mnt/m/Projects/foo/.sandbox/win
#           → SNAPSHOT_DIR  = /mnt/.../.sandbox/win/.snapshot
#           → CHANGES_DIR   = /mnt/.../.sandbox/win/.workspace/session-diffs
#           → INPUT_DIR     = /mnt/.../.sandbox/win/.workspace/input
#           → OUTPUT_DIR    = /mnt/.../.sandbox/win/.workspace/output
#
#   Container: WORKSPACE_DIR_NAME=workspace dirs_resolve /home/agentuser
#           → SNAPSHOT_DIR  = /home/agentuser/.snapshot
#           → CHANGES_DIR   = /home/agentuser/workspace/session-diffs
#           → INPUT_DIR     = /home/agentuser/workspace/input
#           → OUTPUT_DIR    = /home/agentuser/workspace/output
dirs_resolve() {
  local BASE_DIR="$1"
  [[ -z "$BASE_DIR" ]] && { echo "dirs_resolve: BASE_DIR is required" >&2; return 1; }

  local WS="${WORKSPACE_DIR_NAME:-.workspace}"

  SNAPSHOT_DIR="${BASE_DIR}/${SNAPSHOT_DIR_NAME:-.snapshot}"
  CHANGES_DIR="${BASE_DIR}/${WS}/${CHANGES_DIR_NAME:-session-diffs}"
  INPUT_DIR="${BASE_DIR}/${WS}/${INPUT_DIR_NAME:-input}"
  OUTPUT_DIR="${BASE_DIR}/${WS}/${OUTPUT_DIR_NAME:-output}"
  SANDBOX_DIR="${BASE_DIR}/${SANDBOX_DIR_NAME:-sandbox}"
}
```

### 2. New `dirs.sh` defaults (backward-incompatible — requires all callers to migrate to `dirs_resolve`)

| Variable | Old default | New default | Notes |
|---|---|---|---|
| `SNAPSHOT_DIR_NAME` | `.snapshot` | `.snapshot` | Unchanged |
| `SANDBOX_DIR_NAME` | `sandbox` | `sandbox` | Unchanged |
| `CHANGES_DIR_NAME` | `workspace/session-diffs` | `session-diffs` | Stripped `workspace/` prefix — now a leaf name |
| `INPUT_DIR_NAME` | `workspace/input` | `input` | Stripped `workspace/` prefix — now a leaf name |
| `OUTPUT_DIR_NAME` | `workspace/output` | `output` | Stripped `workspace/` prefix — now a leaf name |
| `WORKSPACE_DIR_NAME` | *(new)* | `.workspace` | Host convention; overridden to `workspace` inside container |

The old `CHANGES_DIR_NAME=workspace/session-diffs` was a compound value combining the workspace prefix and the leaf. The new design separates these into `WORKSPACE_DIR_NAME` + `CHANGES_DIR_NAME`.

### 3. Host-side changes

| File | Current | After |
|---|---|---|
| `scripts/onboard.sh` | Writes `SNAPSHOT_DIR`, `CHANGES_DIR`, `INPUT_DIR`, `OUTPUT_DIR` to `.env` | Stops writing them — `.env` retains only `PROJECT_DIR`, `SANDBOX_DIR`, `PROJECT_NAME`, template versions, operator config |
| `scripts/start_agent.sh` | Sources .env, validates 4 derived vars are present (lines 113–124), uses them directly for workspace setup and compose | Sources `dirs_resolve "$SANDBOX_DIR"` after loading .env but before workspace setup. Changes `REQUIRED_ENV_VARS` from 4 to 0 (SANDBOX_DIR guaranteed by CLI arg) |
| `libs/routing.sh` | Re-derives WORKSPACE_DIR/CHANGES_DIR/OUTPUT_DIR inline (lines 136–138, 215–217), misses SNAPSHOT_DIR and INPUT_DIR | Calls `dirs_resolve "$SANDBOX_DIR"` instead |

### 4. Container-side changes

| File | Current | After |
|---|---|---|
| `libs/sandbox-entrypoint.sh` | `ROOT=/home/agentuser`, sources `dirs.sh`, derives `SNAPSHOT_DIR=$ROOT/$SNAPSHOT_DIR_NAME`, `CHANGES_DIR=$ROOT/$CHANGES_DIR_NAME`, etc. | Sets `WORKSPACE_DIR_NAME=workspace`, calls `dirs_resolve "$ROOT"` instead |
| `scripts/dry_run.sh` | Same pattern as entrypoint (line 27–32) | Same — replaces inline with `WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"` |

### 5. `.env` surface area reduction

**Before** (10 lines of path config):
```bash
PROJECT_DIR=/mnt/m/Projects/my-project
SANDBOX_DIR=/mnt/m/Projects/my-project/.sandbox

SNAPSHOT_DIR=/mnt/m/Projects/my-project/.sandbox/.snapshot
CHANGES_DIR=/mnt/m/Projects/my-project/.sandbox/.workspace/session-diffs
INPUT_DIR=/mnt/m/Projects/my-project/.sandbox/.workspace/input
OUTPUT_DIR=/mnt/m/Projects/my-project/.sandbox/.workspace/output

MAKEFILE_VERSION=3
SERVE_PORT=46553
AUTOSAVE_INTERVAL=60
```

**After** (6 lines of operator-meaningful config):
```bash
PROJECT_DIR=/mnt/m/Projects/my-project
SANDBOX_DIR=/mnt/m/Projects/my-project/.sandbox

MAKEFILE_VERSION=3
SERVE_PORT=46553
AUTOSAVE_INTERVAL=60
```

The derived paths are no longer stored — they are produced on demand by `dirs_resolve "$SANDBOX_DIR"`.

---

## Acceptance criteria

1. `dirs_resolve` produces correct paths for both host (`SANDBOX_DIR`) and container (`/home/agentuser`) base dirs
2. `start_agent.sh` creates workspace directories at the correct locations without reading derived paths from `.env`
3. `compose_generate` receives correct SNAPSHOT_DIR/CHANGES_DIR/INPUT_DIR/OUTPUT_DIR in the environment
4. `routing.sh`'s `resolve_source_for_draft` and `resolve_diff_for_apply` derive correct paths (tested via existing tests)
5. `sandbox-entrypoint.sh` starts the session with correct paths (tested via existing diff/draft tests)
6. `dry_run.sh` validates correct paths
7. `.env` files written by `onboard.sh` do not contain derived path lines
8. Existing `.env` files with stale derived paths continue to work (backwards compat): `dirs_resolve` overrides any stale values that might leak from outdated .env files

---

## Excluded from scope (future candidates)

- **`SANDBOX_DIR_NAME`** (`sandbox`) and **`SNAPSHOT_DIR_NAME`** (`.snapshot`) remain in `dirs.sh` but are rarely overridden. No reason to change them.
- **`INPUT_DIR` and `OUTPUT_DIR` in routing.sh** — currently missing from routing's inline derivation. `dirs_resolve` will add them automatically.

---

## Open questions

1. **Backwards compatibility with existing .env files.** After the change, `start_agent.sh` will ignore any stale `SNAPSHOT_DIR`/`CHANGES_DIR`/`INPUT_DIR`/`OUTPUT_DIR` in `.env` and derive fresh values instead. This is correct — the derived values are strict functions of `SANDBOX_DIR`, so stale cache entries cannot produce a different result from derivation. No migration needed, but the change should be documented.

2. **Should `dirs_resolve` export?** Currently, `sandbox-entrypoint.sh` and `start_agent.sh` need the paths as exported vars for compose and downstream scripts. The function should `export` each variable after deriving it, avoiding a separate `export` call site.

3. **Error handling for missing BASE_DIR.** The function returns 1 if `BASE_DIR` is empty or unset. This is a programming error — no runtime path should trigger it since both host (`--sandbox=`) and container (`ROOT`) guarantee a value.
