# Drift State Coherence

**Current:** 2026-09-01

## 2026-09-01 -- Coherence by minimisation, not detection

**Decision:** State coherence across the harness's independently-drifting
copies (container image content, worktree checkout, host CLI) is engineered
by construction rather than detected after the fact. Each surface's drift is
minimised structurally — image identity is a recorded docker digest,
the host CLI is symlink-installed so drift is impossible by construction,
the worktree is identified by its git HEAD — and detection signals are
demoted to narrow, explicitly-scoped checks. The build-time signature family
(`container-sig`, and the retired `harness-sig`/`image-sig`/`[IMAGE_STALE]`
ladder) is reframed: `container-sig` survives only as the interim leaky
implementation of the deferred interface-contract check (binary exact-match,
warns on mismatch, scoped for deletion once a redesigned interface-contract
version lands); list-time staleness detection is retired entirely.

**Rationale:** Detection treats staleness as the defect, but the defect is
the absence of a serializable version underneath: a signature that cannot
address content can warn about drift yet offer no way to name, compare, or
resume the coherent state. The detection ladder also signed sparse file
subsets (leaky by construction) and cost runtime work on every operation
(2×N docker inspects in `resume LIST`). Minimisation gives each surface an
exact, comparable identity (see [harness_versioning.md](harness_versioning.md)
for the per-surface version semantics), removes the recurring detection cost,
and confines any remaining check to the one thing it genuinely guards —
cross-boundary contract compatibility. Grounded in the version-identity
design grill (`20260901-02`).

**Rejected alternatives:**
- *Drift detection as the primary mechanism* (freshness signals, signature
  recomputation at list/preflight time) — detects without addressing, false
  sense of safety, sparse coverage, recurring cost. Retired.
- *Broader source fingerprinting* to widen signature coverage — deferred to
  the full-packaging milestone (manual file list, host/container file-set
  differences, doc-edit false positives); see
  [harness_versioning.md](harness_versioning.md) rejected alternatives.

**Edge cases / drivers:** Two contract points that host-vs-container framing
misses and pure detection cannot fix: (1) intra-session container↔container
drift — agent and sandbox images are buildable independently
(`--targets=agent|sandbox`), so mount-delivery wiring can land in one while
the other is older; (2) the session-record schema (`.compose/<id>.yml` +
in-worktree `SESSION_STATE`) is itself a resume-breaking contract written by
host and read by container. These belong to the deferred interface-contract
compatibility thread, for which `container-sig` is the interim stand-in.
Until the versioning implementation lands, container-sig behavior remains
current — see [sandbox_identity.md](../concepts/sandbox_identity.md#container-sig-image-staleness-detection).

## 2026-07-22 -- Drift detection via build-time source signature

**Decision:** Images carried an `agent-sandbox.container-sig` label — a
SHA-256 over the source file subset baked into the image — recomputed and
compared at preflight and list time to warn when image content was older
than current source (staleness as a surfaced, non-blocking signal).

**Reason superseded by 2026-09-01:** The signature is a leaky subset hash —
it covers baked source files but not base image, runtime, or dependencies —
and it detects drift it cannot address: no recorded version means no
exact-resume and no comparability. It is retained only as the interim
interface-contract check (decision above) and is scoped for deletion.
