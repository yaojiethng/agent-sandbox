# Study — Worktree Backing: Feasibility, Risk, and Rejection

**Status:** settled

**Supersedes:** `20260416-study-superseded-git_worktrees.md` (git worktree feasibility), `20260417-story-superseded-parallel_sessions_worktree.md` (parallel sessions story), `20260611-story-superseded-agent_git_surface.md` (agent git surface), `20260722-design-active-worktree_mount_mechanism.md` (mechanism design), `20260622-study-settled-security_delta_worktree_model.md` (security delta analysis).

## Purpose

Record the full investigation into worktree backing — the proposal, mechanism, security analysis, and the decision to reject it. This document is the single reference for why worktree backing is not supported and what replaces it.

## What worktree backing proposed

Agent commits land directly in the host repository's object store on an agent branch (`refs/agent/<session-id>`). No diff pipeline — `make draft` becomes `git merge agent/<id>`. The mechanism required:

1. `git worktree add` to create the agent's checkout
2. Mount `PROJECT_DIR/.git` RW at a fixed container path
3. Rewrite the worktree `.git` pointer to resolve inside the container
4. `chmod a-w` on packed refs, config, hooks, and object packs
5. `--network=none` on the agent container (block push)
6. Teardown: restore permissions, `git worktree remove`

## Security analysis

The full invariant-by-invariant comparison is preserved below. Summary:

| Invariant | Status under worktree |
|---|---|
| No PROJECT_DIR mount | ❌ Broken — `.git` must be mounted |
| No host mutation before review | ❌ Broken — commits land during session |
| Diff-as-review-gate | ❌ Eliminated — replaced by branch model |
| No Docker socket | ✅ Holds |
| Gitignored files excluded | ✅ Holds via worktree checkout |

Four mitigations were identified as *required*:

1. `--network=none` — blocks push/fetch/exfiltration
2. `chmod a-w .git/packed-refs` — protects main branch pointer
3. `chmod a-w .git/config` + `.git/hooks/` — blocks `core.hooksPath` injection (highest-severity residual risk: post-session host code execution)
4. Architecture choice: mount `.git/` into capability layer only, not reasoning layer — blocks object store access, config write, hooks write, ref pollution

Even with all four mitigations applied, residual risks remain:

- "Clean history" precondition is unverifiable by the harness (operator assertion only)
- Review gate is post-mutation (operator reviews after commits land, not before)
- Object store pollution over multiple sessions accumulates disk usage
- `--network=none` is load-bearing — if network access is needed for API calls, the entire mitigation collapses

## Why we rejected it

1. **Complexity budget.** Six preflight steps, four mitigations, a safety audit, cross-platform gitdir resolution — ~90 lines of mechanism design + ~317 lines of security analysis. For what? Eliminating the diff pipeline. The diff pipeline already works.

2. **High-severity residual risk.** `core.hooksPath` manipulation enables post-session host code execution. The agent can write to `.git/config` during the session, set `hooksPath` to a path inside the worktree, and the operator's `git merge` after the session would execute agent code on the host. Mitigating this requires `chmod a-w` on config and hooks — adding filesystem permission management to the harness.

3. **`--network=none` blocks API access.** The agent needs network access to call AI providers. The worktree model requires `--network=none` to block `git push`. These are mutually exclusive. A proxy-based allowlist could permit API traffic while blocking git remotes, but that adds another layer of complexity.

4. **The simplified model is strictly better.** Under the simplified model (session 20260730-05), the user provides whatever `.git` they want — fresh baseline, clone, worktree, bare repo. The harness does not mediate git operations. If the user wants the agent to have push access, they mount a `.git` with push access and accept the risk. If they want isolation, they provide a fresh baseline. The harness stays out of git entirely.

## Replacement: simplified `.git` mount model

