# Design — Workspace Path Resolution

**Target milestone:** M2.7 — Session Identity and Harness Versioning

**Status:** Design record — problem analysis, settled architecture, and implementation sequence for unifying workspace path definitions under a single authority in the compose template.

**Related:**
- [`libs/docker-compose.yml`](../../libs/docker-compose.yml) — compose template; will host the `x-workspace` anchor
- [`libs/dirs.sh`](../../libs/dirs.sh) — current path derivation module; to be retired from production
- [`libs/compose.sh`](../../libs/compose.sh) — compose generation; `{{VAR}}` substitution bridge
- [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) — container init; will write paths to SESSION_STATE
- [`scripts/start_agent.sh`](../../scripts/start_agent.sh) — host-side preflight; will stop calling `dirs_resolve`
- [`scripts/dry_run.sh`](../../scripts/dry_run.sh) — dry-run checks; will read paths from env vars directly
- [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) — CLI dispatcher; host-side tools will read from SESSION_STATE
- [`libs/session.sh`](../../libs/session.sh) — SESSION_STATE read/write primitives
- [`libs/routing.sh`](../../libs/routing.sh) — routing functions; consumers of SESSION_STATE
- [`libs/interactive_session_select.sh`](../../libs/interactive_session_select.sh) — interactive session selection; consumer of SESSION_STATE
- [`libs/package_diff.sh`](../../libs/package_diff.sh) — diff packaging; host-side consumer of SESSION_STATE
- [`libs/package_branch.sh`](../../libs/package_branch.sh) — branch packaging; host-side consumer of SESSION_STATE
- [`libs/draft_workflow.sh`](../../libs/draft_workflow.sh) — draft workflow; host-side consumer of SESSION_STATE
- [`tests/knowledge/knowledge_session_diffs_path_resolution.sh`](../../tests/knowledge/knowledge_session_diffs_path_resolution.sh) — knowledge test tracing the current resolution chain

---

## Problem

Workspace paths (snapshot, session-diffs, input, output) are defined in multiple places with no single authority:

| Definition site | Role | Fragility |
|---|---|---|
| `libs/dirs.sh` — 6 env var defaults | Canonical defaults for leaf names | Callers must know which env vars to override and how they compose (e.g. `CHANGES_DIR = BASE_DIR / WORKSPACE_DIR_NAME / CHANGES_DIR_NAME`) |
| `libs/docker-compose.yml` — `environment:` overrides | Redundant overrides of `dirs.sh` defaults | Was source of bug: `CHANGES_DIR_NAME=workspace/session-diffs` (subpath with `/`) produced doubled path when combined with `WORKSPACE_DIR_NAME=workspace` |
| `libs/docker-compose.yml` — bind mount `target:` fields | Hardcoded absolute container paths | Five separate specifications of `/home/agentuser/...` paths, each written independently |
| `scripts/onboard.sh` — `mkdir -p` calls | Host-side directory creation | Hardcoded `.workspace/input`, `.workspace/output`, `.workspace/session-diffs` |
| `libs/sandbox.Dockerfile` — `mkdir -p` | Container-side directory creation | Hardcoded `/home/agentuser/workspace/session-diffs` |
| `tests/test_routing.sh` — literal mkdir/test paths | Test fixtures | 14 hardcoded occurrences of `.workspace/session-diffs` and `.workspace/output` |

**Root cause of the bug fixed in session 20260513-02:** the `dirs.sh` documentation says `_NAME` env vars are leaf names, but the compose template set `CHANGES_DIR_NAME=workspace/session-diffs` (a subpath containing `/`). `dirs.sh` faithfully prepended `WORKSPACE_DIR_NAME`, producing a doubled prefix. The bind mount target was the non-doubled version. Diffs were written to a path outside the mount and never survived to the host.

The bug was a single misconfigured env var, but the architecture enabled it: no validation rejects `/` in `_NAME` values, no single place shows all path definitions at once, and no test asserts that the host-side resolved path matches the container-side mount target.

---

## Design

### Principle

**Single authority.** The compose template (`libs/docker-compose.yml`) defines all workspace path mappings in a single `x-workspace` YAML anchor block. Every consumer — host-side script, container entrypoint, routing function — reads paths from this authority, either directly (via `{{VAR}}` substitution at compose generation time) or indirectly (via `SESSION_STATE` written at container init).

### x-workspace anchor

The anchor lives in the compose template and defines host-container path pairs for each workspace directory:

