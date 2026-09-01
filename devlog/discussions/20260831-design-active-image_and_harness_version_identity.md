# Design — Image and Harness Version Identity

**Status:** settled

Mechanism decision recorded in ADR
[`20260901-adr-settled-version_identity_mechanism.md`](../../docs/adr/20260901-adr-settled-version_identity_mechanism.md).
The story [`20260831-story-active-image_and_harness_version_identity.md`](20260831-story-active-image_and_harness_version_identity.md)
fixes the requirements; this design fixed the *how*. Decision and Consequences are settled below; implementation is a follow-up iteration.

This document was created as a **stub** recording the design space opened by the
story. It is populated with the constraints already fixed by the story and the candidate
options known from the codebase. **The Decision and full Consequence analysis were
settled in the session that refined this stub (20260901-02).**

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

**(Settled 20260901-02; ADR `20260901-adr-settled-version_identity_mechanism.md`.)**

A **composition (Option D)** is adopted, per surface:

- **Image surface = docker digest** (`<repo>@sha256:`), recorded per image in the
  record as `agent-sandbox.agent-image-digest` + `agent-sandbox.sandbox-image-digest`.
  Forward-only, no back-compat; digest-less image = hard error.
- **Worktree surface = plain `$REPO_ROOT` git HEAD SHA**, carried conceptually
  into the deferred interface-contract thread — **no record field**.
- **Host surface = symlink install** (self-locating dispatcher); no separate
  version by construction; semver deferred to the full-packaging milestone.
- **Staleness retired**: no list-time image-staleness. Dry-run always builds/runs
  current source; its gate is a **digest roundtrip** + structural phase-3 record
  verification. `--fast`/headless deferred to the dry-run refactor.
- **`container-sig` reframed** as the interim leaky exact-match implementation of
  the deferred interface-contract check (not retired); scoped for deletion once a
  redesigned interface-contract lands.

## Consequences

**(Completed 20260901-02 with the Decision; see ADR.)**

- **Record schema**: adds the two `*-image-digest` labels; retires `image-sig`
  from new records; no `harness-head-sha` field. Older (two-sig) records do not
  decode (forward-only).
- **Resume**: exact-resume via recorded digest; digest-less record = refuse loudly.
- **List-time cost**: `record_image_stale`'s 2×N docker scans removed; `resume LIST`
  faster.
- **Image retention/GC**: out of the immediate scope; digest keeps content
  addressable until GC.
- **`container-sig` role**: interim contract-interface check (preflight `_check_container_sig`
  persists in that role); retired from image-version and dry-run-gate duty.
- **Terminology/name cleanup**: `image-sig` -> image-digest labels; `container-sig`
  label kept as interim contract marker; naming conventions per the ADR.