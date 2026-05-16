# Design — Dual-Layer Seam Testing via Dry-Run

**Target milestone:** M2.7 — Session Identity and Harness Versioning

**Status:** Design record — settled architecture for extending dry-run to assert host-container seam behaviour in both the capability layer (sandbox) and reasoning layer (agent), plus host-side verification.

**Related:**
- [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) — pre-flight checks will be injected here (11b)
- [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) — **new** capability layer checks (11c)
- [`scripts/dry_run.sh`](../../scripts/dry_run.sh) — reasoning layer checks, to be rewritten (11d)
- [`libs/docker-compose.dry-run.yml`](../../libs/docker-compose.dry-run.yml) — dry-run overlay, to expose both scripts (11c, 11d)
- [`libs/compose.sh`](../../libs/compose.sh) — `compose_dry_run` orchestration, three-phase execution (11c, 11d, 11e)
- [`tests/test_capability_layer.sh`](../../tests/test_capability_layer.sh) — docker-dependent tests to be subsumed

---

## Problem

`dry_run.sh` runs only inside the reasoning layer (agent container). It cannot assert:
- Whether the capability layer (sandbox container) initialised correctly
- Whether the sandbox entrypoint completed its full sequence (git init, SESSION_STATE, mount availability)
- Whether files written by the sandbox entrypoint actually survive to the host via bind mounts
- Whether both layers agree on shared state (SESSION_STATE, workspace paths)

The capability layer tests in `test_capability_layer.sh` skip entirely when Docker is unavailable (which is the normal state inside the agent sandbox during development). There is no runtime validation that the seam between host, sandbox, and agent is intact.

---

## Architecture

### Three-phase orchestration

`compose_dry_run` in `libs/compose.sh` executes in three sequential phases:

```
Phase 1 (capability checks):
  docker compose exec sandbox bash /dry_run_capability.sh
  → Exit code 0 = all CRITICAL checks pass
  → Non-zero = abort; dry-run marked as FAIL

Phase 2 (reasoning checks):
  docker compose exec agent bash /dry_run.sh
  → Exit code 0 = all CRITICAL checks pass
  → Non-zero = abort; dry-run marked as FAIL

Phase 3 (host-side verification):
  Host script verifies that artifacts produced by Phase 1/Phase 2
  are visible on the host filesystem (via bind mounts).
  Cleans up any temp artifacts.
```

Each phase runs only if all prior phases passed. The full command sequence:

```bash
compose_dry_run() {
  local dry_run_script="$1"
  local dry_run_capability_script="$2"

  # Start containers
  docker compose "${COMPOSE_ARGS[@]}" up -d

  # Phase 1: capability layer checks
  echo "=== Phase 1: capability layer ==="
  docker compose "${COMPOSE_ARGS[@]}" exec sandbox bash /dry_run_capability.sh
  local cap_exit=$?
  if [[ $cap_exit -ne 0 ]]; then
    echo "FAIL: capability layer checks failed (exit $cap_exit)"
    docker compose "${COMPOSE_ARGS[@]}" down -v
    exit 1
  fi

  # Phase 2: reasoning layer checks
  echo "=== Phase 2: reasoning layer ==="
  docker compose "${COMPOSE_ARGS[@]}" exec agent bash /dry_run.sh
  local rl_exit=$?
  if [[ $rl_exit -ne 0 ]]; then
    echo "FAIL: reasoning layer checks failed (exit $rl_exit)"
    docker compose "${COMPOSE_ARGS[@]}" down -v
    exit 1
  fi

  # Phase 3: host-side verification
  echo "=== Phase 3: host-side verification ==="
  verify_host_artifacts "$SANDBOX_DIR"
  local host_exit=$?
  if [[ $host_exit -ne 0 ]]; then
    echo "FAIL: host-side verification failed (exit $host_exit)"
    docker compose "${COMPOSE_ARGS[@]}" down -v
    exit 1
  fi

  # Cleanup
  docker compose "${COMPOSE_ARGS[@]}" down -v
  echo ""
  echo "=== dry-run: ALL PHASES PASSED ==="
}
```

### Dry-run compose overlay

The dry-run overlay (`libs/docker-compose.dry-run.yml`) must expose both scripts. Currently it only mounts `dry_run.sh` into the agent service. It needs a second bind mount for the sandbox:

