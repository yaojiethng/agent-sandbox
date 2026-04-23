# Project Index

Stable registry of all documentation and policy files in agent-sandbox. Records freeze status, architecture layer assignment, and last milestone to touch each file. Use this when re-scoping tasks or checking whether a proposed change crosses an architecture layer boundary.

The session-scoped hot file list lives in the active handover document (most recent `YYYYMMDD-NN-*.md` in `docs/devlog/handovers/`).

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
| `readme.md` | 🟢 Cold | M2 | System invariants and entry point. Should rarely need updating. |
| `contributors.md` | 🟢 Cold | M2 | Contribution rules. Update only when workflow or security model changes. |
| `agent_context_brief.md` | 🟡 Warm | M2 | Agent collaboration protocol. Update when working practices evolve. |

### Development (`docs/development/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `doc_status.md` — retired | — | M1.5 | Replaced by handover Hot files section. Deleted. |
| `project_index.md` | 🟡 Warm | M2 | This file. Updated when files are added, removed, or freeze status changes. |
| `roadmap.md` | 🔴 Hot | M1.5 | Active milestone tasks and milestone summary table. |
| `roadmap_future.md` | 🟡 Warm | M1.5 | Future milestone detail sections. Updated when milestones are re-scoped or promoted. |
| `changelog.md` | 🟡 Warm | M1.5 | Completed milestone records. Append-only. |

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
| `execution_model.md` | 🟡 Warm | M2.3 | Index document: directory layout, invocation model. Compose generation, mount shape rationale, container lifecycle. Delegates layer implementation to sandbox_lifecycle.md and provider_lifecycle.md . |
| `sandbox_lifecycle.md` | 🟡 Warm | M2.3 | Capability layer's lifecycle: snapshot pipeline (fork), agent work, git baseline, diff pipeline (join), input channels, apply workflow. |
| `provider_lifecycle.md ` | 🟡 Warm | M2.3 | Reasoning layer's lifecycle: config seed (copy-in), agent work, config persist (copy-out). |
| `tool_interface.md` | 🟡 Warm | M2.2 | External contract: command shapes, naming, mount shape guarantees, execution modes, onboarding contract, `.env` variables, provider interface definition. |
| `security.md` | 🟡 Warm | M2.1 | Design constraint and trust boundary spec. Updated for two-container trust boundaries. |
| `threat_model_stride.md` | 🟢 Cold | M1 | Implementation-agnostic STRIDE analysis. Revisit at major threat surface changes. |

### Concepts (`docs/concepts/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `agent_workflow.md` | 🟢 Cold | M2.1 | Design principles, invariants, UX flow names. Rescoped to pure conceptual; operational detail moved to quickstart and tool_interface. |
| `autonomous_task.md` | 🟢 Cold | M2 | Stub: boundary between interactive and autonomous workflow. Replaces `task_lifecycle.md`. Do not edit until M3. |
| `task_lifecycle.md` — retired | — | M2 | Renamed to `autonomous_task.md` and replaced with stub. Deleted. |
| `two_layer_model.md` | 🟢 Cold | M2.2 | Canonical two-layer architecture definition. Implemented in M2. Do not edit; reference only. |

