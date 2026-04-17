# Agent Handover

**Session date:** 2026-04-17
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline (plus new story work)
**Session type:** Planning
**Status:** Closed

## Objective

Investigate and frame the unified session identity, harness versioning, and multi-session problem space; produce story documents capturing design decisions and deferred work.

## Scope

Standalone planning session. Not part of M2.3 implementation. M2.3 Changes 2–3 resume after this session. New story documents produced here feed into a future sub-milestone (proposed M2.7).

## Carried forward

| Item | From handover |
|---|---|
| M2.3 Changes 2–3 pending | `20260416-03-chore-documentation_audit.md` |

## Acceptance criteria

Not applicable — planning session.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/discussions/story_session_identity_and_harness_versioning.md`](../discussions/story_session_identity_and_harness_versioning.md) | New — primary story, resolved |
| [`docs/discussions/story_parallel_sessions_worktree.md`](../discussions/story_parallel_sessions_worktree.md) | New — sub-story, investigation in progress |
| [`docs/discussions/story_harness_packaging_and_install_versioning.md`](../discussions/story_harness_packaging_and_install_versioning.md) | New — sub-story stub, deferred large task |
| [`docs/discussions/investigation_staleness_and_interactivity_regression.md`](../discussions/investigation_staleness_and_interactivity_regression.md) | Superseded — stripped to header + redirect |
| [`docs/discussions/investigation_versioning_and_governance.md`](../discussions/investigation_versioning_and_governance.md) | Superseded — stripped to header + redirect |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Primitive set: `SESSION_TS`, `REPO_COMMIT`, `WORKTREE_ID` | Single timestamp eliminates parity drift; commit hash is stable identity; worktree path hash enables parallel session isolation without renaming projects | `story_session_identity_and_harness_versioning.md` — Design |
| Two-sig model: `container-sig = hash(libs/ + Dockerfiles)`, `harness-sig = hash(scripts/ + compose files + setup.sh)` | Different scopes, different action semantics — rebuild vs warn-only; hash boundary matches folder boundary after compose file refactor | `story_session_identity_and_harness_versioning.md` — Design |
| `harness-sig.ref` stored in `SANDBOX_DIR`, written at session end | Per-project scope is correct for drift detection; writing at end makes comparison meaningful (last successful session vs current) | `story_session_identity_and_harness_versioning.md` — Deferred |
| Images are provider-level not project-level; rename drops `<project>` suffix | Project content enters via mounts only; `<project>` suffix is vestigial namespace pollution | `story_session_identity_and_harness_versioning.md` — Design |
| Image rename blocked on `agents.md` code review | Documentation contradicts itself on whether `agents.md` is baked in or mounted; must verify in provider Dockerfiles before rename proceeds | `story_session_identity_and_harness_versioning.md` — Design |
| `container-sig` is provider-specific (includes provider Dockerfiles) | Provider Dockerfiles affect the container and require rebuild on change | `story_session_identity_and_harness_versioning.md` — Design |
| `harness-sig` scope: `scripts/ + providers/<n>/setup.sh + providers/*.yml + providers/<n>/*.yml` | Covers all host-side behaviour; compose files move from `libs/` to `providers/` in paired refactor so hash boundary matches folder boundary | `story_session_identity_and_harness_versioning.md` — Design |
| `sandbox-entrypoint.sh` must wipe and re-init on every container start | Stopped containers cannot be assumed clean; idempotent entrypoint makes restart equivalent to recreation for sandbox state | `story_session_identity_and_harness_versioning.md` — Design |
| Container naming redesign required: explicit `container_name:` derived from session identity | Current image-name=container-name assumption already broken in practice (compose generates its own names); prerequisite for worktree support | `story_parallel_sessions_worktree.md` — Investigation Findings |
| `WORKTREE_ID` as discriminator, not `PROJECT_NAME` rename | `PROJECT_NAME` is identical across worktrees (committed Makefile); operator should not need to rename per worktree; path hash is unambiguous and requires no state tracking | `story_parallel_sessions_worktree.md` — Investigation Findings |
| Checkpoint tags namespaced by worktree: `agent-checkpoint/<worktree-id>/<timestamp>` | Prevents cross-session tag interference in shared git object store; scopes pruning correctly | `story_parallel_sessions_worktree.md` — Investigation Findings |
| Install versioning extracted as separate future story | Requires full rewrite of `make install` to snapshot harness source; does not block sig model | `story_harness_packaging_and_install_versioning.md` |
| Both prior investigations superseded and stripped | Pre-policy informal documents; reasoning fully re-expressed in story with better structure and accurate conclusions | `investigation_staleness_and_interactivity_regression.md`, `investigation_versioning_and_governance.md` |

## Completed this session

| File | Change |
|---|---|
| `docs/discussions/story_session_identity_and_harness_versioning.md` | New — resolved story, full design for session identity and harness versioning |
| `docs/discussions/story_parallel_sessions_worktree.md` | New — sub-story for parallel sessions via git worktree, investigation in progress |
| `docs/discussions/story_harness_packaging_and_install_versioning.md` | New — stub story for harness packaging and install versioning, deferred |
| `docs/discussions/investigation_staleness_and_interactivity_regression.md` | Superseded — stripped to header + redirect block |
| `docs/discussions/investigation_versioning_and_governance.md` | Superseded — stripped to header + redirect block |

## Deferred items

| Item | Reason | Where next |
|---|---|---|
| `agents.md` code review (verify not baked into provider Dockerfiles) | Requires file access to `providers/<n>/provider.Dockerfile` | Next implementation session before image rename proceeds |
| Worktree sub-story OQ1: `WORKTREE_ID` representation | Not yet resolved — hash vs basename vs operator-supplied | `story_parallel_sessions_worktree.md` — resolve before worktree implementation begins |
| Worktree sub-story OQ3: container naming pattern | Not yet resolved — predictable across restarts or new name per session? | `story_parallel_sessions_worktree.md` — resolve before worktree implementation begins |
| Compose file refactor (`libs/` → `providers/`) | Paired refactor for `harness-sig` hash boundary; not yet implemented | M2.7 or standalone chore |
| M2.3 Changes 2–3 | On hold pending this planning session; now unblocked | Resume next implementation session |

## Next session

**Immediate:** Resume M2.3 implementation — Change 2 (format-patch + session-scoped artefact directory, `libs/diff.sh`).

Before starting Change 2, the implementing agent must also apply the Change 1 additions identified this session that have not yet been acted upon. These are a second handoff spec separate from the one already implemented:

> Three additions to Change 1 scope, all low-risk and independent of the timestamp parity and detached HEAD changes already implemented. First, `WORKTREE_ID` derivation: add a new exported variable derived from the full absolute path of `PROJECT_DIR` — a short hash, e.g. `WORKTREE_ID=$(echo "$PROJECT_DIR" | sha1sum | head -c8)`. Stable across runs for the same worktree, requires no operator input. Second, checkpoint tag namespace: change the tag format from `agent-checkpoint/YYYYMMDD-HHMMSS` to `agent-checkpoint/${WORKTREE_ID}/YYYYMMDD-HHMMSS`. Update pruning to scope to `agent-checkpoint/${WORKTREE_ID}/*`. Update `apply_workspace.sh` to match — the ref file format is unchanged, only the tag name it contains changes. Third, `REPO_COMMIT` capture: add `REPO_COMMIT=$(git -C "$PROJECT_DIR" rev-parse HEAD)` and export alongside `SESSION_NAME`. Not consumed by anything in Change 1 but establishes the primitive for image labels in a later sub-milestone. No other changes to Change 1.

Context for Change 2: [`20260412-02-impl-m2_3.md`](20260412-02-impl-m2_3.md) (frozen design), [`docs/devlog/discussions/design_git_workflow_improvements.md`](../discussions/design_git_workflow_improvements.md) (current spec — note: Context and Status section of this document is due for a refresh).

**After M2.3 completes:** M2.7 — Session Identity and Harness Versioning is now defined in `roadmap.md`. Scope, dependencies, and sub-story links are in the roadmap entry. Worktree parallel session support (`story_parallel_sessions_worktree.md`) two open questions (OQ1, OQ3) must be resolved at M2.7 session open before implementation of the container naming and image rename work begins.