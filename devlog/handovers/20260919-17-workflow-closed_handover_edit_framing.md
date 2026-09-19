# 20260919-17-workflow-closed_handover_edit_framing

- **Handover:** 20260919-17
- **Type:** Workflow
- **Milestone:** M2.6 - Session Persistence (governance)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Reframes the closed-handover edit rule. The current phrasing reads "read-only
once closed", which is too restrictive: the repo already has a working
amendment path (post-close documented corrections), and sometimes a close
commit must be amended (a squash, a fixup, or a bug found after commit A where
rolling the fix into A is cleaner than spawning a second handover). The strict
framing has caused the agent to refuse such operator-directed edits. The new
framing applies the same principle to every closed document: a closed document
is edited only at the operator's direction and carries the corresponding
correction tag.

## Decisions

- Apply one shared correction principle to every closed document type: edited
  only at the operator's direction, every edit carries the correction tag. The
  decision-log rationale differs by type (a handover is a decision record, a
  concept doc a factual reference), but the procedure is the same. This rejects
  the option of splitting the two procedures with no cross-reference: duplicate
  procedures drift, and the drift is what caused this confusion.
- Rewrite the affected paragraph or section in place. No inline markers, no
  reference counts, no `[see correction below]` label.
- Insert the correction tag as a block at the end of the corrected section,
  immediately before the start of the next section: `[CORRECTION -- YYYY-MM-DD:
  <one to three lines>]`.
- Order multiple correction tags newest first, oldest last, the way an ADR
  orders its dated entries.
- Harden the principle language against the exact procedure by linking it and
  by naming the operator's signal words (amend, re-open, edit, fix).
- Keep each document type's existing local tag convention where one exists
  (roadmap keeps `[SUPERSEDED]`/`[REMOVED]`; study and handover use
  `[CORRECTION]`). Normalise study's em-dash tag to `--`.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | handover_policy intro no longer states an absolute read-only rule; it names the operator-directed amendment path |
| AC2 | The Corrections to Closed Handovers section uses the operator-directed + correction-tag framing with the full procedure |
| AC3 | documentation_policy post-close section carries the same operator-directed principle and masks the change in place |
| AC4 | study_policy and roadmap_policy carry the same principle and tag convention; the em-dash tag is normalized to `--` |
| AC5 | No same-type absolute read-only framing remains in the policies or the agent-facing prompts/skills/AGENTS.md |
| AC6 | Changes follow documentation-policy prose rules (one paragraph per physical line, plain ASCII) |