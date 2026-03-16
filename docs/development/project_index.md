# Project Index

Stable registry of all documentation and policy files in agent-sandbox. Records freeze status, architecture layer assignment, and last milestone to touch each file. Use this when re-scoping tasks or checking whether a proposed change crosses an architecture layer boundary.

The session-scoped hot file list lives in the active handover document (`YYYYMMDD_agent_handover.md` at repo root).

---

## Architecture Layers

Layer names and responsibilities are defined in `docs/architecture/system_overview.md`.

| Layer | Name | Status |
|---|---|---|
| 0 | Infrastructure | Frozen at M1 |
| 1 | Execution Mechanics | Frozen at M1.2; changes expected in M1.5 and M2 |
| 2 | Orchestration | Not started |

Security Model and Human Workflow are design constraints and system invariants — they do not map to implementation layers and are not freeze-tracked here.

---

## Document Registry

Temperature reflects the stability of what a document describes — not how carefully it was written.

**🔴 Hot** — changes continuously  
**🟡 Warm** — changes per milestone  
**🟢 Cold** — frozen policy or settled invariants; changes signal design instability

### Root

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `readme.md` | 🟢 Cold | M1 | System invariants and entry point. Should rarely need updating. |
| `contributors.md` | 🟢 Cold | M1 | Contribution rules. Update only when workflow or security model changes. |
| `agent_context_brief.md` | 🟡 Warm | M1.5 | Agent collaboration protocol. Update when working practices evolve. |

### Development (`docs/development/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `doc_status.md` — retired | — | M1.5 | Replaced by handover Hot files section. Delete from repo. |
| `project_index.md` | 🟡 Warm | M1.5 | This file. Updated when files are added, removed, or freeze status changes. |
| `roadmap.md` | 🔴 Hot | M1.5 | Active milestone tasks and milestone summary table. |
| `roadmap_future.md` | 🟡 Warm | M1.5 | Future milestone detail sections. Updated when milestones are re-scoped or promoted. |

### Discussions (`docs/discussions/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `story_obsidian_vault_onboarding.md` | 🟢 Cold | M1.5 | Superseded. Reasoning record only. |
| `story_provider_knowledge_store.md` | 🟢 Cold | M1.5 | Resolved. Reasoning record only. |
| `story_claude_code.md` | 🟢 Cold | M1.5 | Superseded. Findings carry into M2. |
| `investigation_mcp_server.md` | 🟢 Cold | M1.5 | Resolved. Design document for M2.1. Do not edit; reference only. |
| `investigation_claude_code.md` | 🟡 Warm | M1.5 | In progress. Resumes in M2.3. |
| `investigation_claude_desktop.md` | 🟡 Warm | M1.5 | Not started. Resumes in M2. |
| `investigation_claude_desktop_mcp.md` | 🟢 Cold | M1.5 | Superseded by `investigation_mcp_server.md`. Redirect only. |
| `investigation_hermes.md` | 🟡 Warm | M1.5 | Not started. Resumes in M2. |
| `investigation_pi.md` | 🟡 Warm | M1.5 | Not started. Resumes in M2. |
| `investigation_workspace_input_channel.md` | 🟢 Cold | M1.5 | Resolved. Operator input channel implemented in M1.5. |

### Architecture (`docs/architecture/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `system_overview.md` | 🟡 Warm | M1 | Update when major architectural components change. |
| `execution_model.md` | 🔴 Hot | M1.5 | Active implementation document. Updated in M1.5 (directory restructuring, input channel). |
| `security.md` | 🟡 Warm | M1.5 | Design constraint and trust boundary spec. Input channel mount verified; no new invariants required. |
| `threat_model_stride.md` | 🟢 Cold | M1 | Implementation-agnostic STRIDE analysis. Revisit at major threat surface changes. |

### Concepts (`docs/concepts/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `agent_workflow.md` | 🔴 Hot | M1.5 | Operator workflow and directory layout. Updated in M1.5. |
| `autonomous_task.md` | 🟢 Cold | M2 | Stub: boundary between interactive and autonomous workflow. Replaces task_lifecycle.md. Do not edit until M3. |
| `two_layer_model.md` | 🟢 Cold | M1.5 | Canonical two-layer architecture definition. Do not edit; reference only. |

### Operations (`docs/operations/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `standard_operating_procedures.md` | 🟡 Warm | M1 | Update when security mitigations or operational procedures change. |
| `iteration_policy.md` | 🟡 Warm | M2 | Master session workflow. Replaces task_policy.md. Update when workflow steps change. |
| `milestone_policy.md` | 🟡 Warm | M2 | Major loop: milestone planning, story and investigation process. |
| `handover_policy.md` | 🟡 Warm | M2 | Handover format, naming, population rules, session continuity. |
| `story_policy.md` | 🟡 Warm | M2 | Story lifecycle: creation, graduation, closure. |
| `investigation_policy.md` | 🟡 Warm | M2 | Investigation lifecycle: structure, states, recommendation, closure. |
| `roadmap_policy.md` | 🟢 Cold | M1.5 | Roadmap maintenance rules. Updated M1.5 to add milestone promotion convention. |
| `documentation_policy.md` | 🟢 Cold | M1 | Documentation structure rules. Only changes if the doc model changes. |

### Scripts (`scripts/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `dry_run.sh` | 🟡 Warm | M1.5 | Container diagnostic checks for dry-run mode. Uses env vars for dir names. |
| `apply_workspace.sh` | 🟡 Warm | M1.5 | Applies staged.diff to PROJECT_DIR. Takes `--project` and `--sandbox` flags. |
| `agent-sandbox.sh` | 🟡 Warm | M1.5 | CLI dispatch wrapper. Installed to host via `make install`. |
| `onboard.sh` | 🟢 Cold | M1.3 | Dispatches onboard subcommand to workflow-specific script. |

### Lib (`libs/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `snapshot.sh` | 🟢 Cold | M1.2 | Snapshot pipeline functions. Sourced by start_agent.sh and container-entrypoint.sh. |
| `diff.sh` | 🟢 Cold | M1.2 | Diff pipeline functions. Sourced by container-entrypoint.sh. |
| `image.sh` | 🟢 Cold | M1.4 | Image digest computation for staleness detection. |
| `_template/Makefile.template` | 🟡 Warm | M1.5 | Project Makefile template. Updated for PROJECT_DIR/SANDBOX_DIR layout. |

### Knowledge Vault Workflow (`workflow/knowledge-vault/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `README.md` | 🟢 Cold | M1.5 | Entry point. Hot task note added. No further changes until M2.1. |
| `changelog.md` | 🟢 Cold | M1.5 | KV1–KV4 completion record. Append-only; no edits to existing entries. |
| `onboarding.md` | 🟢 Cold | M1.5 | Forward-compatibility note added. No further changes until M2.1. |
| `story.md` | 🟢 Cold | M1.5 | Superseded stub. Redirect to `docs/discussions/story_obsidian_vault_onboarding.md`. |
| `roadmap.md` | 🟢 Cold | M1.5 | Superseded stub. Redirect to README + changelog + main roadmap. |

---

## Architecture Layer Boundary Check

Before making a change to any Layer 0 or frozen Layer 1 document, confirm:
1. The current milestone explicitly calls for changes to that layer
2. The change is recorded in the milestone's task list in `roadmap.md`
3. If the milestone does not call for it — stop and flag as out of scope

Undocumented changes to frozen layers are the primary source of drift between implementation and documentation.
