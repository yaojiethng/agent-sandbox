---
reader: [agent]
---

# Execution Model

This document describes one agent run: the directory layout, the invocation path, the generated compose file, how the two containers are wired, and the start and stop sequence. The per-layer session arcs are in `sandbox_lifecycle.md` and `provider_lifecycle.md`, and the external contract is in `tool_interface.md`.

## Directory Layout

The harness operates against two directories: `PROJECT_DIR` (the project git repository) and `SANDBOX_DIR` (the harness workspace). Both are absolute paths supplied via `.env`. Their location relative to each other on the host is not constrained.

```text
SANDBOX_DIR/
├── Makefile
├── .env
├── .<provider>/               ← provider config (seeded at onboard; persists across sessions)
└── .workspace/                ← harness I/O channels
    ├── input/                 ← operator-placed task briefs and addenda (RO to agent)
    ├── output/                ← agent progress and serialised data (RW, no binaries)
    └── session-diffs/         ← diff pipeline output
        ├── session/            ← exit artefacts
        │   └── <EXPORT_TIME>-<SESSION_ID>/  ← session-scoped directory
        │       ├── .export-status    ← STATUS, TIMESTAMP, INIT_SHA (diff_export adds HEAD)
        │       ├── uncommitted.diff
        │       ├── all-changes.diff
        │       ├── patches/         ← per-commit .diff files
        │       └── changed-files/   ← working tree copies
        └── autosave/           ← checkpoint artefacts
            └── <SESSION_ID>/  ← single checkpoint directory, swapped in per successful tick
                ├── .export-status    ← STATUS, TIMESTAMP, INIT_SHA (diff_export adds HEAD)
                ├── uncommitted.diff
                ├── patches/
                └── changed-files/

Capability layer container (CWD: /home/agentuser/)
├── workspace/session-diffs/   ← RW bind mount: diff output
└── sandbox/                   ← RW Docker volume: working content (owned by this container; seeded host-side at start)

Reasoning layer container (CWD: /home/agentuser/)
├── workspace/input/           ← RO bind mount: task briefs, operator addenda
├── workspace/output/          ← RW bind mount: agent progress (no binaries)
├── sandbox/                   ← RW Docker volume: shared from capability layer via --volumes-from
└── .<provider>/               ← provider config dir, layout defined by provider
    ├── agent/                 ← Pi convention: nested config directory
    │   ├── prompts/           ← RW bind mount: provider-layer prompts (persists)
    │   ├── sessions/          ← RW bind mount: session history (persists)
    │   ├── skills/            ← RW bind mount: provider-layer skills (persists)
    │   ├── bin/               ← overlayfs: container-local, same fs as /tmp/ (mv safe)
    │   ├── settings.json     ← ephemeral: seeded from the image template at startup
    │   ├── auth.json          ← ephemeral: seeded from the image template at startup
    │   ├── models.json        ← ephemeral: seeded from the image template at startup
    │   └── AGENTS.md          ← ephemeral: seeded from the image template at startup
    ├── model-recommendations.md ← RW bind mount: the container's role-table copy, read when the project copy is absent
    └── .env                   ← host-provided: API keys (never committed)
```