```yaml
# x-workspace anchor — single source of truth for all workspace paths.
#
# Host-side paths use {{VAR}} placeholders substituted at compose generation
# time by compose.sh. {{SANDBOX_DIR}} is the one per-project variable from .env.
#
# Container-side paths are literals (fixed relative to $HOME).
#
# Path values MUST NOT contain environment variable references resolved at
# docker compose runtime (${VAR}) — everything is baked at generation time.
# This ensures paths are deterministic regardless of the runtime env state.
x-workspace: &workspace
  # Host-side paths ({{VAR}} substituted at generation time)
  snapshot_host:   "{{SANDBOX_DIR}}/.snapshot"
  changes_host:    "{{SANDBOX_DIR}}/.workspace/session-diffs"
  input_host:      "{{SANDBOX_DIR}}/.workspace/input"
  output_host:     "{{SANDBOX_DIR}}/.workspace/output"

  # Container-side paths (literals — fixed for the image architecture)
  snapshot_container:   "/home/agentuser/.snapshot"
  changes_container:    "/home/agentuser/workspace/session-diffs"
  input_container:      "/home/agentuser/workspace/input"
  output_container:     "/home/agentuser/workspace/output"

  # Provider config bind mount (special case — dynamic per provider)
  provider_config_host:      "{{SANDBOX_DIR}}/.{{PROVIDER_NAME}}"
  provider_config_container: "/opt/provider-config"

  # Dry-run script bind mount
  dry_run_script_host:      "{{DRY_RUN_SCRIPT}}"
  dry_run_script_container: "/dry_run.sh"
```

### Service bind mounts reference the anchor

Sandbox service `volumes:` block becomes self-documenting:

```yaml
services:
  sandbox:
    volumes:
      - type: bind
        source: *workspace.snapshot_host
        target: *workspace.snapshot_container
        read_only: true
      - type: bind
        source: *workspace.changes_host
        target: *workspace.changes_container
```

But YAML anchors cannot be used as both scalar values and map keys in all Compose implementations. An alternative is to reference through `environment:` vars:

```yaml
services:
  sandbox:
    volumes:
      - type: bind
        source: ${SNAPSHOT_HOST}
        target: ${SNAPSHOT_CONTAINER}
        read_only: true
      - type: bind
        source: ${CHANGES_HOST}
        target: ${CHANGES_CONTAINER}
```

Where `SNAPSHOT_HOST`, `CHANGES_HOST` etc. are exported by `start_agent.sh` before compose generation (derived from the x-workspace anchor).

**Implementation note:** The generated compose file uses `${VAR}` for runtime resolution. The anchor itself uses `{{VAR}}` for generation-time substitution. The actual mechanics are: `compose.sh` substitutes `{{VAR}}` placeholders with exported shell variables, then the generated compose file uses `${VAR}` for Docker Compose runtime. The x-workspace anchor is in the source template (before generation), so it uses `{{VAR}}`.

### Container init writes paths to SESSION_STATE

After `snapshot_init_git` runs, `sandbox-entrypoint.sh` writes the workspace paths to `SESSION_STATE`:

```bash
# After snapshot_init_git completes:
session_state_write "$SANDBOX_DIR" "changes_dir"   "${CHANGES_DIR:-/home/agentuser/workspace/session-diffs}"
session_state_write "$SANDBOX_DIR" "snapshot_dir"  "${SNAPSHOT_DIR:-/home/agentuser/.snapshot}"
session_state_write "$SANDBOX_DIR" "input_dir"     "${INPUT_DIR:-/home/agentuser/workspace/input}"
session_state_write "$SANDBOX_DIR" "output_dir"    "${OUTPUT_DIR:-/home/agentuser/workspace/output}"
```

The env vars (`CHANGES_DIR`, `SNAPSHOT_DIR`, etc.) are absolute paths passed by the compose template's environment block. The fallback values after `:-` are the same literals from the x-workspace anchor — they only apply if the env var is somehow unset at container init (should not happen in normal operation).

### Consumers read from SESSION_STATE

After init, all container-side code reads paths from SESSION_STATE instead of calling `dirs_resolve`:

```bash
# Before (fragile — depends on WORKSPACE_DIR_NAME + CHANGES_DIR_NAME agreeing):
source /opt/sandbox/lib/dirs.sh
WORKSPACE_DIR_NAME=workspace dirs_resolve "$ROOT"
# CHANGES_DIR is now $ROOT/workspace/session-diffs

# After (deterministic — read the path the entrypoint wrote):
changes_dir=$(session_state_read "$SANDBOX_DIR" "changes_dir")
```

