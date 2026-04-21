# Agent Handover

**Session date:** 2026-04-21
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Workflow
**Status:** Closed

## Objective

Produce the conceptual and policy documentation grounding for the apply workflow and
baseline advancement model, scoped by gaps surfaced during implementation review of
Changes 3–5.

## Scope

Documentation work spanning three areas: a new concepts doc establishing the
sandbox/host correspondence model; an architecture doc for the apply workflow (stub —
command shapes deferred); and policy patches to `documentation_policy.md` and
`iteration_policy.md` formalising concepts doc creation as an assessed, optional step.

Adjacent implementation questions (untracked file bundling in `package-diff.sh`,
sequential `make apply` failures) were discussed and their resolutions documented in the
concepts doc as model gaps.

## Carried forward

None.

## Acceptance criteria

- [x] `sandbox_host_correspondence_model.md` produced in `docs/concepts/` — covers
  primitives, invariants, correspondence cycle, restart vs advancement, diff primitive
  rationale, parallel sessions, and model gaps
- [x] `design_apply_workflow_and_baseline_advancement.md` updated — delivery framing
  removed from header; known implementation gaps section added with open questions
- [x] `documentation_policy.md` patched — Concepts Docs subsection added under
  Conventions covering location, trigger criteria, distillation pass rules, and Trigger B
  cleanup
- [x] `iteration_policy.md` patched — step notation updated with `(confirmed)` /
  `(assessed)` tags and legend; Step 3 row updated to assessed workflow
- [x] Architecture doc `apply_workflow.md` — deferred; command shapes and path mechanics
  not yet written

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `docs/concepts/sandbox_host_correspondence_model.md` | New — correspondence model concepts doc | ✓ Complete |
| `docs/discussions/design_apply_workflow_and_baseline_advancement.md` | Header update + known gaps section | ✓ Complete |
| `docs/operations/documentation_policy.md` | Concepts Docs subsection added | ✓ Complete |
| `docs/operations/iteration_policy.md` | Step notation + Step 3 row updated | ✓ Complete |
| `docs/architecture/apply_workflow.md` | Command shapes + path mechanics | Deferred |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Concepts docs are assessed (optional, operator-confirmed) not scheduled | Avoids producing concepts docs for areas that don't need them; agent does the assessment work, operator makes the call | `documentation_policy.md` — Concepts Docs, `iteration_policy.md` — Step 3 |
| Step tags: `(confirmed)` / `(assessed)` / `(always)` | "Assessed" captures that the agent recommends and the operator decides, without implying the step is skipped autonomously or that it is mandatory | `iteration_policy.md` — step notation |
| Distillation from design doc, not from scratch | Concepts docs have a source of truth — the design doc — and should be produced by stripping delivery framing and command shapes, not rewritten | `documentation_policy.md` — Concepts Docs |
| Trigger B cleanup note in concepts docs should name the concrete condition, not the workflow mechanism | "Links updated now that `apply_workflow.md` is finalised" is readable to any agent; "Trigger B cleanup complete" requires knowing the internal workflow | `documentation_policy.md` — Concepts Docs |
| Model gaps (mixing two paths, mixed session types) belong in the concepts doc | These are gaps in the correspondence model, not the implementation — they require a design session to resolve and the concepts doc is the right home | `docs/concepts/sandbox_host_correspondence_model.md` — Model Gaps |
| `apply_workflow.md` lives in `docs/concepts/`, not `docs/architecture/` | The document answers why the model is shaped this way — invariants, primitives, design rationale — not what the system does | this handover |
| `sandbox_host_correspondence_model.md` as the document name | "Apply workflow" names one mechanism; the document is about how sandbox and host stay in correspondence across the full project lifecycle | this handover |

## Completed this session

| File | Change summary |
|---|---|
| `docs/concepts/sandbox_host_correspondence_model.md` | Created — full concepts doc with correspondence cycle diagram, incremental packaging diagram, primitives, invariants, restart vs advancement, diff primitive rationale, parallel sessions collision table, model gaps |
| `docs/discussions/design_apply_workflow_and_baseline_advancement.md` | Header updated to remove milestone delivery framing; Known Implementation Gaps section added covering two open model gaps with open questions |
| `docs/operations/documentation_policy.md` | Concepts Docs subsection added under Conventions |
| `docs/operations/iteration_policy.md` | Step notation updated with tag legend; Step 3 row rewritten to assessed workflow |
| `docs/development/roadmap.md` | Change 5 marked complete; status line updated; two pre-close design gap items added under M2.3 |

## Deferred items

| Item | Reason | Goes next |
|---|---|---|
| `docs/architecture/apply_workflow.md` | Command shapes and path mechanics are implementation detail — out of scope for a workflow/docs session; concepts doc was the priority | Next implementation or spec session for M2.3 |
| `package-diff.sh` untracked file tests | Test structure discussed but not written | M2.3 implementation work |

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline  
**Next task:** Implement Change 6 (baseline advancement). Two pre-close design gap items
are now recorded in the roadmap under M2.3 — these require design sessions before Trigger
B fires, but do not block Change 6 implementation.

**Files to upload:**
- This handover
- `roadmap.md`
- `scripts/apply_workspace.sh` — Change 6 starting point
- `scripts/checkpoint.sh` — sourced by advancement script
- Prior impl handover (`20260421-01-impl-m2_3_container_naming_labels_checkpoint.md`) for Change 5 context
