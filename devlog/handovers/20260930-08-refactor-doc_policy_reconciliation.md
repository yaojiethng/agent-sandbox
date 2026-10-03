# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Refactor
**Status:** Closed

## Objective

Reconcile the documentation-related policy files - `adr_policy`, `discussion_policy`, `documentation_policy`, `handover_policy`, `story_policy`, `study_policy` - against the concept index `documentation_taxonomy.md`, so the taxonomy is single-owned in the concept doc and no classification content lingers unreconciled in the policies.

## Scope

Targets the Docs-and-ADR-consolidation group in `roadmap.md`, including the deferred `documentation_policy.md` structural pass recorded in handover `20260930-07`. Exact scope pending operator confirmation of the findings in the session.

## Carried forward

| Item | From handover |
|---|---|
| `documentation_policy.md` structural pass: promote `Rule authority`; re-form `Record Lifecycle`; split the `Enforcement Rules` / `Communication Standards` grab-bags; rename `Read pass economics` / `Document depth and verbosity`; drop or re-source the `Markdown lint gate` roadmap-iteration citation | `20260930-07` |
| `Folder Structure` table / `devlog/` deconflict (the table claims "exactly one of the following" while covering only `docs/`) - may need reconciliation with `discussion_policy` | `20260930-07` |

## Acceptance criteria

1. The concept doc `documentation_taxonomy.md` states the discussion document as one family with four types (story, study, design, report), not three sibling kinds. Accepted.
2. The durability decision is recorded in `policy_declarative_framing.md` (2026-09-30) and phrased reference-durable in the concept doc, `story_policy`, and `study_policy`. Accepted.
3. `story_policy` / `study_policy` drop the stale `story_` / `investigation_` prefixes and the permanent-reasoning-record framing; `study_policy` is titled Study Policy. Accepted.
4. `adr_policy` 'Relationship to other records' classification moves into the concept doc; the policy keeps the rule and a link. Accepted.
5. Header-format rules name discussion document types, not `story_` / `investigation_`; the review skill mirrors it. Accepted.
6. Lint clean; handover Closed. Accepted.

## Hot files