Host path variables are defined in [`tool_interface.md` -- `.env` Runtime Variables](tool_interface.md#env-runtime-variables).

## Invocation Model

`scripts/start_agent.sh` runs from the project Makefile through the `agent-sandbox` CLI. It does host-side pre-flight only: path validation, `.env` loading, git validation, workspace setup, and worktree materialization for mount delivery. It then `exec`s `scripts/run_agent.sh`, which owns the provider lifecycle: the setup hook, the compose file, and the containers from start to teardown.

Container paths are fixed and not configurable through `.env`. The mount shape is in [`tool_interface.md` -- Mount Shape Guarantees](tool_interface.md#mount-shape-guarantees).

## Compose Generation

`scripts/run_agent.sh` writes the generated compose configuration to `$SANDBOX_DIR/.compose/<session-id>.yml`. The file outlives the session and is the inspection handle (`docker compose -f .compose/<session-id>.yml config`). Resume reuses the SESSION_ID and overwrites its own file, so each session leaves one record. Containers mount only SANDBOX_DIR subdirectories, so the agent never sees it. `.compose/` is gitignored.

**Per-session activity log:** alongside the compose record, each session keeps a `.compose/<session-id>.log` holding `KEY=VALUE` lines, `last_started=` and `last_stopped=`, in UTC `YYYYMMDD-HHMMSS`. `run_agent.sh` writes `last_started=` on start or resume and clears `last_stopped=`, so a running session never reads as stopped, then writes `last_stopped=` at teardown. Dry-run ids (session_is_dry_run) are excluded, so dry-run machinery leaves no activity record. `make resume --list` derives its `AGE` column from the latest entry, overridden by live docker state when the two disagree. The compose record also carries the session's image-content identity: `compose_generate` stamps the `agent-sandbox.agent-image-digest` and `agent-sandbox.sandbox-image-digest` labels from image ID digests read via docker inspect after the build, so `make resume --list` reads the record without a docker dependency (ADR harness_versioning.md).

**Merged generation:** `compose_generate` in `src/build/compose.sh` merges the base template with any applicable overlays through `docker compose config --no-interpolate`, bakes image names and host paths into the result, and keeps operator secrets as `${VAR}` for runtime resolution.

**Baked vs `${VAR}` split:** image names, container names, service dependencies, volume definitions, and internal mount paths are baked at generation time, because they are stable per project and do not vary between runs. Machine-specific values (host paths, ports, credentials) stay as `${VARIABLE}` and Docker Compose resolves them from `.env` at runtime.

**Why host paths are baked:** `docker compose config --no-interpolate` relativises unresolved path variables against the staging directory. Baking host paths after reading `.env` avoids this relativisation and produces correct absolute paths in the merged file.

**Why explicit `type: bind`:** Docker Compose misclassifies `${VAR}` sources as named volumes in short volume syntax, so every volume mount uses explicit `type: bind`.

**Mode composition:**

| Mode | Compose files |
|---|---|
| `standard` | Base template + delivery overlay (+ provider overlay if present) |
| `serve` | Base template + delivery overlay + provider overlay (if present) + `src/reasoning/providers/<n>/docker-compose.serve.yml` |
| `dry-run` | Base template + delivery overlay + provider overlay (if present) + `src/build/docker-compose.dry-run.yml` |

**Delivery overlays:** the delivery type reaches `run_agent.sh` as `--delivery` (`copy|mount`); `start_agent.sh` parses it at ingestion (default `copy`), `resume_agent.sh` recovers it from the session record, and `run_agent.sh` never defaults it. The per-delivery overlay carries the worktree wiring, so the base template stays shared. Dry-run on `--delivery=mount` stacks the mount overlay too: the probes run against the real worktree read-only, writing only to the workspace channels and the entrypoint-owned `.git/SESSION_STATE` marker, so tracked repo content is never modified.

- `src/build/docker-compose.copy.yml` -- the per-run named sandbox volume, seeded by the one-shot seeder service (helper-container transport), with no snapshot mount. Copy mode only.
- `src/build/docker-compose.mount.yml` -- the worktree bind mount at `/home/agentuser/sandbox` (default source `${SANDBOX_DIR}/.worktree`, overridable via `WORKTREE_DIR`). Mount mode only.

The provider overlay (`src/reasoning/providers/<n>/docker-compose.<n>.yml`) is optional and merged if the file exists. It covers mounts and environment variables that apply in every mode. The serve, dry-run, and delivery overlays are static repo files; only the merged result is written to `SANDBOX_DIR`.

**Delivery-aware container init:** the capability-layer entrypoint branches on `SANDBOX_TYPE`, which each delivery overlay passes as a container env literal.

- **Copy:** the one-shot seeder service fills the volume before this container starts: repository with index, working tree, `SESSION_STATE`. The entrypoint validates the git state.
- **Mount:** no seed. The entrypoint validates that `.git` is present in the bind-mounted worktree, writes the `SESSION_STATE` init marker into the worktree `.git` if absent, and skips the seed init. `init_sha` is the baseline root commit for a flattened worktree, or the host HEAD at materialization for a full-history one.

`SESSION_STATE` stays in both deliveries as container-side provenance. Copy mode has the seeder write it into the volume's `.git` before the container exists. Mount mode writes it into the worktree `.git`, where it doubles as the init marker. [`terminology.md`](terminology.md) lists the session identifiers.

**Mount worktree materialization:** on a fresh mount run, `start_agent.sh` materializes `${WORKTREE_DIR}` (default `${SANDBOX_DIR}/.worktree`) through the snapshot dispatcher `snapshot_deliver`, full history by default (`cp -a .git` plus a git-enumerated worktree copy) or `--flatten` for a fresh baseline without host history. The worktree records its delivery-history mode in `.git/config` (`agent-sandbox.flatten`), so a later mismatch is refused and a corrupt non-boolean value is refused in the clear. The container then writes the `SESSION_STATE` init marker. On later runs the worktree already has `.git` and is reused. Resume cross-checks the record's `FLATTEN` against the worktree's mode, warns on a mismatch, and continues with the record value.

**File accumulation:** compose files accumulate one per unique SESSION_ID, a few KB each.

## Mount Shape Rationale

The mount shape table is the contract in [`tool_interface.md` -- Mount Shape Guarantees](tool_interface.md#mount-shape-guarantees). This section records why the shape is what it is.

### Why subdirectory mounts rather than the workspace parent

Each `.workspace/` subdirectory has a different trust level and a different container owner, and mounting them separately enforces ownership at the filesystem level. The capability layer cannot write `workspace/input/` because it is not mounted, and the reasoning layer cannot write `workspace/session-diffs/` for the same reason. `input/` is operator-written and agent-read, `output/` is agent-written, and `session-diffs/` is harness-written by the capability layer's diff pipeline.

### Why the sandbox volume is capability-layer-only

The volume is the agent's working content, seeded once before the sandbox container starts. Nothing else references it, and the host receives changes only through the diff pipeline.

### Why `output/` prohibits binaries

`output/` is the reasoning layer's persistent channel to the host. Restricting it to text and serialised data limits the attack surface, because a compromised agent cannot write an executable the operator might run on the host.

### Why the config files are seeded rather than mounted

Provider config cannot be bind-mounted whole as `AGENT_HOME`, because agents may perform filesystem operations (cross-device moves from `/tmp`, binary writes) that fail on host-mounted paths, particularly on Windows. The image bakes the config template at `/opt/workflow/agent/config/`, and `provider-entrypoint.sh` copies it into `AGENT_HOME` at every start. The provider overlay mounts only the subdirectories that carry state, so the agent keeps the host's session history and the image keeps the config files.

### Why `--volumes-from` rather than a named volume for the agent's `sandbox/` view

The reasoning layer shares the capability layer's `sandbox/` mount through `--volumes-from` on the compose `agent` service, which ties the agent's view to the capability container's lifecycle. Docker exposes a directory this way only if the Dockerfile declares it (`VOLUME /home/agentuser/sandbox`). The compose file mounts a SESSION_ID-scoped named volume (`{{SESSION_ID}}-sandbox-data`) at that path on the sandbox service, and a named volume survives `docker compose down`, so session state survives stop and start. See [Container State Contract](#container-state-contract).

## Container State Contract

This is the expected record of what lives where across a session.

**The container is disposable.** Removing or rebuilding a session's containers loses nothing user-authored. Durable state lives in the named volume and bind mounts, and the container writable layer holds only regenerable content.

| What | Where it lives | Survives `docker compose down`? |
|---|---|---|
| Agent WORKDIR `/home/agentuser/sandbox` (project worktree, `node_modules` from `npm install`, session work) | named volume `{{SESSION_ID}}-sandbox-data` | [x] yes (named volume persists) |
| Agent state `.pi/{prompts,sessions,skills}` | bind-mounted to `$SANDBOX_DIR/.pi/...` | [x] yes (host) |
| Model recommendations `.pi/model-recommendations.md` | single-file bind mount to `$SANDBOX_DIR/.pi/model-recommendations.md` | [x] yes (host) |
| Harness workspace `.workspace/{session-diffs,input,output}` | bind-mounted to `$SANDBOX_DIR/.workspace/...` | [x] yes (host) |
| Seed content (shared dispatcher delivery) | streamed via rsync into the volume with `cp -a .git` (full) or a fresh baseline (flatten) | n/a (one-shot transfer) |
| Config files `.pi/settings.json`, `auth.json`, `models.json`, `AGENTS.md`, `bin/` | container writable layer, seeded from the baked image at startup | [ ] regenerated on start |
| Caches `~/.npm`, `~/.cache` | container writable layer | [ ] disposable |

Consequence: `make stop` and session teardown remove the containers and the per-session network, and keep the named volume. Resume comes from the volume, not from stopped containers.

## Docker verb semantics note

Docker's lifecycle verbs have meanings that our command shape only partly matches:

| Docker verb | Docker meaning | Our use |
|---|---|---|
| `docker start` | start an existing stopped container | (unused) -- our `start` is full setup: `compose up` + `compose run agent` |
| `docker stop` | pause a container for later same-container restart | teardown is `compose down` |
| `docker compose down` | end the session; remove containers + network; keep named volumes | our teardown (`session_teardown` -> `down`) |
| `docker compose down -v` | also remove named volumes | our full reset (`session_destroy`) |

Our `start` and `stop` do not match docker's pause-resume semantics. The harness functions are named `session_teardown` and `session_destroy` (intent-based) to avoid implying the docker `stop` verb.

## Session exit semantics

`scripts/run_agent.sh` exits 0 on a clean session end in both modes: standard (agent completes) and serve (operator runs `make stop`). Standard mode propagates a non-zero agent exit code, with one exception: 137 or 143 means the container ended by signal, which is what `make stop` does, so standard mode prints the code and exits 0. Serve mode always exits 0, because its session ends by `make stop` rather than by the agent's completion. The agent container runs an init process at PID 1, so a stop signal reaches the agent and it ends cleanly (measured 0.287s, exit 0). Without one, a process that is the PID-namespace init receives nothing, and docker spends the whole stop grace before a SIGKILL (measured 10.20s, exit 137). Teardown runs on every exit path after the session starts (agent completion, agent failure, `compose up` failure, or sandbox health-wait failure) through run_agent.sh's EXIT trap (`_session_cleanup`), so containers and the session network never leak. The teardown also prints the commands that continue the work, so the end of a `make start` surfaces them: `make resume SESSION_ID=<id>` and `make draft BUNDLE=<name>`, the latter naming the exact session export.

## Session Lifecycle

The following diagram shows the full control flow for a standard session across all three execution contexts.

```mermaid
---
config:
      theme: redux
flowchart TD
    %% Global Styles
    classDef host fill:#f9f9f9,stroke:#333,stroke-width:2px;
    classDef cap fill:#e1f5fe,stroke:#01579b;
    classDef rsn fill:#fff3e0,stroke:#e65100;

    START([<b>START</b>]) --> SA

    subgraph HOST [Host / Harness]
        SA["<b>start_agent.sh</b><br/>preflight • checkpoint • snapshot • brief"]
        RA["<b>run_agent.sh</b><br/>compose gen"]
        DEC{setup.sh<br/>exists?}
        SH["<b>setup.sh</b>"]
        CUS["<b>compose up</b><br/>sandbox"]
        WAIT_HC([healthcheck ready])
        CRA["<b>compose run agent</b><br/>--volumes-from sandbox"]
        PP["<b>_provider_persist</b><br/>output → SANDBOX_DIR"]
        CD["<b>compose down</b><br/>keep named volumes"]
        END([<b>COMPLETE</b>])
    end

    subgraph CAP [Capability Layer]
        SE["<b>sandbox-entrypoint.sh</b><br/>validate • snapshot"]
        TR["register EXIT + TERM traps"]
        WAIT["wait"]
        SIGTERM["<b>SIGTERM</b> → exit 0<br/>EXIT trap: commit"]
        DIFF["<b>diff_export</b><br/>uncommitted.diff, all-changes.diff, patches/, changed-files/"]
    end

    subgraph RSN [Reasoning Layer]
        PE["<b>provider-entrypoint.sh</b>"]
        CI["seed config from the image"]
        ET["register EXIT trap"]
        EX["exec agent command"]
        RDY["ready for user input"]
        AE["<b>agent exits</b><br/>container ends, nothing copied out"]
    end

    %% Logic Flow
    SA --> RA --> DEC
    DEC -- yes --> SH --> CUS
    DEC -- no --> CUS
    CUS --> SE
    SE --> TR --> WAIT
    WAIT -- healthcheck passes --> WAIT_HC
    WAIT_HC --> CRA
    CRA --> PE
    PE --> CI --> ET --> EX --> RDY --> AE
    AE --> PP --> CD
    CD -- triggers --> SIGTERM
    SIGTERM --> DIFF --> END

    %% Apply Styles
    class SA,RA,DEC,SH,CUS,WAIT_HC,CRA,PP,CD host;
    class SE,TR,WAIT,SIGTERM,DIFF cap;
    class PE,CI,ET,EX,RDY,AE rsn;
```

## Staleness Detection

Docker's layer cache is the only staleness mechanism. The repo root is the build context, with repo-relative COPY instructions in each Dockerfile, so a change to any input file invalidates that layer and every downstream layer at the next build. No digest comparison or temp-dir assembly is needed.

## References

| Topic | Document |
|---|---|
| Two-layer conceptual model | [../reference/two_layer_model.md](../reference/two_layer_model.md) |
| Capability layer lifecycle | [sandbox_lifecycle.md](sandbox_lifecycle.md) |
| Reasoning layer lifecycle | [provider_lifecycle.md](provider_lifecycle.md) |
| External contract | [tool_interface.md](tool_interface.md) |
| System invariants and component overview | [system_overview.md](system_overview.md) |
| Security guarantees | `docs/development/security.md` |
