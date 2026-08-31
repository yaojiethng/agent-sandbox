# Handover — 20260831-07-impl session identity prefactor (Option B)

**Status:** Closed
**Iteration:** 20260831-07
**Type:** impl
**Milestone:** M2.6 - Session Persistence
**Predecessor:** 20260831-06 (design) — session identity prefactor, settled Option B (closed `45eceea`)

## Objective
Implement the settled identity change from the design doc. Replace the
two-stage hash (with the dead `sandbox_id` intermediate) with a single canonical
hash over all three identity factors:

```bash
SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
```

Remove `sandbox_id_derive` and its derivation sites; write the accompanying ADR.

## Contract (from design doc 20260831)
- **One hash, one truncation**, over `canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS`.
- **`HOST_HEAD_SHA` stays folded** (session→sandbox-state coupling + same-second
  collision avoidance across commits).
- **Forward-only migration** — no back-compat code. Resume reads `SESSION_ID_ARG`
  off the record filename, never recomputes, so live-session identity is untouched.
- **Canonicalize = absolute path** (`readlink -f`/`realpath`, after `~`-expand).
  An unresolvable `SANDBOX_DIR` **fails loudly** (breaks start/resume anyway).

## Scope
- IN: `session_env.sh` single canonical `session_id_derive`; `start_agent.sh`
  (drop SANDBOX_ID line + debug echo, feed canonical form); `resume_agent.sh`
  (drop dead derivation); test updates (`test_checkpoint.sh`,
  `test_start_agent.sh`, trace stubs); doc sweep (`sandbox_identity.md`,
  `sandbox_host_correspondence_model.md`); write the ADR per `adr_policy.md`.
- OUT: the deferred prune label-reliability fix (separate following iteration);
  changing prune discovery; reverting 20260831-05 output change; name-pattern
  matching.

## Carried forward
- Prune label-reliability fix (coupled-after identity model).
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template +
  duplicate-ID); image-digest tracking (decided, deferred).

## Acceptance criteria
- AC1: `sandbox_id` fully removed — no `SANDBOX_ID` references remain in
  scripts, tests, or docs.
  **DONE — `sandbox_id_derive` + derivation sites removed (start_agent,
  resume_agent); debug echo removed; trace stubs cleared; active docs swept.
  (Historical handovers/changelog remain untouched as records.)**
- AC2: `SESSION_ID` derived once, canonically; formula matches the settled
  `sha256(canon:HEAD:TS)[0:6]`.
  **DONE — `sandbox_dir_canon` + single `session_id_derive` in session_env.sh;
  `~`==absolute convergence verified; path-spelling convergence tested.**
- AC3: suite green (743/43/0 baseline), smoke green, lint clean.
  **DONE — suite 745/0/0 (43 files), lint 0 warnings/101 files, smoke 6/6.**
- AC4: ADR written; identity docs updated to single-hash model.
  **DONE — ADR 20260831-*single_canonical_session_identity; sandbox_identity.md,
  sandbox_host_correspondence_model.md swept; supersede note on ADR 20260722.**

## Hot files
- `src/libs/session_env.sh`, `scripts/start_agent.sh`, `scripts/resume_agent.sh`,
  `tests/test_checkpoint.sh`, `tests/test_start_agent.sh`,
  `tests/test_trace_{start,resume,compose_gen,dry_run}.sh` (stubs),
  `docs/concepts/sandbox_identity.md`,
  `docs/concepts/sandbox_host_correspondence_model.md`, new ADR in `docs/adr/`.

## Findings
- (design doc) `sandbox_id` is a dead intermediate; double hash superfluous;
  un-canonicalized path hash is lossy (spelling-of-folder not folder).

## Completed
- `session_env.sh`: added `sandbox_dir_canon`; replaced `sandbox_id_derive` +
  `session_id_derive` with a single canonical `session_id_derive`
  (`sha256(canon:HEAD:TS)[:6]`).
- `start_agent.sh`: dropped the `SANDBOX_ID` derive + debug echo; pass
  `(SANDBOX_DIR HOST_HEAD_SHA SESSION_TS)`.
- `resume_agent.sh`: removed the dead `SANDBOX_ID` derivation (record id used).
- Tests: rewrote `test_checkpoint.sh` (8 tests incl. path-spelling convergence +
  `sandbox_id` removal + no-inline-pipeline guard); updated `test_start_agent.sh`
  SESSION_ID block (3 tests) + run list; cleared `SANDBOX_ID` stub exports from
  the 4 trace stubs.
- Docs: swept `sandbox_identity.md`, `sandbox_host_correspondence_model.md`,
  `bash-coding-conventions.md`, `project_index.md` to single-hash model.
- ADR: wrote `20260831-*single_canonical_session_identity`; supersede note on
  ADR `20260722-*session_identity`.
- Roadmap: recorded completion entry.
- Verification: suite 745/0/0, lint 0 warnings/101 files, smoke 6/6.

## Deferred items
- (none new)

## What's Next
After this impl, the prune label-reliability fix (identity model now unambiguous).
Watch-outs: trailing-whitespace in the semantic commit message; dual-grep bridge;
full-tree close-out greps.