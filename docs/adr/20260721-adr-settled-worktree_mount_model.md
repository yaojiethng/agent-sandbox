# ADR — Worktree Mount Model

**Status:** settled

## Summary

The sandbox mount model is structured as three tiers — Copy+Tar, Mount+Tar, Mount+Worktree — with increasing host access and decreasing pipeline overhead. Each tier carries a distinct set of security invariants. Adoption is phased: Tier 1 is the current default, Tier 2 is the next implementation target (Phase 1.5 persistence), and Tier 3 is a validated design for a future milestone.

## Context

The harness originally used an anonymous Docker volume with a copy-in startup step (`baseline.tar` → `sandbox/`). This model (Tier 1) is simple and secure — the agent never sees the host filesystem — but it has three problems that motivated the tiered design:

1. **No session persistence.** The anonymous volume is destroyed on `docker compose down -v`. Every session starts from a fresh copy of the baseline, losing the agent's working state between sessions.
2. **Copy overhead at startup.** For large repositories, `baseline.tar` extraction at every session start adds latency proportional to the tracked file set.
3. **No migration path to worktrees.** A future model where the agent writes directly to a git branch (the Hermes workflow) requires the git object store to be accessible from the capability layer, which the copy model explicitly prevents.

The tiered model was designed to solve (1) and (2) in the near term while keeping (3) architecturally reachable without a redesign.

## Options Considered

### Option A — Single model (status quo)

Keep the anonymous volume + copy-in pipeline. Accept that session persistence requires a separate mechanism (export+import) and that Tier 3 is unreachable without a breaking change.

- **Advantages:** Proven, secure, simple.
- **Disadvantages:** No persistence; copy overhead every session; Tier 3 requires a full redesign later.

### Option B — Two-tier (Tier 1 + Tier 2 only)

Add a host bind mount for `.snapshot/` (Tier 2). Keep the copy pipeline as the default; add a flag (`MOUNT_SNAPSHOT=1`) to switch to mount-based delivery. Tier 3 is left as future work with no commitment to a design.

- **Advantages:** Solves persistence for the mount path; minimal security model delta from Tier 1.
- **Disadvantages:** Tier 3 design is deferred to a future phase; the worktree path remains unvalidated.

### Option C — Three-tier (adopted)

Define three explicit tiers as in `security.md` §Trust Boundaries and Mount Models:

| Tier | Delivery | Population | Session persistence |
|---|---|---|---|
| 1 | Copy | `git archive` → `baseline.tar` | No (volume destroyed) |
| 2 | Mount | `baseline.tar` → `.snapshot/` | Yes (host bind mount) |
| 3 | Mount | `git worktree add` → `.snapshot/` | Yes (host bind mount) |

Each tier has a distinct invariant set in `security.md` §Security Invariants. Tier 1 and Tier 2 share most invariants; Tier 3 replaces 4 of the 6 Tier 1 invariants and adds 4 new ones.

- **Advantages:** Full design space mapped; Tiers 1 and 2 share a common code path (snapshot + diff pipeline); Tier 3 is design-validated and can be implemented when needed without re-opening architectural questions.
- **Disadvantages:** Three invariant sets to maintain; Tier 3 requires operator precondition (no secrets in git history) that cannot be enforced by the harness.

## Decision

Adopt **Option C — Three-tier model**.

- Tier 1 (Copy+Tar) remains the default for all sessions.
- Tier 2 (Mount+Tar) is implemented when the Phase 1.5 named volume + host bind mount work lands.
- Tier 3 (Mount+Worktree) is design-validated but gated behind operator precondition and not yet implemented.

The three tiers are documented together in `security.md` because they share the same trust-boundary analysis — the differences are incremental (which paths are mounted, which invariants apply). Maintaining them in one document ensures that a change to a shared invariant (e.g. Docker socket access) propagates uniformly across all tiers.

## Consequences

### Positive

- **Persistence path exists.** Tier 2 gives sessions that survive container restarts without a separate export+import mechanism.
- **Worktree path is validated.** The analysis in `20260416-study-superseded-git_worktrees.md` confirmed that worktrees are viable under relaxed assumptions (no secrets in history, `--network=none`, read-only hooks and config). The Tier 3 invariant set in `security.md` encodes the required mitigations.
- **No redundant design cycles.** The worktree question was fully investigated in M2.3; the findings are absorbed into the tiered model rather than left as a suspended investigation.
- **Migration is additive.** Tier 2 adds invariants to Tier 1 without removing any. Tier 3 replaces invariants but the replacement is explicit in `security.md`.

### Negative

- **Three-tier invariant maintenance.** A change to a cross-cutting invariant (e.g. Docker socket access) must be verified against all three tiers. The table in `security.md` makes this tractable but adds review burden.
- **Tier 3 precondition is unenforceable.** The harness cannot verify that no secrets exist in git history. This is an operator precondition documented in `security.md`.
- **Pipeline divergence.** Tier 2 and Tier 3 share the same mount shape but use different population methods (tar extraction vs. `git worktree add`). The entrypoint must detect which mode to use at startup.

### Neutral

- **`20260416-study-superseded-git_worktrees.md`**, **`20260611-story-superseded-agent_git_surface.md`**, and **`20260417-story-superseded-parallel_sessions_worktree.md`** are superseded by this ADR. Their substantive findings are absorbed here and in `security.md`. They are retained as historical record with supersede headers.
- The naming of these discussion docs has been updated to the current convention (`YYYYMMDD-{type}-{status}-{description}.md`).

## Supersedes

- `20260416-study-superseded-git_worktrees.md` — full document
- `20260611-story-superseded-agent_git_surface.md` — full document (superseded by M2.6 design decisions)
- `20260417-story-superseded-parallel_sessions_worktree.md` — full document (resolved; absorbed into tiered model)
