# Agent Handover

**Session date:** 2026-04-20
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Planning
**Status:** Closed

## Objective

Produce the authoritative design for the M2.3 apply workflow (Changes 3, 5, 6), resolve
open stories, and update the roadmap to reflect the new change scope.

## Scope

- Design document: apply workflow, baseline advancement, diff primitives, parallel sessions
- Story closures: `story_diff_pipeline_unification.md` (renamed from `story_diff_pipeline_unification_and_baseline_advancement.md`),
  `story_parallel_sessions_worktree.md`
- Roadmap update: M2.3 change table, M2.7 scope reduction
- Supersede `design_git_workflow_improvements.md` as design reference

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) | New authoritative design doc — produced this session |
| [`docs/discussions/story_diff_pipeline_unification.md`](docs/discussions/story_diff_pipeline_unification.md) | Closed this session (renamed from `story_diff_pipeline_unification_and_baseline_advancement.md`) |
| [`docs/discussions/story_parallel_sessions_worktree.md`](docs/discussions/story_parallel_sessions_worktree.md) | Closed this session |
| [`docs/discussions/design_git_workflow_improvements.md`](docs/discussions/design_git_workflow_improvements.md) | Superseded as design reference; header update pending apply |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | M2.3 and M2.7 updated this session |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Change 3 candidate approved with two targeted fixes | `git am --abort` on failure; `SANDBOX_DIR` existence check | Design doc — Apply Workflow section |
| `make confirm SYNC=1` rather than auto-sync | Operator controls timing; tight validation against container session label | Design doc — Baseline Advancement section |
| `make sync` as separate catch-up command | Loose, no session validation; applies all unadvanced sessions in order | Design doc — Apply Workflow section |
| `checkpoint-latest.ref` removed | Replaced by container label lookup + `checkpoint.sh` tag query; ref files can go stale | Design doc — Primitives table |
| `container-name.ref` and `last-confirmed` removed | Same rationale — labels and `ADVANCED_SESSIONS` are ground truth | Design doc — Primitives table |
| `scripts/checkpoint.sh` introduced | Consolidates tag creation, pruning, lookup, `WORKTREE_ID` derivation across all scripts | Design doc — Container naming section |
| Container naming moved from M2.7 to M2.3 Change 5 | Required for `make sync` and parallel session safety; unblocks Change 6 | roadmap.md — M2.3 and M2.7 |
| Baseline advancement as M2.3 Change 6 | Logically part of apply workflow; depends on Change 5 only, not M2.7 | roadmap.md — M2.3 |
| `package-diff` unification: `libs/package-diff.sh` + git alias | Logic must be versioned and shared, not reconstructed from prose; local git alias fits onboard pattern | Story resolution |
| `story_parallel_sessions_worktree` closed | All OQs resolved: OQ1/OQ2 by Change 1, OQ3/OQ4/OQ5 by design | Story resolution + roadmap M2.7 |
| `story_diff_pipeline_unification` closed | All OQs resolved by design doc | Story resolution |
| `design_git_workflow_improvements.md` superseded | Retained as implementation log for Changes 1–4 only; pending deletion after bundle | Header update |
| Short-form session aliases deferred | `latest` default covers 90% case; revisit on operator feedback | Design doc — Session resolution |
| `make refresh` in `Makefile.template` passes `--project` | Needed for git alias re-registration; consistent with `make onboard` invocation | Makefile.template |
| `make onboard` not in `Makefile.template` | Sandbox Makefile is post-onboard; bootstrapping is a one-time external operation | Makefile.template |
| `--baseline` required on host for `package-diff.sh` | No synthetic baseline outside container; silent HEAD default would produce misleading diff | `libs/package-diff.sh` |
| Container fallback chain for baseline | env var → `.git/BASELINE_SHA` file → hard error | `libs/package-diff.sh` |

## Completed this session