| File | Why in scope |
|---|---|
| `docs/concepts/documentation_taxonomy.md` | the unit of record; inventory mis-frames the discussion family, durability labels contradict story/study policy |
| `docs/operations/discussion_policy.md` | owns the discussion document types (story, study, design, report) and naming |
| `docs/operations/story_policy.md` | stale `story_` naming; lifecycle contradicted by concept-doc durability label |
| `docs/operations/study_policy.md` | titled Investigation Policy; `investigation_` prefix vs `study` type code |
| `docs/operations/adr_policy.md` | `Relationship to other records` classification partially duplicates the concept doc |
| `docs/operations/documentation_policy.md` | deferred structural pass; header-format references stale `story_` / `investigation_` names |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A settled discussion-family record (story, study, design, report) is reference-durable, not permanent: kept as a reference for the course of the implementation it describes, then subsumable; the approaches considered and the knowledge tested surface in summary in the ADR, the durable home of record | operator statement, 2026-09-30; ADRs already hold approaches and knowledge in summary | `policy_declarative_framing.md` (2026-09-30 entry); concept doc Durability |
| Study is the canonical name for the feasibility discussion type; `investigation` retires as a name | matches the `study` type code and current file practice (`-study-<status>-`) | `discussion_policy.md` (retired-name note) |
| Convert story and study to workflows returning a generic `report` is deferred as a future task, not this iteration | they are rarely used now; a back-compatibility surface is needed | `roadmap.md` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Story and study are valid, current discussion document types (the `story`/`study`/`design`/`report` table in `discussion_policy`); the concept doc inventory had mis-framed them as sibling top-level kinds | contradiction | current iteration - fixed the inventory to the family-with-four-types model |
| The story/study sub-policies carried pre-ADR intent ("never deleted / permanent reasoning record") contradicting the durable-home-of-record model | contradiction | current iteration - rephrased to reference-durable, subsumable; ADR is the durable home |
| The `study` type and the `investigation_` file prefix are two names for one document kind; `study_policy.md` was already renamed from `investigation_policy.md` | naming conflict | current iteration - canonicalized to `study`; `investigation` retired in `discussion_policy` |
| Legacy `investigation_` (9) and `story_` (11) files have no determinable date from a naive `git log --diff-filter=A` read (they predate or were bulk-added pre-snapshot), so they cannot be renamed by guessing | blocker | resolved - the fanout workers dated each from its `--follow` introduction commit cross-checked against the creating handover; all 20 renamed, links swept: below |
| Fanout one-per-file with read-only provenance workers worked cleanly for the rename batch: 20 workers each analyzed one file (git date + content status + inbound-link list + hard-case) and replied via the pool join; the primary consolidated the writes, so no worker wrote and no file collided. The operator's decompose-to-provenance / consolidate-writes shape is the right fanout form for a propagation task whose link updates touch shared files | process | current iteration - rename batch landed this way |
| Date prefixes follow the `--follow` introduction-commit date, cross-checked against the creating handover; where no same-date handover exists (the handover system began 2026-03-13) the commit date stands. A few files (container_layer, linux_fs_uid) were committed the day after their authoring handover, so the commit date is one day later than the handover prefix | data | current iteration - adopted commit date for determinism |
| The `Folder Structure` table / `devlog/` deconflict and the `documentation_policy` structural pass remain deferred | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| `docs/concepts/documentation_taxonomy.md` | inventory corrected to the discussion family with four types; Durability phrased reference-durable with the ADR as the durable home |
| `docs/adr/policy_declarative_framing.md` | added 2026-09-30 durability entry; corrected entry ordering to newest-at-top |
| `docs/operations/story_policy.md` | dropped stale `story_` prefix; rephrased durability reference-durable; renamed investigation references to studies |
| `docs/operations/study_policy.md` | retitled Study Policy; `investigation` to `study` throughout; dropped stale `investigation_` prefix; rephrased durability |
| `docs/operations/discussion_policy.md` | recorded that `investigation` is retired in favor of `study` |
| `docs/operations/documentation_policy.md` | header-format rule names discussion document types; correction-forms row `Study or investigation` to `Study` and re-anchored |
| `docs/operations/adr_policy.md` | migrated `Relationship to other records` classification into the concept doc; kept the rule and a link |
| `workflow/coding-agent/audits/architecture-doc-reviewer.skill.md` | header-format check names discussion type names instead of `story_`/`investigation_` prefixes |
| `devlog/roadmap.md` | added the future story/study-to-`report` workflow-conversion task |
| 20 legacy discussion documents | renamed to canonical `YYYYMMDD-{type}-{status}-{description}` via fanout provenance: 9 `investigation_*` -> `study` (6 settled, 1 superseded, 1 active, 1 workspace-input settled) and 11 `story_*` -> `story` (5 settled, 3 active, 1 draft, 2 superseded). All relevant inbound links swept across 41 files (50 handovers/docs/scripts) |
| `scripts/manual/cleanup_orphan_volumes.sh` | comment retargeted to the renamed prune-rule2 study |
| `devlog/discussions/20260516-story-superseded-windows_filesystem_incompatibilities.md` | status line updated and a superseded redirect added to `20260522-story-settled-agent_state_persistence.md` |

## Deferred items

| Item | Reason | Where it goes next |
|---|---|---|
| The `documentation_policy` structural pass and the `Folder Structure` / `devlog/` deconflict | not part of this reconciliation; a grab-bag pass | next iteration |

## What's Next

M3.2.1 - Loops as Workflows; Docs-and-ADR-consolidation group.

Roadmap maintenance already run (the future story/study-to-`report` task added this iteration).

Watch-outs: the `documentation_policy` structural pass and the `Folder Structure`/`devlog/` deconflict are the next deferred group. No legacy `story_`/`investigation_` discussion files remain.

**Conclusions:** the durability model for discussion-family records is settled (reference-durable, subsumable; ADR is the durable home); `study` is the canonical name and `investigation` is retired; story and study remain valid discussion document types; the concept index is the single owner of the taxonomy; all 20 legacy discussion files now carry the canonical naming with their inbound links swept. The one-per-file read-only fanout is the durable shape for propagation renames that touch shared files.
