# Provider Onboarding Guide

Step-by-step guide to adding a new reasoning layer provider to agent-sandbox. A provider is a self-contained directory under `providers/<n>/` that supplies the Dockerfiles, serve overlay, and `.env` stubs for one reasoning layer agent.

The provider interface contract is defined in [`../architecture/tool_interface.md` — Provider Interface](../architecture/tool_interface.md#provider-interface). This guide walks through implementing that contract. Refer to [`../architecture/execution_model.md`](../architecture/execution_model.md) for implementation detail on how the harness calls provider scripts.

`opencode` and `hermes` are both conforming providers and are the reference implementations for this guide.

---

## Harness Script Conventions

Two directories contain scripts in the agent-sandbox repo. Understanding the distinction matters when deciding where provider-specific logic belongs:

**`scripts/`** — control flow entry points. Scripts that own a session lifecycle or orchestrate a sequence of operations. Not intended for direct reuse by providers. `start_agent.sh`, `run_agent.sh`, and `build_container.sh` live here.

**`libs/`** — reusable utility functions. Sourced by scripts and providers alike. No top-level control flow — only named functions. `compose.sh`, `containers.sh`, `snapshot.sh` live here.

Provider `setup.sh` hooks are sourced by `scripts/run_agent.sh` and have access to all functions in `libs/`. They must not source scripts from `scripts/` directly.

---

## What You Are Building

A conforming provider supplies four required files and up to two optional files:

**Required:**
```
providers/<n>/
├── base.Dockerfile               ← stable install layers; tagged <provider>-base
├── provider.Dockerfile           ← provider layer inheriting from base; tagged <provider>-agent-<project>
├── docker-compose.serve.yml      ← serve mode overlay
└── .env.example                  ← provider-specific .env stubs
```

**Optional:**
```
providers/<n>/
├── docker-compose.<n>.yml        ← provider overlay, merged in all modes if present
└── setup.sh                      ← pre-run host setup hook, sourced if present
```

None of these files are copied to `SANDBOX_DIR`. They live in the agent-sandbox repo and are referenced directly at run time. Providers do not supply a `build.sh` — the harness builds all images via `scripts/build_container.sh`.

---

## Step 1 — Create the provider directory

```sh
mkdir providers/<n>
```

Use a short lowercase name with hyphens if needed (e.g. `opencode`, `hermes`, `claude-desktop`). This name becomes the `<provider>` component in image and container names (`<provider>-base`, `<provider>-agent-<project>`).

---

## Step 2 — Write `base.Dockerfile`

`base.Dockerfile` contains the slow, stable install layers: system packages, language runtimes, and the agent source installation. It is tagged `<provider>-base` and contains no project-specific content.

The base image is built once and reused across all projects using this provider. It is only rebuilt when system packages or the agent runtime version changes. `scripts/build_container.sh` skips the base build if the image already exists unless `--no-cache` is passed.

```dockerfile
# providers/<n>/base.Dockerfile
FROM <base-os>

# System packages, runtimes, agent install
RUN ...
```

The base image ends as root. User creation and runtime configuration belong in `provider.Dockerfile`.

**Reference:** `providers/opencode/base.Dockerfile`, `providers/hermes/base.Dockerfile`

---

## Step 3 — Write `provider.Dockerfile`

`provider.Dockerfile` inherits from `<provider>-base` and adds the fast-changing provider layer: shared libs, user creation, runtime config, working directories, healthcheck, and entrypoint. It is tagged `<provider>-agent-<project>`.

```dockerfile
# providers/<n>/provider.Dockerfile
ARG BASE_IMAGE=<provider>-base
FROM ${BASE_IMAGE}

COPY dirs.sh /libs/dirs.sh

RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

ENTRYPOINT ["<agent-command>"]
```

The `ARG BASE_IMAGE` declaration allows `scripts/build_container.sh` to inject the correct base image name at build time via `--build-arg`. The default value is the conventional base image name for the provider.

The agent command is supplied at runtime via `docker compose run --rm agent "<command>"` for standard mode, and via `command:` in `docker-compose.serve.yml` for serve mode.

The agent brief and operator input files are available at `/home/agentuser/workspace/input/` via a read-only bind mount at runtime. `sandbox/` is available at `/home/agentuser/sandbox/` via `--volumes-from`. Neither path needs to be created in the Dockerfile.

**Reference:** `providers/opencode/provider.Dockerfile`, `providers/hermes/provider.Dockerfile`

---

## Step 4 — Write `docker-compose.serve.yml`

The serve overlay is a static Compose file that extends the base configuration for serve mode. It is referenced directly by `scripts/run_agent.sh` using a deterministic path into the repo — it is never copied to `SANDBOX_DIR`.

It must declare the agent `command:` for serve mode. It may also define port bindings, additional services (e.g. a UI container), and provider credentials.

```yaml
services:
  agent:
    command: ["<agent-serve-command>"]
```

If the provider does not support serve mode, create the file anyway with a comment and ensure the agent behaviour on `make serve` is documented.

**Reference:** `providers/opencode/docker-compose.serve.yml`, `providers/hermes/docker-compose.serve.yml`

---

## Step 5 — Write `.env.example`

`.env.example` documents and seeds the provider-specific variables the provider requires. It is appended to the project's `.env` by `agent-sandbox onboard` — once for each provider present in the repo at onboard time.

Format: one variable per line, with a comment explaining the expected value. Variables should be left empty or given a safe default.

```sh
# Provider-specific variables for <n>
SOME_API_KEY=
SOME_PORT=8080
```

Variables that are always derivable from other `.env` values (e.g. image names) should not appear here — they are exported by `scripts/start_agent.sh` at run time.

**Reference:** `providers/opencode/.env.example`, `providers/hermes/.env.example`

---

## Step 6 (optional) — Write `docker-compose.<n>.yml`

If the provider requires mounts, environment variables, or service configuration that applies in **all modes** (not just serve), add a provider overlay file:

```
providers/<n>/docker-compose.<n>.yml
```

`scripts/run_agent.sh` merges this overlay automatically if the file exists, before the mode overlay (dry-run or serve). The merge order is:

```
base → provider overlay → mode overlay
```

Use this for bind mounts that must be present in standard mode too, or for environment variables common to all modes.

**Reference:** `providers/hermes/docker-compose.hermes.yml`

---

## Step 7 (optional) — Write `setup.sh`

If the provider requires host-side setup before containers start — exporting provider-specific vars, pre-creating directories or files for bind mounts — add a setup hook:

```
providers/<n>/setup.sh
```

`scripts/run_agent.sh` sources this file before compose generation if it exists. If `setup.sh` exits non-zero, the session aborts with an error attributing the failure to the provider setup hook.

`setup.sh` has access to all variables exported by `scripts/start_agent.sh` (including `OUTPUT_DIR`, `SANDBOX_DIR`, `REPO_ROOT`) and all functions in `libs/`.

Common uses:
- Export vars that compose overlays reference via `${VAR}` — these must be exported before `compose_generate` runs
- `mkdir -p` host directories that will be bind-mounted — Docker creates missing sources as root-owned directories; pre-creating them ensures correct ownership
- Seed config files on first run

**Reference:** `providers/hermes/setup.sh`

---

## Step 8 — Verify conformance

Run the dry-run sequence against an onboarded project to verify the provider integrates correctly:

```sh
make dry-run PROVIDER=<n>
```

A passing dry-run confirms:
- Both images build without error (`<provider>-base` and `<provider>-agent-<project>`)
- Both containers start and the capability layer initialises `sandbox/`
- The reasoning layer can access `sandbox/` via the shared volume
- Both containers terminate gracefully
- The diff pipeline produces output in `.workspace/changes/`

If `make dry-run` passes, the provider conforms to the harness interface.

Optionally verify serve mode if implemented:

```sh
make serve PROVIDER=<n>
```

Confirm the serve overlay is picked up from the repo (not from `SANDBOX_DIR`) and the provider-specific service starts correctly.

---

## Step 9 — Register the provider

No changes to `scripts/` or `libs/` are required. The harness discovers providers by scanning `providers/*/base.Dockerfile`. Once the required files exist under `providers/<n>/`, the provider is available to all onboarded projects.

Operators onboarding new projects after the provider is added will receive the provider's `.env.example` stubs automatically. Operators with existing projects should run `agent-sandbox onboard --refresh` to append the new provider's stubs to their `.env`.

---

## References

| Document | Purpose |
|---|---|
| [`../architecture/tool_interface.md`](../architecture/tool_interface.md) | Provider interface contract and execution mode definitions |
| [`../architecture/execution_model.md`](../architecture/execution_model.md) | How `start_agent.sh` calls `run_agent.sh`; compose generation internals |
| [`libs/compose.sh`](../../libs/compose.sh) | Helper functions available to `setup.sh` and provider scripts |
