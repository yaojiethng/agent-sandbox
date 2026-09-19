# Interface Contract Compatibility

**Current:** 2026-09-19
**Status:** open/pending-impl (closes when the mechanism lands)

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Serializable | The contract version is a value a script can read and compare |
| R2 | Comparable across boundaries | Every co-resident copy (host source, image, record) can be compared against the others |
| R3 | Bump discipline | The version increments only on a cross-boundary contract change, never on doc edits or internal refactors |
| R4 | Without-starting check | The record surface is comparable without starting a container |
| R5 | Early check | Comparison runs at the earliest possible point per surface |
| R6 | Rollover without breakage | The old check (container-sig) is stripped only after the new check is proven |

## 2026-09-19 -- Interface-contract version: one version, two declarations, layered comparison

**Decision:** The harness gets one explicit interface-contract version,
`INTERFACE_CONTRACT_VERSION`, a single positive integer declared once in a
host-side lib (`src/libs/interface_contract.sh`). It is stamped into each
tier-3 image at build time (declaration 1: the container's artifact names its
own contract revision) and into the session record at write time (declaration
2: `.compose/<session-id>.yml` label set + in-worktree `SESSION_STATE` key,
readable without starting a container). Comparison is layered by surface and
timing: host<->container and record at start/resume preflight (before any
container exists); container<->container at the agent entrypoint (the first
moment both containers are up, since the sandbox initializes first).

**Bump rule:** increment exactly when a cross-boundary contract changes — wiring
shape, mount/bind shape, `SANDBOX_DIR` format, onboard command shape,
host/container command semantics, session-record schema, docker labels the
container consumes. Doc edits, tests, and internal refactors never bump it.

**Mismatch policy:** two regimes gated by the migration plan. Parallel phase:
the new check warns exactly as `container-sig` does today — a warning never
blocks a start. Authoritative phase (after live proof): a mismatch is a hard,
preflight-time refusal naming the mismatched surface and the fix (rebuild, or
restart the session from the record). Refusal happens before any container is
created. The entrypoint container<->container check is expected to be
superfluous when preflight passes; its failure signals a larger problem
(orchestration error, corrupt container state), not ordinary drift.

**Rationale:** The retired freshness signal and the interim `container-sig`
check detect drift they cannot name: no serializable version means no
comparability, no resume decision, no record linkage. A deliberate version
number closes that gap without reintroducing file-hash fingerprints (immune to
doc edits by construction). Baking into the image names the artifact's own
revision; stamping the record names the session's revision and makes the check
cheap — a file read, no docker inspect. Checking early minimises wasted
operations and blast radius: a failed preflight check costs only the preflight
work; a failed entrypoint check stops an already-invested session with a named
cause.

**Rejected alternatives:**
- *Container-sig-style source fingerprint* (status quo, extended) — intent:
  a subset hash cannot name a version, cannot drive a resume decision, and
  doc edits change it without a contract change (R3 fails). Superseded by this
  mechanism.
- *Build-baked version only* — execution gap: needs an image present/inspect,
  so the record surface is not comparable without starting (R4 fails) and the
  session-record schema is uncovered.
- *Record-layered version only* — execution gap: the image's own wiring
  declares nothing; host<->container and container<->container drift are
  invisible (R2 fails on the image surface).
- *Per-surface version split from day one* — neither intent nor execution:
  the harness ships as one repo and its copies move together; split adds
  ceremony without detection value. Deferred as a compatible extension (additive
  constants + comparators, not rework).

**Rollover (container-sig -> interface-contract version), exact switch-over
moments:** see the design record
[`20260919-design-interface_contract_compatibility.md`](../../devlog/discussions/20260919-design-interface_contract_compatibility.md)
for the live matrix and the operator-released gates. The hard rule, from the
recorded past failure (new-mechanism errors blocked container start after the
old check was stripped): the old check is not stripped before the new check is
proven under the strict regime. Phases: P0 land in parallel (warn-only, both
checks live), P1 live proof (full matrix + deliberately drifted samples),
P2 flip authoritative (one reversible flag; entrypoint check added), P3 strip
(`container_sig.sh` deleted, interim-section rewrite, ADR entries
drift_state_coherence / harness_versioning updated to close the interim
status).

**Edge cases / drivers:** old images carry no version label — the check treats a
missing label as "pre-dating the contract version" and warns (matching
`container-sig`'s missing-label behavior); container<->container comparison
requires both images present — the agent entrypoint reads its own baked version
and the sandbox image's baked version, both available by then. The design record
resolves the remaining review items: warn-then-strict confirmed, single version
first, doc consolidation to one interface concept doc
(`sandbox_host_interface.md`, renamed from the correspondence model) + one
lifecycle architecture doc (`sandbox_lifecycle.md`).