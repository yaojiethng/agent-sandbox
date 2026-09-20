# Design -- Interface-contract compatibility

**Target milestone:** M2.6 - Session Persistence
**Status:** settled
**Raised:** `20260901-02` (deferred design thread); roadmap row 117 (unchecked)
**Related:** [`harness_versioning.md`](../../docs/adr/harness_versioning.md) (per-surface version identity), [`drift_state_coherence.md`](../../docs/adr/drift_state_coherence.md) (coherence by minimisation), [`sandbox_identity.md`](../../docs/concepts/sandbox_identity.md#container-sig-interim-interface-contract-check) (container-sig interim role), [`sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md), [`sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md)

---

## Context

The retired freshness signal addressed the wrong layer. The real need: the host
checkout that drives a session and the wiring baked into the image must speak
the same shape. Silence on that shape is how differences in bind-mount folder
shape, `SANDBOX_DIR` format, onboard command shape, and host/container command
semantics (the change-class-1/2/3 High band, `investigation_harness_sig_requirements.md`)
became field failures instead of refused starts.

Three contract surfaces carry the drift:

1. **Host<->container wiring.** The host dispatches; the container discloses
   (`entrypoint.sh`, `seed_volume.sh`, `snapshot.sh`, provider preflight). A
   host rebuilt on a newer lib set can drive an older-baked container, or
   vice versa.
2. **Container<->container pairing.** Agent and sandbox images build
   independently (`--targets=agent|sandbox`); mount-delivery wiring can land in
   one while the other is older.
3. **Session-record schema.** `.compose/<session-id>.yml` and the in-worktree
   `SESSION_STATE` are written by the host at start and read by host
   resume/list and the container entrypoint. A schema change is a resume-break
   (sharper under exact-resume-via-digest).

The current interim check, `container-sig`, is a source-subset hash baked as a
Docker label and warn-compared at preflight. It detects drift it cannot name:
no version means no comparability, no resume decision, no record linkage.

The operator-directed mechanism (thread, `20260901-02`): an explicit
interface/contract version, declared and compared by each co-resident copy,
bumped only when a cross-boundary contract changes, immune to doc edits.

Operator steering (2026-09-19, review of this design's scope): the version must
be **baked at build and layered on the record** -- baked so it is solidified into
 the artifact the container runs; layered on the record so it can be read
without starting the container. The `container-sig` rollover needs a migration
plan: both checks run in parallel, the old one is only stripped after the new
one is proven. Past failure recorded: new-mechanism errors blocked container
start after the old mechanism had already been fully stripped.

Operator steering (2026-09-19, entrypoint framing): the goal is to **minimise
wasted operations and blast radius** of a failed contract check, by checking as
early as possible. Host<->container checks therefore run at preflight, before
any container starts. Container<->container checks necessarily cannot run
before the containers start; the earliest possible point with strong
consequences is the agent's entrypoint (the sandbox starts and finishes
initializing first, so the agent entrypoint is the first moment both are up).
If the preflight checks work, the entrypoint check is likely superfluous; if it
fails anyway, it points at a larger problem -- an orchestration error or corrupt
container state, not ordinary drift.

---

## Options Considered

### Option A -- Container-sig-style source fingerprint (status quo, extended)

Recompute a subset hash at every comparison point.

- Detects drift it cannot address: no comparability level, no resume decision,
  no record linkage (ADR drift_state_coherence, rejected).
- Leaky by construction: signs the source subset, not base image, runtime, or
  dependencies (ADR harness_versioning, rejected).
- Doc edits change the hash without a contract change -- the "immune to doc
  edits" requirement fails.
- **Rejected**: this is the mechanism being replaced.

### Option B -- Build-baked version only

A version constant is stamped into the image at build time (label or baked
file) and compared against the current host source at start/resume preflight.

- Solidifies the version into the artifact -- the container's own declaration
  exists.
- To check it you must inspect the image (needs the image present in the local
  daemon). Record-oriented reads (resume list, prune) cannot compare without a
  container or an image inspect.
- Does not cover the session-record schema as a contract surface.
- **Partial**: catches host<->container and container<->container wiring; misses
  the record surface and the without-starting read.

### Option C -- Record-layered version only

The version is stored in `.compose/<session-id>.yml` and `SESSION_STATE` at
session write, and compared at resume/list/preflight.

- Readable without starting a container -- the without-starting requirement.
- Covers the record schema as a contract surface.
- The image's own wiring declares nothing: a freshly rebuilt image can speak an
  older wiring shape while the record claims the newer version. Container<->container
  and host<->container wiring drift are invisible.
- **Partial**: covers the record; misses the baked artifact.

### Option D -- Combined: baked at build, layered on the record (recommended)

One interface-contract version, declared in a single host-side constant,
stamped into images at build time and into the session record at write time;
compared by the host at start/resume preflight (host<->container + record) and
by the agent entrypoint (container<->container) against the current source
constant.

- Every co-resident copy declares the version it was built with: the host
  source (the constant), the images (baked), the record (stamped).
- Readable without starting: record-space compare at resume list/prune preflight
  needs only the `.compose` file + `SESSION_STATE`, both host-readable.
- Bump is a deliberate act (a contract change), not an artifact of file hashes:
  immune to doc edits by construction.
- One number covers all three surfaces: any cross-boundary contract change
  bumps it, so host<->container, container<->container, and record-schema
  drift all surface on the same comparable.
- **Chosen.**

---

## Decision

### Mechanism: one interface-contract version, two declarations, one comparator

**The version.** `INTERFACE_CONTRACT_VERSION` -- a single positive integer,
declared once in a host-side lib (`src/libs/interface_contract.sh`), consumed
by build, start, resume, and prune. Bump rule: increment exactly when a
cross-boundary contract changes (wiring shape, mount/bind shape, `SANDBOX_DIR`
format, onboard command shape, host/container command semantics, session-record
schema, docker labels the container consumes). No other event bumps it; doc
edits, tests, and internal refactors never do.

**Declaration 1 -- baked at build.** `scripts/build.sh` stamps the version into
each tier-3 image at build time (label, same injection point as the current
`container-sig` label, replacing its content role). The image thus declares, in
its own artifact, the contract revision its baked wiring (`entrypoint.sh`,
`seed_volume.sh`, `snapshot.sh`, provider files) was built against.

**Declaration 2 -- layered on the record.** At session write, start stamps the
version into `.compose/<session-id>.yml` (label set) and the in-worktree
`SESSION_STATE`. Resume-list and prune can compare record-space versions
without any container or image inspect.

**Comparator -- layered by surface and timing.** One version, but not one
comparison point: the check runs at the earliest moment each surface can be
compared, to minimise wasted operations (a failed check before any container
starts costs only the check) and blast radius (a failed check after containers
start costs a terminated session).

- **Host<->container + record: preflight** (start and resume paths).
  `preflight()` compares host source vs image-label vs record against the
  current host-side constant, before any container is created. A failure here
  refuses the start/run with a remediation message naming the mismatched
  surface. Earliest point, smallest blast radius: the check wastes only the
  preflight work it already does.

- **Container<->container: agent entrypoint.** The sandbox container starts and
  finishes initializing first; the agent container's entrypoint is the first
  moment both are up, and the earliest possible point for a check with strong
  consequences. It compares the two images' baked versions (and the record's
  stamped version, which the sandbox has seen by then). This check is expected
  to be superfluous when the preflight checks pass; a failure here therefore
  signals a larger problem -- an orchestration error (images started from the
  wrong artifacts) or corrupt container state -- and is surfaced as such, in the
  agent entrypoint's diagnostics, rather than as ordinary drift. Consequences
  are strong by design: the session is already invested at this point, so a
  mismatch stops the agent with a named cause instead of letting it run on
  incompatible wiring.

