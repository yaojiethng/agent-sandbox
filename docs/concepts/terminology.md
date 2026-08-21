# Terminology

> Registry of reserved technical terms. Add new terms under their own header;
> keep each term's identity, scope, and relationships together under it.

## Usage

These are reserved technical terms: use them with exactly the meanings defined
below, and do not use either as a bare noun or loose synonym in prose or code.
Historical records and past handovers are not retro-renamed. Deprecated tokens
are noted in the relevant term's entry.

---

## session

One container lifecycle, from container start to teardown. The harness unit of
execution. Has a resume path and a persisted state file.

### Identity

- `SESSION_ID` (formerly `RUN_ID`, deprecated)
- `SESSION_TS`, `SESSION_STATE`

### Scope

Session-scoped resources: the container lifecycle, the compose project, the
named volume, the session-diffs channel.

### Relationships

- A session may contain zero or more [iterations](#iteration).

**Last updated:** 2026-08-19

---

## iteration

One work cycle that produces a handover and a commit. The operator unit of
governance. Targets one sub-milestone step; recorded in `devlog/handovers/`.

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
- **image staleness** — the image's baked `agent-sandbox.container-sig` differs from the recomputed source signature. Means the image content (feature set, `/opt/sandbox/` + `/opt/workflow/` sources) is out of date, so even resuming the session may carry an incomplete feature set. Computed by comparing the image `container-sig` label against `container_sig` recomputation (`build.sh`).

### Identity

- sandbox staleness: `agent-sandbox.host-head-sha` vs current `HEAD` (registry-truth).
- image staleness: `agent-sandbox.container-sig` label vs recomputed `container_sig`.

### Scope

- Applies per session (sandbox staleness) and per image (image staleness).
- Staleness is **surfaced** in `resume --list` and used as a **selection criterion** in `prune` (Rule 1); it is not a blocking resume gate.

### Relationships

- Distinct from the image/container `container-sig` *marker* (see `sandbox_identity.md`); staleness is the comparison, not the marker.
- `session_stale` (`resume_agent.sh`/shared lib) computes sandbox staleness.

**Last updated:** 2026-08-21
