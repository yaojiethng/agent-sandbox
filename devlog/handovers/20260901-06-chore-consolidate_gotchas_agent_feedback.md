# Handover 20260901-06 — chore consolidate gotchas and agent-feedback entries

**Milestone:** M2.6 - Session Persistence
**Type:** chore
**Status:** Closed
**Session date:** 2026-09-01

## Objective

Sweep `devlog/GOTCHAS.md` and `devlog/AGENT_FEEDBACK.md` and consolidate
entries that record the same or the same-family pattern, so the loaded
session-open surface shrinks without losing any lesson. Single `chore:`
delivery commit.

## Scope

- Within-file consolidation of duplicate/family entries (map below).
- State corrections where consolidation changes monitoring status.
- Structure questions resolved with operator before writing.

Out of scope: state cleanups unrelated to consolidation (e.g. deleting
mitigated entries pending durability confirmation); GOTCHAS sweep triggers
(dual-grep 30-handover check); folding patterns into skills (preamble says
that is a separate durable-fix decision).

## Consolidation map (applied per D1–D5)

AGENT_FEEDBACK.md:

- C1: merge `[A] 2026-08-10 git checkout normalized stub mode...` into
  `[A] 2026-08-10 git restore wiped uncommitted session work` (the latter
  already generalizes the former via `legacy:`) → one entry: git operations
  touching index/worktree revert uncommitted work.
- C2: fold `[A] 2026-08-18 Asserted "recorded" for a decision before the row
  landed` into `[A] 2026-08-09 A "did the write land?" reflex` (assert-
  without-write is an instance of verify-the-write-landed).
- C3: merge the two mid-session-findings entries (`duplicate-entry churn`,
  `under-recorded during edit-heavy`) → one recording-discipline entry.
- C4: fold `[A] 2026-09-01 Manual column-wrapping` into the `[A] 2026-08-09
  Hard-wrapped instruction blocks` entry (declared resurfacing of it); set
  the probation entry's state to `open` (resurfacing confirmed).
- C5: Bash section: merge `grep -c` entry into the `|| true` entry (its own
  text proposes pairing as an expected-failure-commands family).

GOTCHAS.md:

- C6 (resolved by Q1a): no within-file GOTCHAS duplicates; cross-file
  duplicates/family entries kept in place with bidirectional cross-
  references (GOTCHAS `2026-08-18` ↔ AF write-land; GOTCHAS `2026-09-01` ↔
  AF hard-wrapped).

## What's Next

- Closed after operator pre-authorized the `chore:` delivery commit; next
  suggested iteration remains the version-identity implementation (roadmap
  line 158).

## Acceptance Criteria

- AC1: Consolidation map applied per operator answers; no lesson lost
  (every dropped entry's content is carried by its merge target).
- AC2: Entry format template preserved; `legacy:`/`state:` fields updated
  where merges occur.
- AC3: Single `chore:` delivery commit; handover closed in it.

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Consolidation map C1–C5 applied as proposed | confirmed (operator) |
| D2 | Q1 → option (a): files keep separate ownership; duplicates/family entries cross-reference instead of merging across files | confirmed (operator) |
| D3 | Q2 → keep the per-session section headers (simple session list); merged entries live under the earliest originating session | confirmed (operator) |
| D4 | Q3 → delete the Bash skill cross-reference table; keep per-entry Cross-reference lines; retain one line recording the deferred skill-consolidation work | confirmed (operator) |
| D5 | Wrapping incident: AF `2026-08-09` entry state `probation` → `open` (first confirmed resurfacing, session `20260901-03`); GOTCHAS `2026-09-01` retained as the operator-side record, cross-linked | confirmed (operator via Q1a) |

## Completed

- C1: AF git-restore and git-checkout/stash entries merged into one (`git
  operations touching the index/worktree revert uncommitted session work`);
  post-edit annotation moved with it.
- C2: AF `Asserted "recorded"...` folded into the write-land entry as a
  20260818 resurfacing instance; cross-reference to GOTCHAS `2026-08-18`
  added both ways.
- C3: two AF mid-session-findings entries merged into one recording-
  discipline entry (churn + under-recording).
- C4: AF `Manual column-wrapping` (09-01) folded into `Hard-wrapped
  instruction blocks` as `resurfaced:`; state probation → open; cross-
  reference to GOTCHAS `2026-09-01` added both ways.
- C5: Bash `grep -c` entry merged into the `|| true` entry (retitled to
  expected-failure-commands family).
- Skill cross-reference table deleted; one-line deferred-work note retained;
  per-entry Cross-reference lines carry coverage.
- Entry counts: AF 33 → 28; GOTCHAS 11 (unchanged, cross-refs added). No
  orphan references; session headers intact; entry template preserved.

## Findings

- GOTCHAS `2026-08-19` dual-grep sweep trigger (newest handover index ≥30
  since 20260819) is ambiguous under daily-reset handover numbering — flag
  for the operator at the next sub-milestone cleanup, not resolved here.
