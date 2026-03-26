# Container Model

This document describes how Docker implements the two-layer architecture: how the compose configuration is generated, why the mounts are shaped the way they are, how the two containers start and stop, and what each entrypoint does.

The conceptual model for why the layers are separate is in [`two_layer_model.md`](../concepts/two_layer_model.md). The sandbox lifecycle — snapshot, diff, input channels — is in [`sandbox_lifecycle.md`](sandbox_lifecycle.md). The external contract — mount shape table, image naming, execution modes — is in [`tool_interface.md`](tool_interface.md).

---

## Compose Generation

`scripts/start_agent.sh` generates the compose configuration on each run. Compose files are written to a tmpfile — never to `SANDBOX_DIR` — and are not operator-managed.

**Tmpfile generation:** `compose_generate` in `libs/compose.sh` merges the base template with any mode overlay using `docker compose config --no-interpolate`, bakes image names and host paths into the result, and preserves operator secrets as `${VAR}` for runtime resolution. The merged file is written to a tmpfile and its path passed to `run.sh` via `--compose-file`. The tmpfile is deleted by a trap in `run.sh` on exit.

**Baked vs `${VAR}` split:** Image names, container names, service dependencies, volume definitions, and internal mount paths are baked at generation time — they are stable per project and do not vary between runs. Machine-specific values — host paths, ports, credentials — are preserved as `${VARIABLE}` and resolved from `.env` at runtime by Docker Compose.

**Why host paths are baked:** `docker compose config --no-interpolate` relativises unresolved path variables against the staging directory. Baking host paths at generation time — after reading `.env` — avoids this relativisation and produces correct absolute paths in the merged file.

**Why explicit `type: bind`:** Docker Compose misclassifies `${VAR}` sources as named volumes in short volume syntax. All volume mounts use explicit `type: bind` syntax to prevent this.

**Mode composition:**

| Mode | Compose files |
|---|---|
| `standard` | Base tmpfile only |
| `serve` | Base tmpfile + `providers/<n>/docker-compose.serve.yml` |
| `dry-run` | Base tmpfile + `libs/docker-compose.dry-run.yml` |

The serve overlay is a static file in the repo under `providers/<n>/` — never generated or written to `SANDBOX_DIR`. The dry-run overlay is sourced from `libs/docker-compose.dry-run.yml` and merged at generation time.

**Deferred — multi-service project composition:** Projects that run multiple services (e.g. a web app with a database and test containers) have no mechanism to inject additional services alongside the harness-managed containers. A composition mechanism allowing operator-defined services to be merged with the harness-generated base is a future design task. See `roadmap.md`.

---

## Mount Shape Rationale

