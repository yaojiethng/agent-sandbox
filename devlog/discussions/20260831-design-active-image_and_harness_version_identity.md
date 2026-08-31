# Design — Image and Harness Version Identity

**Status:** active (decision exploration not yet settled)

This document is a **stub** created to record the design space opened by the
story [`20260831-story-active-image_and_harness_version_identity.md`](20260831-story-active-image_and_harness_version_identity.md).
It is populated with the constraints already fixed by the story and the candidate
options known from the codebase. **The Decision and full Consequence analysis are
explicitly out of scope for the session that created this stub** — the design is
to be reasoned through and settled in the next session, then recorded as an ADR.

---

## Context

The harness runs its own software as three independently-drifting copies —
container image content, git worktree checkout, and host installed CLI — none of
which carries a serializable, monotonically increasing version. The absence of a
version identity prevents exact-resume, silently absorbs host checkout drift,
and has produced a ladder of partial remedies (`container-sig`, `harness-sig`,
`image-sig`, `[IMAGE_STALE]`) that sign sparse file subsets and treat staleness
as the defect rather than the gap under it. This design must choose a version
mechanism that satisfies the story's Constraints for all three surfaces.

The story fixes the requirements; this design fixes the *how*.

## Requirements (from the story, fixed)

1. Serializable and monotonic (comparable, storable without re-deriving).
2. Project- and format-agnostic.
3. Low-ceremony user-facing versions (derivable, not hand-bumped).
4. Identifies actual image content (base image + runtime + deps + harness), not
   a hand-picked source subset.
5. Stored in the session record, readable docker-free at list time.
6. Exact-resume capable; older-but-working image content stays addressable.
7. No back-compat code for old records (forward-only migration).
8. Harness host surface (installed CLI / checkout drift) included.

## Options Considered

### Option A — Docker digest as the image-surface version (`<repo>@sha256:`)

Per-image immutable content address over the whole built artifact (config +
every layer). Closes the `container-sig` leak (base image, runtime, deps all
covered). Store in the record at start/resume (docker already present there);
resume references the exact digest; docker keeps the content addressable until
GC'd.

- Trade-offs: docker-native (not resolvable from source alone); a digest is
  not human-friendly; only addresses the *image* surface — the worktree and
  host surfaces need their own mechanism.
- How staleness might work: "newer image available" = the digest a fresh build
  would produce differs from the recorded one — but that is only knowable at
  build time (you cannot diff a digest against source). This is the open
  question the next session must resolve (retain a source hash for the
  staleness signal, or drop staleness).

### Option B — Content hash of the harness source subset (current `container-sig`)

What exists today. Cheap, docker-free, project-agnostic.
- Trade-offs: **inadequate per the story** — signs a fixed subset, misses
  base/runtime/dependency content, not a comparable version. Retained only as a
  candidate where the surface is genuinely source-only (host/checkout), not for
  the image surface.

### Option C — Semantic versioning (hand-bumped `VERSION`)

The textbook "serializable increasing version".
- Trade-offs: conscious bump discipline on every meaningful change — the exact
  ceremony the story says operators want to avoid; easy to forget (that is the
  origin of the staleness bugs). Likely rejected for the *user-facing* surface;
  possibly retained as a thin human-readable label on top of a derivable
  signature.

### Option D — Composition (recommended to explore)

A content-addressed identity (digest for the image surface; a source hash for
the worktree/host surfaces) plus, optionally, a derived human-readable short
form. This is the likely synthesis the next session should evaluate against the
story's Constraints, including whether staleness survives as a distinct signal.

## Decision

*(Pending — out of scope for this session. The next session selects among the
options above or a refinement, records rationale, and writes the ADR.)*

## Consequences

*(Pending — to be completed with the Decision. Anticipated dimensions: record
schema change (which fields carry the version(s)); resume image-resolution;
image retention/GC and prune scope; retirement or downgrade of the `[IMAGE_STALE]`
marker and `record_image_stale` (and its O(n×2) docker cost); whether `container-sig`
keeps any role; terminology/name cleanup (`image-sig` vs `container-sig` vs
`digest`).)*