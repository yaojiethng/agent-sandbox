# Provider Onboarding Guide

A provider is a directory under [`src/reasoning/providers/`](../../src/reasoning/providers/) holding the two Dockerfiles and the serve overlay for one reasoning layer agent. This guide is a checklist of what to create. The contract it implements is [`../architecture/tool_interface.md` -- Provider Interface](../architecture/tool_interface.md#provider-interface).

Read a shipped provider before writing one. Each file below is a working example of the shape it names.

| Provider | Use as the reference for |
|---|---|
| [`pi`](../../src/reasoning/providers/pi/) | every optional file: `setup.sh`, a provider compose overlay, `config/` |
| [`opencode`](../../src/reasoning/providers/opencode/) | the minimum: two Dockerfiles and the serve overlay |
| [`hermes`](../../src/reasoning/providers/hermes/) | a multi-stage build, and a provider with no agent compose overlay |

---

## Step 1 -- Create the directory

```sh
mkdir -p src/reasoning/providers/<n>
```

Short lowercase with hyphens. The name becomes the image and container prefix (`<n>-base`, `<n>-agent-<project>`) via [`src/build/image.sh`](../../src/build/image.sh).

## Step 2 -- Write `base.dockerfile`

The agent install and nothing else. The runtimes come from the shared base [`src/reasoning/base.dockerfile`](../../src/reasoning/base.dockerfile) (image `agent-base`), which owns Node, Python, uv, the shared CLI tools, and the repo lint gates. [`tests/test_shared_base_contract.sh`](../../tests/test_shared_base_contract.sh) fails the build if a provider base installs a runtime or a linter.

```dockerfile
ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}
RUN ...
```

Ends as root. User creation and runtime configuration belong in `provider.dockerfile`. A multi-stage build starts the final stage from `agent-base` too, so the runtime keeps the full set while the build tools stay in the builder.

## Step 3 -- Write `provider.dockerfile`

Shared libs, user creation, runtime config, workspace directories, healthcheck, entrypoint. Copy the shape from [`pi/provider.dockerfile`](../../src/reasoning/providers/pi/provider.dockerfile) or [`opencode/provider.dockerfile`](../../src/reasoning/providers/opencode/provider.dockerfile).

Two things are not yours to write:

- The harness files. `src/libs/`, `src/reasoning/entrypoint.sh`, and `src/reasoning/agent/` are copied by repo-relative COPY to the paths the entrypoint and the agents expect. Copy the paths verbatim; a provider that invents a path breaks every session.
- The user creation. The shipped providers thread `HOST_UID` and `HOST_GID` build args, which is what keeps bind mounts writable on macOS. A fixed UID is the failure mode that threading exists to prevent.

### Standard invocation interface

`ENTRYPOINT` is the harness wrapper only, identical across providers:

```dockerfile
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh"]
CMD ["<agent-command>"]
```

`command:` in a compose overlay replaces the invocation, which is how serve mode and the dry-run probe select what runs. See [`../architecture/tool_interface.md`](../architecture/tool_interface.md#provider-interface) and the comment in [`opencode/provider.dockerfile`](../../src/reasoning/providers/opencode/provider.dockerfile).

## Step 4 -- Write `docker-compose.serve.yml`

Required even when the provider has no serve mode, in which case the file carries a comment saying so. It must declare the serve `command:`.

```yaml
services:
  agent:
    command: ["<agent-command>", "<serve-args...>"]
```

Reference: [`pi/docker-compose.serve.yml`](../../src/reasoning/providers/pi/docker-compose.serve.yml).

## Step 5 (optional) -- Environment variables

Compose passes only what a compose file declares, so a variable the agent needs must appear in a compose `environment:` block. For values that apply in every mode, write `docker-compose.<n>.yml`; [`scripts/run_agent.sh`](../../scripts/run_agent.sh) merges it before the mode overlay. Reference: [`pi/docker-compose.pi.yml`](../../src/reasoning/providers/pi/docker-compose.pi.yml).

## Step 6 (optional) -- `config/`

Files seeded into `AGENT_HOME` at container start, never overwriting what is already there. Name the environment stub `env.stub`; [`scripts/onboard.sh`](../../scripts/onboard.sh) renames it to `.env` on the host, which keeps a real `.env` out of the repository.

```text
src/reasoning/providers/<n>/config/
├── AGENTS.md    ← provider-layer agent context, seeded as AGENT_HOME/AGENTS.md
└── env.stub     ← seeded as AGENT_HOME/.env
```

Copy the directory into the image and let the entrypoint do the seeding. The provider-layer `AGENTS.md` starts from [`AGENTS.template.md`](../../src/reasoning/providers/AGENTS.template.md) and covers only the container-local environment; the two-layer model is in [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md#agent-context-model). Reference: [`pi/config/`](../../src/reasoning/providers/pi/config/), [`hermes/config/`](../../src/reasoning/providers/hermes/config/).

## Step 7 (optional) -- `setup.sh`

Sourced by [`scripts/run_agent.sh`](../../scripts/run_agent.sh) before compose generation. A non-zero exit aborts the session with the failure attributed to the provider. It can export vars the overlays interpolate and can pre-create the host config directory. Functions from [`src/build/compose.sh`](../../src/build/compose.sh) and [`src/libs/`](../../src/libs/) are in scope. Reference: [`pi/setup.sh`](../../src/reasoning/providers/pi/setup.sh).

## Step 8 -- Verify

```sh
make dry-run PROVIDER=<n>
```

A pass confirms both images build, both containers start, the capability layer initialises `sandbox/`, the reasoning layer reaches it through the shared volume, and the diff pipeline produces output. Then `make serve PROVIDER=<n>` if the provider serves.

Providers hold no registry. The agent chooses a provider by name at run time, and the provider is available to every onboarded project once its files exist. A project onboarded earlier needs `agent-sandbox onboard --refresh` to pick up the new provider's config.

---

## References

| Document | Purpose |
|---|---|
| [`../architecture/tool_interface.md`](../architecture/tool_interface.md) | the provider interface contract |
| [`../architecture/execution_model.md`](../architecture/execution_model.md) | how the harness calls provider scripts |
| [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md) | two-layer agent context model |
| [`scripts/build.sh`](../../scripts/build.sh) | the three-tier build a provider base sits in |
