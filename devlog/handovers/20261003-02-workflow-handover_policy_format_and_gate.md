---
date: 2026-10-03
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - Align the handover policy with the tree, and gate its format

## Objective

Align `handover_policy.md`'s declared format with the tree's YAML frontmatter, add a handover-format gate scoped to incoming handovers with a manual single-file mode, and remove the superseded handover audit files.

## Scope

The deconfliction campaign left the handover surface with three defects. The policy's `## Format` block describes a header the tree abandoned at handover `20261002-20`; the no-`Deferred` prohibition has no check and one live violation; and the audit files the maintenance skill replaced are still on disk. A fourth, adjacent item states the correction-marker order a closed roadmap row needs when two corrections land on it.

| In | Out |
|---|---|
| Rewrite `handover_policy.md` `## Format` to the YAML-frontmatter form | Reformatting the existing handover records |
| Add a cutover-scoped gate, `scripts/lint/handover-format.mjs` and `scripts/check_handover_format.sh`, with a `--staged` mode and a single-file mode | Dead links in the exempted record trees (roadmap 90) |
| Reduce `handover-maintenance.md` Track B Step 5 to the gate command | Stale prompt references in the record layer (roadmap 128) |
| Add the marker-order rule to `roadmap_policy.md` `## Corrections to Closed Roadmap and Changelog Entries` | The last unpaired handover's roadmap row (roadmap 239) |
| Delete the two superseded audit files, `handover-audit.skill.md` and `audit.skill.md` | Stale-handover rotation (roadmap 295) |

The gate exempts every handover dated before the cutover, `20261003`, so the existing records are grandfathered and a correction to an old record stays exempt. A named file enforces regardless of date, so the same tool audits history on demand.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy's format block matches the tree | `handover_policy.md` `## Format` carries `date:`, `milestone:`, `type:`, `status:` and no `**Date:**` | Agent [x] -- the block carries the four fields and no bold header |
| The gate flags a non-conforming handover | run `bash scripts/check_handover_format.sh <fixture>` on a fixture with a bold header and a `## Deferred` section; expect findings | Agent [x] -- 9 fixture cases in `tests/test_handover_format_gate.sh` |
| The default tree run exempts existing handovers | `bash scripts/check_handover_format.sh` over the tree reports 0 findings | Agent [x] -- clean across 2, the two post-cutover handovers |
| A named file enforces regardless of date | `bash scripts/check_handover_format.sh devlog/handovers/20261002-25-workflow-loop_state_model_and_close_seam.md` reports its `## Deferred` | Agent [x] -- reports `## Deferred` and a missing `## Completed` |
| The gate is wired into the lint gate and the pre-commit hook | `scripts/lint.sh` names the gate; `pre-commit.sh` runs its `--staged` mode | Agent [x] -- GATES lists it; the hook runs `--staged` |
| The maintenance skill runs the gate instead of enumerating sections | `handover-maintenance.md` Track B Step 5 names `scripts/check_handover_format.sh` | Agent [x] -- Step 5 names the gate |
| The two superseded audit files are gone | `ls workflow/coding-agent/audits/handover-audit.skill.md workflow/coding-agent/audits/audit.skill.md` fails | Agent [x] -- both paths absent |
| The marker order is stated | `roadmap_policy.md` `## Corrections to Closed Roadmap and Changelog Entries` carries the newest-first rule | Agent [x] -- the marker-order paragraph landed |

`make lint` clean and the suite pass are preconditions, verified before close, not criteria.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | the `## Format` block moves to the YAML frontmatter form |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | gains the correction-marker order rule |
| `scripts/lint/yaml-loader.mjs` | the shared YAML loader lifted out of `prompt-frontmatter.mjs` |
| `scripts/lint/prompt-frontmatter.mjs` | now imports the shared loader |
| `tests/test_handover_format_gate.sh` | the gate's behavioural test |
| `scripts/lint/handover-format.mjs` | new scanner: frontmatter fields and the section set |
| `scripts/check_handover_format.sh` | new gate: cutover scan, `--staged`, and single-file modes |
| [`workflow/coding-agent/skills/handover-maintenance.md`](../../workflow/coding-agent/skills/handover-maintenance.md) | Track B Step 5 reduces to the gate command |
| `workflow/coding-agent/audits/handover-audit.skill.md` | deleted; superseded by `handover-maintenance.md` |
| `workflow/coding-agent/audits/audit.skill.md` | deleted; superseded by `handover-maintenance.md` |
| `scripts/lint.sh` | the new gate joins GATES |
| `src/capability/git-hooks/pre-commit.sh` | runs the gate's `--staged` mode |
| `devlog/roadmap.md` | the write-back for rows 110, 165, 251 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Enforce by cutover date, not by a changed-file list | a handover is immutable, so "incoming" is "created after the rule"; no list to maintain, and a corrected old record stays exempt | `handover_policy.md` and the gate |
| Enforce a named file regardless of date | the same code path serves the manual audit, so `handover-maintenance.md` drops its enumeration | this handover |
| Stack the correction markers newest-first on a closed roadmap row | mirrors `handover_policy.md`'s correction-tag order and ADR dated entries | `roadmap_policy.md` |
| Delete the two audit files rather than keep them | `handover-maintenance.md` carries their content and names them for removal | roadmap row 165 |
| Leave `20261002-25`'s `## Deferred` section as history | the cutover grandfathers existing records, and the gate never rewrites one | this handover |
| List `Open` in the format block's status enum | `## Lifecycle` names three states while the old format block listed two; the enum now matches the lifecycle | `handover_policy.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `20261002-25` is non-conforming on two counts: a `## Deferred` section and no `## Completed`. The cutover grandfathers both, and the manual mode reports them on demand. | gap | grandfathered by the cutover; recorded here |

## Completed

| File | Change |
|---|---|
| `docs/operations/handover_policy.md` | `## Format` moved to YAML frontmatter; the status enum lists three states |
| `docs/operations/roadmap_policy.md` | the marker-order rule added |
| `scripts/lint/yaml-loader.mjs` | new: the shared YAML loader |
| `scripts/lint/prompt-frontmatter.mjs` | now imports the shared loader |
| `scripts/lint/handover-format.mjs` | new: the handover format scanner |
| `scripts/check_handover_format.sh` | new: the gate, cutover scan, `--staged`, and `--force` single-file modes |
| `scripts/lint.sh` | the gate joined GATES and the header comment |
| `src/capability/git-hooks/pre-commit.sh` | runs the gate `--staged` when a handover is staged |
| `workflow/coding-agent/skills/handover-maintenance.md` | Track B Step 5 delegates to the gate; the provenance note names the removal |
| `workflow/coding-agent/audits/handover-audit.skill.md` | deleted |
| `workflow/coding-agent/audits/audit.skill.md` | deleted |
| `workflow/coding-agent/audits/surface-area-report.md` | the two rows marked removed; the stale naming bullet dropped |
| `tests/test_handover_format_gate.sh` | new: 9 behavioural cases |
| `devlog/roadmap.md` | rows 110, 165 and 251 closed with landing notes |