**Mismatch policy at preflight (host<->container + record).** Two regimes,
gated by the migration phase (below):

- Parallel phase (new check lands alongside `container-sig`): the new check
  **warns** exactly as `container-sig` does today. A warning must never block a
  start; false positives in a new mechanism must not reproduce the recorded
  past failure (start blocked after old check stripped).
- Authoritative phase (after live proof, old check stripped): mismatch is a
  **hard, preflight-time refusal** with a remediation message naming the
  mismatched surface and the fix (rebuild, or restart the session from the
  record). Refusal happens before any container is created.

### Rollover / migration plan (container-sig -> interface-contract version)

**Exact switch-over moments.** Each phase transition is a concrete, operator-
released event, not a time box:

| Phase | What runs | Switch-over moment (gate) |
|---|---|---|
| P0 -- land in parallel | New check lands, warn-only, at the same preflight call sites. `container-sig` untouched: bake, `_check_container_sig`, tests, install dependency all stay | Suite green; both checks report on a drifted image |
| P1 -- live proof | Operator runs the full live matrix below with the new check warn-only | Operator release: zero false warnings across the matrix AND the new check agrees with `container-sig` on every deliberately drifted sample |
| P2 -- flip authoritative | New check becomes fail-closed at preflight (the warn/strict decision is one flag in the lib, so the flip is reversible by hand). Agent-entrypoint container<->container check added here | Operator release: live matrix green under the strict regime, including a deliberately drifted sample that is refused pre-flight with the named surface |
| P3 -- strip | Remove `container-sig` bake + compare: `_check_container_sig`, `container_sig()`/`current_sig`/`image_baked_sig`, label injection, `sig_helpers.sh`, container-sig tests, install `xargs` dependency note. Delete `src/libs/container_sig.sh`; rewrite the `sandbox_identity.md` interim section; update ADR entries (drift_state_coherence, harness_versioning) to close the interim status | Zero references to container-sig remain; suite green |

