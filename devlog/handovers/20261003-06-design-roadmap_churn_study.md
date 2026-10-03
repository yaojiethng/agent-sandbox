---
date: 2026-10-03
milestone: T5 - Archival
type: Design
status: Closed
---

# Handover - The roadmap churn diagnostic study

## Objective

Diagnose why the roadmap file churns, from the session logs and the tree, and write the evidence into a study that feeds the T5 `Roadmap-mechanism rewrite study`.

## Scope

This iteration is a diagnostic study, not a fix. It applies no change to the roadmap, to the policies, or to the gates. The deliverable is one report under `devlog/discussions/`, at draft status.

The trigger is the operator's observation after the 2026-10-03 session: the roadmap file produced disproportionate review load, and the churn repeated across several sessions. Three tracks feed the diagnosis, and each is independent of the others:

| In | Out |
|---|---|
| The session logs under `~/.pi/agent/sessions`, read for recurring friction | Any fix to the roadmap, its policies, or its gates |
| A measured structural audit of `devlog/roadmap.md`, `roadmap_future.md` and `changelog.md` | The T5 rewrite itself, which this study only informs |
| The policies and prompts that read and write the roadmap, read for the rules that force churn | The `space-bunny-free` model's contribution, which is stated as a separate cause and not diagnosed here |

The study answers a different question from the T5 row it feeds. The T5 row asks what mechanism to adopt; this study asks what the present mechanism costs, and which costs are local defects a small change removes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The study exists at draft status in `devlog/discussions/` | `ls devlog/discussions/20261003-study-draft-roadmap_churn_study.md` | Agent [x] |
| Each finding carries the command and its output, or a quoted session excerpt | reading the study's evidence column; no finding rests on assertion | Agent [x] |
| The churn causes are separated into model-driven, mechanism-driven, and workflow-context-driven | the study's Findings summary; each cause names its class | Agent [x] |
| The study names the low-hanging improvements separately from the rewrite requirements | the study's Resolution status and requirements sections | Agent [x] |
| The tree passes the gates | `bash scripts/lint.sh` reports clean across 6 gates | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20261003-study-draft-roadmap_churn_study.md`](../discussions/20261003-study-draft-roadmap_churn_study.md) | the deliverable |
| [`devlog/roadmap.md`](../roadmap.md) | the subject of the audit, read and not written beyond its write-back row |
| `~/.pi/agent/sessions/*.jsonl` | the session evidence, read outside the tree |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fan the three discovery tracks out to subagents rather than run them serially | the tracks are independent, each reads a disjoint evidence set, and none writes to the tree | this handover |
| Study status `draft`, not `settled` | a study moves from draft to settled only on review, and this one has not been reviewed | `discussion_policy.md` |
| Keep the model's contribution as a stated cause, not a subject | the operator named it directly; the study's value is what the mechanism contributes beyond it | this handover |
| Land one study document with a requirements section, not a study plus a story | the requirements are derived from the same measurements as the findings, so a second file would restate them; a split stays available at review | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The roadmap file is edited by 105 of 157 commits since 2026-09-25, and 80 of those 105 change six lines or fewer. Every iteration writes back to it, so the file is on the critical path of every commit. | mechanism | measured before the fan-out; the study confirms or refutes the cost |
| The active sub-milestone's rows carry prose rather than identifiers, so a row cannot be referenced by anything stable: handovers, prompts and other rows cite a position or a paraphrase, and both break on the next edit. | mechanism | 197 positional references name a roadmap record, and 3 of 3 sampled are stale |
| The discovery fan-out found the same access ratio as the maintenance skill: 22 of 27 checks read and judge a row, against 5 mechanical ones, and the schedule runs it at every iteration open and close. | mechanism | the judgement load is the operator's review cost, and no gate reduces it |
| `python3` is absent from the image, so 51 failures in the window came from it and every mutation-tier run of that period was blocked rather than failed. | tool | a silent-blocked tier is worse than a failing one; recorded here for the harness track, not this study's subject |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261003-study-draft-roadmap_churn_study.md` | new: the diagnostic study, at draft, with six causes, seven local improvements and eight rewrite requirements |
| `devlog/roadmap.md` | the T5 write-back row for this study, and a pointer from the rewrite-study row to the study |
| `devlog/handovers/20261003-06-design-roadmap_churn_study.md` | this handover |