```yaml
services:
  sandbox:
    volumes:
      - type: bind
        source: {{DRY_RUN_CAPABILITY_SCRIPT}}
        target: /dry_run_capability.sh
        read_only: true

  agent:
    volumes:
      - type: bind
        source: {{DRY_RUN_SCRIPT}}
        target: /dry_run.sh
        read_only: true
```

This requires `start_agent.sh` to export both `DRY_RUN_SCRIPT` and `DRY_RUN_CAPABILITY_SCRIPT` before compose generation.

---

## Phase details

### Phase 1 — Capability layer checks (`dry_run_capability.sh`)

New file at `scripts/dry_run_capability.sh`. Runs inside the sandbox container after the entrypoint has completed (sandbox healthcheck = healthy). Inherits the sandbox's env vars from the compose template.

**CRITICAL checks (must pass, exit 1 on failure):**

| Check | What it asserts | How |
|---|---|---|
| `.git` exists | Git init completed | `test -d "$SANDBOX_DIR/.git"` |
| SESSION_STATE has init_sha | Baseline commit was made | `session_state_read "$SANDBOX_DIR" "init_sha"` |
| SESSION_STATE has session_ts | Session timestamp recorded | `session_state_read "$SANDBOX_DIR" "session_ts"` |
| CHANGES_DIR writable | session-diffs bind mount is functional | Touch a temp file in `$CHANGES_DIR` |
| SNAPSHOT_DIR readable | Snapshot mount is present | `test -f "$SNAPSHOT_DIR/baseline.tar"` |
| INPUT_DIR readable | Brief input mount is present | `test -d "$INPUT_DIR"` |
| OUTPUT_DIR writable | Output mount is functional | Touch a temp file in `$OUTPUT_DIR` |
| CHANGES_DIR round-trip | Write marker, verify it lands on the resolved path | Same pattern as existing `dry_run.sh` round-trip test |

**WARN checks (log but do not exit non-zero):**

| Check | What it asserts | How |
|---|---|---|
| `brief.md` present in INPUT_DIR | AGENTS.md was injected | `test -f "$INPUT_DIR/brief.md"` |
| Working tree is clean | No stray files from prior state | `git -C "$SANDBOX_DIR" status --short` empty |
| All mount paths match expected pattern | Bind mounts align with dirs.sh resolution | Compare `$CHANGES_DIR`, `$SNAPSHOT_DIR` to expected patterns |

Subsumes the docker-dependent static-file-existence checks from `test_capability_layer.sh` (lines ~114–137: checks for `sandbox-entrypoint.sh`, `snapshot.sh`, `diff.sh`, `dirs.sh` existence in the image).

### Phase 2 — Reasoning layer checks (`dry_run.sh`, rewritten)

Existing file at `scripts/dry_run.sh`, rewritten to focus only on the reasoning layer's perspective. Runs inside the agent container.

**CRITICAL checks:**

| Check | What it asserts | How |
|---|---|---|
| INPUT_DIR readable | Brief mount present | `test -f "$INPUT_DIR/brief.md"` |
| OUTPUT_DIR writable | Output mount functional | Touch a temp file |
| CHANGES_DIR readable (via volumes_from) | Can see sandbox's session-diffs mount | `test -d "$CHANGES_DIR"` |
| SESSION_STATE readable (via shared .git) | Can read what sandbox wrote | `session_state_read "$SANDBOX_DIR" "init_sha"` |
| Can read markers written by capability layer | Cross-container communication via shared mounts | Read the marker file Phase 1 wrote to CHANGES_DIR |

**WARN checks:**

| Check | What it asserts | How |
|---|---|---|
| SESSION_STATE has all expected keys | Entrypoint wrote full state | Check for `changes_dir`, `snapshot_dir`, etc. |

The existing session-diffs round-trip test (written in session 20260513-02) stays here — it validates the reasoning layer side of the seam.

### Phase 3 — Host-side verification

Inline in `compose_dry_run` or a small helper script. Runs on the host after both containers have exited.

**Checks:**

| Check | What it asserts | How |
|---|---|---|
| Marker file exists on host | Artifact written by sandbox survived the bind mount | `test -f "$CHANGES_DIR/.dryrun_seam_test"` |
| Marker file content matches | Round-trip is intact | `cat "$CHANGES_DIR/.dryrun_seam_test"` == expected value |
| brief.md exists on host | Input file was properly staged | `test -f "$INPUT_DIR/brief.md"` |

