# ADR — Version Identity for Image, Worktree, and Host Surfaces

**Status:** settled

> **Note:** settled here means "decision made and recorded". The implementing
> iteration (record fields, dry-run digest roundtrip, container-sig transition)
> is a separate follow-up; the roadmap task remains open until that lands. See
> the Deferred section and the handover `20260901-02-design-harness_version_identity.md`.

## Summary

Give the harness a single version model across its three independently-drifting
copies: the image content (a docker digest per image), the worktree (a plain
`$REPO_ROOT` git HEAD SHA, absorbed into the interface-contract thread, no
record field), and the host CLI (symlink install — no separate version by
construction). Retire the freshness/staleness signal; reframe `container-sig` as
the interim leaky implementation of the deferred interface-contract check.

## Context

The harness runs its own software as three copies that drift independently, none
carrying a serializable, increasing version: container image content, git
worktree checkout, host installed CLI. The absence of a version prevents
exact-resume, silently absorbs host checkout drift, and produced a ladder of
partial remedies (`container-sig`, `harness-sig`, `image-sig`,
`[IMAGE_STALE]`) that sign sparse file subsets and treat staleness as the defect
rather than the gap under it. Grounded by the story
[`20260831-story-active-image_and_harness_version_identity.md`](../../devlog/discussions/20260831-story-active-image_and_harness_version_identity.md)
(`Resolved`), which fixed the requirements and problem frame.

The design space opened by the story was stubbed in
[`20260831-design-active-image_and_harness_version_identity.md`](../../devlog/discussions/20260831-design-active-image_and_harness_version_identity.md)
and settled via the design grill this iteration.

## Options Considered

### Image surface
- **Docker digest** (`<repo>@sha256:`) — content-addresses the whole built
  artifact (config + every layer: base image, runtime, deps, harness). Closes the
  `container-sig` leak. Docker-native; a digest is only knowable post-build, and
  is not human-friendly — but it is stored (docker-free readable) in the record
  and is exact-resume capable. **Adopted.**
- Both image subset hash (`container-sig`) and semantic versioning as image
  version were rejected: the subset hash leaks by design; semver adds the
  hand-bump ceremony the story says to avoid.

### Worktree / host surfaces
- Plain git HEAD SHA, `git describe`, and semantic version.
- Plain `$REPO_ROOT` HEAD SHA is the natural zero-ceremony "which copy of my own
  source" identity. **Adopted as the worktree concept**, but **not recorded as a
  record field** — image identity is fully carried by the digest, and the harness
  source version is a contract-compatibility concern absorbed into the deferred
  interface-contract thread (over the subsets the container actually consumes,
  not a full-repo HEAD).
- Host CLI: the current copy-install (`make install` sed-bakes the repo path into
  a thin dispatcher) creates a *false* independent artifact. **Adopted: symlink
  install** with a self-locating dispatcher, so the installed CLI *is* the
  worktree file — no independent version to record; drift is impossible by
  construction. Semantic versioning is **deferred** to the full-packaging
  milestone (self-contained snapshot install), where a genuine independent
  artifact first appears.

## Decision

1. **Image surface version = docker digest**, recorded per image in the session
   record as `agent-sandbox.agent-image-digest` and
   `agent-sandbox.sandbox-image-digest`. Forward-only; no back-compat.
2. **Worktree surface** = plain `$REPO_ROOT` git HEAD SHA, carried conceptually
   into the deferred interface-contract thread; **no record field for it**.
3. **Host surface = symlink install** (self-locating dispatcher); no separate
   version; semver deferred to the full-packaging milestone.
4. **Freshness signal retired.** `[IMAGE_STALE]` / `record_image_stale` /
   `image_is_stale` list-time usage is removed (kills the 2×N docker-inspect
   cost). A fresh digest is only knowable post-build, so "newer image available"
   is not a list-time property; the recorded digest is exact identity.
5. **Dry-run** always builds/runs current source; its correct-container gate is a
   **digest roundtrip** (running image's repo-digest == just-built-from-current
   source digest) alongside structural phase-3 record verification, replacing
   the `container_sig` recompute. `--fast`/headless is deferred to the dry-run
   refactor scope.
