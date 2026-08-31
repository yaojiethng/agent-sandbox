# Story — Image and Harness Version Identity

**Status:** Resolved

The mechanism decision (semantic-versioning vs content-hash vs docker-digest) is
scoped to the design document [`20260831-design-active-image_and_harness_version_identity.md`](20260831-design-active-image_and_harness_version_identity.md)
(created this session as a stub, to be refined and settled in the next session).
This story constrains that design: it fixes the requirements the design must
satisfy and the problem frame, and it retires the prior, inadequate solutions.
Problem framing and requirements are complete; the mechanism selection is
staged out of this story.

---

## Context

The agent-sandbox harness runs its own software as three separate copies that
drift independently, yet none of them carries a serializable, monotonically
increasing version:

1. **Container image content** — the harness sources (`libs/`, capability
   layer, reasoning layer) baked into the sandbox and agent images at build
   time, plus the base images and dependency versions those lock in.
2. **Git worktree content** — the source checkout the images are built from and
   the installed host CLI reads from.
3. **Host installed CLI** — `make install` drops a dispatcher that `exec`s the
   live checkout at every invocation; it has no version of its own and silently
   tracks whatever the checkout holds after any `git pull`.

Because there is no serializable version on any of these surfaces, the harness
cannot say, for any artefact or session, *which copy of itself produced it*.
Every "version-mismatch" symptom in the system — image staleness markers, the
`[IMAGE_STALE]`/`[IMG-STALE]` list columns, `record_image_stale`'s repeated
docker inspects, the preflight rebuild warnings, silent host-drift after a pull —
is a manifestation of this single absence. This story reframes those as one
problem so they stop being fought as unrelated defects.

## Pain Points

**No serializable version on any of the three surfaces.** Neither the images,
the checkout, nor the installed CLI exposes an increasing, comparable version.
Consequence: no way to pin a session to a known-good harness state, to rewind to
an image that matched a specific source, or to detect (rather than silently
absorb) a host checkout drift.

**`container-sig` signs only a subset of the real image.** `container_sig()`
hashes a fixed harness source list (sandbox: `src/libs`, capability
entrypoint/snapshot, `docs/architecture`, `docs/concepts`; agent: those +
provider + skills). It does **not** cover the base image tag, the node/runtime
version, or installed dependency versions and their transitive resolution — all
of which change agent runtime behavior. So the image's "signature" omits real
content that ends up in the running container. This is a genuine leak, and it is
why `container-sig` cannot be the image version.

**Two signatures from two file subsets, neither a version.** Because the
container and the host consume different subsets of the repo, the model ended up
with two hashes — `container-sig` (image sources) and `harness-sig`
(scripts + provider setup, deferred). They are not a version of anything; they
are two partial fingerprints over two disjoint file lists, with no shared
ordering, no monotonicity guarantee, and no stable reference to the content they
sign afterward.

**`image-sig` duplicates `container-sig` in the record without adding version
semantics.** `compose_generate` copies the agent image's `container-sig` label
into the record as `agent-sandbox.image-sig` so `--list` can show `pi
(<short-sig>)` docker-free. It is the same hash moved location; it does not
answer "which exact image does this record correspond to" and it does not cover
the sandbox image at all.

**Staleness is a symptom, not the problem.** The `[IMAGE_STALE]` marker and the
preflight warning exist only because we cannot name image versions. A "stale"
image is not, on its own, broken — it is simply *a newer build exists*. The
concept of staleness appeared because forgetting to bump harness versions after
editing core executables produced bugs, and because the host CLI reads the live
checkout (so a pull can change what a session runs without any signal). Treating
staleness as the defect has led to repeated, reactive patches — the repeat
docker inspections, the staleness markers, the digest-deferral — none of which
fix the versioning gap underneath.

**The host installed CLI has no version surface at all.** `make install` runs
`sed 's|@@AGENT_SANDBOX_REPO@@|<repo>|'` over `scripts/agent-sandbox.sh` into
`~/.local/bin/agent-sandbox`; every subcommand then `exec bash
"$AGENT_SANDBOX_REPO/scripts/…"`. The installed binary is a thin dispatcher whose
real code drifts silently with the checkout. This is the harness-sig /
host-packaging thread; it is not a separate problem, it is the host-surface
branch of the same root issue.

**Versioned-image desire is a versioning need, not a staleness need.** The
operator named a concrete case: a bad HEAD that the operator wants to rewind
away from. That is "make the session use the image content that matched a
specific known-good source" — a version-pinning need. Staleness language does
not carry it.

## Constraints

Any reconciled solution must satisfy all of the following.

- **Serializable and monotonic.** There must exist a representation of each
  surface's version that is comparable (can say older/newer or different/same)
  and can be recorded in a file or record without re-deriving it from docker or
  from the source tree.
- **Project- and format-agnostic.** Must work for any project, with or without
  semantic-version-tagged dependencies — which is why the original design leaned
  on content hashing over semver.
- **User-facing versioning must be low-ceremony.** Where a human-visible version
  is needed, it must be derivable, not a manually-bumped field.
