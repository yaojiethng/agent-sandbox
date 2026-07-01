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

The system includes the following explicit trust boundaries, which vary by mount model:

1. Host OS ↔ WSL
2. WSL ↔ Docker daemon
3. Docker daemon ↔ Container
4. Container ↔ Mounted directories
5. Agent runtime ↔ Project files within the container

**The agent runtime is explicitly untrusted** in all models. The container runs system dependencies (apt packages), the agent runtime (e.g. OpenCode), and project dependencies — none of which are fully auditable.

See [Mount Models](#mount-models) below for the per-model boundary description.

---

### Tier 1 — Copy + Tar (current default)

```
SANDBOX_DIR/.snapshot/   → copied into anonymous Docker volume at session start
PROJECT_ROOT             → not mounted into any container
PROJECT_DIR/.git         → not mounted into any container
```

**Trust boundaries:**

- `.bootstrap/` is mounted read-only — contains the pre-built project snapshot and agent brief
- `.workspace/` is mounted read-write — the sole output channel from the container to the host
- `PROJECT_ROOT` is not mounted at container runtime
- The agent works exclusively in `sandbox/`, a container-local copy of `.bootstrap/snapshot/` made at startup

The agent's view of the project is limited to what was enumerated by `git ls-files` on the host and copied into `.bootstrap/snapshot/` before the container started. Gitignore controls what enters the snapshot. Sensitive files gitignored on the host are excluded from the snapshot and therefore never visible to the agent runtime. Sensitive files must not exist in `PROJECT_ROOT` at all if there is any risk of them being unintentionally tracked. See [Secrets Handling](../operations/standard_operating_procedures.md#2-secrets-handling) for operational guidance.

---

### Tier 2 — Mount + Tar

```
SANDBOX_DIR/.snapshot/   → mounted read-write into the capability layer
PROJECT_ROOT             → not mounted into any container
PROJECT_DIR/.git         → not mounted into any container
```

**Trust boundaries — same as Tier 1 with one addition:**

- `.bootstrap/` is mounted read-only — unchanged
- `.workspace/` is mounted read-write — unchanged
- `SANDBOX_DIR/.snapshot/` is mounted read-write into the capability layer, replacing the anonymous Docker volume. The agent's working tree lives on a host-mapped filesystem and survives container restarts.
- `PROJECT_ROOT` is not mounted — unchanged
- The agent works in `.snapshot/` (mounted) instead of a copy. No copy step at startup.

Remaining boundaries (Docker socket, no access outside permitted paths) are identical to Tier 1.

---

### Tier 3 — Mount + Worktree

```
SANDBOX_DIR/.snapshot/   → mounted read-write into the capability layer
PROJECT_ROOT             → not mounted (working tree is not mounted)
PROJECT_DIR/.git         → mounted read-only into the capability layer only
                           (not into the reasoning layer)
```

**Trust boundaries — adds two new host access points:**

- `.snapshot/` is mounted read-write — same as Tier 2
- `PROJECT_DIR/.git` is mounted read-only into the **capability layer only**. The reasoning layer does not have access to the git object store. The capability layer manages git operations (staging, committing, branch creation) on behalf of the agent.
- The worktree working directory is the agent's view — tracked files only, same filtering property as the snapshot pipeline but enforced by `git worktree add` rather than by `git ls-files` enumeration.
- `.workspace/` is mounted read-write — unchanged
- `PROJECT_ROOT`'s working tree is not mounted — unchanged

**New trust boundary — Session lifetime ↔ Repository integrity:**

Git objects are written to `PROJECT_DIR`'s object store during the session (commits on the agent's branch). A crash or mid-session failure can leave the repo with orphaned objects or a partially-written agent branch. The git object model is content-addressed and self-checking, which provides partial protection, but the boundary between "session in progress" and "repo is safe to use" collapses.

