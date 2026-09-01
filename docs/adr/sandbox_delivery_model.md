# Sandbox Delivery Model

**Current:** 2026-07-30

## 2026-07-30 -- Two-axis model; harness never mediates git

**Decision:** Sandbox delivery is a two-axis model: **delivery** = copy or mount of the sandbox to the reasoning layer; **backing** = whatever `.git` the user provides (fresh baseline, clone, worktree). The harness provides the container boundary and does not implement, mediate, or protect git operations between the agent container and the host repository. If the user wants push access, they mount a repo with push access and accept the risk. Raw project directory backing is a non-goal. Worktree backing — linking the agent's working tree to the host repository via `git worktree add`, with agent commits landing in the host object store — is rejected.

**Rationale:** Worktree backing required four mitigations to be adequately hardened (`--network=none`, filesystem `chmod` on config/hooks/refs, `.git/` restricted to the capability layer — breaking agent git usage), and even with all four the `core.hooksPath` vector remained a high-severity residual risk enabling post-session host code execution. The mechanism cost 6 preflight steps, bidirectional permission management, and cross-platform gitdir pointer resolution — to replace a diff pipeline that already works and is simpler.
The revised model separates concerns cleanly: security boundary = harness (capability layer); git topology = user choice. Capability-layer git mediation is retired; the backing axis has one active option: user-provided `.git`. Full investigation:
[`20260730-study-settled-worktree_rejection.md`](../../devlog/discussions/20260730-study-settled-worktree_rejection.md); mount-model design:
[`20260730-design-settled-mount_model.md`](../../devlog/discussions/20260730-design-settled-mount_model.md).

**Rejected alternatives:**
- *Worktree backing (harness-mediated `git worktree add`)* — security cost
  exceeds value; complexity budget; the simplified model is strictly better.
  Roadmap scope note: permanently removed (M2.6.6 Not in scope). Security posture: [security.md](../architecture/security.md).
- *Raw project directory backing* — non-goal; the sandbox must be a harness-
  controlled copy/boundary, not the user's live checkout.

**Edge cases / drivers:** Parallel worktree sessions of the same project must not share one sandbox; the `SANDBOX_DIR`-per-instance identity factor exists precisely so distinct backings map to distinct sandboxes. Diff exchange across the boundary is git-agnostic by design — see [sandbox_host_correspondence_model.md](../concepts/sandbox_host_correspondence_model.md).

## 2026-07-21 -- Worktree mount model (three-tier)

**Decision:** The sandbox working content was to be delivered via harness-managed `git worktree` wiring between the host repository and the agent container, with the harness mediating git operations across the boundary.

**Reason superseded by 2026-07-30:** The harness-mediated git topology concentrated unacceptable security cost (residual `core.hooksPath` host execution vector) and complexity in the harness to reproduce something the user can provide directly. The replacement principle — harness owns the boundary, user owns the git topology — made the whole mediation layer unnecessary. Superseding decision above.
