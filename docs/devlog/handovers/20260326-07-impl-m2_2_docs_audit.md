# Agent Handover

**Session date:** 2026-03-26
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Implementation

## Objective

Run the M2.2 docs audit: move decisions with architectural significance from the roadmap M2.2 section into the relevant `docs/architecture/` documents; compact or remove the rest. Consolidate Known Limitations. Confirm no architecture document contradicts the system as built after session 04's changes.

## Scope

Three tasks completed this session:

1. **Decisions audit** — M2.2 Design decisions block read and removed from roadmap. All durable architectural facts promoted to `execution_model.md`, `tool_interface.md`, and the new `provider_onboarding_guide.md`. Transient rationale removed.

2. **Known Limitations consolidation** — duplicates removed, stale build bug entry removed (superseded by M2.2 refactor, confirmed by operator), malformed multi-topic entry split and cleaned.

3. **Conformance pass** — `execution_model.md` and `tool_interface.md` both had M2.2 divergences (compose tmpfile model not reflected) and scope overlap (compose generation and capability layer contract implementation detail in `tool_interface.md`). Both fixed. Scope split clarified. `provider_onboarding_guide.md` created to fill the gap neither document addressed.

## Acceptance criteria

Carried from prior session (04):
- [x] `make stop` finds and stops containers by correct compose project label
- [x] `make serve PROVIDER=opencode` starts cleanly — compose file generated as tmpfile, no files written to `SANDBOX_DIR`
- [x] `make serve PROVIDER=hermes` starts cleanly
- [x] `make dry-run PROVIDER=opencode` passes
- [x] `make dry-run PROVIDER=hermes` passes
- [x] `agent-sandbox onboard` on a fresh directory does not produce `docker-compose.yml` or `Dockerfile.sandbox` in `SANDBOX_DIR`
- [x] Architecture documents in scope describe the system as built
- [x] `make build PROVIDER=hermes` builds `hermes-agent-<project>` image
- [x] `make build` builds sandbox + all providers
- [ ] A second provider can be added with no changes to `scripts/` or `libs/` — confirmed structurally; proven empirically when a third provider is added
- [ ] Claude Desktop provider integration complete
- [ ] Pi provider integration complete
- [ ] Open WebUI ↔ Hermes API connection confirmed in serve mode

Added this session:
- [x] Roadmap M2.2 Design decisions block removed — all durable facts moved to `docs/architecture/`
- [x] Known Limitations consolidated — duplicates removed, superseded entries removed
- [x] `execution_model.md` and `tool_interface.md` conform to the system as built after session 04

## Hot files

| File | Why in scope |
|---|---|
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Reduced to index document; mechanism detail delegated to new documents |
| [`docs/architecture/sandbox_lifecycle.md`](docs/architecture/sandbox_lifecycle.md) | New — snapshot pipeline, git baseline, diff pipeline, input channels, apply workflow |
| [`docs/architecture/container_model.md`](docs/architecture/container_model.md) | New — compose generation, mount rationale, container lifecycle, entrypoint sequences |
| [`docs/concepts/two_layer_model.md`](docs/concepts/two_layer_model.md) | Status updated; Architecture Documents table updated to reflect new document set |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | Scope fix — Docker Compose Generation removed; Capability Layer Contract trimmed; onboarding note fixed |
| [`docs/operations/provider_onboarding_guide.md`](docs/operations/provider_onboarding_guide.md) | New — step-by-step provider onboarding guide |
| [`docs/operations/project_onboarding_guide.md`](docs/operations/project_onboarding_guide.md) | New — operator guide for onboarding a project |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | M2.2 Design decisions block removed; Known Limitations consolidated |
| [`docs/development/project_index.md`](docs/development/project_index.md) | Descriptions updated; `provider_onboarding_guide.md` and `project_onboarding_guide.md` entries added |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Docker Compose Generation section removed from `tool_interface.md` | Internal mechanism, not external contract; onboarded projects have no dependency on how compose files are generated | `execution_model.md`, `tool_interface.md` |
| Capability Layer Contract in `tool_interface.md` trimmed to guarantees only | `--volumes-from` rationale, `VOLUME` detail, anonymous volume lifecycle are implementation detail; mechanics remain in `execution_model.md` | `tool_interface.md` |
| `provider_onboarding_guide.md` named (renamed from `provider_guide.md`) | Naming convention standardised: `_onboarding_guide` suffix for all operator onboarding procedures | `project_index.md` |
| `project_onboarding_guide.md` created in `docs/operations/` | Reworked from skill format; onboarding now automated via CLI; operator needs a concise procedural guide, not an agent skill | `project_onboarding_guide.md` |
| `tool_interface.md` Onboarding section collapsed to link | Full procedure now in `project_onboarding_guide.md`; reference card retains required-files table only | `tool_interface.md` |
| M2.2 Design decisions block removed from roadmap | All durable facts promoted to architecture documents; transient rationale has served its purpose | `roadmap.md` |
| `make build hermes` bug entry removed from Known Limitations | Superseded by M2.2 build target refactor — confirmed resolved by operator | `roadmap.md` |
| `execution_model.md` split into `sandbox_lifecycle.md` and `container_model.md` | Snapshot/diff and compose/mount are two coherent concerns that change independently; `execution_model.md` becomes a short index | `execution_model.md`, `sandbox_lifecycle.md`, `container_model.md` |
| `two_layer_model.md` cleaned up | M2 is implemented, not in progress; Architecture Documents table updated to current document set | `two_layer_model.md` |

