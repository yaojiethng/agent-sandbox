# Handover — 20260831-03-docs context-knowledge-light naming convention

**Status:** Closed
**Iteration:** 20260831-03
**Type:** docs (markdown-only)
**Milestone:** M2.6 - Session Persistence
**Operator task:** the "naming-conventions fold" — write the recurring **contextual-knowledge-light naming** principle (and its STE100/exception-only family) into a canonical conventions doc, instead of leaving it as an ad-hoc per-iteration habit.

## Objective
Fold the contextual-knowledge-light naming principle — carried as a standing escalation since `20260828-02` — into `docs/development/interface-conventions.md` as a written convention, so future naming follows a documented rule.

## Scope
- IN: new convention section in `docs/development/interface-conventions.md`; index/cross-reference touch-ups if needed.
- OUT: `AGENTS.md` changes (holds process rules, not interface naming); code changes; new feature behavior.

## Carried forward
- This is the naming-conventions fold (deferred at every iteration end since `20260828-02`). Standing after this: SERVE mode integration (roadmap), Bug E (`make stop` template + duplicate-ID), image-digest tracking (decided, deferred).

## Acceptance criteria
- AC1: `interface-conventions.md` documents the contextual-knowledge-light naming principle (textual/self-describing over numeric/opaque).
- AC2: Documents the exception-only / snap-decision display pattern (headers as vehicle) as a convention.
- AC3: Terms followed-convention (STE100, reserved-term linking to `terminology.md` on first use if applicable).
- AC4: Suite + lint still clean (docs-only; no code change).

## Hot files
- `docs/development/interface-conventions.md`, `docs/development/conventions.md` (index).

## Findings
- Audit of this session's changes (54d26d6 + f440a72) against the new principles: largely compliant. Single genuine violation — `PROVIDER (SIG)` header in `resume_agent.sh --list`: `SIG` is an opaque abbreviation (principle 1) and does not align with the `image-sig` field it describes (principle 3). Other this-session names (`[SANDBOX_STALE]`/`[IMAGE_STALE]`, `last_started`/`last_stopped`, `image-sig` record label, `image_sig`/`short_sha` vars, `LAST_USED`/`STARTED`/`BRANCH`/`SESSION_ID` headers, `relative_time`/`ts_to_epoch`/`session_log_*`) are self-describing and aligned — no fix needed.

## Completed
- `docs/development/interface-conventions.md`: added section 11 (Contextual-Knowledge-Light Naming and Value Disambiguation) — STE100, no transient references; three principles (self-describing names over opaque tokens; disambiguate repeated values with a descriptive header / warning-tag-beside-value, a tag being one mechanism not the only one; keep internal variable names descriptive and aligned with the value for the maintainer).
- `docs/development/conventions.md`: index row notes the naming content.
- Cleanup sweep (this-session only): `scripts/resume_agent.sh` `--list` header `PROVIDER (SIG)` → `PROVIDER (IMAGE-SIG)` (the sole this-session violation).
- Suite **737/43/0**, lint 0 warnings / 100 files.

## Deferred items
- None new. Standing: SERVE mode integration (roadmap), Bug E (`make stop` template + duplicate-ID), image-digest tracking (decided, deferred).

## What's Next
M2.6 - Session Persistence. The contextual-knowledge-light naming fold is delivered: the principle is now a written convention (interface-conventions.md section 11), the single this-session violation (PROVIDER (SIG) header) is swept, and no AGENTS.md/governance change was needed.
Standing: SERVE mode integration (roadmap), Bug E (`make stop` template + duplicate-ID), image-digest tracking (decided, deferred).
Watch-outs: dual-grep bridge; full-tree close-out greps.