The mount shape table — host paths, container paths, modes, owners — is the contract defined in [`tool_interface.md` — Mount Shape Guarantees](tool_interface.md#mount-shape-guarantees). This section records why the shape is what it is.

### Why subdirectory mounts rather than the workspace parent

Each `.workspace/` subdirectory has a different trust level and a different container owner. Mounting them separately enforces ownership at the filesystem level: the capability layer cannot write to `workspace/input/` because it is not mounted; the reasoning layer cannot write to `workspace/changes/` for the same reason.

- `input/` — operator-written, agent-read (reasoning layer, read-only)
- `output/` — agent-written (reasoning layer, read-write)
- `changes/` — harness-written (capability layer, read-write — diff pipeline)

Any future capability layer code path must write only to `workspace/changes/` — writing to the workspace parent must be treated as a bug.

### Why `.snapshot/` is read-only and capability-layer-only

The snapshot is an input prepared before the run. Mounting it read-only prevents either container from modifying the baseline. Only the capability layer needs it — it copies the snapshot into `sandbox/` at startup and does not reference it again.

### Why `output/` prohibits binaries

`output/` is the reasoning layer's persistent output channel to the host. Restricting it to text and serialised data limits the attack surface — a compromised agent cannot write executable files that the operator might inadvertently run on the host. Binary outputs, if needed, must go through `sandbox/` and the diff pipeline.

### Why `--volumes-from` rather than a named volume

A named Docker volume is daemon-managed and persists independently of any container. This breaks capability layer ownership: a second session would find the previous session's sandbox content in the volume, and any container could mount it regardless of whether the capability layer is running.

`--volumes-from` ties the sandbox lifecycle to the capability layer container. The reasoning layer can only access `sandbox/` while the capability layer container exists — if the capability layer is not running, `--volumes-from` fails and the reasoning layer cannot start.

**`VOLUME` declaration is required for `--volumes-from` to work.** Docker only exposes directories via `--volumes-from` if they are declared as volumes in the Dockerfile (`VOLUME /home/agentuser/sandbox`). Without this declaration the directory exists only in the container's writable layer and is invisible to other containers. The `VOLUME` instruction promotes `sandbox/` to an anonymous Docker volume at container creation time.

The anonymous volume is created fresh at each session start and destroyed on teardown (`docker compose down -v`). Each session starts with an empty `sandbox/` — the entrypoint copies the snapshot in. The previous session's volume is deleted on teardown.

---

## Container Lifecycle

The harness manages two containers per session via Docker Compose. Start order is enforced by service dependencies; stop order is fixed.

**Start sequence:**
1. `scripts/start_agent.sh` runs pre-flight: validates paths, loads `.env`, runs snapshot pipeline stage 1, resolves brief
2. `scripts/start_agent.sh` generates a merged compose tmpfile via `compose_generate`; dispatches to `providers/<n>/run.sh` with mode and `--compose-file`
3. `providers/<n>/run.sh` assembles compose args — appending the serve overlay if mode is `serve` — then invokes `docker compose`
4. Capability layer starts first (service dependency), runs snapshot pipeline stage 2, initialises `sandbox/`, records baseline SHA
5. Reasoning layer starts with `--volumes-from <capability-layer>` — attaches to `sandbox/`, mounts `workspace/input/` and `workspace/output/` from host
6. Reasoning layer hands off to the agent

**Stop sequence:**
1. Reasoning layer container exits (agent completes or is interrupted)
2. Harness stops the capability layer via `docker stop`, sending SIGTERM to PID 1 (`sandbox-entrypoint.sh`)
3. The TERM trap calls `exit 0`, triggering the EXIT trap
4. The EXIT trap runs the diff pipeline — commits pending changes in `sandbox/`, writes `staged.diff`

The capability layer must be running before the reasoning layer starts and must not stop until after the reasoning layer exits. The TERM trap ensures `docker stop` produces a clean exit code so the EXIT trap fires reliably regardless of shutdown path.

---

## Entrypoint Sequence

**Capability layer entrypoint** (`scripts/sandbox-entrypoint.sh`):
```
  1. snapshot_validate (gate 2)         — confirm .snapshot/ is intact
  2. snapshot_copy_to_sandbox           — copy .snapshot/ into sandbox/
  3. snapshot_init_git                  — git init + baseline commit; records baseline SHA
  4. register EXIT trap → diff pipeline — fires on any exit; commits pending changes, writes staged.diff
  5. register TERM trap → exit 0        — docker stop sends SIGTERM to PID 1; clean exit ensures EXIT trap fires
  6. start autosave loop                — if AUTOSAVE_INTERVAL > 0
  7. wait                               — stays running while reasoning layer is active
```

Steps 1–3 must succeed before the reasoning layer container starts. Any failure exits the capability layer without starting the reasoning layer.

**Reasoning layer entrypoint:**

Provider-specific. Defined in `providers/<n>/Dockerfile` via `ENTRYPOINT`. Brief and operator input files are accessible via the `workspace/input/` read-only mount — no copy step is required.

---

## References

| Topic | Document |
|---|---|
| Why the two layers exist | [../concepts/two_layer_model.md](../concepts/two_layer_model.md) |
| Sandbox lifecycle — snapshot, diff, input channels | [sandbox_lifecycle.md](sandbox_lifecycle.md) |
| Execution model (index) | [execution_model.md](execution_model.md) |
| Mount shape guarantees (contract) | [tool_interface.md](tool_interface.md#mount-shape-guarantees) |
| Provider interface contract | [tool_interface.md](tool_interface.md#provider-interface) |
| Adding a provider | [../operations/provider_onboarding_guide.md](../operations/provider_onboarding_guide.md) |
