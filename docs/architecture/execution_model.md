# Execution Model

This document describes the structure of a single agent run: the directory layout, how the harness is invoked, and where the implementation detail for each mechanism lives.

The conceptual model for the two-layer architecture is in [`../concepts/two_layer_model.md`](../concepts/two_layer_model.md). The external contract — image naming, mount shape guarantees, execution modes — is in [`tool_interface.md`](tool_interface.md).

---

## Directory Layout

The harness operates against two directories: `PROJECT_DIR` (the project git repository) and `SANDBOX_DIR` (the harness workspace). Both are absolute paths supplied via `.env`. Their location relative to each other on the host is not constrained.

```
SANDBOX_DIR/
├── Makefile
├── .env
├── .snapshot/                 ← project snapshot (built at run time by harness)
├── .<provider>/               ← provider config (seeded on first run; persists across sessions)
└── .workspace/                ← harness I/O channels
    ├── input/                 ← operator-placed task briefs and addenda (RO to agent)
    ├── output/                ← agent progress and serialised data (RW, no binaries)
    └── changes/               ← diff output
        └── staged.diff

Capability layer container (CWD: /home/agentuser/)
├── .snapshot/                 ← RO bind mount: project snapshot from host
├── workspace/changes/         ← RW bind mount: diff output
└── sandbox/                   ← RW Docker volume: working content (owned by this container)

Reasoning layer container (CWD: /home/agentuser/)
├── workspace/input/           ← RO bind mount: task briefs, operator addenda
├── workspace/output/          ← RW bind mount: agent progress (no binaries)
├── sandbox/                   ← RW Docker volume: shared from capability layer via --volumes-from
└── .<provider>/               ← provider config dir (populated via copy-in, not mounted)
```

Host path variables are defined in [`tool_interface.md` — `.env` Runtime Variables](tool_interface.md#env-runtime-variables).

---

## Invocation Model

`scripts/start_agent.sh` is invoked by the project-side Makefile via the `agent-sandbox` CLI. It handles host-side pre-flight only: path validation, `.env` loading, git validation, workspace directory setup, snapshot pipeline, and brief resolution. On completion it dispatches to `scripts/run_agent.sh` via `exec`.

`scripts/run_agent.sh` owns the provider lifecycle: sourcing the provider setup hook, assembling and generating the compose file, managing the container lifecycle (start, copy-in, agent attach, copy-out, teardown). It is provider-agnostic — provider-specific behaviour is declared via `providers/<n>/setup.sh`, compose overlays, and copy-in/copy-out hooks.

Container paths are fixed by the harness and not configurable via `.env`. The full mount shape is in [`tool_interface.md` — Mount Shape Guarantees](tool_interface.md#mount-shape-guarantees).

The provider interface is defined in [`tool_interface.md` — Provider Interface](tool_interface.md#provider-interface). The implementation guide is in [`../operations/provider_onboarding_guide.md`](../operations/provider_onboarding_guide.md).

---

## Mechanisms

**Sandbox lifecycle** — how project content enters the sandbox (fork), how provider config is seeded (seed), how the agent works, and how changes are returned to the host (join). Covers the snapshot pipeline (both stages), provider config copy-in/copy-out, git baseline, input channels, diff pipeline, autosave, and apply workflow. See [`sandbox_lifecycle.md`](sandbox_lifecycle.md).

**Container model** — how Docker implements the two-layer architecture. Covers compose generation, mount shape rationale, container lifecycle (start and stop sequences), and entrypoint sequences. See [`container_model.md`](container_model.md).

---

## Staleness Detection

The harness uses two mechanisms to detect potentially out-of-date components.

**Template version check — operator-installed files:** The capability layer Dockerfile is repo-owned (`libs/sandbox.Dockerfile`) and never copied to `SANDBOX_DIR` — this staleness vector is eliminated. The `Makefile` is seeded at onboard time but not version-checked at run time — staleness is a manual operator concern. See `roadmap.md` for a planned versioning approach.

**Docker layer cache — repo-controlled files:** `build_context.sh` assembles a deterministic build context from a fixed set of repo files. Docker hashes each layer's inputs at build time — if any input has changed since the last build, Docker invalidates that layer and all downstream layers. No separate digest comparison is required.

A `agent-sandbox.digest` label is embedded in each image at build time, recording a hash of the build context. It is not read back at run time but is available for future tooling.

---

## References

| Topic | Document |
|---|---|
| Two-layer conceptual model | [../concepts/two_layer_model.md](../concepts/two_layer_model.md) |
| Sandbox lifecycle | [sandbox_lifecycle.md](sandbox_lifecycle.md) |
| Container model | [container_model.md](container_model.md) |
| External contract | [tool_interface.md](tool_interface.md) |
| System invariants and component overview | [system_overview.md](system_overview.md) |
| Operator-facing workflow | [../concepts/agent_workflow.md](../concepts/agent_workflow.md) |
| Security guarantees | [security.md](security.md) |
