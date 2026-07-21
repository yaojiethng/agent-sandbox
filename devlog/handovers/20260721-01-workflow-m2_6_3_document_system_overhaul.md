# Agent Handover

**Session date:** 2026-07-21
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Session type:** Workflow — Document system overhaul
**Status:** Closed

## Objective

Overhaul the document naming convention, establish an ADR workflow, consolidate 5 overlapping documents about the mount model into a single ADR, enforce the new conventions via agent-forwarding in AGENTS.md, and define a cleanup lifecycle for stale documents.

---

## Scope

### Part 1 — Discussion policy

Create `docs/operations/discussion_policy.md` — covers lifecycle and naming for all files in `devlog/discussions/`. Absorbs content from `story_policy.md` and `investigation_policy.md` (those become superseded). Includes:

- **Naming rules:** `YYYYMMDD-{type}-{status}-{description}.md` with type codes (story, study, design), status codes, valid state transitions
- **Lifecycle:** story —study / design → settled → superseded / archived / rejected
- **Deletion rule:** single-use specs rolled into handovers; docs with no bearing on current state
- **Forward reference:** when a design settles with an implementation decision, the decision moves to an ADR
- **Legacy docs:** old-format docs keep names until touched; rename on first edit

### Part 2 — ADR policy

Create `docs/operations/adr_policy.md` — covers lifecycle and naming for docs in `docs/adr/`. Includes:

- **Naming rules:** `YYYYMMDD-adr-{status}-{description}.md` (type is always `adr`, enforced)
- **Creation trigger:** when a design decision reaches implementation
- **Content:** summary, context, options considered, decision, consequences, supersedes
- **Lifecycle:** created `settled`; only valid transition is `superseded`
- **Supersede protocol:** old ADR gets one header edit — `> **Superseded by:**` — then frozen. Partial (§section) supported.

### Part 3 — Policy amendments to existing files

**`docs/operations/git_policy.md`** — add to Commit Message Format:
- Description summarises *why*, not *what changed line by line*. The diff is visible in `git show`.
- No file paths or line numbers in the message body. That is the diff's job.

**`docs/operations/handover_policy.md`** — add Brevity section:
- Implementation steps (file-by-file changes, edit descriptions) belong in git commits, not handovers.
- `Completed this session` table: one line per file, stating what changed and why. Not every edit.
- `Acceptance criteria`: one observable delta per criterion. If verification requires reading the handover, it is too detailed.
- `Hot files`: one-line reason per file. If it duplicates Objective or Scope, it is redundant.

**`docs/operations/iteration_policy.md`** — update references:
- Replace direct links to `story_policy.md` and `investigation_policy.md` with links to `discussion_policy.md` (which then links to sub-policies)
- Add ADR creation as a recognised step in the major and/or minor loop workflow
- Add `adr_policy.md` to the References table

### Part 4 — Agent enforcement

- Update `AGENTS.md` Session Start table to include the new policies
- Update `src/reasoning/providers/pi/config/agent/AGENTS.md` Write Discipline section with forward links to policy documents

- Update `AGENTS.md` Session Start table to include the new policy
- Update `src/reasoning/providers/pi/config/agent/AGENTS.md` Write Discipline section with a forward link

### Part 5 — Migration strategy

**Supersede old policies (no content changes):**
- `docs/operations/story_policy.md` — add supersede header → `discussion_policy.md`
- `docs/operations/investigation_policy.md` — add supersede header → `discussion_policy.md`

**For this session:

**For this session:**

| Action | Scope |
|---|---|
| **Consolidate + delete** | 4 spec files rolled into handovers, then deleted |
| **Consolidate + supersede** | 5 docs about mount model → new ADR, old docs get SUP headers |
| **ADR create** | `docs/adr/20260721-adr-stl-worktree-mount-model.md` |
| **Policy create** | `docs/operations/document_naming_policy.md` |
| **Link updates** | Any doc that links to a deleted/renamed doc gets its link updated |

**For future sessions:**

| Trigger | Action |
|---|---|
| Any edit to an old-format doc | Rename to new convention + update inbound links + add status header |
| New decision supersedes an old doc | Supersede header + rename + redirect roadmap/ADR references |
| Session touches a spec as part of its work | Check if it's single-use → if so, roll into handover and delete the spec |
| Roadmap entry edited | Rename any referenced old-format doc + update the roadmap link |

No bulk sweep. Rename-on-touch only. Overhead per session: at most 2-3 old docs renamed as part of the session's natural work.

### Part 6 — Documents to consolidate/delete this session

**Specs to roll into handovers and delete:**

| File | Action | Reason |
|---|---|---|
| `devlog/discussions/spec_context_dir_removal.md` (221 lines) | Condense key decisions into `20260609-09-design-context_dir_removal.md` + `20260611-01-impl-context_dir_removal.md`. Delete spec. | Single-session impl, fully captured in handovers |
| `devlog/discussions/spec_apply_workspace_refactor.md` (238 lines) | Condense key decisions into relevant apply workflow handovers. Delete spec. | Multi-session but fully implemented; spec is no longer referenced |
| `devlog/discussions/spec_test_infrastructure.md` (134 lines) | Condense into test infrastructure handovers. Delete spec. | Implemented; code + handovers are the record |
| `devlog/discussions/spec_container_layer_redesign.md` (312 lines) | **Keep.** But rename to new format and update status. | Still Active — sessions 2+ pending. Cannot delete. |

