# ADR — Worktree Backing Rejected

**Status:** settled

**Supersedes:** `20260721-adr-settled-worktree_mount_model.md` (removed pre-settlement, retained in git history)

## Decision

Worktree backing — linking the agent's working tree to the host repository via `git worktree add`, with agent commits landing in the host object store — is rejected. The harness will not implement, mediate, or protect git operations between the agent container and the host repository.

## Rationale

1. **Security cost exceeds value.** Four mitigations are required to adequately harden the model: `--network=none` (blocks AI API access), filesystem `chmod` on config/hooks/refs (adds pre-flight and teardown permission management), and restricting `.git/` to the capability layer (breaks agent git usage). Even with all four, the `core.hooksPath` vector remains a high-severity residual risk enabling post-session host code execution.

2. **Complexity budget.** The mechanism required 6 preflight steps, bidirectional permission management, cross-platform gitdir pointer resolution, and a safety audit. The diff pipeline it aimed to replace already works and is simpler.

3. **Simplified model is strictly better.** The revised mount model (session 20260730-05) separates concerns: the harness provides the container boundary; the user provides whatever `.git` they want (fresh baseline, clone, worktree). The harness does not mediate git operations. If the user wants push access, they mount a repo with push access and accept the risk.

## Consequences

- Worktree backing permanently removed from roadmap scope (M2.6.6 Not in scope).
- `docs/architecture/security.md` Mount modes table: Worktree row removed or marked rejected.
- The full investigation (mechanism, security delta, residual risk analysis) is preserved in [`devlog/discussions/20260730-study-settled-worktree_rejection.md`](../../devlog/discussions/20260730-study-settled-worktree_rejection.md).
- The backing axis in the mount model design now has one active option: user-provided `.git`.

## References

| Document | Purpose |
|---|---|
| [`devlog/discussions/20260730-study-settled-worktree_rejection.md`](../../devlog/discussions/20260730-study-settled-worktree_rejection.md) | Full investigation record |
| [`devlog/discussions/20260730-design-settled-mount_model.md`](../../devlog/discussions/20260730-design-settled-mount_model.md) | Mount model design |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | M2.6.6 Not in scope |
