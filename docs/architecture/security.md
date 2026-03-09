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
3. Docker daemon ↔ Container
4. Container ↔ Mounted directories (`.bootstrap/`, `.workspace/`)
5. Agent runtime ↔ Project files within the container

Within the container:

- `.bootstrap/` is mounted read-only — contains the pre-built project snapshot and agent brief
- `.workspace/` is mounted read-write — the sole output channel from the container to the host
- `PROJECT_ROOT` is not mounted at container runtime
- The agent works exclusively in `sandbox/`, a container-local copy of `.bootstrap/snapshot/` made at startup

**The agent runtime is explicitly untrusted.** The container runs system dependencies (apt packages), the agent runtime (e.g. OpenCode), and project dependencies — none of which are fully auditable. `PROJECT_ROOT` is not mounted into the container, so the agent runtime cannot read host repository files directly. The agent's view of the project is limited to what was enumerated by `git ls-files` on the host and copied into `.bootstrap/snapshot/` before the container started.

Gitignore controls what enters the snapshot. Sensitive files gitignored on the host are excluded from the snapshot and therefore never visible to the agent runtime. Sensitive files must not exist in `PROJECT_ROOT` at all if there is any risk of them being unintentionally tracked. See [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling) for operational guidance.

---

## Security Invariants

The following invariants must hold:

- `PROJECT_ROOT` must not be mounted into the container at runtime.
- The container must not access host filesystem paths outside `.bootstrap/` and `.workspace/`.
- The container must not have access to the Docker socket.
- Repository mutation must occur only on the host after human review.
- Agent-produced changes must be staged as `patch.diff` before application.
- Gitignored files (including secrets) must never be copied into `.bootstrap/snapshot/` or `sandbox/`.

Validation procedures for these invariants are defined in operational documentation.

---

## Execution Model Assumptions

- Docker provides namespace and filesystem isolation.
- Containers are ephemeral.
- Only `.workspace/` persists agent outputs across runs.
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