Host-side CLI tools (`agent-sandbox.sh package-diff`, `package-branch`) also read from SESSION_STATE:

```bash
source "$AGENT_SANDBOX_REPO/libs/session.sh"
changes_dir=$(session_state_read "$SANDBOX_DIR" "changes_dir") || {
  echo "Error: sandbox not initialized — run make start first"
  exit 1
}
```

### Host-side compose generation

`scripts/start_agent.sh` no longer calls `dirs_resolve`. Instead, it:

1. Reads `SANDBOX_DIR` from `.env` (as before)
2. Computes the four workspace host paths by appending the same suffixes the x-workspace anchor uses:

```bash
export SNAPSHOT_HOST="${SANDBOX_DIR}/.snapshot"
export CHANGES_HOST="${SANDBOX_DIR}/.workspace/session-diffs"
export INPUT_HOST="${SANDBOX_DIR}/.workspace/input"
export OUTPUT_HOST="${SANDBOX_DIR}/.workspace/output"
```

These are exported for `compose.sh` to substitute into the template as `${SNAPSHOT_HOST}` etc.

### dirs.sh retirement

`libs/dirs.sh` and its `dirs_resolve` function are removed from all production code paths:

- `scripts/start_agent.sh` — no longer sources dirs.sh or calls dirs_resolve
- `libs/sandbox-entrypoint.sh` — no longer sources dirs.sh; reads paths from env vars
- `scripts/dry_run.sh` — reads paths from env vars directly (baked at compose gen time)
- `libs/routing.sh` — reads paths from SESSION_STATE
- `libs/interactive_session_select.sh` — reads paths from SESSION_STATE
- `scripts/agent-sandbox.sh` — host-side subcommands read from SESSION_STATE

`libs/dirs.sh` may remain in the repo as a test fixture helper (for tests that need to construct paths without a running sandbox), but is excluded from production source includes.

### SESSION_STATE key schema

| Key | Value type | Written by | Consumers |
|---|---|---|---|
| `init_sha` | SHA | `snapshot_init_git` | `package_diff`, `package_branch`, `routing` |
| `session_ts` | timestamp | `snapshot_init_git` | `package_branch` |
| `changes_dir` | absolute path (container) | `sandbox-entrypoint.sh` after init | `routing`, `interactive_session_select`, `draft_workflow` |
| `snapshot_dir` | absolute path (container) | `sandbox-entrypoint.sh` after init | `sandbox-entrypoint` (already knows it) |
| `input_dir` | absolute path (container) | `sandbox-entrypoint.sh` after init | `routing`, `interactive_session_select` |
| `output_dir` | absolute path (container) | `sandbox-entrypoint.sh` after init | `routing`, `interactive_session_select` |

---

## Change inventory

### Files to modify

| File | Change |
|---|---|
| `libs/docker-compose.yml` | Add `x-workspace` anchor. Replace all `source:`/`target:` in volumes with anchor references. Replace all `environment:` `_NAME` vars with absolute path vars (`CHANGES_DIR`, `SNAPSHOT_DIR`, `INPUT_DIR`, `OUTPUT_DIR`). |
| `libs/compose.sh` | No change needed — already substitutes `{{VAR}}` and `${VAR}` correctly. Verify `{{SANDBOX_DIR}}` substitution is correct. May need to substitute new template vars (`{{SNAPSHOT_HOST}}` etc.) if `start_agent.sh` exports them. |
| `scripts/start_agent.sh` | Remove `source libs/dirs.sh` and `dirs_resolve` call. Export `SNAPSHOT_HOST`, `CHANGES_HOST`, `INPUT_HOST`, `OUTPUT_HOST`. |
| `libs/sandbox-entrypoint.sh` | Remove `source /opt/sandbox/lib/dirs.sh` and `WORKSPACE_DIR_NAME=workspace dirs_resolve` call. After `snapshot_init_git`, write paths to `SESSION_STATE`. Read `CHANGES_DIR` from env var. |
| `scripts/dry_run.sh` | Remove `source /opt/sandbox/lib/dirs.sh` and `WORKSPACE_DIR_NAME=workspace dirs_resolve`. Read `CHANGES_DIR`, `INPUT_DIR`, `OUTPUT_DIR` from env vars. |
| `libs/routing.sh` | Add SESSION_STATE read for `changes_dir`, `input_dir`, `output_dir` in `dirs_resolve` callers. `dirs_resolve` call replaced with SESSION_STATE lookup. |
| `libs/interactive_session_select.sh` | Same as routing.sh — replace `dirs_resolve` with SESSION_STATE lookup. |
| `scripts/agent-sandbox.sh` | Replace `source libs/dirs.sh + dirs_resolve` with `source libs/session.sh + session_state_read` for `package-diff` and `package-branch` subcommands. |
| `scripts/onboard.sh` | Replace hardcoded `.workspace/input` etc. with a source-reference or document that these must match the x-workspace anchor values. |
| `libs/sandbox.Dockerfile` | Remove hardcoded `/home/agentuser/workspace/session-diffs` if present — the bind mount creates this path. |
| `tests/test_routing.sh` | Replace hardcoded `.workspace/session-diffs` paths. Use `dirs.sh` as a test helper to construct paths, or write literal paths that match the canonical values from the x-workspace anchor. |
| `tests/test_draft_workflow.sh` | Same as test_routing.sh. |
| `tests/test_capability_layer.sh` | Update `WORKSPACE_CHANGES_DIR` to match canonical path. |
| `tests/test_dirs.sh` | Update or remove — if `dirs.sh` is retired from production, the test may be demoted to knowledge test status. |

