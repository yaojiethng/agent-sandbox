# OpenCode Contributor Guidelines

Welcome to the OpenCode repository! This document provides guidelines for contributing safely and consistently to the autonomous coding agent system. All contributors must follow operational procedures to maintain security, integrity, and reproducibility.

---

## 1. General Principles

- Contributors are responsible for understanding the workflow and security model of OpenCode.
- All contributions should respect container isolation, staging, and output validation procedures.
- Agents are considered **untrusted**; outputs must always be staged and validated before merging.

---

## 2. Agent Workflow Rules

- **Parent agents** handle orchestration for tasks; maximum 2 layers (parent + child).  
- **Child agents** cannot spawn other agents.  
- All outputs must be **text files** or approved non-executable binaries.  
- Outputs must be staged, validated, and merged according to the SOP.  
- Naming conventions:
  - Parent agent: `parent_<task_id>`  
  - Child agent: `child_<task_id>_<child_id>`  

For full details, see [Agent Lifecycle Compliance](docs/operations/standard_operating_procedures.md#7-agent-lifecycle-compliance).

---

## 3. Security and Secrets

- Secrets must reside in dedicated `.secret` files.
- Agents receive secrets explicitly; they should never be preloaded in the workspace.
- All secret access must be audited.
- Network outputs are untrusted and must be validated before use.

See [Secrets Handling](docs/operations/standard_operating_procedures.md#2-secrets-handling) and [Network Access Rules](docs/operations/standard_operating_procedures.md#3-network-access-rules) for detailed SOPs.

---

## 4. Workspace and Repository Management

- Protect key branches with branch protection rules.
- All merges should follow PR review and CI/CD validation.
- Manual interventions should be minimal and logged.
- Workspace integrity must be maintained; accidental overwrites are prohibited.

See [Child Agent Output Handling](docs/operations/standard_operating_procedures.md#1-child-agent-output-handling) and [Human / Operational Protocols](docs/operations/standard_operating_procedures.md#5-human--operational-protocols) for operational procedures.

---

## 5. Container and Dependency Guidelines

- Use only verified and minimal dependencies.
- Reproducible container builds are required.
- Containers must run unprivileged with minimal capabilities.
- Do not mount sensitive host directories.

Refer to [Container Build & Deployment](docs/operations/standard_operating_procedures.md#6-container-build--deployment) for SOP compliance.

---

## 6. Documentation and Communication

- All contributors must follow the documentation policy before making any changes to documents or architecture.
- All contributors must follow the roadmap policy before updating the roadmap.
- Update documentation when workflow, security, or operational procedures change.
- Link to existing documents rather than duplicating guidance.

See [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) and [`docs/operations/roadmap_policy.md`](docs/operations/roadmap_policy.md).

---

## 7. References

- [Security & Threat Model](docs/architecture/security.md)
- [STRIDE Threat Model](docs/architecture/threat_model_stride.md)
- [Operational SOPs](docs/operations/standard_operating_procedures.md)
- [Documentation Policy](docs/operations/documentation_policy.md)
- [Roadmap Policy](docs/operations/roadmap_policy.md)
- [README / Quickstart](readme.md)
- Branch protection and CI/CD policies (internal)