| File | Change |
|---|---|
| `docs/discussions/design_apply_workflow_and_baseline_advancement.md` | Created — authoritative design spec |
| `docs/discussions/story_diff_pipeline_unification.md` | Closed — renamed, pain point added, unification target updated to `libs/package-diff.sh` + git alias, resolution rewritten |
| `docs/discussions/story_parallel_sessions_worktree.md` | Closed — Status Resolved, open questions resolved inline, resolution written |
| `docs/discussions/design_git_workflow_improvements.md` | Header updated — superseded redirect added |
| `docs/development/roadmap.md` | M2.3 change table expanded (Changes 5, 6 added); Change 1 note updated; Change 3 description updated; M2.7 container naming removed; M2.7 sub-stories updated |
| `libs/package-diff.sh` | Created — shared diff packaging script, baseline fallback chain, mechanical label derivation with override, host enforcement |
| `.skills/package-diff.md` | Rewritten — inline bash removed, script invocation, BASELINE_SHA documented, migration-guide structured |
| `scripts/onboard.sh` | Git alias registration added; refresh path derives PROJECT_DIR from .env as safety net |
| `libs/Makefile.template` | `make refresh` target added with `--project`; `make onboard` explicitly excluded |

## Deferred items

| Item | Reason | Goes to |
|---|---|---|
| `checkpoint-latest.ref` removal from tests and docs | Implementation-time change; lands with Change 5 | M2.3 Change 5 session |
| `20260412-02-m2_3_onhold.md` deletion | Pending changes bundle and commit | After M2.3 Changes 3–6 committed |
| `design_git_workflow_improvements.md` deletion | Retained as implementation log until Changes 1–4 bundle committed | After M2.3 complete |

| Validate `package-diff.sh` behaviour | Script not yet tested against live repo | `20260420-02-chore-package_diff_unification` |

## Next session

Context handover: [`20260420-02-chore-package_diff_unification.md`](handovers/20260420-02-chore-package_diff_unification.md)


## Objective

Produce the authoritative design for the M2.3 apply workflow (Changes 3, 5, 6), resolve open stories, and update the roadmap to reflect the new change scope.
open stories, and update the roadmap to reflect the new change scope.

## Scope

- Design document: apply workflow, baseline advancement, diff primitives, parallel sessions
- Story closures: `story_diff_pipeline_unification.md` (renamed from `story_diff_pipeline_unification_and_baseline_advancement.md`),
  `story_parallel_sessions_worktree.md`