See [Design — Mount Model](../../devlog/discussions/20260730-design-settled-mount_model.md) for the current design. The backing axis now has one active option: **user-provided `.git`** (copy or mount). The harness boundary is the container — what happens inside is the agent's business; what `.git` the user provides is the user's business.

## Detailed security analysis (preserved)

### Assumption comparison

**Current model:**
1. Agent runtime explicitly untrusted
2. PROJECT_DIR never reachable from containers
3. Gitignored files never visible to agent
4. Repository mutation requires human review first
5. Containers are ephemeral
6. Secrets excluded from snapshot by gitignore

**Worktree model:**
1. Agent runtime remains untrusted (unchanged)
2. `PROJECT_DIR/.git` must be accessible from container — core mount change
3. Gitignored files remain invisible (worktree checks out tracked files only)
4. Commit history assumed clean (operator precondition, unverifiable)
5. Remote operations blocked by `--network=none`
6. Main branch protected by `chmod a-w packed-refs`
7. Agent commits land immediately in host object store

### Invariant-by-invariant comparison

**Invariant 1 — No PROJECT_DIR mount:** Broken by design. `.git` must be mounted.

**Invariant 2 — Capability layer host path access:** Requires revision — capability layer needs worktree directory and `.git`.

**Invariant 3 — Reasoning layer host path access:** Broken by design — reasoning layer needs worktree directory. Whether `.git` is also accessible depends on Option A (capability layer only) vs Option B (also reasoning layer).

**Invariant 4 — No Docker socket:** Holds.

**Invariant 5 — Pre-mutation review gate:** Broken by design. Commits land during session. Review becomes post-mutation (merge or discard branch).

**Invariant 6 — staged.diff review gate:** Eliminated. Replaced by branch protection model.

**Invariant 7 — Gitignored file exclusion:** Holds via worktree checkout mechanism. Covers working tree only — history requires operator "clean history" precondition.

**Invariant 8 — No binary/executable output:** Holds. `workspace/output/` unchanged.

### Assets at risk after mitigations

| Asset | After mitigations | Residual risk |
|---|---|---|
| Full commit history | Readable (Option B) | Accepted if history is clean; unverifiable |
| Secrets in git history | Readable if present | Unmitigated — operator precondition |
| `.git/config` | Readable + Writable | **`core.hooksPath` write is high-severity** |
| `.git/hooks/` | Readable + Writable | **Post-session host code execution** |
| Main branch pointer | Write-protected by chmod | Covered |
| Packed refs | Write-protected by chmod | Covered |
| New loose ref creation | Possible | Ref pollution; not critical |
| Remote push/fetch | Blocked by --network=none | Covered |
| Object store integrity | Writable | Hygiene concern |

### Required mitigations (all four needed for adequate hardening)

1. `--network=none` — blocks push, fetch, exfiltration. Strong, reliable. Conflict: blocks AI API access.
2. `chmod a-w .git/packed-refs` — protects main branch pointer. Covers packed refs only; new loose refs still possible.
3. `chmod a-w .git/config` + `.git/hooks/` — closes `core.hooksPath` vector. Requires pre-flight `chmod` + teardown restore.
4. Mount `.git/` into capability layer only (Option A) — blocks object store, config, hooks, ref access from reasoning layer. Trade-off: agent cannot use git directly.

## References

| Document | Purpose |
|---|---|
| [`docs/adr/20260730-adr-settled-worktree_rejection.md`](../../docs/adr/20260730-adr-settled-worktree_rejection.md) | ADR: formal rejection of worktree backing |
| [`devlog/discussions/20260730-design-settled-mount_model.md`](20260730-design-settled-mount_model.md) | Mount model design — simplified .git mount |
| [`devlog/discussions/20260730-design-settled-copy_model.md`](20260730-design-settled-copy_model.md) | Copy model design |
| [`devlog/roadmap.md`](../roadmap.md) | M2.6.6 Not in scope |
| [`docs/architecture/security.md`](../../docs/architecture/security.md) | Security model |
