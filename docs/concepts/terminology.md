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
