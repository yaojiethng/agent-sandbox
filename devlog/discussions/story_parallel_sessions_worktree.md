# Story — Parallel Sessions via Git Worktree

**Status:** Resolved

> **Resolved.** Design recorded in [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md).

**Parent story:** [`story_session_identity_and_harness_versioning.md`](story_session_identity_and_harness_versioning.md)

---

## Context

The harness currently assumes one session per project at a time. A session is tied to a
`PROJECT_DIR` / `SANDBOX_DIR` pair, and container names are derived from `PROJECT_NAME` —
a single global name per project. Running two sessions against the same repository
simultaneously requires two independent working trees, two sandbox directories, and
non-colliding identity tokens.

`git worktree add` provides independent working trees of the same underlying repository at
different paths. Each worktree is treated as its own `PROJECT_DIR` for the harness,
enabling parallel sessions without architectural changes — the operator sets up worktrees,
onboards each, and runs independent harness instances.

This story investigated whether the worktree convention is viable given the current
identity model, and what needs to change to make it safe.

---

## Pain Points

**Sequential sessions are a development bottleneck.** Planning and validation sessions do
not block each other logically, but the single-session model forces them to be serial.

**`PROJECT_NAME` is identical across all worktrees.** All worktrees of the same repo carry
the same `PROJECT_NAME`. Using it alone for collision avoidance is insufficient.

**Checkpoint tags live in the shared git object store.** All worktrees share the same tag
namespace. Two concurrent sessions could create tags with colliding names or interfere with
each other's pruning logic.

**Container naming was broken and unscalable.** The harness assumed container name equals
image name. In practice Docker Compose overrides this with generated names, so the harness
had no reliable way to address a running container. This was a prerequisite fix for
worktree support.

---

## Constraints

- Worktree sessions must not corrupt or interfere with each other's git state.
- `PROJECT_NAME` must remain stable and human-assigned.
- Container names, artefact directories, and state files must be non-colliding without
  requiring the operator to rename projects.
- The solution works as a workflow convention with minimal harness changes.

---

## Investigation Findings

### Collision analysis

| Identity token | Shared across worktrees? | Resolution |
|---|---|---|
| `PROJECT_NAME` | Yes — insufficient as sole discriminator | `WORKTREE_ID` introduced as per-instance discriminator |
| `WORKTREE_ID` | No — derived from `PROJECT_DIR` absolute path | None — path is unique per worktree |
| Image names | Yes — correctly shared; images are per-project not per-instance | None needed |
| Container names | Was broken — compose-generated, not harness-controlled | Fixed in Change 5: explicit `container_name:` derived from session identity |
| Checkpoint tags | Yes — shared object store | Fixed in Change 1: namespaced as `agent-checkpoint/<worktree-id>/<timestamp>` |
| `SESSION_NAME` | Partial — branch + timestamp | Mitigated by git worktree branch uniqueness constraint |
| `.workspace/`, `draft-state` | No — per `SANDBOX_DIR` | None |
| Session artefact directories | No — per `SANDBOX_DIR` | None |

### `WORKTREE_ID` as discriminator

`WORKTREE_ID` is derived from a short hash of the `PROJECT_DIR` absolute path. Used in
checkpoint tag namespace and container naming. `PROJECT_NAME` remains stable and
human-assigned; image names continue to use `PROJECT_NAME` alone.

Implemented in Change 1. Checkpoint tag format: `agent-checkpoint/<worktree-id>/<timestamp>`.
Pruning scopes to `agent-checkpoint/<worktree-id>/*`.

### Container naming redesign

Explicit `container_name:` set in the generated compose, derived from session identity.
Container lookup for `make confirm SYNC=1` and `make sync` uses the
`agent-sandbox.project-dir` Docker label rather than any ref file — label is authoritative
for the container's lifetime. Implemented in Change 5.

### Git worktree branch constraint as collision guard

`git worktree` requires each worktree to check out a distinct branch. Parallel sessions
are on different branches by construction — `SESSION_NAME` values differ and artefact
directories are non-colliding. No additional guard required.

### Onboarding ceremony

Existing workflow is sufficient:

```bash
git worktree add ../project-feature feature-branch
mkdir ../project-feature-sandbox
agent-sandbox onboard --name=project \
  --project=../project-feature \
  --sandbox=../project-feature-sandbox
make start PROVIDER=<n>
```

No `make worktree` convenience command needed at this stage.

### Worktree to main repo

Changes produced in a worktree session land on the worktree branch after `make confirm`.
Merging to the main repo branch is standard git. The harness does not orchestrate
cross-worktree merges.

### `.snapshot/` trimming — deferred

With `baseline.tar` covering the HEAD state, the rsync copy in `.snapshot/` serves only
the working tree overlay. A delta-only approach (copy only the diff between HEAD and the
working tree) was evaluated and deferred — rsync handles all cases uniformly and the
correctness tradeoff is not worth the space saving at current scale.

---

## Resolution

**Decision:** Worktree convention is viable with two harness-level prerequisites, both
implemented in M2.3:

- Change 1 (complete): `WORKTREE_ID` + checkpoint tag namespace
- Change 5 (pending): container naming redesign + Docker labels

No architectural changes to the harness are required beyond these. The worktree pattern
works as an operator workflow convention.

**Where the work goes:** Change 5, M2.3. Full design in
[`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md)
— Parallel Sessions section.

**Why:** `WORKTREE_ID` eliminates tag namespace collision. Explicit container naming
eliminates the container addressing bug. Docker label lookup eliminates ref files that
can go stale. Together these make the worktree convention safe without requiring the
operator to manage any additional identity tokens.
