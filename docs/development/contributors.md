# Contributor Guidelines -- agent-sandbox

Guidelines for contributing safely and consistently to the agent-sandbox project. All contributors -- human and agent -- must follow these procedures to maintain security, integrity, and reproducibility.

Agents: read [`AGENTS.md`](../../AGENTS.md) for the working protocol specific to your interface. This document covers rules that apply to all contributors regardless of type.

## General Principles

- All contributions must respect container isolation, staging, and output validation procedures.
- Agents are **untrusted** -- outputs must always be staged and validated before merging.
- Link to existing documents rather than duplicating guidance.

## Agent Workflow Rules

- The agent runtime is untrusted. Agents operate inside containers; no direct host access.
- All outputs are proposals. The operator reviews, approves, and commits all changes.
- Multi-agent coordination (parent/child dispatch) is planned in `roadmap_future.md` M4. The `task-queue` prompt is its sequencing primitive.
- Output naming conventions and metadata requirements are defined per milestone as they are implemented.

For the workflow expression model, policy map, and authority hierarchy between policy documents, skill files, and prompt templates, see [`docs/reference/agent_workflow.md`](../reference/agent_workflow.md).

## Security and Secrets

- Secrets must reside in dedicated `.env` files inside `SANDBOX_DIR`. Never committed to the repo.
- Agents receive secrets via environment variable injection at container runtime -- never preloaded in the workspace or baked into images.
- Network outputs are untrusted and must be validated before use.

See [`docs/development/security.md`](../development/security.md) and [`docs/development/standard_operating_procedures.md`](../development/standard_operating_procedures.md) -- Secrets Handling.

## Workspace and Repository Management

- Protect key branches with branch protection rules.
- All merges follow PR review and CI/CD validation.
- Manual interventions should be minimal and logged.
- Workspace integrity must be maintained -- accidental overwrites are prohibited.

See [`docs/development/standard_operating_procedures.md`](../development/standard_operating_procedures.md) -- Human / Operational Protocols.

## Container and Dependency Guidelines

- Use only verified and minimal dependencies.
- Reproducible container builds are required.
- Containers must run unprivileged with minimal capabilities.
- Do not mount sensitive host directories.

See [`docs/development/standard_operating_procedures.md`](../development/standard_operating_procedures.md) -- Container Build & Deployment.

## Documentation and Roadmap

Before making any documentation or roadmap change, read the relevant policy:

- [`docs/policies/documentation_policy.md`](../policies/documentation_policy.md) -- document structure, folder ownership, enforcement rules
- `.agents/skills/task-list/SKILL.md` -- roadmap update sequence and cleanup rules
- [`docs/policies/iteration_policy.md`](../policies/iteration_policy.md) -- iteration workflow, milestone planning, story and investigation conventions

## References

| Document | Purpose |
|---|---|
| [`readme.md`](../../readme.md) | System overview and invariants |
| [`docs/development/security.md`](../development/security.md) | Security model and trust boundaries |
| [`docs/development/threat_model_stride.md`](threat_model_stride.md) | STRIDE threat model |
| [`docs/development/standard_operating_procedures.md`](../development/standard_operating_procedures.md) | Operational SOPs |
| [`docs/policies/iteration_policy.md`](../policies/iteration_policy.md) | Iteration workflow and milestone planning |
| `.agents/skills/task-list/SKILL.md` | Task-list convention |
