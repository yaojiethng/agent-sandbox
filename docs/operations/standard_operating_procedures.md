# Agent Orchestration SOPs

## Overview

This document defines Standard Operating Procedures (SOPs) for operating the agent-sandbox system. These procedures cover mitigations that cannot be fully enforced via Dockerfile or code and ensure workflow compliance with the threat model defined in [`architecture/threat_model_stride.md`](../architecture/threat_model_stride.md).

---

## STRIDE Mitigation Index

Maps each threat category to its primary SOP mitigations. Impact ratings use STRIDE initials: S T R I D E.

| Threat | D | I | T | R | E | S | Primary SOPs |
|---|---|---|---|---|---|---|---|
| [1. Resource Exhaustion](#1-resource-exhaustion) | High | Low | Med | Med | Low | Low | [API Control](#4-api--billable-resource-control), [Output Handling](#1-child-agent-output-handling), [Container Build](#6-container-build--deployment) |
| [2. Orchestration / Agent Runtime Compromise](#2-orchestration--agent-runtime-compromise) | High | High | High | Med | High | Med | [Output Handling](#1-child-agent-output-handling), [Secrets Handling](#2-secrets-handling), [Container Build](#6-container-build--deployment), [Agent Lifecycle](#7-agent-lifecycle-compliance) |
| [3. Container Misconfiguration / Image Compromise](#3-container-misconfiguration--image-compromise) | Med/High | High | High | Med | High | Low/Med | [Container Build](#6-container-build--deployment), [Agent Lifecycle](#7-agent-lifecycle-compliance) |
| [4. External Network Threats](#4-external-network-threats) | Med | High | High | Med | Low/Med | Med | [Network Access Rules](#3-network-access-rules), [Output Handling](#1-child-agent-output-handling), [Secrets Handling](#2-secrets-handling) |
| [5. Package / Dependency Compromise](#5-package--dependency-compromise) | Med/High | High | High | Med | High | Med | [Container Build](#6-container-build--deployment), [Secrets Handling](#2-secrets-handling), [Agent Lifecycle](#7-agent-lifecycle-compliance) |
| [6. Secrets / Sensitive Data Leakage](#6-secrets--sensitive-data-leakage) | Low | High | Med | Med | Med | Med | [Secrets Handling](#2-secrets-handling), [Output Handling](#1-child-agent-output-handling), [Network Access Rules](#3-network-access-rules) |
| [7. Human / Operational Misuse](#7-human--operational-misuse) | Med | Med/High | High | High | Low/Med | Low/Med | [Human Protocols](#5-human--operational-protocols), [Container Build](#6-container-build--deployment), [Output Handling](#1-child-agent-output-handling), [Agent Lifecycle](#7-agent-lifecycle-compliance) |

---

## 1. Child Agent Output Handling

- All child agent outputs must be staged in a temporary workspace.
- Only **text files** or approved non-executable binaries are allowed.
- Outputs are validated before merging into parent agent workspace.
- Pull-request style review may be applied for critical branches.

---

## 2. Secrets Handling

- Sensitive data must reside in dedicated `.secret` files.
- Agents receive secrets explicitly; no secrets are preloaded in general workspace.
- Secrets must **never** be committed or transmitted over untrusted channels.
- Access to secrets must be audited and logged.

---

## 3. Network Access Rules

- **Safe Mode**: No network access.
- **Unsafe Mode**: Read-only network access; all outputs must be staged and validated.
- Only approved tasks can enable network access.
- Network outputs are always treated as untrusted; do not blindly execute returned code.

---

## 4. API / Billable Resource Control

- Limit the number of API calls or compute resources per agent.
- Monitor and alert if thresholds are exceeded.
- Ensure logs provide attribution to specific agents or tasks to mitigate repudiation risk.
- Agents cannot directly execute billing operations; orchestration enforces all usage policies.

---

## 5. Human / Operational Protocols

- Protect key branches with Git branch protection rules.
- Use CI/CD pipelines to validate merges; automate checks for sensitive data.
- Educate operators on minimal manual intervention and safe container usage.
- Log all manual operations that interact with agents or workspaces.

---

## 6. Container Build & Deployment

- Use reproducible builds and verified base images.
- Scan container images for vulnerabilities before deployment.
- Maintain immutability of deployed images to prevent runtime tampering.
- Use unprivileged containers and drop unnecessary capabilities.
- Do not mount sensitive host directories into containers.

---

## 7. Agent Lifecycle Compliance

- Parent agents spawn at most two layers (parent + child).
- Child agents cannot spawn additional children.
- All outputs from child agents must be staged and validated.
- Agents are retired after completing their assigned task.

---

## Notes

- These SOPs complement technical mitigations in the Dockerfile and orchestration logic.
- Regular review of SOPs is recommended to incorporate workflow changes or threat evolution.
- SOP adherence is critical for reducing residual risk and maintaining secure operations.