**Cleanup:**

Remove temp files:
```bash
rm -f "$CHANGES_DIR/.dryrun_seam_test"
rm -f "$OUTPUT_DIR/.dryrun_reasoning_test"
```

---

## Implementation sequence

### Session 11b — Pre-flight script (in sandbox-entrypoint)

- Add a `preflight_check` block at the end of `libs/sandbox-entrypoint.sh`, after `snapshot_init_git` and the diff pipeline sourcing, before the `wait` loop.
- Inline the CRITICAL and WARN checks from Phase 1's table above (minus the CHANGES_DIR round-trip — that's a dry-run-only investigation check).
- CRITICAL failures: `echo "PREFLIGHT FAIL: ..." >&2; exit 1`
- WARN failures: `echo "PREFLIGHT WARN: ..." >&2` (no exit)
- `make test` must pass.

**Files changed:** `libs/sandbox-entrypoint.sh`

### Session 11c — dry_run_capability.sh + compose overlay

- Create `scripts/dry_run_capability.sh` with the full Phase 1 check table (including round-trip, minus the pre-flight checks that are now redundant — or keep them for double-validation).
- Update `libs/docker-compose.dry-run.yml` to add the sandbox bind mount.
- Update `scripts/start_agent.sh` to export `DRY_RUN_CAPABILITY_SCRIPT`.
- No orchestration changes yet — Phase 1 runs stand-alone for testing.
- `make test` must pass.

**Files changed:** `scripts/dry_run_capability.sh` (new), `libs/docker-compose.dry-run.yml`, `scripts/start_agent.sh`

### Session 11d — dry_run.sh rewrite (reasoning layer)

- Rewrite `scripts/dry_run.sh` to focus solely on reasoning layer checks (Phase 2).
- Remove any capability-layer checks that leaked into the original file.
- Keep the existing round-trip test for reasoning layer.
- `make test` must pass.

**Files changed:** `scripts/dry_run.sh`

### Session 11e — Host-side verification + orchestration

- Add `verify_host_artifacts` function or inline block to `libs/compose.sh`'s `compose_dry_run`.
- Wire up the three-phase sequence.
- Add cleanup of temp artifacts.
- `make test` must pass.

**Files changed:** `libs/compose.sh`

---

## Pre-flight vs dry-run: what goes where

| Check | Pre-flight (every start) | dry_run_capability (dry-run only) |
|---|---|---|
| `.git` exists | ✅ | — |
| SESSION_STATE has init_sha + session_ts | ✅ | — |
| CHANGES_DIR writable | ✅ | — |
| SNAPSHOT_DIR readable | ✅ | — |
| INPUT_DIR readable | ✅ | — |
| OUTPUT_DIR writable | ✅ | — |
| brief.md present (warn) | ✅ | — |
| Working tree clean (warn) | ✅ | — |
| CHANGES_DIR round-trip (write + read via mount) | — | ✅ |
| Image file existence (`sandbox-entrypoint.sh`, `snapshot.sh`, etc.) | — | ✅ |
| Diff pipeline invocable | — | ✅ |
| Cross-container marker read (reasoning reads what capability wrote) | — | ✅ (dry_run.sh) |
| Host-side artifact verification | — | ✅ (host-side phase) |

---

## SESSION_STATE key schema (pre-flight additions)

The pre-flight reads existing SESSION_STATE keys but does not write any new ones. The dry_run_capability.sh may write a temporary key (e.g. `dryrun_marker`) that dry_run.sh reads and the host-side phase cleans up. This is an implementation detail to be decided in 11c.

---

## Safety and error handling

- Any CRITICAL failure in any phase causes the entire dry-run to fail with a non-zero exit code and `docker compose down -v`.
- WARN failures are logged but do not abort.
- Cleanup (`down -v`) runs on success and on failure (after logging the failure).
- Temp files created by the sandbox for round-trip testing are cleaned up by the host-side phase. If the host-side phase crashes before cleanup, temp files remain in `CHANGES_DIR` — acceptable because `SNAPSHOT_DIR` is cleaned on next `make start` anyway.
