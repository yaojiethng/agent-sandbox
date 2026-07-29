# Design — Worktree Mount Mechanism

**Status:** active

**Direction + Parent:** M2.6.4 — Mount Model Design and Implementation. Proposes the mechanism for worktree backing defined in [20260722-design-active-mount_model.md](20260722-design-active-mount_model.md). When this mechanism is implemented and audited, an ADR is recorded per `docs/operations/adr_policy.md`, `security.md` is updated to assert the worktree security posture, and this document is marked settled.

## Context

Worktree backing requires the agent's working tree to be a `git worktree` of the host repository, with agent commits landing in the host repository's object store on an agent branch. Three constraints were established during the security model reframe:

- Git operations are executed by the agent in the reasoning layer — directly or via the provider's command prefix (e.g. pi's `!`). The capability layer never invokes git; capability-layer mediation is retired.
- A read-only `.git` mount cannot accept commits — object, ref, and index writes are intrinsic to committing.
- The raw project dir is never offered as a backing.

This left three open questions, resolved by this proposal:

1. How to permit agent-branch writes while protecting all other refs.
2. How to resolve the worktree gitdir pointer (an absolute host path) inside the container.
3. Whether any git-operation mediation is needed, given the agent runs git directly.

**Gate:** `security.md` asserts the worktree security posture only after this mechanism is implemented and audited for safety. Until then worktree mode is not supported.

## Options Considered

### Resolving the worktree gitdir pointer

A worktree's `.git` file contains an absolute host path (`gitdir: /home/user/proj/.git/worktrees/<name>`) that does not resolve inside the container.

- **A — Mount at the identical absolute path.** Recreate the host's directory prefix in the container. Rejected: leaks host filesystem layout; brittle across host OSes.
- **B — Rewrite `commondir`.** Mount the worktree gitdir and the common dir at separate container paths; rewrite `commondir` to an absolute container path. Workable, but requires two rewrites.
- **C — Fixed-path full-`.git` mount + gitdir rewrite (recommended).** Mount the whole `PROJECT_DIR/.git` at a fixed container path; rewrite only the worktree's `.git` file. The worktree's relative `commondir` (`../..`) then resolves correctly with no second rewrite.

### Protecting non-agent refs

- **A — `packed-refs` read-only only.** Insufficient: a loose ref in `refs/heads/` can shadow a packed entry.
- **B — Ref namespace + filesystem permissions (recommended).** The agent branch lives in `refs/agent/`; all other ref directories are made read-only on the host before session start.
- **C — Git shim mediation.** A PATH shim blocking destructive verbs. Rejected as a boundary: the agent has a full shell and can invoke the real binary. Optional as an advisory convenience only.

### Git-operation mediation

- **Not adopted.** The boundaries are filesystem permissions, the `refs/agent/` namespace, and network isolation. A shim cannot be a boundary because the agent can bypass it.

## Decision

Proposed mechanism (not yet implemented):

**Mount shape:**

- `PROJECT_DIR/.git` mounted read-write at `/home/agentuser/.repo.git` (a fixed container path).
- The worktree checkout mounted read-write as the agent's working directory.

**Session start (host preflight):**

1. `git -C "$PROJECT_DIR" worktree add "$SNAPSHOT_DIR" -b "agent/<session-id>"` (the path must be empty or absent).
2. Rewrite `$SNAPSHOT_DIR/.git` to `gitdir: /home/agentuser/.repo.git/worktrees/<name>`; save the original content for teardown.
3. `git -C "$PROJECT_DIR" pack-refs --all`, then `chmod a-w .git/packed-refs`.
4. `chmod -R a-w .git/refs/heads/ .git/refs/tags/`; ensure `.git/refs/agent/` remains writable.
5. `chmod a-w .git/config .git/HEAD .git/index`; `chmod -R a-w .git/hooks/`.
6. `chmod a-w` on `.git/objects/pack/*` files — packed objects become undeletable; new objects are still written as loose.
7. Recommended: `git -C "$PROJECT_DIR" gc` before step 3, to maximise packed coverage (reduces loose-object exposure — see Consequences). Recommended, not mandatory; interacts with session-start latency.
8. `--network=none` on the agent container.

**Session end (teardown):**

1. Restore permissions on all paths above.
2. Restore the original `$SNAPSHOT_DIR/.git` content (or `git worktree repair`).
3. `git worktree remove` / `git worktree prune` as appropriate.

**Why `--network=none` is load-bearing:** `.git/config` is readable, so a credentialed remote URL (`https://token@…`) leaks to the agent; with network access the agent could authenticate as the host. No network closes push, fetch, and exfiltration in one control.

**No mediation layer.** An optional PATH shim returning friendly errors for destructive verbs (`gc`, `update-ref`, `filter-branch`) is defence-in-depth and must be documented as non-boundary.

## Consequences

### Residual risk (to be restated in `security.md` when the mode lands)

- **Loose-object deletion.** `objects/` must be writable for new commits; pre-existing loose objects are deletable by a determined agent. Mitigated by the host-side `gc` preflight (packed objects become read-only).
- **Repository hooks fire.** Hooks are shared from the common dir; a repo's `pre-commit` / `commit-msg` hooks run on agent commits. Candidate mitigation: `core.hooksPath` override for the worktree — unresolved.
- **`git gc --prune` inside the session** fails partially against read-only packs — inconvenience, not corruption.
- **Host-side git commands against the worktree fail** while its `.git` pointer is rewritten. Operator review runs against the agent branch from the main repo (`git diff main..agent/<id>`), which does not touch the worktree file. The pointer is restored at teardown.

### Open items

- `gc` preflight: recommended vs. mandatory.
- `core.hooksPath` handling for agent commits.
- Cross-platform gitdir path forms (macOS, Windows/WSL) in the rewrite step.

### Exit condition

Implement per the M2.6.4 task list, then audit against the residual-risk list. On audit pass: update `security.md` to assert the worktree posture, record the mechanism in an ADR, and mark this document settled. On audit failure: revise the mechanism or mark worktree rejected.
