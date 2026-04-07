# Provider Lifecycle

This document describes the full arc of a reasoning layer session: how provider config enters the container, how the agent works, and how state is returned to the host.

The capability layer lifecycle — snapshot, diff pipeline — is in [`sandbox_lifecycle.md`](sandbox_lifecycle.md). How the two layers are wired together — mount shape, compose generation, start/stop sequencing — is in [`execution_model.md`](execution_model.md).

---

## Overview

A provider session has three phases:

1. **Copy-in** — provider config is copied from the host into `AGENT_HOME` before the agent command runs.
2. **Work** — the agent operates, reading input channels and writing to `AGENT_HOME` and `workspace/output/`.
3. **Copy-out** — `AGENT_HOME` is copied back to the host on container exit, persisting session state for the next run.

Provider config flows through `$SANDBOX_DIR/.<provider>/` on the host and `/opt/provider-config/` inside the container. These are the same directory via bind mount. The agent never touches this mount directly — `provider-entrypoint.sh` mediates all access.

### provider config cannot be directly mounted

Provider config directories (e.g. `.hermes/`) cannot be bind-mounted as directories because agents may write binaries or perform filesystem operations (cross-device moves from `/tmp`) that fail on Windows-mounted paths. Individual file mounts fail when agents replace files via `mv` rather than in-place writes. The copy-in/copy-out mechanism avoids these issues: the agent has full ownership of its config directory inside the container, and files are synchronised to `SANDBOX_DIR` when the container terminates.

---

## Phase 1 — Copy-in

`libs/provider-entrypoint.sh` runs before the agent command. It copies the contents of `/opt/provider-config/` (bind-mounted from `$SANDBOX_DIR/.<provider>/`) into `AGENT_HOME`.

**First run:** `$SANDBOX_DIR/.<provider>/` contains the onboarding templates populated by `agent-sandbox onboard` (see [Onboarding](#onboarding)). The agent starts from those.

**Subsequent runs:** `$SANDBOX_DIR/.<provider>/` contains the state persisted by the prior session's copy-out. The agent resumes from that state.

If `$SANDBOX_DIR/.<provider>/` is empty or absent, copy-in is a no-op and the agent starts with no config. This is an operator error — the provider config directory must be populated before the first run.

---

## Phase 2 — Work

The agent works inside `AGENT_HOME` and has access to two read-only input channels:

**`workspace/input/`** — the dynamic input channel. Files placed in `$SANDBOX_DIR/.workspace/input/` by the operator before the run are mounted read-only into the reasoning layer. The agent brief (resolved from `AGENT_BRIEF` in `.env`) is placed here by `scripts/start_agent.sh` before the containers start.

**`agents.md`** — the static agent context brief. Baked into the reasoning layer image at build time via the provider Dockerfile. Describes the project, conventions, and expected outputs. Written by the operator at onboard time.

Input channel lifecycle:
- Written by operator before the run
- Read by agent during the run
- Operator clears or replaces contents before the next run — the harness does not clear automatically

**`workspace/output/`** — the agent's persistent output channel to the host. Text and serialised data only; binaries are prohibited. Accumulates across the session; cleared by the operator between runs if desired.

---

## Phase 3 — Copy-out

An EXIT trap in `libs/provider-entrypoint.sh` fires on all exits — normal completion, interrupt, or `docker stop`. It copies the contents of `AGENT_HOME` back to `/opt/provider-config/` (which is `$SANDBOX_DIR/.<provider>/` via bind mount).

If `AGENT_HOME` is empty or absent at exit (e.g. the agent crashed before writing any state), copy-out is a no-op. `$SANDBOX_DIR/.<provider>/` retains its prior state.

---

## Onboarding

`providers/<n>/config/` is a template directory committed to the repo. It contains default config stubs for the provider — not secrets, not complete configuration.

`agent-sandbox onboard` copies `providers/<n>/config/` to `$SANDBOX_DIR/.<provider>/` during project setup. If `env.stub` is present, it is renamed to `.env` at this point — `env.stub` is the committed name used to avoid `.gitignore` matches in the repo; `.env` is what the agent expects.

The operator fills in secrets and provider-specific values in `$SANDBOX_DIR/.<provider>/` before the first run. These files are never baked into provider images.

`providers/<n>/config/` is never copied into the image. `build_context_agent` does not include it in the build context.

---

## References

| Topic | Document |
|---|---|
| Capability layer lifecycle | [sandbox_lifecycle.md](sandbox_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Provider interface contract | [tool_interface.md](tool_interface.md#provider-interface) |
| Adding a provider | [../operations/provider_onboarding_guide.md](../operations/provider_onboarding_guide.md) |
| Project onboarding | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
