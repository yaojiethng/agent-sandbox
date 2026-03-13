# Contributor Guidelines — agent-sandbox

Guidelines for contributing safely and consistently to the agent-sandbox project. All contributors — human and agent — must follow these procedures to maintain security, integrity, and reproducibility.

Agents: read [`agent_context_brief.md`](../../agent_context_brief.md) for the working protocol specific to your interface. This document covers rules that apply to all contributors regardless of type.

---

## General Principles

- All contributions must respect container isolation, staging, and output validation procedures.
- Agents are **untrusted** — outputs must always be staged and validated before merging.
- Link to existing documents rather than duplicating guidance.

---

## Agent Workflow Rules

- The agent runtime is untrusted. Agents operate inside containers; no direct host access.
- All outputs are proposals. The operator reviews, approves, and commits all changes.
- Multi-agent orchestration (parent/child dispatch) is a future milestone — not currently active. See `roadmap_future.md` — M4–M6.
- Output naming conventions and metadata requirements are defined per milestone as they are implemented.

For the current single-agent workflow, see [`docs/concepts/agent_workflow.md`](../concepts/agent_workflow.md).

---

## Security and Secrets

- Secrets must reside in dedicated `.env` files inside `SANDBOX_DIR`. Never committed to the repo.
- Agents receive secrets via environment variable injection at container runtime — never preloaded in the workspace or baked into images.
- Network outputs are untrusted and must be validated before use.

See [`docs/architecture/security.md`](../architecture/security.md) and [`docs/operations/standard_operating_procedures.md`](../operations/standard_operating_procedures.md) — Secrets Handling.

---

## Workspace and Repository Management

- Protect key branches with branch protection rules.
- All merges follow PR review and CI/CD validation.
- Manual interventions should be minimal and logged.
- Workspace integrity must be maintained — accidental overwrites are prohibited.

See [`docs/operations/standard_operating_procedures.md`](../operations/standard_operating_procedures.md) — Human / Operational Protocols.

---

## Container and Dependency Guidelines

- Use only verified and minimal dependencies.
- Reproducible container builds are required.
- Containers must run unprivileged with minimal capabilities.
- Do not mount sensitive host directories.

See [`docs/operations/standard_operating_procedures.md`](../operations/standard_operating_procedures.md) — Container Build & Deployment.

---

## Documentation and Roadmap

Before making any documentation or roadmap change, read the relevant policy:

- [`docs/operations/documentation_policy.md`](documentation_policy.md) — document structure, folder ownership, enforcement rules
- [`docs/operations/roadmap_policy.md`](roadmap_policy.md) — roadmap update sequence and cleanup rules
- [`docs/operations/task_policy.md`](task_policy.md) — task working principles, story and investigation conventions

---

## References

| Document | Purpose |
|---|---|
| [`readme.md`](../../readme.md) | System overview and invariants |
| [`docs/architecture/security.md`](../architecture/security.md) | Security model and trust boundaries |
| [`docs/architecture/threat_model_stride.md`](../architecture/threat_model_stride.md) | STRIDE threat model |
| [`docs/operations/standard_operating_procedures.md`](../operations/standard_operating_procedures.md) | Operational SOPs |
| [`docs/operations/task_policy.md`](task_policy.md) | Task policy |
| [`docs/operations/roadmap_policy.md`](roadmap_policy.md) | Roadmap policy |
| [`docs/concepts/task_lifecycle.md`](../concepts/task_lifecycle.md) | Task lifecycle |
