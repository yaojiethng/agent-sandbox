# Terminology

> Registry of reserved technical terms. Add new terms under their own header;
> keep each term's identity, scope, and relationships together under it.

## Usage

These are reserved technical terms: use them with exactly the meanings defined below, and do not use either as a bare noun or loose synonym in prose or code.
Historical records and past handovers are not retro-renamed. Deprecated tokens are noted in the relevant term's entry.

---

## session

One container lifecycle, from container start to teardown. The harness unit of execution. Has a resume path and a persisted state file.

### Identity

- `SESSION_ID` (formerly `RUN_ID`, deprecated)
- `SESSION_TS`, `SESSION_STATE`

### Scope

Session-scoped resources: the container lifecycle, the compose project, the named volume, the session-diffs channel.

### Relationships

- A session may contain zero or more [iterations](#iteration).

**Last updated:** 2026-08-19

---

## iteration

One work cycle that produces a handover and a commit. The operator unit of governance. Targets one sub-milestone step; recorded in `devlog/handovers/`.

### Identity

- Handover `YYYYMMDD-NN`; governed by `iteration_policy.md`

### Scope

Iteration-scoped resources: a draft branch, a diff bundle.

### Relationships

- An iteration is hosted within exactly one [session](#session).
- The `new-iteration` prompt (formerly `new-session`) opens an iteration.

**Last updated:** 2026-08-19

---

## staleness

A session's or image's divergence from the current project or build content, in one of two distinct dimensions:

- **sandbox staleness** — the session's recorded `host-head-sha` differs from the current project `HEAD`. Means the git state the sandbox was built from is out of date (the repo has moved on). Computed over the `.compose` registry record (`host-head-sha` vs current `git rev-parse HEAD`).
- **image staleness** — retired. The interim `agent-sandbox.container-sig`-based comparison (image content vs recomputed source signature) is removed (P3, 2026-09-19). Image identity is now the recorded image-ID digest (`agent-sandbox.agent-image-digest` / `agent-sandbox.sandbox-image-digest`); the container-boundary contract is the interface-contract version, ADR [interface_contract_compatibility.md](../adr/interface_contract_compatibility.md).

### Identity

- sandbox staleness: `agent-sandbox.host-head-sha` vs current `HEAD` (registry-truth).
- image staleness: retired (2026-09-19); image identity is the recorded digest.

### Scope

- Applies per session (sandbox staleness); image staleness is retired.
- Staleness is **surfaced** in `resume --list` and used as a **selection criterion** in `prune` (Rule 1); it is not a blocking resume gate.

### Relationships

- `session_stale` (`resume_agent.sh`/shared lib) computes sandbox staleness.
- Image staleness detection is a superseded principle: the settled direction retires list-time staleness in favour of recorded version identity — see [drift_state_coherence.md](../adr/drift_state_coherence.md) and [harness_versioning.md](../adr/harness_versioning.md). Until that implementation lands, the behaviour above is current.

**Last updated:** 2026-08-21
