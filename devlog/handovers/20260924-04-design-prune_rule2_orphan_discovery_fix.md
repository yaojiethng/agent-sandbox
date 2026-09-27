# Agent Handover

**Date:** 2026-09-24
**Milestone:** M3.1 - Backpressure
**Type:** Design
**Status:** Closed

## Objective

Record the prune Rule 2 orphan-discovery defect as a durable incident report, evaluate the fix candidates in a study, add the owning roadmap task under T9, and deliver a host-side cleanup tool, so the defect is tracked and remediable without immediate implementation.

## Scope

Roadmap track T9 (Session and Harness Identity): the session-identity label contract that prune's Rule 2 discovery key depends on. No harness behaviour changes; no prune code changes. The fix implementation is deferred to the T9 iteration.

## Carried forward

None.

## Acceptance criteria

- [x] **Incident record exists and is accurate** -- `devlog/discussions/investigation_prune_rule2_orphan_visibility.md` records evidence, code-verified facts, the open hypothesis, impact, remediation, and follow-ups. Observable: the file opens with a Status line naming Active; section map via `grep -n "^##"` matches the investigation format.
- [x] **Study evaluates the fix candidates and reaches a recommendation** -- `20260924-study-settled-prune_rule2_orphan_discovery_fix.md` follows the fixed study sections (Status, Direction + Parent story, Required reading, Summary, Findings, Open Questions, Constraints, Resolution) and recommends Fix A (empty-session-id orphan test) first, then Fix B (canonical label bake).
- [x] **Roadmap owns the follow-up** -- `devlog/roadmap.md` track T9 gains the named task "Prune Rule 2 orphan-discovery reliability" linking the incident, the study, and the cleanup tool; no fix work lives only in the handover.
- [x] **Host-side cleanup tool delivered** -- `scripts/manual/cleanup_orphan_volumes.sh` lists record-guarded orphans, asks for confirmation, removes only on confirmation, and reports the no-label review list separately. Observable: `bash -n` and `shellcheck` pass; `bash scripts/manual/cleanup_orphan_volumes.sh` prints the orphan count and prompts before removal.
- [x] **Docs gates green** -- new markdown files pass the repository ASCII and one-paragraph-per-line gates; roadmap edit is a targeted insertion.

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/investigation_prune_rule2_orphan_visibility.md`](../discussions/investigation_prune_rule2_orphan_visibility.md) | incident record (new) |
| [`devlog/discussions/20260924-study-settled-prune_rule2_orphan_discovery_fix.md`](../discussions/20260924-study-settled-prune_rule2_orphan_discovery_fix.md) | fix-candidate study (new) |
| [`scripts/manual/cleanup_orphan_volumes.sh`](../../scripts/manual/cleanup_orphan_volumes.sh) | record-guarded host-side removal tool (new) |
| [`devlog/roadmap.md`](../roadmap.md) | T9 task added |
| [`devlog/handovers/20260924-04-design-prune_rule2_orphan_discovery_fix.md`](20260924-04-design-prune_rule2_orphan_discovery_fix.md) | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Handover type Design, not Study | `study` is a deprecated handover type (handover_policy.md); the work is option evaluation (the design deliverable) | handover_policy.md |
| Commit type `docs` | the diff is decision records, a report, and a roadmap entry; the one manual script supports the incident record | git_policy.md |
| Fix work lands under T9 | the prune discovery key is the session-identity label contract; T9 owns identity | roadmap.md task "Prune Rule 2 orphan-discovery reliability" |
| No harness code changed in this iteration | the fix is deliberately deferred; remediation is operator-run in the meantime | the study's Resolution section |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Rule 2 silently keeps empty-session-id-labeled resources (code-verified `_sid_is_orphaned`); 21 volumes on the reported host are permanently invisible | bug | roadmap (T9 task) |
| baked label spelling can hide whole eras; 6+ orphans escaped the recorded prune run; host verification pending | bug | roadmap (T9 task) |
| handover type `study` is deprecated and folded into `design` | steering | current iteration |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/investigation_prune_rule2_orphan_visibility.md` | added: incident report (evidence, established facts, open hypothesis, impact, remediation, follow-up, links) |
| `scripts/manual/cleanup_orphan_volumes.sh` | added: operator-run script that lists record-guarded orphans, confirms, removes, and reports the no-label review list |
| `devlog/discussions/20260924-study-settled-prune_rule2_orphan_discovery_fix.md` | added: study of Rule 2 fix candidates (empty-session-id orphan test; canonical label bake), recommendation recorded |
| `devlog/roadmap.md` | added: T9 task "Prune Rule 2 orphan-discovery reliability" with incident, study, and tool links |

## Deferred items

None. The fix implementation has a roadmap home (T9 task "Prune Rule 2 orphan-discovery reliability") and is deliberately deferred there.

## What's Next

- Next iteration: the T9 design iteration picks up the Prune Rule 2 orphan-discovery reliability task (Fix A first, then Fix B).
- Roadmap maintenance: not run; no sub-milestone completed this iteration.
- Blocking design questions: none for the fix; the study's Open Questions (host verification of the label-value hypothesis; legacy settlement vs settle-forward) gate the fix's priority, not its shape.
- Watch-outs: run the incident record's verification commands on the host before implementing (they confirm which blind class dominates); use `scripts/manual/cleanup_orphan_volumes.sh` for immediate host cleanup; do not reintroduce `docker system prune` or name-pattern matching.
- Grep or file reads at iteration start: `scripts/prune.sh` (Rule 2 lines), the T9 task, and the study's Constraints section.

**Conclusions from this iteration:** Rule 2's label-value discovery is the blind spot, not the registry model: the registry-truth invariant survives; the discovery key does not cover empty labels and can drift by spelling. The fix is two small, label-only changes owned by T9; everything else (legacy settlement, build cache) stays operator-run or out of scope.
