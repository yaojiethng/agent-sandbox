# Agent Handover

**Session date:** 2026-03-16
**Milestone:** Workflow Policy Restructuring — pre-M2.1 documentation
**Session type:** Documentation

## Objective
Audit and reconstruct the development workflow policy documents to reflect the two-loop model (major/minor), retire stale documents, consolidate index maintenance, and ensure all policy cross-references are explicit and correctly linked.

## Open design questions

None.

## Task list

### Policy document restructure (completed)
- [x] `iteration_policy.md` — new; replaces `task_policy.md` and `task_lifecycle.md`; two-loop workflow with gated steps
- [x] `milestone_policy.md` — new; major loop planning process, story and investigation trigger rules
- [x] `handover_policy.md` — new; extracted from `task_policy.md`; format, canonical null markers, task list grouping
- [x] `story_policy.md` — new; extracted and formalised from `task_policy.md`
- [x] `investigation_policy.md` — new; extracted and formalised from `task_policy.md`
- [x] `autonomous_task.md` — new stub; replaces `task_lifecycle.md`; boundary between interactive and autonomous workflow
- [ ] `handover_policy.md` — add explicit naming standard section for handover files (currently defined inline in File Naming; promote to a named rule)

### Entrypoint and index updates (completed)
- [x] `agent_context_brief.md` — operating workflow replaced with pointer; references restructured into session-start / major-loop / session-end / on-demand tables; missing output format header restored; read discipline section restored
- [x] `readme.md` — frontmatter stamp replaced with pointer to active handover; documentation guide updated
- [x] `project_index.md` — `Last milestone` renamed to `Last touched in`; `doc_status.md` marked retired; new policy documents registered; `task_policy.md` and `task_lifecycle.md` rows updated
- [x] `roadmap_policy.md` — two-step update sequence replaced with session-boundary model (Step 1 compacts, Step 9a marks only)
- [x] `documentation_policy.md` — linking convention extended with two new subsections: link wherever possible, link at workflow handoff points

### Skill updates (completed)
- [x] `kelsey-code-reviewer.skill.md` — new; Bash/Docker audit skill modelled on Kelsey Hightower
- [x] `architecture-doc-reviewer.skill.md` — updated; `doc_status.md` staleness reference replaced with handover + `project_index.md`

### Operator deletions (completed by operator)
- [x] `task_policy.md` — deleted
- [x] `task_lifecycle.md` — renamed to `autonomous_task.md` and replaced with stub
- [x] `doc_status.md` — deleted

## Hot files

All files below were produced this session and are in outputs. The next session should treat all of them as the authoritative versions.

| File | Why in scope |
|---|---|
| [`iteration_policy.md`](iteration_policy.md) | Master workflow — primary subject of next session audit |
| [`milestone_policy.md`](milestone_policy.md) | Major loop — verify closing steps reference handover not doc_status |
| [`handover_policy.md`](handover_policy.md) | Handover format — verify canonical markers consistent throughout |
| [`story_policy.md`](story_policy.md) | Story lifecycle — verify cross-references to milestone and iteration policy |
| [`investigation_policy.md`](investigation_policy.md) | Investigation lifecycle — verify cross-references |
| [`autonomous_task.md`](autonomous_task.md) | Stub — verify references to iteration_policy and execution_model are correct |
| [`agent_context_brief.md`](agent_context_brief.md) | Entrypoint — verify all document links resolve; session table is complete |
| [`readme.md`](readme.md) | Entrypoint — verify documentation guide links resolve |
| [`project_index.md`](project_index.md) | Registry — verify all new files registered; no stale rows |
| [`roadmap_policy.md`](roadmap_policy.md) | Roadmap rules — verify step references match iteration_policy numbering |
| [`documentation_policy.md`](documentation_policy.md) | Doc rules — verify new linking convention sections are coherent |
| [`contributors.md`](contributors.md) | Not yet updated — contains stale references (see Deferred items) |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Retire `task_policy.md` and `task_lifecycle.md` | `iteration_policy.md` absorbs the workflow; `autonomous_task.md` preserves the TASK.md stub | `project_index.md` |
| Retire `doc_status.md` | Hot file list moves to handover; eliminates staleness from dual-index problem | `iteration_policy.md` — Index Maintenance |
| Two-loop model: major loop (milestone planning) and minor loop (session) | Session targets one sub-milestone; milestone planning is a separate cadence triggered after major milestone closes | `iteration_policy.md` |
| `roadmap.md` is session-boundary only in minor loop | Agent works from handover during session; roadmap touched at Step 1 (compact + read) and Step 9a (mark only) | `roadmap_policy.md` |
| Canonical null markers for all nullable handover sections | Blank sections are ambiguous; explanatory filler is noise; one-word markers are unambiguous | `handover_policy.md` |
| Task list grouped by functional area, ordered by dependency | Operation-type grouping (New/Modified/Docs) doesn't reflect dependency or cohesion | `handover_policy.md` |
| `iteration_policy.md` in session-start always table (Option A) | Agents don't reliably self-assess whether they know the policy; cost of redundant read is lower than cost of skipping | `agent_context_brief.md` |
| Linking policy: link at handoff points, not only in References tables | A reference table is navigation aid; a link at the action point is the instruction to read the policy | `documentation_policy.md` — Linking Convention |

