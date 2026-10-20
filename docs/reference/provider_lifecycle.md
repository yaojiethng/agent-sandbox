---
reader: [agent]
---

# Provider Lifecycle

This document describes the full arc of a reasoning layer session: how provider config enters the container, how the agent works, and what persists between runs.

The capability layer lifecycle -- snapshot, diff pipeline -- is in [`sandbox_lifecycle.md`](sandbox_lifecycle.md). How the two layers are wired together -- mount shape, compose generation, start/stop sequencing -- is in [`execution_model.md`](execution_model.md).

## Overview

A provider session has three phases:

1. **Provisioning** -- `provider-entrypoint.sh` copies the provider config baked into the image into `AGENT_HOME` before the agent command runs.
2. **Work** -- the agent operates, reading input channels and writing to `AGENT_HOME` and `workspace/output/`.
3. **Persistence** -- the subdirectories the provider overlay mounts from the host survive the session. Nothing is copied out.

The transport splits in two, and the split is the design:

- **Config files** (`settings.json`, `auth.json`, `models.json`, `AGENTS.md`) come from the image template at `/opt/workflow/agent/config/` on every start. The image owns them, so a session's write to one lasts for that session.
- **State** (`prompts/`, `sessions/`, `skills/`) lives on the host under `$SANDBOX_DIR/.<provider>/agent/` and is mounted read-write over the provisioned tree.
- **Model recommendations** (`model-recommendations.md`) are operator-owned. They live on the host at `$SANDBOX_DIR/.<provider>/model-recommendations.md`, are never committed, and are mounted read-write as a single file. The `setup-model-recommendations` skill populates them.

An agent cannot tell the two apart while it works. The difference appears at the next start: the config files come back from the image, and the mounted subdirectories come back from the host.

### Why the config files are seeded rather than mounted

A provider config directory cannot be mounted whole, and a single-file mount fails in two ways on a host filesystem: an agent that writes a binary or moves a file from `/tmp` trips a cross-device error on Windows-mounted paths, and an agent that replaces a file with `mv` breaks a file bind mount. So the image bakes the config files, the entrypoint seeds them, and the overlay mounts only the directories that carry state. The model recommendations file is the one deliberate exception: it is a single-file mount because it is operator-owned and must not live in the image, and every writer replaces its content in place instead of moving over it.

## Phase 1 -- Provisioning

`src/reasoning/entrypoint.sh` runs before the agent command. When the image carries the config template at `/opt/workflow/agent/config/`, the script copies it into `AGENT_HOME` with `cp -RT --no-preserve=all`. The copy runs at every start and overwrites, so the image's config files always win.

The provider overlay mounts the persistent subdirectories, and Docker places those mounts before the entrypoint runs. The copy therefore writes into the mounted tree: a template file lands beside the host's files, and the host's content is what the agent finds afterward.

