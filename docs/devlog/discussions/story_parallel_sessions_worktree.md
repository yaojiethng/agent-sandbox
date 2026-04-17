# Story — Parallel Sessions via Git Worktree

**Status:** Investigation in progress

**Parent story:** [`story_session_identity_and_harness_versioning.md`](story_session_identity_and_harness_versioning.md)

---

## Context

The harness currently assumes one session per project at a time. A session is tied to a `PROJECT_DIR` / `SANDBOX_DIR` pair, and container names are derived from `PROJECT_NAME` — a single global name per project. Running two sessions against the same repository simultaneously would require two independent working trees, two sandbox directories, and non-colliding identity tokens.

`git worktree add` provides independent working trees of the same underlying repository at different paths. Each worktree can be treated as its own `PROJECT_DIR` for the harness, potentially enabling parallel sessions without architectural changes to the harness itself — the operator sets up worktrees, onboards each as a separate project, and runs independent harness instances.

This story investigates whether the worktree convention is viable given the current identity model, and what — if anything — needs to change to make it safe.

---

## Pain Points

**Sequential sessions are a development bottleneck.** Planning and validation sessions do not block each other logically, but the single-session model forces them to be serial. A parallel session capability would allow implementation work and planning work to proceed simultaneously against the same repository.

**`PROJECT_NAME` is identical across all worktrees of the same repo.** `PROJECT_NAME` defaults to the git repo name and is baked into the committed Makefile. All worktrees of the same repo carry the same `PROJECT_NAME`. Using `PROJECT_NAME` alone for collision avoidance is insufficient — it cannot distinguish two worktrees of the same project.

**Checkpoint tags live in the shared git object store.** Checkpoint tags (`agent-checkpoint/<timestamp>`) are written into `PROJECT_DIR`'s git repo. All worktrees share the same tag namespace. Two concurrent sessions could: (a) create tags with colliding names if started within the same second, (b) interfere with each other's 5-tag pruning logic — one session pruning tags created by another.

**Container naming is broken and unscalable.** The harness assumes container name equals image name (`<provider>-agent-<project>`), enforcing one container per image. In practice Docker Compose overrides this with its own generated names (e.g. `agent-sandbox-agent-run-9b367bce9a11`), so the harness has no reliable way to address a running container by a predictable name. This breaks `docker stop`, `docker logs`, and any future reuse or multi-session logic. Needs redesign before worktree support is viable.

**`SESSION_NAME` has marginal collision risk.** Derived from branch name and timestamp. In practice constrained by the git worktree branch uniqueness requirement, but worth confirming as a sufficient guard.

---

## Constraints

- Worktree sessions must not corrupt or interfere with each other's git state in the shared repository.
- `PROJECT_NAME` must remain stable and human-assigned — it must not need to change per worktree instance.
- Container names, artefact directories, and ref files must be non-colliding across concurrent sessions without requiring the operator to rename projects.
- The fix for tag namespace collision must not break single-session behaviour or require changes to the checkpoint tag recovery workflow.
- The solution should work as a workflow convention with minimal harness changes — operator sets up worktrees, runs independent harness instances.
- Container naming must be redesigned as a prerequisite — the current image-name-equals-container-name assumption is already broken in practice.

---

## Open Questions

1. **`WORKTREE_ID` derivation:** Proposed: derive a `WORKTREE_ID` from the full absolute path of `PROJECT_DIR` (e.g. a short hash of the path, or the path basename). Used solely for collision avoidance in checkpoint tag namespacing and container naming. `PROJECT_NAME` remains unchanged and human-assigned. What is the right representation — full path hash (opaque but stable), basename (readable but potentially non-unique), or operator-supplied at onboard time?

2. **Tag namespace isolation:** Namespace checkpoint tags by worktree: `agent-checkpoint/<worktree-id>/<timestamp>` instead of `agent-checkpoint/<timestamp>`. Pruning scopes to `agent-checkpoint/<worktree-id>/*`. Does this break any existing recovery workflow that depends on the current tag format?

3. **Container naming redesign:** Container name should be derived from session identity: `<provider>-agent-<project>-<session-ts>` or similar. Image name (`<provider>-agent-<project>`) remains stable as the build identity — one image, multiple container instances. This is a prerequisite fix for worktree support and also corrects the existing naming bug. What is the right container name pattern? Does it need to be predictable across restarts of the same session, or is a new name per session acceptable?