**Mount-model docs to supersede into new ADR:**

| File | Action |
|---|---|
| `devlog/discussions/investigation_git_worktrees.md` | Supersede header + rename to new format |
| `devlog/discussions/story_agent_git_surface.md` | Supersede header. Delete if ADR fully covers the questions. |
| `devlog/discussions/story_parallel_sessions_worktree.md` | Supersede header. Delete if ADR covers the design. |
| `devlog/discussions/security_delta_worktree_model.md` | Supersede header + rename. Keep — invariant analysis still relevant as reference. |
| `devlog/discussions/story_agent_state_persistence.md` | Supersede header + rename. Keep — Phase 1 decisions still relevant. |

**Criterion for deletion vs keep:**
- Delete if: the ADR fully replaces the content AND there are no inbound links from active docs
- Keep + SUP if: the doc has historical value as decision trail AND/OR has active inbound links that would break

### Part 7 — Consolidation ADR: worktree mount model

Create `docs/adr/20260721-adr-stl-worktree-mount-model.md` covering:

- Context — which problem, why worktree model under relaxed assumptions
- Invariant-level changes — what security.md invariants change vs stay
- Architecture-level changes — mount shape, container wiring, capability layer role
- Feature-level changes — worktree lifecycle, branch naming, operator workflow
- What's eliminated — snapshot pipeline, diff export, apply script
- Supersedes — explicit list of which docs and which sections
- Supersedes and removes — which docs are fully replaced and deleted

---

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `docs/operations/` has 14 policy files with unclear boundaries. `documentation_policy.md`, `handover_policy.md`, `iteration_policy.md`, `story_policy.md` overlap in scope. Naming convention for discussions/ADRs doesn't fit any existing policy cleanly. Needs a separate pass to merge or clarify boundaries. | scope change | next session |
| All existing `spec`-type files must be cleaned up. `spec_container_layer_redesign.md` becomes `design` (still active). The other three are single-use and should be rolled into handovers then deleted. | scope change | current session |
| Design policy does not exist as a standalone document. `iteration_policy.md` references `design` as a workflow step but doesn't link to any policy for format/lifecycle. Whether to distill from references across `documentation_policy.md` and `iteration_policy.md` into `discussion_policy.md` is an open question. | scope change | next session |
| `iteration_policy.md` links directly to `story_policy.md` and `investigation_policy.md`. These should redirect through `discussion_policy.md`. ADR creation should be added as a recognised step. | scope change | current session |

---

## Out of scope

- Rewriting `docs/architecture/security.md` or `docs/architecture/execution_model.md` (gated on Phase 2 implementation, not this session)
- Updating `roadmap.md` or `roadmap_future.md` (deferred until ADR is accepted)
- Renaming every old-format doc in the repo (rename-on-touch only)
- Actual Phase 2 implementation (design session outputs into implementation)

---

## Completed this session

| File | Change |
|---|---|
| `docs/operations/discussion_policy.md` | New — naming rules, type/status codes, document type hub linking to sub-policies |
| `docs/operations/adr_policy.md` | New — ADR lifecycle, content requirements, supersede protocol |
| `docs/operations/iteration_policy.md` | Updated references to redirect through discussion_policy.md; added ADR creation to minor loop Step 3 |
| `docs/operations/git_policy.md` | Added commit message brevity rule and prefix enforcement |
| `docs/operations/handover_policy.md` | Added Brevity section — implementation steps belong in git, not handovers |
| `docs/operations/study_policy.md` | Renamed from investigation_policy.md; all stale links in active docs updated |
| `docs/operations/story_policy.md` | Updated stale links to study_policy.md |
| `docs/operations/documentation_policy.md` | Updated stale links to study_policy.md |
| `docs/operations/milestone_policy.md` | Updated stale links to study_policy.md |
| `docs/concepts/agent_workflow.md` | Updated stale link to study_policy.md |
| `docs/development/project_index.md` | Updated table — renamed study_policy.md, added discussion_policy.md and adr_policy.md |
| `AGENTS.md` | Added governance document procedure; added new policies to Session Start table |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | Added forward links to discussion_policy.md and adr_policy.md |
| `devlog/roadmap.md` | Added M2.6 Phase 1.6 — Document consolidation tasks for future session |

## Deferred items

| Item | Reason | Next session |
|---|---|---|
| Roll single-use spec files into handovers and delete | Scope grew beyond single session | M2.6 Phase 1.6 |
| Write worktree mount model ADR | Requires design work not yet started | M2.6 Phase 1.6 |
| Supersede mount-model discussion docs | Gated on ADR being written | M2.6 Phase 1.6 |
| Policy file disambiguation pass | 14 policy files with unclear boundaries — needs dedicated pass | Future (unassigned) |
| Design policy extraction | Unresolved — whether to extract from documentation_policy.md and iteration_policy.md | Future (unassigned) |

## Next session

**M2.6 Phase 1.6 — Document consolidation.**

Tasks:
- Roll spec files into handovers
- Write worktree mount model ADR
- Supersede old mount-model discussion docs