- Roadmap update: M2.3 change table, M2.7 scope reduction
- Supersede `design_git_workflow_improvements.md` as design reference

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/discussions/design_apply_workflow_and_baseline_advancement.md`](docs/discussions/design_apply_workflow_and_baseline_advancement.md) | New authoritative design doc — produced this session |
| [`docs/discussions/story_diff_pipeline_unification.md`](docs/discussions/story_diff_pipeline_unification.md) | Closed this session (renamed from `story_diff_pipeline_unification_and_baseline_advancement.md`) |
| [`docs/discussions/story_parallel_sessions_worktree.md`](docs/discussions/story_parallel_sessions_worktree.md) | Closed this session |
| [`docs/discussions/design_git_workflow_improvements.md`](docs/discussions/design_git_workflow_improvements.md) | Superseded as design reference; header update pending apply |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | M2.3 and M2.7 updated this session |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Change 3 candidate approved with two targeted fixes | `git am --abort` on failure; `SANDBOX_DIR` existence check | Design doc — Apply Workflow section |
| `make confirm SYNC=1` rather than auto-sync | Operator controls timing; tight validation against container session label | Design doc — Baseline Advancement section |
| `make sync` as separate catch-up command | Loose, no session validation; applies all unadvanced sessions in order | Design doc — Apply Workflow section |
| `checkpoint-latest.ref` removed | Replaced by container label lookup + `checkpoint.sh` tag query; ref files can go stale | Design doc — Primitives table |
| `container-name.ref` and `last-confirmed` removed | Same rationale — labels and `ADVANCED_SESSIONS` are ground truth | Design doc — Primitives table |
| `scripts/checkpoint.sh` introduced | Consolidates tag creation, pruning, lookup, `WORKTREE_ID` derivation across all scripts | Design doc — Container naming section |
| Container naming moved from M2.7 to M2.3 Change 5 | Required for `make sync` and parallel session safety; unblocks Change 6 | roadmap.md — M2.3 and M2.7 |
| Baseline advancement as M2.3 Change 6 | Logically part of apply workflow; depends on Change 5 only, not M2.7 | roadmap.md — M2.3 |
| `package-diff` unification: `libs/package-diff.sh` + git alias | Logic must be versioned and shared, not reconstructed from prose; local git alias fits onboard pattern | Story resolution |
| `story_parallel_sessions_worktree` closed | All OQs resolved: OQ1/OQ2 by Change 1, OQ3/OQ4/OQ5 by design | Story resolution + roadmap M2.7 |
| `story_diff_pipeline_unification` closed | All OQs resolved by design doc | Story resolution |
| `design_git_workflow_improvements.md` superseded | Retained as implementation log for Changes 1–4 only; pending deletion after bundle | Header update |
| Short-form session aliases deferred | `latest` default covers 90% case; revisit on operator feedback | Design doc — Session resolution |

## Completed this session

| File | Change |
|---|---|
| `docs/discussions/design_apply_workflow_and_baseline_advancement.md` | Created — authoritative design spec |
| `docs/discussions/story_diff_pipeline_unification.md` | Closed — renamed, pain point added, unification target updated to `libs/package-diff.sh` + git alias, resolution rewritten |
| `docs/discussions/story_parallel_sessions_worktree.md` | Closed — Status Resolved, open questions resolved inline, resolution written |
| `docs/discussions/design_git_workflow_improvements.md` | Header updated — superseded redirect added |
| `docs/development/roadmap.md` | M2.3 change table expanded (Changes 5, 6 added); Change 1 note updated; Change 3 description updated; M2.7 container naming removed; M2.7 sub-stories updated |
| `libs/package-diff.sh` | New script — shared diff packaging, baseline arg, mechanical label derivation with override |
| `.skills/package-diff.md` | Updated — inline bash removed, invokes `libs/package-diff.sh` |
| `scripts/onboard.sh` | Git alias registration added for `package-diff` in `PROJECT_DIR/.git/config` |

## Deferred items

| Item | Reason | Goes to |
|---|---|---|
| Apply two story file fixes to repo | Session artifacts not yet committed | Next implementation session |
| `checkpoint-latest.ref` removal from tests and docs | Implementation-time change; lands with Change 5 | M2.3 Change 5 session |
| `20260412-02-m2_3_onhold.md` deletion | Pending changes bundle and commit | After M2.3 Changes 3–6 committed |
| `design_git_workflow_improvements.md` deletion | Retained as implementation log until Changes 1–4 bundle committed | After M2.3 complete |
| `package-diff` chore — remaining items | `libs/package-diff.sh` and `onboard.sh` produced this session. No `diff_package` extraction needed — script is standalone, no shared logic with `libs/diff.sh` warrants extraction. Remaining: validate script behaviour. Non-blocking on Change 3 | `20260420-02-chore-package_diff_unification` |

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Change 3 implementation — `scripts/apply_workspace.sh` and `Makefile.template`.

**Two targeted fixes required before implementing Change 3 as-is:**
1. Add `git am --abort` + draft branch cleanup on patch application failure
2. Add `SANDBOX_DIR` existence check alongside `PROJECT_DIR` check

**Key design constraints for the implementer:**
- Checkpoint tag resolved via `checkpoint.sh` (new script, Change 5) — for Change 3, implement inline or as a stub; `checkpoint.sh` is formalised in Change 5
- `draft-state` is single file per `SANDBOX_DIR` — correct as-is
- `make confirm` does not auto-sync — `SYNC=1` flag only; `make sync` is a separate target (Change 6)
- `latest` default for session resolution is already implemented in candidate — retain as-is

**Watch-outs:**
- `make confirm` in Change 3 does not include `SYNC=1` — that flag is added in Change 6. Change 3 implements draft/confirm/reject only. Confirm this boundary is clear before implementing.
- Change 5 (container naming + labels) is a prerequisite for Change 6 (baseline advancement) but not for Change 3. Changes 3 and 5 can be implemented in either order or the same session.

**Hot files for next session:**
- This handover
- `roadmap.md` (updated)
- `apply_workspace.sh` (candidate)
- `Makefile.template` (candidate)
- `design_apply_workflow_and_baseline_advancement.md` (produced this session)
