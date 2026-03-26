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
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Conformance pass; absorbed compose generation content; M2.2 divergences fixed |
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

## Completed this session

| File | Change |
|---|---|
| `docs/architecture/execution_model.md` | Absorbed Docker Compose Generation; fixed M2.2 divergences (compose files removed from directory tree, duplicate step 3 collapsed, duplicate heading removed); removed duplicate mount table; provider interface section points to `provider_onboarding_guide.md` |
| `docs/architecture/tool_interface.md` | Docker Compose Generation section removed; Capability Layer Contract trimmed to guarantees only; onboarding note contradiction fixed; references updated |
| `docs/operations/provider_onboarding_guide.md` | Renamed from `provider_guide.md`; title updated |
| `docs/development/roadmap.md` | M2.2 Design decisions block removed; Known Limitations: stale build bug removed, duplicate multi-service entry removed, malformed entry cleaned |
| `docs/architecture/tool_interface.md` | Stripped to reference card — orientation prose removed; Onboarding section collapsed to link; Capability Layer Dockerfile section removed; Execution Modes and `.env` intro prose removed |
| `docs/operations/project_onboarding_guide.md` | New — reworked from skill; operator-facing; covers prerequisites, onboard command, agents.md authoring, verification checklist |
| `docs/development/project_index.md` | `execution_model.md` and `tool_interface.md` descriptions updated to M2.2; `provider_onboarding_guide.md` and `project_onboarding_guide.md` entries added |

## Deferred items

None.

## Next session

M2.2 — Reasoning Layer Modularisation (provider integrations: Claude Desktop, Pi, Open WebUI ↔ Hermes).

Trigger B has not run. Three acceptance criteria remain open. Docs audit is complete.

Blocking questions to resolve before implementation:
1. **Claude Desktop** — confirm the integration pattern before writing `run.sh` (e.g. MCP server in capability layer container, Desktop app on host connecting to it).
2. **Open WebUI ↔ Hermes** — is this a serve overlay config change or a missing env variable (see deferred Hermes serve mode model configuration from session 04)?

Watch-out items:
1. Delete `libs/_templates/docker-compose.yml.template` and `libs/_templates/docker-compose.dry-run.yml.template` from disk — superseded.
2. Patch existing sandbox `Makefile` `stop` target to add `--name=$(PROJECT_NAME)`, or run `agent-sandbox onboard --refresh`.
