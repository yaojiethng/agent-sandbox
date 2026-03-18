# Security Model

## Overview

This document summarizes the threat entities, impacted assets, STRIDE categorization, and mitigation strategies for the OpenCode containerized coding agent system.

It defines trust boundaries, threat assumptions, and security invariants.

Operational workflow details are defined in [`concepts/agent_workflow.md`](../concepts/agent_workflow.md).

---

## Scope

- Local, single-user environment
- Agent Runtimes may read, generate, and execute code inside containers
- Isolation is enforced via Docker, mount permissions, and OS primitives
- Host repository integrity must be protected from direct container mutation

This document defines the security properties of that model.

---

## Trust Boundaries

The system includes the following explicit trust boundaries:

1. Host OS ↔ WSL
2. WSL ↔ Docker daemon
3. Docker daemon ↔ Capability layer container
4. Docker daemon ↔ Reasoning layer container
5. Capability layer ↔ Reasoning layer (shared Docker volume)
6. Containers ↔ Mounted host directories (`.snapshot/`, `.workspace/`)
7. Agent runtime ↔ Project files within the container

The two containers have different trust levels. The capability layer is harness-controlled — it runs the snapshot pipeline and diff pipeline with no agent code. The reasoning layer is agent-controlled — it runs the agent runtime and is explicitly untrusted.

Within the capability layer container:

- `.snapshot/` is mounted read-only — contains the pre-built project snapshot
- `.workspace/changes/` is mounted read-write — the diff output channel
- `sandbox/` is a shared Docker volume — the working content the agent modifies

Within the reasoning layer container:

- `.workspace/input/` is mounted read-only — operator-placed task briefs and addenda
- `.workspace/output/` is mounted read-write — agent progress and serialised data (no binaries)
- `sandbox/` is the same shared Docker volume — the agent's working copy
- `PROJECT_DIR` is not mounted at container runtime

**The agent runtime is explicitly untrusted.** The reasoning layer container runs system dependencies (apt packages), the agent runtime (e.g. OpenCode), and project dependencies — none of which are fully auditable. `PROJECT_DIR` is not mounted into either container, so the agent runtime cannot read host repository files directly. The agent's view of the project is limited to what was enumerated by `git ls-files` on the host and copied into `.snapshot/` before the containers started.

Gitignore controls what enters the snapshot. Sensitive files gitignored on the host are excluded from the snapshot and therefore never visible to the agent runtime. Sensitive files must not exist in `PROJECT_DIR` at all if there is any risk of them being unintentionally tracked. See [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling) for operational guidance.

---

## Security Invariants

The following invariants must hold:

- `PROJECT_DIR` must not be mounted into either container at runtime.
- The capability layer container must not access host filesystem paths outside `.snapshot/` and `.workspace/changes/`.
- The reasoning layer container must not access host filesystem paths outside `.workspace/input/` and `.workspace/output/`.
- Neither container must have access to the Docker socket.
- Repository mutation must occur only on the host after human review.
- Agent-produced changes must be staged as `staged.diff` before application.
- Gitignored files (including secrets) must never be copied into `.snapshot/` or `sandbox/`.
- `agent-output/` must not contain binary or executable files.

Validation procedures for these invariants are defined in operational documentation.

---

## Execution Model Assumptions

- Docker provides namespace and filesystem isolation.
- Two containers run per session: capability layer (harness-controlled) and reasoning layer (agent-controlled, untrusted).
- Containers are ephemeral.
- Only `.workspace/` subdirectories persist agent and harness outputs across runs.
- Network access may be enabled depending on execution mode.

Network policy details are defined by configuration, not by this document.

---

## Non-goals

This sandbox does not attempt to:

- Defend against kernel or hypervisor exploits
- Provide protection against a compromised Docker daemon
- Provide compliance guarantees
- Protect secrets that are explicitly injected into the container
- Prevent all forms of denial-of-service within resource limits

Residual risk is acknowledged.

---

## Threat Model Table

| Threat Entity | STRIDE | Mitigations (link to SOP) |
|---------------|--------|---------------------------|
| Resource Exhaustion | D: High, R: Medium, T: Medium | [API / Billable Resource Control](../operations/standard_operating_procedures.md#4-api--billable-resource-control), [Child Agent Output Handling](../operations/standard_operating_procedures.md#1-child-agent-output-handling), [Container Build & Deployment](../operations/standard_operating_procedures.md#6-container-build--deployment) |
| Orchestration / Agent Runtime Compromise | T/I/D/E: High | [Child Agent Output Handling](../operations/standard_operating_procedures.md#1-child-agent-output-handling), [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling), [Container Build & Deployment](../operations/standard_operating_procedures.md#6-container-build--deployment), [Agent Lifecycle Compliance](../operations/standard_operating_procedures.md#7-agent-lifecycle-compliance) |
| Container Misconfiguration / Image Compromise | T/E/I: High | [Container Build & Deployment](../operations/standard_operating_procedures.md#6-container-build--deployment), [Agent Lifecycle Compliance](../operations/standard_operating_procedures.md#7-agent-lifecycle-compliance) |
| External Network Threats | T/I: High | [Network Access Rules](../operations/standard_operating_procedures.md#3-network-access-rules), [Child Agent Output Handling](../operations/standard_operating_procedures.md#1-child-agent-output-handling), [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling) |
| Package / Dependency Compromise | T/I/E: High | [Container Build & Deployment](../operations/standard_operating_procedures.md#6-container-build--deployment), [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling), [Agent Lifecycle Compliance](../operations/standard_operating_procedures.md#7-agent-lifecycle-compliance) |
| Secrets / Sensitive Data Leakage | I: High | [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling), [Child Agent Output Handling](../operations/standard_operating_procedures.md#1-child-agent-output-handling), [Network Access Rules](../operations/standard_operating_procedures.md#3-network-access-rules) |
| Human / Operational Misuse | T/R: High | [Human / Operational Protocols](../operations/standard_operating_procedures.md#5-human--operational-protocols), [Container Build & Deployment](../operations/standard_operating_procedures.md#6-container-build--deployment), [Child Agent Output Handling](../operations/standard_operating_procedures.md#1-child-agent-output-handling), [Agent Lifecycle Compliance](../operations/standard_operating_procedures.md#7-agent-lifecycle-compliance) |

---

## Additional Clarifications

- **Resource Exhaustion** includes compute exhaustion and financial impact from billable services.
- **Container / Package compromise** assumes the container image and dependency graph may contain vulnerabilities.
- **Secrets and network responses** are treated as untrusted inputs.
- **Human operational errors** are included as explicit threat entities due to branch protection and review bypass risk.
- STRIDE mappings reflect primary impact categories; absence of a category does not imply zero risk.

---

## Network Exposure Model

Current model:

- No ports are exposed unless explicitly published via Docker.
- When serving a local agent endpoint, ports must be bound to `127.0.0.1`.
- Outbound network access may be enabled to allow AI provider communication.
- No implicit firewalling is provided by this document.

Future hardening steps (e.g., outbound whitelisting, proxy enforcement) are tracked in `roadmap.md`.

---

## References

- Microsoft STRIDE Threat Model: https://docs.microsoft.com/en-us/security/compass/stride
- Docker Security Best Practices: https://docs.docker.com/engine/security/security/
- LLM and AI Security Considerations: https://arxiv.org/abs/2301.11381

## Further Reading

- Linux namespaces
- Linux cgroups
- Container escape research
(Refer to authoritative sources as needed.)