`agent-sandbox onboard` seeds the host side -- the config template into `$SANDBOX_DIR/.<provider>/`, the mounted subdirectories as empty directories, and a slug-free skeleton at `$SANDBOX_DIR/.<provider>/model-recommendations.md` -- so the overlay has a source on the first run. See [Onboarding](#onboarding).

When the image carries no config template, provisioning is a no-op and `AGENT_HOME` starts empty apart from what the mounts carry. The hermes and opencode images are in that state.

## Phase 2 -- Work

The agent works inside `AGENT_HOME` and has access to two read-only input channels:

**`workspace/input/`** -- the dynamic input channel. Files placed in `$SANDBOX_DIR/.workspace/input/` by the operator before the run are mounted read-only into the reasoning layer. The channel is for operator-supplied files (task specs, reference documents); it is not used for agent orientation -- the static context brief is `AGENTS.md` below.

**`AGENTS.md`** -- the static agent context brief. Baked into the reasoning layer image at build time via the provider Dockerfile. Describes the project, conventions, and expected outputs. Written by the operator at onboard time.

Input channel lifecycle:

- Written by operator before the run
- Read by agent during the run
- Operator clears or replaces contents before the next run -- the harness does not clear automatically

**`workspace/output/`** -- the agent's persistent output channel to the host. Text and serialised data only; binaries are prohibited. Accumulates across the session; cleared by the operator between runs if desired.

## Phase 3 -- Persistence

Nothing is copied out. The container ends, its writable layer goes with it, and the next session starts from the same two sources: the image's config template and the host's mounted subdirectories.

The consequence is visible in what a session can lose. A session that edits `settings.json` keeps that edit until the container ends, and the next session starts from the image's copy. A session that writes a skill under `$AGENT_HOME/agent/skills/` keeps it, because the host carries that directory.

## Onboarding

`src/reasoning/providers/<n>/config/` is a template directory committed to the repo. It carries the provider's default config stubs -- not secrets, and not a complete configuration.

Two consumers read it. The image bakes it -- a `COPY` line in the provider's `provider.dockerfile` sends it to `/opt/workflow/agent/config/`, and `src/build/container-interface.json` declares that pair with a `provision` row -- and `provider-entrypoint.sh` seeds `AGENT_HOME` from the baked copy at every start. `agent-sandbox onboard` seeds the same tree into `$SANDBOX_DIR/.<provider>/` on the host, renames `env.stub` to `.env` there, and pre-creates the subdirectories the provider overlay mounts.

The operator fills in secrets in `$SANDBOX_DIR/.<provider>/.env` before the first run. Those values reach the container as environment variables; no secret reaches an image.

## Config Flow and Fragility Notes

The provider config reaches a session from two sources:

```text
   Image template      ──COPY──> /opt/workflow/agent/config/ ──seed──> AGENT_HOME
   (src/reasoning/providers/<n>/config/)                                        │
                                                                  ├──> the agent reads it
                                                                  │
   Host state          ──bind mount──> AGENT_HOME/agent/{prompts,sessions,skills}
   ($SANDBOX_DIR/.<n>/agent/)                                     │
                                                                  └──> survives the session
```

### Ownership split: settings.json

`settings.json` is a config file, so the image owns it. The harness seeds the key that points at the harness's own payload (`packages`, naming `/opt/workflow/agent` and the module root inside it), pi reads and rewrites the file during the session, and the next session starts from the image's copy. A key pi drops lasts only for that session.

### What the mounted subdirectories carry

`prompts/`, `sessions/` and `skills/` are the provider-layer content the operator and the agent add: prompt files the provider loads by discovery, session history, and skills. They are mounted read-write, so they persist, and nothing in the harness copies them.

### Fragility summary

| Issue | Mechanism | Impact |
|---|---|---|
| **Session-local config edits** | config files are seeded at every start and not mounted | a `settings.json` or `AGENTS.md` edit made in one session does not reach the next |
| **Empty `AGENT_HOME` with no baked template** | the image carries no `config/` directory, so provisioning is a no-op | the provider starts on its own defaults; hermes and opencode are shaped this way by decision, and pi carries a template |
| **Onboard template is a snapshot** | `src/reasoning/providers/<n>/config/settings.json` is committed at a point in time; pi versions evolve independently | default values drift between the template and the runtime pi version |
| **Recommendations file uninitialized** | the skeleton carries empty role lines | a dispatch falls back to the pi startup default until `setup-model-recommendations` writes values |

### How the three-layer skills/prompts model interacts with this split

Sandbox-layer skills and prompts (under `agent/skills/` and `agent/prompts/` in the repo) are loaded through a different path than provider-layer or user-layer content:

- **Sandbox layer** -- image-baked at `/opt/workflow/agent/skills|prompts`. Loaded through the `"packages"` key in `settings.json`, whose entries name `/opt/workflow/agent` and the module root beside it, each contributing its `prompts/` and `skills/` subdirectories as roots; a key pi does not preserve costs that layer for the rest of the session. A workflow module's payload is image-baked at `/opt/workflow/agent/modules/<module>/skills|prompts` and reached through the same key. The next session starts from the image's `settings.json`, which carries it again.
- **Provider layer** -- the provider's own content under `$AGENT_HOME/agent/prompts/`, seeded from the image template and mounted from the host. Loaded by pi's discovery from that directory.
- **User layer** -- files the operator places in `$AGENT_HOME/agent/skills|prompts/`, which the mounts carry. Loaded by pi's discovery from the same directories.

The three-layer model is defined in [`../reference/agent_workflow.md`](../reference/agent_workflow.md#skills-and-prompts-layer-model).

## References

| Topic | Document |
|---|---|
| Capability layer lifecycle | [sandbox_lifecycle.md](sandbox_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Provider interface contract | [tool_interface.md](tool_interface.md#provider-interface) |
| Adding a provider | `docs/development/provider_onboarding_guide.md` |
| Project onboarding | [../reference/project_onboarding_guide.md](../reference/project_onboarding_guide.md) |