### Files to create

| File | Content |
|---|---|
| `tests/knowledge/knowledge_workspace_paths.sh` | Knowledge test asserting that the x-workspace anchor values, the host-side derivation in `start_agent.sh`, and the container-side SESSION_STATE values all agree. |

### Files to remove from production includes (may stay for tests)

- `libs/dirs.sh` — remove from all `source` calls in production scripts. Keep in `tests/lib/` or `tests/knowledge/` for fixture construction.

---

## SESSION_STATE caveat (known, deferred to M2.6)

`session_state_write` appends (`>>`) rather than overwriting in place. This is currently safe because the sandbox `.git/` directory is container-ephemeral — destroyed on each `make stop`. If M2.6 binds-mounts `.git/` for session resume, the append semantics will cause stale key accumulation. M2.6 must either:

1. Make `session_state_write` idempotent: grep for existing key in SESSION_STATE and replace it, or
2. Have `snapshot_init_git` truncate SESSION_STATE before writing.

---

## Implementation sequence

The refactor should proceed in this order, with each step gated by passing `make test`:

1. **Add `x-workspace` anchor to compose template** — define the anchor block with all paths. No other changes yet. `make test` must pass (compose generation is tested indirectly through `test_start_agent.sh` and dry-run).
2. **Export host paths in `start_agent.sh`** — add `SNAPSHOT_HOST`, `CHANGES_HOST`, `INPUT_HOST`, `OUTPUT_HOST` exports derived from `SANDBOX_DIR`. Remove `dirs_resolve` call. `start_agent.sh` now no longer sources `dirs.sh`.
3. **Update compose template volumes/environment** — replace bind mount `source:`/`target:` with `${SNAPSHOT_HOST}`/`${SNAPSHOT_CONTAINER}` etc. Replace `_NAME` env var overrides with absolute path vars. The sandbox service `environment:` receives `CHANGES_DIR`, `SNAPSHOT_DIR`, `INPUT_DIR`, `OUTPUT_DIR` as absolute paths.
4. **Update sandbox-entrypoint.sh** — remove `dirs.sh` source and `dirs_resolve` call. After `snapshot_init_git`, write paths to SESSION_STATE. Read `CHANGES_DIR` directly from env var.
5. **Update dry_run.sh** — remove `dirs.sh` source and `dirs_resolve` call. Read paths from env vars.
6. **Update routing.sh + interactive_session_select.sh** — replace `dirs_resolve` calls with SESSION_STATE reads. These are the most complex changes because they're called from both host-side (no SESSION_STATE yet) and container-side contexts. May need a guard: try SESSION_STATE first, fall back to `dirs_resolve` for host-side calls.
7. **Update agent-sandbox.sh** — host-side subcommands read from SESSION_STATE instead of calling `dirs_resolve`.
8. **Update tests** — `test_routing.sh`, `test_draft_workflow.sh`, `test_capability_layer.sh`, `test_dirs.sh` to match new path sources.
9. **Create knowledge test** — `knowledge_workspace_paths.sh` asserting cross-context path agreement.
10. **Cleanup** — remove `dirs.sh` from production source includes. Update `onboard.sh` to reference x-workspace values.
