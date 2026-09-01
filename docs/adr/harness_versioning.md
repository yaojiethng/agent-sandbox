# Harness Versioning

**Current:** 2026-09-01

## 2026-09-01 -- Per-surface version semantics: digest, HEAD, symlink

**Decision:** The harness's three independently-drifting copies each get a version identity matched to what the copy actually is:

1. **Image surface = docker digest** (`<repo>@sha256:`), recorded per image in
   the session record as `agent-sandbox.agent-image-digest` and `agent-sandbox.sandbox-image-digest`. Forward-only; no back-compat. A digest-less image is a hard error (no `unknown -> FAIL` fallback); a temporary double-check runs while moving to digest, then is removed.
2. **Worktree surface = plain `$REPO_ROOT` git HEAD SHA**, carried
   conceptually into the deferred interface-contract thread; **no record field** — image identity is fully carried by the digest.
3. **Host surface = symlink install** (self-locating dispatcher); the
   installed CLI *is* the worktree file, so no independent version exists by construction. Semantic versioning is deferred to the full-packaging milestone, where a genuine independent installed artifact first appears.
4. **Freshness signal retired**: `[IMAGE_STALE]` / `record_image_stale` /
   `image_is_stale` list-time usage removed (kills the 2×N docker-inspect cost). A fresh digest is only knowable post-build, so "newer image available" is not a list-time property; the recorded digest is exact identity.
5. **Dry-run** always builds/runs current source; its correct-container gate
   is a digest roundtrip (running image's repo-digest == just-built digest) alongside structural phase-3 record verification, replacing the `container_sig` recompute.

**Rationale:** None of the three copies carried a serializable, comparable version, which blocked exact-resume, silently absorbed host checkout drift, and produced a ladder of partial remedies (`container-sig`, `harness-sig`, `image-sig`, `[IMAGE_STALE]`) that signed sparse file subsets and treated staleness as the defect rather than the gap under it. Docker digest content-addresses the whole built artifact (config + every layer: base image, runtime, deps, harness), closing the subset-signature leak; git HEAD is the natural zero-ceremony "which copy of my own source" identity; symlink install removes the host copy as a distinct artifact. Grounded by the story [`20260831-story-active-image_and_harness_version_identity.md`](../../devlog/discussions/20260831-story-active-image_and_harness_version_identity.md) (Resolved); design settled via the grill in [`20260831-design-active-image_and_harness_version_identity.md`](../../devlog/discussions/20260831-design-active-image_and_harness_version_identity.md).
The story's eight constraints (serializable/monotonic, project-agnostic, low-ceremony, identifies actual image content, docker-free readable, exact- resume capable, no back-compat, host surface included) are all satisfied by this mechanism set.

**Rejected alternatives:**
- *Container-sig-style subset hash as image version* — leaks by design: signs
  only the source file subset, not base image/runtime/deps.
- *Semantic versioning as image version* — adds the hand-bump ceremony the
  story's constraints forbid; a digest is derivable, not hand-bumped.
- *Source fingerprint across host and container* — deferred to the
  full-packaging milestone (challenges: manual file list, host/container file-set differences, doc-edit false positives).
- *Keeping the freshness/staleness signal* — detects drift it cannot address;
  see [drift_state_coherence.md](drift_state_coherence.md) for why minimisation replaced detection as the governing principle.

**Edge cases / drivers:** `make resume LIST=1` slowness (2×N docker inspects); silent host-CLI drift under the sed-baked copy-install; dry-run truthfulness as an e2e of current source; digest is not human-readable or build-time-comparable — accepted, since "newer available" is genuinely unknowable without building. Under symlink install, rollback character changes: rollback is `git -C $REPO_ROOT checkout <sha>`, same as the worktree. Implementation is a separate follow-up (roadmap line: harness version identity); until it lands, `container-sig` behavior is current and described in [sandbox_identity.md](../concepts/sandbox_identity.md#container-sig-image-staleness-detection).
This ADR is orthogonal to the [session identifier](session_identifier.md) — that governs project/session identity, this governs the harness's own software-version model.
