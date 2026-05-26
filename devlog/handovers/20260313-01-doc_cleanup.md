# Agent Handover

**Session date:** 2026-03-13  
**Milestone:** M1.5 — Workflow Convergence & Directory Restructuring  
**Session type:** Documentation housekeeping

---

## Completed this session

| File | Change |
|---|---|
| `docs/discussions/story_obsidian_vault_onboarding.md` | Renamed from `workflow/knowledge-vault/story.md`. Links updated for new path. |
| `docs/discussions/story_claude_code.md` | Superseded. Resolution section added. M1.7 refs updated to M2.3. |
| `docs/discussions/story_provider_knowledge_store.md` | Section names aligned to convention (Problem→Context+Pain Points, Solution Space→Investigation Findings). Links fixed. |
| `docs/discussions/investigation_mcp_server.md` | Status updated to Resolved. Links fixed. |
| `docs/discussions/investigation_workspace_input_channel.md` | Status updated to Resolved. Resolution section added replacing task list. Links fixed. |
| `docs/discussions/investigation_claude_code.md` | M1.7 refs updated to M2.3. Next Steps updated. Links fixed. |
| `docs/discussions/investigation_claude_desktop.md` | Links fixed. |
| `docs/discussions/investigation_claude_desktop_mcp.md` | Superseded (duplicate of investigation_mcp_server.md). |
| `docs/discussions/investigation_hermes.md` | Links fixed. |
| `docs/discussions/investigation_pi.md` | Links fixed. |
| `workflow/knowledge-vault/story.md` | Superseded stub — redirects to new path. |
| `workflow/knowledge-vault/README.md` | Hot task note added. KV5 refs removed. Roadmap.md (kv) removed from doc map. |
| `workflow/knowledge-vault/changelog.md` | Milestone summary table added at top. |
| `workflow/knowledge-vault/roadmap.md` | Superseded stub — redirects to README + changelog + main roadmap. |
| `docs/development/roadmap.md` | Split: future milestone detail moved out. Summary table links updated to roadmap_future.md. |
| `docs/development/roadmap_future.md` | New. All M2–M8 detail sections. Promotion rule documented at top. |
| `docs/development/doc_status.md` | Rewritten as thin session-scoped hot file list for M1.5. |
| `docs/development/project_index.md` | New. Stable project-wide file registry with freeze status and architecture layer assignments. Absorbs old doc_status comprehensive table. |
| `docs/development/task_policy.md` | Investigation document format section added. Agent read discipline section added. |
| `agent_context_brief.md` | Provider-specific line removed. Read discipline section added. References restructured with reading order and question-per-file framing. agents.md and 20260313_agent_handover.md added. |
| `docs/development/contributors.md` | Rewritten. Moved from root to docs/development. Agent-facing content removed. Parent/child naming removed (superseded). Paths updated. |
| `docs/development/task_policy.md` | Session Handover policy section added. Handover is a session log, not a document. |
| `docs/operations/documentation_policy.md` | discussions/ folder added to folder structure. doc_status filename corrected. Root document audience section updated for four-document agent model. Document header format convention added. |

---

## Next task

**M1.5 — Directory restructuring and operator input channel implementation.**

Task list in `docs/development/roadmap.md` — M1.5 section. All implementation tasks are unchecked. Start with `start_agent.sh`.

Files needed from operator: `scripts/start_agent.sh` (or `providers/opencode/start_agent.sh`), `scripts/agent-sandbox.sh`, `build_agent.sh`, `container-entrypoint.sh`, `libs/snapshot.sh`, `libs/image.sh`.

Run at session start:
```bash
grep -rn "PROJECT_ROOT\|--root" scripts/ libs/ providers/
```

---

## Watch out for

- `task_policy.md` now lives in `docs/development/` in our outputs, but the real repo may still have it under `docs/operations/`. Verify path before updating any cross-references.
- `docs/discussions/` is a new folder — confirm it exists in the repo before committing files there. If not, create it.
- `roadmap_future.md` is new — `roadmap_policy.md` has not been updated to document the split or the promotion rule. Flag this when `roadmap_policy.md` is next in scope.