4. **`SESSION_NAME` collision:** Git worktree branch uniqueness (each worktree must be on a different branch) means same-branch parallel sessions are blocked by git itself. Confirm this is a sufficient guard against `SESSION_NAME` collision.

5. **Onboarding ceremony:** Worktree convention requires: `git worktree add`, create `SANDBOX_DIR`, run `agent-sandbox onboard`. Acceptable as-is, or worth a `make worktree` convenience command?

6. **Advancing the baseline within a running container:** If the operator applies a draft, commits to the host repo, and wants to continue in the same container without restart, the container needs a mechanism to advance its own `BASELINE_SHA` — consuming applied patches and moving HEAD forward in `sandbox/`. Distinct capability from parallel sessions but same motivation. Flag for Change 3 design.

---

## Investigation Findings

### Collision analysis

| Identity token | Lives in | Shared across worktrees? | Collision risk |
|---|---|---|---|
| `PROJECT_NAME` | Makefile (committed, same across worktrees) | **Yes** | Same for all worktrees of same repo — insufficient as sole discriminator |
| `WORKTREE_ID` (proposed) | Derived from `PROJECT_DIR` full path | No — path is unique per worktree | None |
| Image names | Docker daemon, keyed by `PROJECT_NAME` | Yes — correctly shared, images are per-project not per-instance | None — sharing is correct |
| Container names | Currently broken — compose-generated, not harness-controlled | N/A | Needs redesign regardless of worktree support |
| Checkpoint tags | Shared git object store | **Yes** | Collision if same-second start; pruning interference |
| `SESSION_NAME` | Derived from branch + timestamp | Partial | Mitigated by git worktree branch uniqueness constraint |
| `.snapshot/`, `.workspace/` | `SANDBOX_DIR` (per worktree) | No | None |
| `harness-sig.ref`, `checkpoint-latest.ref` | `SANDBOX_DIR` | No | None |
| Session artefact directories | `SANDBOX_DIR/.workspace/changes/` | No | None |

### `WORKTREE_ID` as discriminator

Rather than requiring the operator to assign a unique `PROJECT_NAME` per worktree, introduce a separate `WORKTREE_ID` derived automatically from the full absolute path of `PROJECT_DIR`. Used solely in tokens that need per-instance uniqueness: checkpoint tag namespace and container name. `PROJECT_NAME` remains stable and human-assigned; image names continue to use `PROJECT_NAME` alone (correct — images are per-project, not per-instance).

Proposed checkpoint tag format: `agent-checkpoint/<worktree-id>/<timestamp>`. Pruning scopes to `agent-checkpoint/<worktree-id>/*`. No operator action required; no project renaming.

### Container naming redesign (prerequisite)

Current state: harness assumes `container_name = image_name`. In practice Docker Compose overrides this — observed container name was `agent-sandbox-agent-run-9b367bce9a11`, not `pi-agent-agent-sandbox` as the harness expects. The harness cannot reliably address running containers by name.

Required: explicitly set `container_name:` in the generated compose file to a harness-controlled value derived from session identity. Pattern: `<provider>-agent-<project>-<session-ts>`. Image name (`<provider>-agent-<project>`) remains the stable build identity. This fix is a prerequisite for worktree support and also corrects an existing bug.

### `.snapshot/` trimming — deferred

With `baseline.tar` covering the HEAD state, the rsync copy in `.snapshot/` serves only the working tree overlay. In principle only the delta between HEAD and the working tree is needed (untracked files, unstaged modifications, unstaged deletions). In practice rsync handles all three cases uniformly — deletions via `--delete`, modifications and untracked files via direct copy. A delta-only approach would need to special-case each of these, trading correctness simplicity for space efficiency. The three edge cases where the delta approach is non-trivial: (1) files deleted from working tree but present in HEAD — rsync `--delete` handles this; a delta copy would need explicit enumeration of deletions. (2) files modified in working tree — need to copy the modified version, not skip; requires distinguishing "same as HEAD" from "modified". (3) untracked files — not in git index, need explicit `git status --others` enumeration. Left as-is; revisit if large repo space cost becomes a real pain point.

### Git worktree branch constraint as a natural guard

`git worktree` requires each worktree to check out a distinct branch — checking out the same branch in two worktrees is a git error. Parallel sessions are therefore on different branches by construction, meaning `SESSION_NAME` values differ (branch component differs) and diffs are non-conflicting. Operator workflow: create a feature branch, `git worktree add`, onboard with `agent-sandbox onboard`, run session.

---

## Resolution

_Not yet written — investigation in progress._