**The live matrix (P1 and P2 gates):** for each delivery mode (copy, mount) x
each flatten setting (on, off): start, resume, list, prune. Plus a deliberately
drifted sample (a rebuilt image from a different contract revision) exercised
in both regimes: warn-only at P1, refused at P2. This is the AC9-style live
dry-run matrix from `20260919-01`, extended with list/prune and drift samples.

The hard rule, from the recorded past failure: **the old check is not stripped
before the new check has been proven in live runs under the strict regime.** A
new-mechanism error must be fixable with both checks present, never after the
old check is gone.

### Rename: correspondence model -> interface

`docs/concepts/sandbox_host_correspondence_model.md` renames to
`docs/concepts/sandbox_host_interface.md` (impl-milestone task, with the
propagation checklist: 17 referencing files).

**Pro:** interface is the standard engineering term for a boundary contract;
correspondence reads as the two-sig section's display name, and the doc is now
re-scoped as the one main interface contract. The ADR
(`container_host_correspondence_mechanism.md`) keeps its name -- that principle
is about the mechanism, not the boundary.

**Criticism (assessed):** the term `interface` is already used by
`tool_interface.md` (the CLI/tool surface). The two documents name different
boundaries -- `sandbox_host_interface.md` is the container boundary, tool_interface
is the agent tool surface -- so the overlap is nominal, not semantic; the
re-scoped doc must carry a one-line distinction when the rename lands.

### Doc consolidation (end state, proposed for the impl milestone)

The interface problem, top level, is: *what the harness expects vs what we wire
images and containers to provide.* That framing is currently scattered across
four records (`sandbox_host_correspondence_model.md` - renamed per the rename
section, `sandbox_lifecycle.md`, `sandbox_delivery_model.md`, `sandbox_identity.md`).
End state after this thread's impl:

- **One main interface document in `docs/concepts/`** -- the harness<->container
  interface contract: the contract surfaces, what the harness expects from each
  co-resident copy, the version declaration and comparison points. Branches by
  link to the ADRs it resolves (`interface_contract_compatibility.md`,
  `sandbox_delivery_model.md`, `harness_versioning.md`, `drift_state_coherence.md`,
  `session_identifier.md`, `container_host_correspondence_mechanism.md`).
  Candidate base: `sandbox_host_correspondence_model.md`, re-scoped as the
  interface contract and linked from `sandbox_identity.md`.
- **One main lifecycle document in `docs/architecture/`** -- the session
  lifecycle with the interface mechanisms and state changes an end user needs:
  what writes the record at start, what reads it at resume/list, where the
  contract check sits in the sequence. Base: `sandbox_lifecycle.md`.

The consolidation is an impl-milestone task (docs restructure + link repoints),
not part of this design iteration's code surface.

---

## Consequences

- **Bump discipline becomes a process rule**: bumping
  `INTERFACE_CONTRACT_VERSION` is a deliberate contract change with a record
  (changelog row / ADR entry); it is not derived from any hash.
- `container-sig` retires in P3 as already promised by drift_state_coherence;
  its interim role description in `sandbox_identity.md` is rewritten at that
  phase.
- Resume decision sharpens: a record whose version differs from current source
  is refused at preflight with the record surface named -- the resume-breaking
  contract the thread identified becomes an explicit, comparable one.
- Container<->container drift is finally comparable: on start, both image labels
  and the record must agree with the host constant; a mismatched pair is named
  before any container starts.
- Record writes gain one field set (`.compose` label + `SESSION_STATE` key);
  the record schema is itself versioned by the single contract version on its
  next bump.
- The without-starting read (list/prune record-space compare) costs nothing at
  runtime: a file read, no docker inspect.
- **Foreclosed**: any per-surface version split in the near term (one number
  today; splitting to per-surface later is a compatible extension, not a
  rework). Text-level freshness/staleness signals stay retired.

## Open items (resolved by review)

1. **Mismatch policy: warn-then-strict, confirmed.** The exact switch-over
   moments are now explicit in the rollover table (operator-released gates, one
   reversible flag at P2).
2. **Version granularity: single first, confirmed.** Single is easier: one
   constant, one comparison site set, one bump rule; the harness ships as one
   repo, so its co-resident copies move together. Per-surface split is a
   compatible extension later (additive constants + comparators), not a rework;
   there is no near-term benefit to splitting first.
3. **Doc consolidation: confirmed, with rename.** One interface document in
   `docs/concepts/` (candidate base `sandbox_host_correspondence_model.md`,
   renamed `sandbox_host_interface.md` per the rename section) + one lifecycle
   document in `docs/architecture/` (`sandbox_lifecycle.md`), ADRs branching by
   link.
