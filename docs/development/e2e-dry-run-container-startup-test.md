# End-to-End `make dry-run` Test — Container Start-Up Execution Point

> **README FIRST.** This verifies the *unverified container-start-up change* from
> handover `20260828-02-impl-dry_run_container_startup`. It MUST be run on a real
> docker host (not the agent sandbox container, which has no docker daemon). The
> goal is to confirm the two bearer containers now run their readiness-layer
> self-checks (docker_image -> workspace_mounts -> session_state ->
> at container **start-up** (via a compose `command:` override) instead of the
> harness exec'ing the probes, and that `make dry-run` still validates the
> correct container from the per-container diagnostics records + the
> image-signature gate.

## What changed vs the previous behaviour

| Aspect | Before (exec-based) | Now (start-up) |
|---|---|---|
| Capability probe run: | `docker compose exec sandbox bash /dry_run_capability.sh` (harness-pulled) | sandbox `command:` override — runs as a **prelude** (after init + preflight, then stays alive) |
| Reasoning probe run: | `docker compose exec agent bash /dry_run_reasoning.sh` | agent `command:` override — runs at start-up, then exits (one-shot) |
| `DRY_RUN_IDENTITY` source: | injected into `exec` env | baked into the compose overlay `environment:` (`{{SANDBOX_IMAGE_NAME}}` / `{{AGENT_IMAGE_NAME}}`) |
| Orchestration assertion: | read feature records + image-sig gate | **unchanged** (records + image-sig gate are the source of truth) |
| Harness composes: | `up` → `exec` cap → `exec` rea → verify → down | `up` (both probes self-run) → wait for records → verify → down |

## Preconditions

1. A host with **docker + docker compose** and the `agent-sandbox` CLI on `PATH`.
2. A **scratch git repo** with at least one commit (the sandbox mounts it and
   asserts a valid `init_sha`). Example:
   ```bash
   mkdir -p /tmp/drytest/project && cd /tmp/drytest/project
   git init -q && git config user.email t@t && git config user.name t
   git commit -q --allow-empty -m init   # ≥1 commit required by init_sha check
   ```
3. A provider choice, e.g. `pi` (any supported provider works).

---

## Phase A — Fresh build (required for the image-signature gate)

The option-(c) gate fails if the running image carries **no** `container-sig` label (a pre-two-sig build) or a **stale** signature. Build fresh so the label matches the current source.

```bash
cd /path/to/agent-sandbox   # repo that provides `make build`/`make dry-run`
make build PROVIDER=pi      # sandbox + pi provider images built from current source
```

Confirm the image carries a signature label:

```bash
docker image inspect agent-sandbox-sandbox --format '{{ index .Config.Labels "agent-sandbox.container-sig" }}'
# → a non-empty hex string (NOT empty)
```

> If this is empty, the image predates the two-signature build — rebuild with
> `make build REBUILD=1`.

---

## Phase B — Run dry-run

```bash
make dry-run PROVIDER=pi \
  --name=drytest \
  --project=/tmp/drytest/project   \
  --sandbox=/tmp/drytest/sandbox
```

(`--name/--project/--sandbox` come from your sandbox Makefile/env normally; the above is the direct equivalent.)

### Expected stdout sequence

```
Warning: SERVE_PORT is not set ...        (harmless, non serve mode)
Running dry-run...
Starting containers (bearer probes run at start-up)...
Wait: for per-container diagnostics records...
=== Phase 3: record verification (correct container) ===
Phase 3 PASSED (correct container linked and ready).
Cleaning up containers...
=== dry-run: ALL PHASES PASSED ===
             (exit code 0)
```

There is **no** `=== Phase 1: capability layer ===` / `=== Phase 2: reasoning layer ===` block and **no** `compose exec` in the flow.

### What to capture and feed back

1. **Full stdout + stderr** of the `make dry-run` command (or the underlying
   `agent-sandbox dry-run ...`).
2. **Both diagnostics records** (confirmed present + correct content):
   ```bash
   cat /tmp/drytest/sandbox/.workspace/output/dryrun.capability.record
   cat /tmp/drytest/sandbox/.workspace/output/dryrun.reasoning.record
   ```
   Expected shape per record:
   ```
   container=<image-name>
   layer.docker_image=PASS
   layer.workspace_mounts=PASS
   layer.session_state=PASS
   layer.session_data=PASS
   layer.container_network=PASS
   layer.agent_runtime=PASS
   status=PASS
   status=PASS
   ```
   (The `container=` line MUST match the image name for that layer: sandbox record = `{{SANDBOX_IMAGE_NAME}}`, agent record = `{{AGENT_IMAGE_NAME}}`.)

---

## Phase C — Prove start-up execution (the point of this change)

The probes must ALREADY have run by the time `up -d` returns — orchestration never exec's them.

**1. No `compose exec` in the entirety of a dry-run.** Re-run dry-run with `--trace` (or `DOCKER_TRACE_LOG=/tmp/drytrace bash my dry-run`) and confirm there is **no** line containing `compose exec`; there **is** a single `compose up`.

**2. Container start-up logs show the probe.** The sandbox entrypoint should emit, before the stay-alive comment block:
```
entrypoint: running start-up command: bash /dry_run_capability.sh
```
Grab it during the run (container is up while the agent probe runs):
```bash
# in another terminal, DURING the dry-run:
docker logs sandbox-drytest-<session> 2>&1 | grep 'running start-up command'
```
The agent container similarly runs its probe at start-up (its provider entrypoint fulfills the `command:` with `bash /dry_run_reasoning.sh`).

**3. The sandbox STAYS UP (prelude semantic).** Because the reasoning layer mounts sandbox/ via `--volumes-from` and needs it healthy for the container_network (cross-component) checks, the sandbox must NOT exit after its probe. During the wait window, confirm:
```bash
# in another terminal, DURING the wait:
docker ps --format '{{.Names}}\t{{.Status}}' | grep drytest
# both sandbox-... and pi-... show "Up ..." -- NOT "Exited"
```

---

## Phase D — Image-signature staleness gate (negative test)

Proves the option-(c) gate hard-fails on a stale image.

1. After a clean Phase B **PASS**, modify any **source** file the signature
   covers (e.g. touch `scripts/dry_run_capability.sh` or add a blank line to a `src/` file) **without rebuilding**.
2. Re-run the same `make dry-run`.
3. **Expected:** Phase 3 FAILS — `dry_run_image_verify` reports the running
   image's `container-sig` diverges from the recomputed source signature:
   ```
   RECORD-VERIFY FAIL: image ... stale (source has diverged) ...
   Phase 3 FAILED  --  N record check(s) failed.
   === dry-run: FAILED ===
   ```
   and the command exits non-zero. (This is the hard gate that replaces the old staleness warning; it forces a rebuild.)
4. `docker compose down` still runs (teardown is unaffected by verify failure).

---

## Phase E — Teardown semantics (unchanged)

Confirm `down -v` is used iff `--reset-volume`/persist flags request it:
- plain `make dry-run` → `docker compose down` only (NO `down -v`).
- `make dry-run RESUME=0`-style refresh reset (if your make wiring exposes it)
  → a single `docker compose down -v`.

---

## Acceptance gates for this iteration

| # | Behaviour | Pass = |
|---|---|---|
| E2E-1 | Probes run at start-up, no `compose exec` | no `compose exec` in trace; `entrypoint: running start-up command: ...` in sandbox logs |
| E2E-2 | Both records written + correct identity | `container=` lines match the right images; `layer.<name>` = PASS for all of docker_image / workspace_mounts / session_state / session_data / container_network / agent_runtime; `status=PASS` |
| E2E-3 | Sandbox stays up during agent probe | both containers `Up` during the wait window |
| E2E-4 | Fresh image → PASS | `Phase 3 PASSED` + `ALL PHASES PASSED`, exit 0 |
| E2E-5 | Stale image → hard FAIL | `Phase 3 FAILED` + non-zero exit |
| E2E-6 | Teardown correct | `down` (or `down -v` only with reset flag) |

**Feed back:** (1) full dry-run stdout/stderr, (2) both record file contents, (3) the `docker logs` lines showing `running start-up command`, (4) `docker ps` during the wait, (5) output of the Phase D negative test, and (6) any deviation from the expected sequences above.