- **Identifies the actual image content.** The image-surface version must cover
  the whole built artifact (base image, runtime, dependencies, harness), not a
  hand-picked source subset — closing the `container-sig` leak.
- **Stored in the record, readable docker-free.** The session `.yml` must carry
  the version(s) so `--list` and inventory reads do not require docker at list
  time.
- **Exact-resume capable.** Resume must be able to reference the exact image
  content the session was created with, or else document loudly that it will
  rebuild. Older-but-working image content must remain addressable (not silently
  overwritten into history).
- **No back-compat code for old records.** Existing `.compose/*.yml` records
  predating the change are not re-read under the new scheme; migration is
  forward-only (consistent with earlier identity migrations).
- **Harness host surface included.** The installed-CLI / checkout drift must be
  addressable under the same version model, not left as a permanently separate
  never-done thread.

## Why the prior solutions are inadequate (subsumption)

- **`host-head-sha`.** Works because git serializes and because it served a
  narrow need (sandbox state). It records the *host project* state, not the
  harness's own software version; not sufficient as a harness-version identity.
- **`container-sig` / `harness-sig` (the two-sig model).** Premised on hashing
  disjoint file subsets. Both leak (harness subsets ≠ real image content; no
  host subset was ever implemented for the dispatcher), and neither yields a
  comparable version. Their names (`container-sig`, `harness-sig`, `image-sig`)
  are also not accurate for what they sign.
- **`[IMAGE_STALE]` / `record_image_stale` markers.** Treat the symptom. The
  repeated docker inspects and the docker-dependency at list time are a direct
  cost of not storing a version in the record.
- **Digest-deferral (`20260831-02`).** Filed "surface the digest in the list" as
  docker-only, marginal-value — the narrow framing made it look optional. The
  underlying need (a content address that can survive as identity) is the
  correct primitive, and this story reopens it at the root.

## Equivalence with the design doc

This story hands the design doc a fixed problem frame and requirement set:
- **Requirement set:** the Constraints above; the design must pick a mechanism
  satisfying them for each of the three surfaces.
- **Deferred to design (this session: stub, next session: settle):** whether the
  version mechanism is semantic versioning, a content hash, the docker digest,
  or a composition — and whether, once image identity is content-addressed, the
  staleness marker is retained, downgraded, or retired.

## Investigation Findings

- `make install` produces a dispatcher in `~/.local/bin/agent-sandbox` that
  `exec`s the live checkout (`Makefile install:` + `scripts/agent-sandbox.sh`).
  Confirmed: the host CLI has no version surface and tracks the checkout.
- `container_sig()` covers only a fixed harness source subset per layer
  (`src/libs/container_sig.sh` `_sandbox_sig_sources` / `_agent_sig_sources`).
  Confirmed: dependency/base/runtime versions are not part of any signature.
- `container-sig` is baked as a docker label at build time
  (`scripts/build.sh` `--label "agent-sandbox.container-sig=…"`); `image-sig` is
  that label copied into the record by `compose_generate`
  (`src/build/compose.sh`, `{{IMAGE_SIG}}`); the sandbox image has no `image-sig`
  in the record (docker-compose.yml lists `agent-sandbox.image-sig` only).
- `record_image_stale` (`src/libs/session_inventory.sh`) calls `image_is_stale`
  twice per record (agent + sandbox), each a `docker image inspect` via
  `image_baked_sig` (`container_sig.sh`); with N records on identical images this
  is 2×N docker CLI invocations — the observed `make resume LIST=1` slowness.
- The deferred digest-tracking decision (`20260831-02`) framed digest as
  "docker-only, marginal value over image-sig", which understated its role as a
  content-address identity primitive.
- The prior session-identity work (`20260831-06/07`, ADR `20260831-*`) settled
  **session** identity (`SESSION_ID`) and is orthogonal: it identifies the
  *session*, not the *software* version that produced it. It is respected, not
  subsumed, by this story.

## Resolution

**Decision:** The problem is reframed and its requirements fixed as above: the
harness needs a serializable, comparable version on each of three surfaces
(container image, git worktree, host CLI), recorded in a way that supports exact
resume and docker-free inventory reads, and the prior hash-subset/staleness
artefacts are retired as inadequate for that purpose.

**Where the work goes:** A road map entry for "harness (image + worktree + host)
version identity" is added under M2.6 this session. The mechanism decision is
staged in the design document
[`20260831-design-active-image_and_harness_version_identity.md`](20260831-design-active-image_and_harness_version_identity.md);
the design is to be settled in the next session, after which an ADR records the
decision and this story is closed as resolved.

**Superseded / archived documents:** the two-sig model and its descendants are
subsumed — [`story_session_identity_and_harness_versioning.md`](story_session_identity_and_harness_versioning.md) [REMOVED]
(two-sig design; content absorbed by the session-identity ADR; file deleted by
operator), [`story_harness_packaging_and_install_versioning.md`](story_harness_packaging_and_install_versioning.md)
(saved as `superseded` — deferred questions feed the design), and
`investigation_harness_sig_requirements.md` (`superseded`). Each remaining doc
carries a redirect to this document and stays as the reasoning record.