The four required mitigations for Tier 3 are enumerated in [Security Invariants — Tier 3](#tier-3--mount--worktree).

---

## Security Invariants

Invariants differ by mount model. The user selects the model per session at startup; the corresponding invariant set applies for that session.

---

### Tier 1 — Copy + Tar (current default)

The following invariants must hold:

1. `PROJECT_ROOT` must not be mounted into the container at runtime.
2. The container must not access host filesystem paths outside `.bootstrap/` and `.workspace/`.
3. The container must not have access to the Docker socket.
4. Repository mutation must occur only on the host after human review.
5. Agent-produced changes must be staged as `staged.diff` before application.
6. Gitignored files (including secrets) must never be copied into `.bootstrap/snapshot/` or `sandbox/`.

Validation procedures for these invariants are defined in operational documentation.

---

### Tier 2 — Mount + Tar

Invariants 1, 3, 4, 5, and 6 are **identical** to Tier 1.

Invariant 2 is **revised** to include the `.snapshot/` mount:

> 2. The container must not access host filesystem paths outside `.bootstrap/`, `.workspace/`, and `SANDBOX_DIR/.snapshot/`.

New invariant (implicit in Tier 1, now explicit because `.snapshot/` is a host bind mount):

> 7. `SANDBOX_DIR/.snapshot/` must not be mounted into the reasoning layer. Only the capability layer accesses `.snapshot/` directly.

---

### Tier 3 — Mount + Worktree

Six of the Tier 1 invariants are **replaced or revised**:

| Original (Tier 1) | Tier 3 |
|---|---|
| 1. `PROJECT_ROOT` not mounted | **Revised:** `PROJECT_ROOT`'s **working tree** must not be mounted. `PROJECT_DIR/.git` is mounted read-only into the capability layer only (not the reasoning layer). |
| 2. No paths outside `.bootstrap/` + `.workspace/` | **Revised:** No paths outside `.bootstrap/`, `.workspace/`, `SANDBOX_DIR/.snapshot/`, and `PROJECT_DIR/.git` (capability layer only). |
| 3. No Docker socket | **Unchanged.** |
| 4. Mutation after human review | **Replaced:** Agent-produced commits go directly into `PROJECT_DIR`'s object store during the session. Agent-produced commits must not be **merged** into any protected branch without operator review and an explicit merge action. The agent's branch is not a protected branch. Object creation in the agent's branch is an accepted risk. |
| 5. `staged.diff` before application | **Replaced:** Branch diff (e.g. `main..agent/session`) is the review artefact. The `staged.diff` pipeline is preserved as an optional output channel for compatibility. |
| 6. Gitignored files not in snapshot | **Revised:** Gitignored files must never appear in the worktree checkout. Enforced by `git worktree add` (tracked files only) instead of the snapshot pipeline. |

**New Tier 3–specific invariants:**

> 7. `SANDBOX_DIR/.snapshot/` must not be mounted into the reasoning layer. Only the capability layer accesses `.snapshot/` directly. (Same as Tier 2.)
>
> 8. `.git/config` and `.git/hooks/` must be made read-only within the container before the session starts (`chmod a-w` on the host before container launch). Restored to writable after the session ends.
>
> 9. `--network=none` must be set on the agent container to block `git push`, `git fetch`, and data exfiltration.
>
> 10. Main branch pointers must be write-protected via `chmod a-w .git/packed-refs` (after `git pack-refs --all`).

**Unverifiable precondition:**

The harness cannot verify that `PROJECT_DIR`'s git history contains no committed secrets. The operator must verify this (e.g. via `git secrets --scan-history` or equivalent) before enabling Tier 3 for a given repository. Secrets committed at any point in history are present in the object store and readable if `.git/` is mounted.

---

## Execution Model Assumptions

- Docker provides namespace and filesystem isolation.
- Containers are ephemeral. Under Tier 2 and Tier 3 (mount models), the agent's working tree in `.snapshot/` survives container restarts via the host bind mount.
- Only `.workspace/` persists agent outputs across runs. Under Tier 2 and Tier 3, `.snapshot/` additionally persists (it is a host bind mount rather than an anonymous volume).
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
- Verify that no secrets have been committed to the project's git history (Tier 3 only — operator precondition, not harness-enforceable)

Residual risk is acknowledged. Residual risk for Tier 3 additionally includes: post-mutation review gate (operator must reject the branch rather than decline to apply a diff), and the possibility of orphaned git objects after a session crash.

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