## Completed this session

| File | Change |
|---|---|
| `docs/architecture/execution_model.md` | Reduced to index — directory layout, invocation model, staleness detection, mechanism pointers |
| `docs/architecture/sandbox_lifecycle.md` | New — snapshot pipeline (both stages), git baseline, diff pipeline, autosave, input channels, apply workflow; fork-and-join framing |
| `docs/architecture/container_model.md` | New — compose generation (tmpfile model, baked vs ${VAR}, mode composition, rationale), mount shape rationale, container lifecycle, entrypoint sequences |
| `docs/concepts/two_layer_model.md` | Status line updated (M2 implemented, not in progress); context block updated; Architecture Documents table replaced with current document set |
| `docs/architecture/tool_interface.md` | Docker Compose Generation section removed; Capability Layer Contract trimmed to guarantees only; onboarding note contradiction fixed; references updated |
| `docs/operations/provider_onboarding_guide.md` | Renamed from `provider_guide.md`; title updated |
| `docs/development/roadmap.md` | M2.2 Design decisions block removed; Known Limitations: stale build bug removed, duplicate multi-service entry removed, malformed entry cleaned |
| `docs/architecture/tool_interface.md` | Stripped to reference card — orientation prose removed; Onboarding section collapsed to link; Capability Layer Dockerfile section removed; Execution Modes and `.env` intro prose removed |
| `docs/operations/project_onboarding_guide.md` | New — reworked from skill; operator-facing; covers prerequisites, onboard command, agents.md authoring, verification checklist |
| `docs/development/project_index.md` | `execution_model.md` description updated; `sandbox_lifecycle.md`, `container_model.md` entries added; `two_layer_model.md` last-touched updated to M2.2 |

## Deferred items

None.

## Next session

M2.2 — Reasoning Layer Modularisation (Open WebUI ↔ Hermes serve mode connection).

Trigger B has not run. Three acceptance criteria remain open; Claude Desktop and Pi deferred beyond next session.

Next session focus — Open WebUI ↔ Hermes:
- Hermes requires provider credentials in `HERMES_HOME/.hermes/.env` inside the container. `HERMES_HOME` is ephemeral. Fix: document variables in `providers/hermes/.env.example`; inject via serve overlay into agent service environment.
- Investigate whether Hermes accepts a static config file for provider/model configuration before implementing — if yes, pre-prepare and mount/copy via overlay so operator does not need to configure the model in the UI on each serve start.

Watch-out items:
1. Delete `libs/_templates/docker-compose.yml.template` and `libs/_templates/docker-compose.dry-run.yml.template` from disk — superseded.
2. Patch existing sandbox `Makefile` `stop` target to add `--name=$(PROJECT_NAME)`, or run `agent-sandbox onboard --refresh`.