6. **`container-sig` reframed as the interim leaky implementation of the deferred
   interface-contract check** — NOT retired. After symlink install, host-side
   computes it, the container records it; combined they give a binary
   exact-match check (leaky: exact-match only, no back-compat/range; warns on
   mismatch, current behavior). Scoped for deletion once a redesigned
   interface-contract implementation lands.
7. **Digest-less image is a hard error** (no `unknown -> FAIL` fallback): the
   no-sig case was a container-sig-migration hangover; all images must bear a
   digest/sig. A temporary double-check runs while moving to digest, then is
   removed.

## Consequences

### Positive
- **Exact image identity** now recorded docker-free and readable at list time —
  closes the `container-sig` leak (whole artifact vs source subset).
- **`resume LIST` slowness removed** — the 2×N docker-inspect staleness scan is
  gone.
- **Host drift impossible by construction** under symlink install.
- **Dry-run becomes a truthful e2e of current source** — no staleness stopgap.
- **Single version model** across all three surfaces, with semver deliberately
  bounded to the future packaging milestone.

### Negative / accepted trade-offs
- **Digest is not human-readable or build-time-comparable** — "newer available"
  is genuinely not knowable without building; accepted as the correct scoping.
- **Forward-only migration, no back-compat** — older records (two-sig / project
  `host-head-sha` only) do not decode under the new scheme; consistent with prior
  identity migrations.
- **container-sig remains as a leaky exact-match contract check** until the
  redesigned interface-contract lands — incomplete but intentional, and
  explicitly scoped for deletion.
- **Symlink install changes rollback character** — rollback is now
  `git -C $REPO_ROOT checkout <sha>` (same as worktree); no separate pinned
  artifact.

### Constraints evaluation (all 8 from the story)

1. **Serializable and monotonic** — digest and git HEAD SHA are both serializable;
   comparable via ancestry/equality. ✔
2. **Project- and format-agnostic** — digest and git SHA work for any project,
   with or without semver-tagged deps (no reliance on semver). ✔
3. **Low-ceremony user-facing version** — digest + HEAD SHA are derivable, not
   hand-bumped. ✔ (semver deliberately deferred, not adopted here)
4. **Identifies actual image content** — digest covers the whole built artifact
   (base + runtime + deps + harness), closing the `container-sig` leak. ✔
5. **Stored in the record, docker-free readable** — digests are stored as labels;
   list reads them without docker. ✔
6. **Exact-resume capable** — resume references the recorded digest; older-but-working
   content stays addressable until GC. ✔
7. **No back-compat code for old records** — forward-only; digest-less old records
   refuse loudly on resume. ✔
8. **Harness host surface included** — symlink install makes the host CLI the
   worktree (no independent drift); semver deferred to packaging milestone. ✔

## Supersedes

Partial — replaces the image-identity marking claim in
[`20260722-adr-settled-session_identity_and_container_markers.md`](../../docs/adr/20260722-adr-settled-session_identity_and_container_markers.md)
("images carry no version; name tags encode harness identity") and additively
extends its marker/label schema with the two image-digest labels. The
session-identity derivation (superseded separately by
`20260831-single_canonical_session_identity`) and the label-based lifecycle
filtering decisions of `20260722` remain in force and are **not** subsumed.

## Deferred (not subsumed, not decided)

- **Interface-contract compatibility** — the real need behind the retired
  freshness signal: two co-resident harness copies speaking the same shape.
  Distinct design thread; container-sig is its interim implementation.
- **Source fingerprint** — deferred to the full-packaging milestone (challenges:
  manual file list, host/container file-set differences, doc-edit false
  positives).
- **Semantic versioning for host installs** — deferred to the full-packaging
  milestone (where a genuine independent installed artifact appears).
- **Dry-run `--fast` / headless mode** — deferred to the dry-run refactor scope.

## Terminology

Uses `agent-sandbox` session identity without redefining it: session identity is
governed by [terminology.md#session](../concepts/terminology.md#session) and the
session-identity ADRs, and is orthogonal to this software-version model.