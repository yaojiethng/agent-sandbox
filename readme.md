---
Architecture Status: Implemented
Milestone: M1.5 — Single Container Agent
Last Verified: 2026-03
---

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

## Key Concepts

Harness is built around a small set of architectural invariants.

### Execution Model

- Agents execute inside isolated containers.
- Each task is executed by a single agent instance.
- Agents may spawn child agents for sub-tasks (maximum depth: 2).

### Safety Model

- Code execution occurs in **Safe** or **Unsafe** modes.
- Safe mode enforces strict filesystem and execution isolation.
- Unsafe mode allows broader execution for trusted environments.

### Change Control

- Agents do not directly modify the repository.
- All agent output is staged as a **diff**.
- Humans review and approve diffs before merging.

### Reproducibility

- Execution occurs inside containerized environments.
- Containers ensure deterministic tooling and dependency environments.

## Documentation Guide

| Topic | Document |
|------|---------|
| Security guarantees and threat model | [security.md](docs/architecture/security.md) |
| Setup and environment configuration | [quickstart.md](docs/development/quickstart.md) |
| Contribution workflow | [contributors.md](contributors.md) |
| Past and future development milestones | [roadmap.md](docs/development/roadmap.md) |

### Documentation Policy

Architecture documents describe the system as it currently exists.
Future design work belongs in [roadmap.md](docs/development/roadmap.md).
Do not place TODOs or speculative features in architecture docs.

## Conceptual Separation

This repository separates concerns into three categories:

- **Workflow** → What currently happens  
- **Security** → What is guaranteed  
- **Roadmap** → What may happen later

Future design work and planned features are tracked in the roadmap rather than architecture documentation.
