# Handover 20260901-09 — docs reconcile-before-acting rule for feedback entries

**Milestone:** M2.6 - Session Persistence
**Type:** docs
**Status:** Closed
**Session date:** 2026-09-01

## Objective

Record the lesson from `20260901-08` (the runner-selftest feedback entry was
stale against the tree — a self-test had landed after the entry was written —
and was acted on without reconciliation): establish "reconcile feedback
entries against the current tree before acting on them" in the place(s) where
the feedback-resolution procedure lives.

## Where the procedure lives today (orientation result)

- No dedicated feedback/gotchas policy file exists. The resolution procedure
  is distributed across:
  1. `iteration_policy.md` — Sub-milestone pre-close review gate (open
     entries surfaced to the operator) and the findings review/publish step
     (routing *into* the records).
  2. The two records' own preambles (`AGENT_FEEDBACK.md`, `GOTCHAS.md`) —
     entry lifecycle: "An entry is deleted when resolved…"
  3. The finalized workflow artifact
     `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`
     (design record, not operational).

## Proposed change (per governance rules: section-by-section release)

Two locations, minimal text:

1. `iteration_policy.md`, **Pre-close review gate** (sub-milestone cleanup) —
   the gate that already surfaces open entries to the operator.
2. `AGENTS`-facing preambles of `AGENT_FEEDBACK.md` and `GOTCHAS.md` — the
   surface the agent reads before acting on an entry.

## Acceptance Criteria

- AC1: The reconcile-before-acting rule is recorded in the review gate and
  both preambles, with released text.
- AC2: `chore:`/`docs:` delivery commit; handover closed in it.

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Placement: both record preambles + iteration_policy **Step 2 scoping gate** (operator: not the pre-close review gate — pre-implementation checks belong in scoping, where scope and AC are presented) | confirmed (operator) |
| D2 | Preamble rule: tree has outgrown an entry → mark **resolved or superseded**, keep for monitoring, drop on no resurfacing (operator refinement; deletes-when-resolved sentence amended to match, state enum extended) | confirmed (operator) |
| D3 | Scoping-gate rule: purpose reconciliation before scope proposal and again at AC presentation (Step 5); silently-resolved purpose is surfaced, scope becomes recording/retiring the resolution | confirmed (operator) |

## Completed

- Both preambles: reconcile-before-acting rule added; entry-format `state:`
  enum extended with resolved/superseded (kept for monitoring, dropped on no
  resurfacing); "deleted when resolved" sentence amended to the mark-and-
  monitor flow so the two texts agree.
- `iteration_policy.md` Step 2: **Purpose reconciliation** rule added before
  Gate 1 — applies at scope proposal and again at AC presentation.
- AC1 ✅ AC2 pending commit.

## What's Next

- Closed; delivery commit `docs:`.

---
[Post-close correction -- 2026-09-01]: operator correction to the state
model above. There are no resolved/superseded states: a tree-outgrown entry
is marked **probation**, and a **superseded** entry (lesson already carried
by another entry or record) jumps to probation as well; from probation the
normal procedure applies -- wait for resurfacing, drop on none. The enum
stays `open | probation | mitigated` (state order); the probation comment
now reads "durable fix applied, or the tree has outgrown the entry"; the
drop sentence references probation, not resolved/superseded.
