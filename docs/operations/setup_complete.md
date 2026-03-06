# OpenCode Idealized Complete Setup

This document describes the full, mature setup for the OpenCode autonomous coding agents system, including containerized execution, staging, workflow enforcement, and security practices.

---

## 1. Project Folder Structure

project-alpha/
├── src/             # main source code
├── tests/           # tests
├── data/            # sensitive files, .secret extensions ignored
├── .workspace/      # staged outputs for validation
│   ├── changes/
│   ├── patch.diff
│   └── metadata.json
├── .skills/         # agent-specific skills or templates
├── .config/         # agent configuration (workflow rules, parameters)
├── logs/            # execution logs
└── README.md

---

## 2. Container Setup

- Base Docker image with minimal dependencies (`ubuntu:22.04`, Python, Git, curl)
- Unprivileged user for agent execution
- Resource limits (`--memory`, `--cpus`)
- Read-only mounts for `.skills/` and `.config/`
- Writeable mount only for `.workspace/`
- Safe and unsafe network modes (`--network none` / `--network bridge`)

---

## 3. Agent Context and Seeding

- `.config/workflow.yaml` encodes allowed directories, staging rules, safe/unsafe mode, branch prefix, review requirements
- `.workspace/metadata.json` contains:
  - `agent_id`
  - `task_id`
  - allowed files
  - instructions
  - secrets list
- `.skills/` provides agent templates / capabilities

---

## 4. Return Staging & Branch Workflow

1. Agent writes everything to `.workspace/changes/`
2. Parent agent or human validates outputs
3. `apply_workspace.sh` script applies changes to agent-specific git branch
4. CI/CD or PR validation
5. Merge branch → main
6. Archive logs and workspace snapshot

---

## 5. SOP Enforcement

- Only `.workspace/` is trusted
- Immutable mounts for `.config/` and `.skills/`
- All other output ignored
- Automated scripts enforce workflow compliance and file restrictions
- Logs track agent ID, task ID, and operations

---

## 6. Milestones & Checkpoints

| Milestone | Checkpoint |
|-----------|------------|
| Containerized agent | Can spin up agent container with mounts and resource limits |
| Workspace staging | `.workspace/` exists and agent can write outputs safely |
| Context seeding | `.config/workflow.yaml` and `.workspace/metadata.json` read correctly by agent |
| Git branch workflow | Agent outputs applied to branch after validation |
| Safe vs Unsafe modes | Network restrictions enforceable |
| SOP compliance | Scripts enforce allowed directories, staging, and merge rules |
| Logs & audit | Logs preserved per agent and task |

---

## 7. References

- [CONTRIBUTORS.md](../CONTRIBUTORS.md)
- [SECURITY.md](SECURITY.md)
- [SOPS.md](SOPS.md)