> **Current milestone status:** see the active handover at repo root (most recent `YYYYMMDD-NN-*.md`).

# Autonomous Coding Agent Sandbox

This repository provides a containerized sandbox and orchestration harness
for running autonomous coding agents safely.

The system isolates agents inside containers, stages their changes as diffs,
and requires human review before repository modification.

Currently supported agent provider:
- OpenCode

### System Invariants

The following guarantees define the harness architecture:

- Agents run in containers
- Tasks produce diffs instead of direct commits
- Humans approve repository changes
- Agent nesting depth is limited to two layers
- Child agents cannot spawn additional children

## Key Concepts

Harness is built around a small set of architectural invariants.

### Execution Model

- Agents execute inside isolated containers.
- Each task is executed by a single agent instance.
- Agents may spawn child agents for sub-tasks (maximum depth: 2).

### Safety Model

- Code execution occurs in **Standard** or **Safe** modes.
- Standard mode allows network access for AI provider communication.
- Safe mode enforces no-network execution (reserved, not yet implemented — see M6).

### Change Control

- Agents do not directly modify the repository.
- All agent output is staged as a **diff**.
- Humans review and approve diffs before merging.

### Reproducibility

- Execution occurs inside containerized environments.
- Containers ensure deterministic tooling and dependency environments.

### Architecture Layers

The implementation stack has three layers where lower layers must stabilize before higher layers evolve:

| Layer | Name | Responsibility |
|---|---|---|
| 0 | Infrastructure | Docker runtime, filesystem, container environment |
| 1 | Execution Mechanics | How a single agent runs tasks and generates diffs |
| 2 | Orchestration | Coordination between multiple agents |

Two elements frame the stack without belonging to it: the **Security Model**, which is a design constraint specified before implementation and applied to all layers; and the **Human Workflow**, which is a system invariant — the operator initiates every run and has final authority over all outputs.

See [system_overview.md](docs/architecture/system_overview.md) for the full layer model.

## Documentation Guide

Start here and follow the path in order. Architecture documents describe the system as it currently exists — future work belongs in the roadmap, not in architecture docs.

| Step | Document | Purpose |
|---|---|---|
| 1 | [contributors.md](contributors.md) | Contribution rules, secrets handling, workflow responsibilities |
| 2 | [project_index.md](docs/development/project_index.md) | Full file registry, freeze status, architecture layer assignments |
| 3 | [documentation_policy.md](docs/operations/documentation_policy.md) | Documentation rules and structure (read once) |
| 4 | [iteration_policy.md](docs/operations/iteration_policy.md) | Session workflow and milestone planning process (read once) |
| 5 | [roadmap.md](docs/development/roadmap.md) | Current tasks, open validation items, planned milestones |

For architecture detail, start at [system_overview.md](docs/architecture/system_overview.md).

## Conceptual Separation

This repository separates concerns into three categories:

- **Workflow** → What currently happens
- **Security** → What is guaranteed
- **Roadmap** → What may happen later

Future design work and planned features are tracked in the roadmap rather than architecture documentation.
