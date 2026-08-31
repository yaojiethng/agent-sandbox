# Handover — 20260831-06-design session identity prefactor

**Status:** Closed
**Iteration:** 20260831-06
**Type:** design
**Milestone:** M2.6 - Session Persistence
**Predecessor:** 20260831-05 (impl) — prune container-status reporting + label Finding (closed, released)

## Scope re-orientation (operator direction, same session)
The iteration opened targeting the prune **label-reliability** fix, but partway
through investigation the operator redirected: **write a design document first**
because the change will span multiple sessions. The requested prefactor:

> Do we still need `sandbox_id`, if `session_id` is a much more effective
> identifier? Are we doing superfluous hash operations? Does hashing
> `sandbox_dir` too early lose valuable data (multiple path representations
> can point to one folder)?

This handover now tracks the **identity prefactor investigation + design doc**.
The prune label-reliability implementation is deferred until the identity
model settles (they are coupled).

## Design document
devlog/discussions/20260831-design-active-session_identity_prefactor.md

## Accepted direction (from 20260831-05)
- **Do NOT** reintroduce docker name-pattern matching (ambiguous across
  sandboxes; not durable under multi-`SANDBOX_DIR`).
- Do not shift to `docker system prune` (would delete kept sessions' volumes).
- One-time host-side `docker system prune -a --volumes -f` (operator runs it by
  hand) clears the current leftovers.

## Scope
- IN (this iteration): **design investigation + document** — settle whether
  `sandbox_id` is still needed, whether `session_id` is a more effective
  identifier on its own, and whether hashing `sandbox_dir` too early loses
  identity data under multiple path-representations. Deliverable is the design
doc `devlog/discussions/20260831-design-active-session_identity_prefactor.md`.
- DEFERRED (until identity model settles): the prune label-reliability
  implementation from the original scope (relabel resources, canonicalization,
  Rule 2 discovery key alignment).
- OUT: reverting the output-suppression change (20260831-05); reintroducing
  name-pattern matching; changing prune selection logic.

## Carried forward
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template +
  duplicate-ID); image-digest tracking (decided, deferred).
- Deferred label-reliability fix (Rule 2 discovery key per identity model).

## Acceptance criteria
- AC1: Investigation answers the prefactor question with evidence — is
  `sandbox_id` a dead intermediate, superfluous hash, lossy early hash?
  **DONE — all three confirmed. `sandbox_id` is a dead intermediate (sole
  functional consumer = `session_id_derive` at fresh start; resume derives then
  discards). Double hash superfluous. Un-canonicalized path hash is lossy.**
- AC2: Design doc written with established sections and reads-ready status.
  **DONE — `devlog/discussions/20260831-design-active-session_identity_prefactor.md`**
- AC3: Design recommended a direction with rationale.
  **DONE — Option B: one hash
  `sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[0:6]`; drop `sandbox_id`**

## Operator resolutions (20260831)
1. **Migration: forward-only.** No back-compat code — all sessions but the live
   one pruned. Resume never re-derives `SESSION_ID` (reads `SESSION_ID_ARG` off
   the record filename), so the live session's identity is untouched.
2. **Canonicalize = absolute path** (`readlink -f`/`realpath`). Unresolvable
   `SANDBOX_DIR` → **fail loudly** (it breaks start/resume anyway).
3. **Keep `HOST_HEAD_SHA` in the hash** — reconstructs intended
   session→sandbox-state coupling, and disambiguates same-folder-same-second
   starts across commits. Option C (drop it) withdrawn.

## Hot files
- Design doc: `devlog/discussions/20260831-design-active-session_identity_prefactor.md`
- Evidence sources: `src/libs/session_env.sh`, `scripts/start_agent.sh`,
  `scripts/resume_agent.sh`, `docs/concepts/sandbox_identity.md`,
  `docs/concepts/sandbox_host_correspondence_model.md`.

## Findings
- **`sandbox_id` is a dead intermediate.** Its only functional consumer is
  `session_id_derive` at fresh start (`start_agent.sh:187`). It is derived but
  never read in `resume_agent.sh:259`; appears in no compose label, image name,
  stop/prune filter, or Docker artifact. Debug echo (`start_agent.sh:313`) is
  unparsed.
- **Superfluous double-hash:** `sandbox_id = sha256(DIR:HEAD)[:8]` then
  `session_id = sha256(TS:SANDBOX_ID)[:6]` — two SHA-256 rounds, two truncated
  digests, one ident.
- **Lossy early hash:** `sandbox_dir` has many spellings for one folder
  (absolute, `~`, symlink, trailing-slash, relative). Each spelling yields a
  distinct `sandbox_id` → distinct `session_id`, though they are the same
  folder. But `session_id` is what names containers/labels/registry/artefacts;
  and prune filters by `sandbox-dir` label (spelling at creation) vs invocation
  spelling → mismatch → the hang observed.
- Root cause recorded in 20260831-05: leftover volumes/resources carry
  inconsistent/absent `agent-sandbox.*` labels, invisible to label-only Rule 2.

## Completed
- Inventoried every `SANDBOX_ID` consumer across repo — confirmed it's a dead
  intermediate (sole consumer `session_id_derive` at fresh start; resume
  derives then discards; no label/image/filter/path consumer).
- Confirmed the double-hash + truncation magnitudes (8-then-6; two SHA rounds).
- Read identity model docs (ADR 20260722, sandbox_identity.md,
  hash-based design 20260423) for intended roles.
- Verified resume reads `SESSION_ID_ARG` off the record (no re-derivation) —
  basis for forward-only migration.
- Verified `readlink -f`/`realpath` return canonical absolute paths.
- Opened this handover and the design doc; settled Option B with operator
  resolutions (forward-only, absolute canonicalization + loud failure, keep
  `HOST_HEAD_SHA` folded).

## Deferred items
- (none new)

## Status
**Design settled (Option B); awaiting operator release to close this design
iteration.** The ADR for the identity change is written per adr_policy during
the **implementation** session (the policy requires an ADR when a decision
results in implemented code; implementation is a separate iteration).

## What's Next
Follow-on iteration: implement Option B (single canonical hash, drop
`sandbox_id`), then the deferred prune label-reliability fix. Write the ADR up
and settle the roadmap entry that the care deliverables roll into.
Watch-outs: dual-grep bridge; full-tree close-out greps.