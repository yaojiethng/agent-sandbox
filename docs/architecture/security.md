# Security Model

## Overview

This document summarizes the threat entities, impacted assets, STRIDE categorization, and mitigation strategies for the OpenCode containerized coding agent system.

It defines trust boundaries, threat assumptions, and security invariants.

---

## Scope

- Local, single-user environment
- Agent Runtimes may read, generate, and execute code inside containers
- Isolation is enforced via Docker, mount permissions, and OS primitives
- Host repository integrity must be protected from unauthorized direct container mutation

This document defines the security properties of that model.

---

## Trust Boundaries and Mount Models

The system includes the following explicit trust boundaries, which hold in every configuration:

1. Host OS ↔ WSL
2. WSL ↔ Docker daemon
3. Docker daemon ↔ Container
4. Container ↔ Mounted directories
5. Agent runtime ↔ Project files within the container

**The agent runtime is explicitly untrusted** in all configurations. The container runs system dependencies (apt packages), the agent runtime (e.g. OpenCode), and project dependencies — none of which are fully auditable.

### Principle

The sandbox adds no security beyond what the host provides — it only restricts what the host shares. The default share is nothing. Every mount is an explicit grant, and each grant carries its required controls. The harness provides the container boundary; the user provides what `.git` backs the sandbox. The harness does not mediate, protect, or audit git operations. See [Design — Mount Model](../../devlog/discussions/20260730-design-settled-mount_model.md).

### Mount modes

| Mode | `.snapshot/` | `.git` | Consequence |
|---|---|---|---|
| **Copy** (current default, M2.6.5) | Copied into container storage at session start; frozen view | Reinitialized — fresh `git init`, no link to host repo | None — baseline posture |
| **Mount** (not yet implemented, M2.6.6) | Bind-mounted live from host | User-provided — whatever `.git` the user places in the mounted directory (fresh baseline, clone, snapshot). Harness does not mediate git operations. | Live view: mid-session host changes (incl. accidentally introduced secrets) visible without review; user-error surface; git risk is user-owned |
| *Raw project dir* (not offered) | Operator's own checkout | Operator's own `.git` | — see [Non-goals](#non-goals) |

Worktree backing (agent commits landing in the host object store via `git worktree add`) is out of scope — see [ADR — Worktree Backing Rejected](../../docs/adr/20260730-adr-settled-worktree_rejection.md) and the [full investigation](../../devlog/discussions/20260730-study-settled-worktree_rejection.md).

**Invariants (all modes):**

- `PROJECT_ROOT`'s working tree is never mounted into any container.
- The working tree contains tracked files only — gitignore controls what enters. Sensitive files must not exist in `PROJECT_ROOT` at all if there is any risk of unintentional tracking.
- `.bootstrap/` mounted read-only (snapshot, agent brief); `.workspace/` mounted read-write (sole output channel).

**Assumptions:**

- *Mount containment* — the agent cannot escape the mount boundary to reach the backing filesystem. Container escapes are outside the current threat model, but the assumption's strength erodes over time.

---

## Security Invariants

The following invariants hold in every configuration. Per-mode mount shapes are defined in [Mount modes](#mount-modes).

1. `PROJECT_ROOT`'s working tree must not be mounted into any container.
2. The container must not access host filesystem paths outside `.bootstrap/` and `.workspace/`.
3. The container must not have access to the Docker socket.
4. Repository mutation must occur only on the host after human review.
5. Agent-produced changes must be staged as `staged.diff` before application.
6. Gitignored files (including secrets) must never enter the agent's working tree.

Validation procedures for these invariants are defined in operational documentation.

**Mount delivery (not yet implemented)** revises invariant 2 and adds invariant 7:

> 2. The container must not access host filesystem paths outside `.bootstrap/`, `.workspace/`, and `SANDBOX_DIR/.snapshot/`.
>
> 7. `SANDBOX_DIR/.snapshot/` must not be mounted into the reasoning layer. Only the capability layer accesses `.snapshot/` directly.

---

## Execution Model Assumptions

- Docker provides namespace and filesystem isolation.
- Containers and volumes persist across restarts via `docker compose stop` (not `down`) and a named Docker volume (`sandbox-data`). With mount delivery (not yet implemented), the agent's working tree in `.snapshot/` additionally survives container restarts via the host bind mount.
- `.workspace/` persists agent outputs across runs via host bind mounts. The sandbox's git state persists via the named volume. With mount delivery, `.snapshot/` additionally persists (it is a host bind mount rather than a volume).
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
- Offer the operator's own checkout as the agent's working tree (raw project dir mount)

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