## Acceptance criteria

Not yet defined.

## Completed this session

| File | Change |
|---|---|
| `iteration_policy.md` | Created — two-loop workflow with gated steps, index maintenance section, child document links at all handoff points |
| `milestone_policy.md` | Created — major loop planning, scoping criteria, story/investigation trigger rules |
| `handover_policy.md` | Created — format template, canonical null markers, task list grouping, population rules |
| `story_policy.md` | Created — story lifecycle extracted and formalised |
| `investigation_policy.md` | Created — investigation lifecycle extracted and formalised |
| `autonomous_task.md` | Created — stub preserving TASK.md boundary reference for M3 |
| `agent_context_brief.md` | Updated — operating workflow replaced; references restructured into four tables; output format section header restored; read discipline section restored |
| `readme.md` | Updated — frontmatter stamp replaced; documentation guide table updated |
| `project_index.md` | Updated — column renamed; doc_status retired; new policy documents registered |
| `roadmap_policy.md` | Updated — two-step sequence replaced with session-boundary model |
| `documentation_policy.md` | Updated — linking convention extended with two subsections |
| `kelsey-code-reviewer.skill.md` | Created — Bash/Docker audit skill |
| `architecture-doc-reviewer.skill.md` | Updated — staleness check corrected |

## Deferred items

**`contributors.md` — stale references not updated this session.**
Contains three references to deleted documents: `task_policy.md` (lines 66 and 78) and `task_lifecycle.md` (line 80). Needs updating to reference `iteration_policy.md` and `autonomous_task.md` respectively. Documentation audit task — fix in next session.

**`milestone_policy.md` — one stale `doc_status.md` reference.**
Line 104 in the closing section reads: "`doc_status.md` has been updated to reflect the new active milestone and its hot files." Should read: "The next handover stub has been created and its Hot files section populated." Documentation audit task — fix in next session.

**`handover_policy.md` — naming standard not yet a named rule.**
The `YYYYMMDD_agent_handover.md` convention exists in the File Naming section but is prose, not a codified rule. Promote to an explicit named standard consistent with how other naming conventions are expressed in the policy documents. Documentation audit task — fix in next session.

## Next session

**Session type:** Documentation / Audit
**Milestone:** Workflow policy restructuring — audit and correction pass (pre-M2.1)

This is a documentation audit session, not an implementation session. M2.1 implementation begins in a separate session window after this audit is complete.

**Scope:** Complete the three deferred documentation tasks above, then run a coherence audit across all new policy files to verify cross-references, step numbering consistency, and link correctness. Use the outputs from this session as the working documents — verify operator has committed them before treating as canonical.

**Suggested audit order:**
1. Fix `contributors.md` stale references
2. Fix `milestone_policy.md` stale `doc_status.md` reference
3. Update `handover_policy.md` naming standard to a named rule
4. Audit cross-references: verify all links in new policy files resolve and point to the correct sections
5. Verify step numbering in `handover_policy.md` (Step 1, Step 7, Step 9a, Step 9b) matches `iteration_policy.md`
6. Verify `project_index.md` rows are complete and temperatures are correct for all new files

**Watch-out items:**
1. All policy files for this session are in outputs, not yet committed to the repo. Verify operator has committed before treating them as canonical.
2. `project_index.md` rows for new policy files show `Last touched in: M2` — correct as placeholder; update to specific sub-milestone once committed.
3. Step references in `handover_policy.md` must stay in sync with `iteration_policy.md` — check both in the same pass.
