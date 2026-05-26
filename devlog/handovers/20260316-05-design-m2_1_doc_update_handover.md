# Agent Handover

**Session date:** 2026-03-16
**Milestone:** M2.1 — General Capability Layer Prototype
**Session type:** Design

## Objective
Update all architecture, conceptual, and operator documentation to reflect the M2.1 two-container design confirmed in the prior session.

## Scope
M2.1 documentation task group: `tool_interface.md` (new), `execution_model.md`, `security.md`, `agent_workflow.md`, `quickstart.md`, `project_index.md`. Write design decisions from session 00 into architecture docs.

## Acceptance criteria
- `tool_interface.md` covers command shapes, naming, Compose generation, `.env` variables, Dockerfile generation, dry-run guarantees, staleness — **accepted**
- `execution_model.md` reflects two-container mount shape, directory layout, entrypoint sequences, `.snapshot/` paths — **accepted**
- `security.md` reflects two-container trust boundaries, per-container mount visibility, `agent-output/` no-binary invariant — **accepted**
- `agent_workflow.md` rescoped to pure conceptual — **accepted**
- `quickstart.md` updated for `SANDBOX_DIR` layout and two-image build — **accepted**
- `project_index.md` entries added for new files — **accepted**

## Hot files

| File | Why in scope |
|---|---|
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | New file |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Two-container lifecycle, mount shape, entrypoints |
| [`docs/architecture/security.md`](docs/architecture/security.md) | Trust boundaries, stale reference correction |
| [`docs/concepts/agent_workflow.md`](docs/concepts/agent_workflow.md) | Rescoped to pure conceptual |
| [`docs/operations/quickstart.md`](docs/operations/quickstart.md) | SANDBOX_DIR layout, operator input channel |
| [`docs/development/project_index.md`](docs/development/project_index.md) | New entries, temperature updates |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| `tool_interface.md` is full architecture document, not stub | External contract is large enough to warrant its own document | `tool_interface.md` |
| `agent_workflow.md` rescoped to pure conceptual | Implementation detail now covered by `execution_model.md`, `tool_interface.md`, `quickstart.md` | `agent_workflow.md` |

## Completed this session

| File | Change |
|---|---|
| `docs/architecture/tool_interface.md` | New — external contract: naming, Compose generation, `.env` variables, Dockerfile generation, dry-run guarantees, staleness |
| `docs/architecture/execution_model.md` | Two-container directory layout, 5-row mount shape table, entrypoint sequences, `.agent-input/` → `.snapshot/`, Docker Compose lifecycle |
| `docs/architecture/security.md` | 7 trust boundaries, per-container mount visibility, stale refs fixed, `agent-output/` no-binary invariant |
| `docs/concepts/agent_workflow.md` | Rescoped to pure conceptual — principles, invariants, write-back rules, two UX flows named |
| `docs/operations/quickstart.md` | SANDBOX_DIR layout, two-image build, operator input channel, stale refs fixed |
| `docs/development/project_index.md` | Added `tool_interface.md`, `quickstart.md` entries; updated temperatures and last-touched |

## Deferred items

None.

## Next session

M2.1 implementation — all design decisions confirmed and recorded in architecture docs. Proceed to code.

**Watch-out items:**
1. `sandbox/` mount path differs between containers: `/home/agentuser/sandbox/` (capability) vs `/home/agentuser/project/sandbox/` (reasoning)
2. `container-entrypoint.sh` elimination must be an explicit decision, not a silent drop
3. Dogfood compose file first, then derive template