### Operations (`docs/operations/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `standard_operating_procedures.md` | 🟡 Warm | M1 | Update when security mitigations or operational procedures change. |
| `provider_onboarding_guide.md` | 🟡 Warm | M2.2 | Step-by-step guide to adding a new reasoning layer provider. References tool_interface.md for contract and execution_model.md for mechanics. |
| `project_onboarding_guide.md` | 🟡 Warm | M2.2 | Step-by-step guide to onboarding a new project. Covers prerequisites, onboard command, AGENTS.md authoring, and verification. |
| `quickstart.md` | 🟡 Warm | M2.2 | First-run setup guide. Covers install, onboard, build, and dry-run verification. Provider-specific commands in provider quickstart. |
| `iteration_policy.md` | 🟡 Warm | M2 | Master session workflow. Replaces task_policy.md. Update when workflow steps change. |
| `milestone_policy.md` | 🟡 Warm | M2 | Major loop: milestone planning, story and investigation process. |
| `handover_policy.md` | 🟡 Warm | M2 | Handover format, naming, population rules, session continuity. |
| `story_policy.md` | 🟡 Warm | M2 | Story lifecycle: creation, graduation, closure. |
| `investigation_policy.md` | 🟡 Warm | M2 | Investigation lifecycle: structure, states, recommendation, closure. |
| `roadmap_policy.md` | 🟢 Cold | M2 | Roadmap maintenance rules. Session-boundary update model. |
| `documentation_policy.md` | 🟢 Cold | M2 | Documentation structure rules. Only changes if the doc model changes. |
| `task_policy.md` — retired | — | M2 | Replaced by `iteration_policy.md`. Deleted. |

### Scripts (`scripts/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `dry_run.sh` | 🟡 Warm | M1.5 | Container diagnostic checks for dry-run mode. Uses env vars for dir names. |
| `apply_workspace.sh` | 🟡 Warm | M2.3 | Applies staged.diff to PROJECT_DIR. Takes `--project` and `--sandbox` flags. |
| `agent-sandbox.sh` | 🟡 Warm | M2.3 | CLI dispatch wrapper. Installed to host via `make install`. |
| `onboard.sh` | 🟡 Warm | M2.1 | Onboards new projects; `--refresh` flag updates stale template files without full re-onboard. |
| `start_agent.sh` | 🟡 Warm | M2.3 | Starts agent session. Sources checkpoint.sh for WORKTREE_ID derivation. |
| `checkpoint.sh` | 🟡 Warm | M2.3 | Checkpoint library. Retains only worktree_id_derive after Unit B. |

### Lib (`libs/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `snapshot.sh` | 🟢 Cold | M2.3 | Snapshot pipeline functions. Sourced by start_agent.sh and container-entrypoint.sh. |
| `diff.sh` | 🟢 Cold | M2.3 | Diff pipeline functions. Sourced by container-entrypoint.sh. |
| `package_branch.sh` | 🟢 Cold | M2.3 | Package branch commits as numbered diff files. Sourced by `diff_on_exit`. |
| `package_diff.sh` | 🟢 Cold | M2.3 | Package diffs for apply workflow. Reads INIT_SHA from .git/ at container init. |
| `build_context.sh` | 🟡 Warm | M2.1 | Build context preparation. Creates mktemp dir, copies required files per image type, errors on missing file. |
| `compose.sh` | 🟡 Warm | M2.3 | Docker Compose generation. Template substitution for session variables. |
| `docker-compose.yml` | 🟡 Warm | M2.3 | Base Docker Compose template. Session labels applied to all containers. |
| `_templates/Makefile.template` | 🟡 Warm | M2.3 | Project Makefile template. Template version tag added. |
| `_templates/dockerfile-default.sandbox` | 🟡 Warm | M2.1 | Default capability layer Dockerfile template. COPY paths updated to flat layout; template version tag added. |

### Tests (`tests/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `test_apply_workspace.sh` | 🟡 Warm | M2.3 | Functional tests for apply_workspace.sh. Covers draft/confirm/reject/apply workflow. |
| `test_capability_layer.sh` | 🟡 Warm | M2.1 | Standalone capability layer functional test. All checks passing. |
| `test_build_context.sh` | 🟡 Warm | M2.1 | Property-based tests for `build_context`. Covers output contract, file contents, digest determinism, error cases. |
| `test_snapshot_container.sh` | 🟡 Warm | M2.3 | Container-side snapshot pipeline tests. Covers snapshot_init_git working tree state matrix. |

### Providers (`providers/`)

| Document | Temp | Last touched in | Notes |
|---|---|---|---|
| `providers/opencode/quickstart.md` | 🟡 Warm | M2.2 | Day-to-day command reference and troubleshooting for the OpenCode provider. |

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
