# Agent Handover

**Session date:** 2026-03-16
**Milestone:** Workflow Policy Restructuring — pre-M2.1 documentation
**Session type:** Workflow

## Objective
Complete deferred documentation fixes from the prior session, then run a coherence audit across all new policy files to verify cross-references, step numbering, and link correctness.

## Open design questions

None.

## Task list

### Deferred fixes from prior session
- [x] `contributors.md` — replace three stale references (`task_policy.md` → `iteration_policy.md`, `task_lifecycle.md` → `autonomous_task.md`)
- [x] `milestone_policy.md` — replace stale `doc_status.md` reference (line 104) with handover-based language
- [x] `handover_policy.md` — promote naming convention to named standard; add Session Types table

### Carried task from prior session
- [x] `handover_policy.md` — add explicit naming standard section for handover files

### Stale references discovered this session
- [x] `documentation_policy.md` line 43 — `doc_status.md` reference → replaced with `project_index.md` + active handover
- [x] `documentation_policy.md` line 107 — `task_policy.md` reference and old handover filename pattern → replaced with `handover_policy.md` link and new pattern
- [x] `agent_context_brief.md` line 94 — old `YYYYMMDD_agent_handover.md` pattern → updated to new naming standard
- [x] `readme.md` line 1 — old `YYYYMMDD_agent_handover.md` pattern → updated to new naming standard

### Coherence audit
- [x] Cross-reference link verification across all new policy files — all links resolve
- [x] Step numbering consistency: `handover_policy.md` references match `iteration_policy.md` step headers
- [x] `roadmap_policy.md` step references (Step 1, Step 9a) match `iteration_policy.md`
- [x] Bidirectional references between policy files verified (iteration ↔ milestone ↔ story ↔ investigation ↔ handover)
- [x] `project_index.md` row completeness and temperatures — verified and corrected

## Hot files

| File | Why in scope |
|---|---|
| [`handover_policy.md`](handover_policy.md) | Naming standard and session types added |
| [`contributors.md`](contributors.md) | Three stale references replaced |
| [`milestone_policy.md`](milestone_policy.md) | One stale reference replaced |
| [`documentation_policy.md`](documentation_policy.md) | Two stale references replaced |
| [`agent_context_brief.md`](agent_context_brief.md) | Handover filename pattern updated |
| [`readme.md`](readme.md) | Handover filename pattern updated |
| [`project_index.md`](project_index.md) | Retired rows added; Last touched in updated; changelog.md registered; frontmatter updated |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Handover naming: `YYYYMMDD-NN-TYPE-description_handover.md` | Encodes session type and index in filename; eliminates ambiguity of old suffix convention | `handover_policy.md` — File Naming Standard |
| Session index derived at session start by listing existing files for the date | Agent cannot persist state between sessions; filesystem is the source of truth | `handover_policy.md` — File Naming Standard |
| Eight session types replacing original six | Design absorbs Step 3, Spec absorbs Step 5, Documentation removed (overloaded), added Story/Planning/Workflow | `handover_policy.md` — Session Types |
| Shortform `study` for Investigation | `invest` collides with the financial term; `study` is short and distinct | `handover_policy.md` — Session Types |

## Acceptance criteria

Not yet defined.

## Completed this session

| File | Change |
|---|---|
| `handover_policy.md` | File Naming Standard section (replaces File Naming); Session Types table; format template session type list updated |
| `contributors.md` | Three stale references replaced (`task_policy.md` × 2, `task_lifecycle.md` × 1) |
| `milestone_policy.md` | `doc_status.md` reference replaced with handover-based language |
| `documentation_policy.md` | `doc_status.md` reference replaced; `task_policy.md` reference replaced; handover filename pattern updated |
| `agent_context_brief.md` | Handover filename pattern updated to new naming standard |
| `readme.md` | Frontmatter handover filename pattern updated to new naming standard |
| `project_index.md` | Frontmatter updated; retired rows for `task_policy.md`, `task_lifecycle.md` added; `doc_status.md` note corrected; `changelog.md` registered; `Last touched in` updated for 7 files |

## Deferred items

None.

## Next session

**Session type:** Planning
**Milestone:** M2.1 — General Capability Layer Prototype

**Scope:** Begin the M2.1 minor loop. The roadmap entry in `roadmap.md` has an objective and task list. Assess whether the scoping criteria in `milestone_policy.md` are met (objective, resolved design decisions with rationale, specific task list, named dependencies). If met, proceed to Step 2 (Design). If not, resolve open questions first.

**Watch-out items:**
1. All seven output files from this session need operator commit before next session treats them as canonical.
2. The workflow policy restructuring is now complete — all deferred items from the prior session are resolved.
3. Old handover files (`YYYYMMDD_agent_handover.md` pattern) in the repo are historical and should not be renamed.
