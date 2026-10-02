---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Docs
status: Closed
---

# Handover - The maintenance skill completed, and the record corrections it found

## Objective

Complete the roadmap-maintenance design so the runbook carries the checks the design settled, the superseded files it judged removable are removed, and the record corrections the maintenance pass found are landed in the three records.

## Scope

The runbook's extension, the two superseded files, the `/wrapup` close-check gap, the three record files, and the document-side corrections the link gate reported. The design record is resolved into this handover and its file is deleted. Out of scope: re-pathing the dead links inside the exempted record trees, and the changelog's append-only format, both of which are roadmap rows.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The runbook carries the settled checks: 1.4, 3.11 to 3.13, 3.15 to 3.18, and Step 5's four correction rules | `grep -c "3.11\|3.18\|1.4" workflow/coding-agent/skills/roadmap-maintenance.md` | pass |
| 2 | The superseded files are gone and no live surface points at them | `git status` shows both deletions; `grep -rn "roadmap-audit.skill.md\|roadmap-management.skill.md"` returns only the records of their removal | pass |
| 3 | The close self-check tests the write-back pairing | `/wrapup` B11 carries check (9) | pass |
| 4 | No roadmap row states a fact the tree falsifies, and the summary table agrees with the sections | maintenance pass over all three records, four review rounds | pass |
| 5 | Suite and lint green | `bash scripts/run_tests.sh`: 1028 of 1028; lint clean across 5 gates | pass |

## Hot files

| File | Change |
|---|---|
| `workflow/coding-agent/skills/roadmap-maintenance.md` | subject widened to the three records; access-triggered schedule with an operator carve-out; checks 1.4, 3.11 to 3.18; Step 5's permission, evidence, minimality and re-read rules |
| `workflow/coding-agent/audits/roadmap-audit.skill.md` | removed; its checks A to D are Steps 1 to 4 |
| `src/reasoning/agent/drafts/roadmap-management.skill.md` | removed; its content is duplicated in the prompts and the policy |
| `workflow/coding-agent/prompts/wrapup.md` | B11 check (9): the range left a roadmap write-back |
| `docs/operations/roadmap_policy.md` | the summary-table link rule, and a row's status following its section |
| `devlog/roadmap.md`, `devlog/roadmap_future.md`, `devlog/changelog.md` | the corrections the maintenance pass found |
| `workflow/coding-agent/prompts/`, `drafts/`, `docs/`, `AGENTS.md` | dead links the gate reported |

## Decisions

The design record's decisions, settled by the operator inside its review, now recorded here.

1. **`roadmap-audit.skill.md` is subsumed; `roadmap-management.skill.md` is deleted, not promoted.** The audit's checks A to D map one-to-one onto Steps 1 to 4, and Step 5 adds the correction pass it deliberately lacked. The management file answers a different question -- how to move the roadmap between milestone states -- and the two milestone prompts plus the policy own every transition; its marker semantics also conflicted with the policy's, since it made `- [x]` mean "ready for verification" where the roadmap treats it as complete.
2. **The runbook owns the coherence checks; the policy owns the invariants.** The checks carry their full rule text. The compaction cascade and the top-level close stay in the policy, because they are transitions the prompts invoke.
3. **The run schedule follows access.** `roadmap.md` on every iteration; `roadmap_future.md` when a promotion reads it; `changelog.md` when a close appends to it; plus an operator-triggered read of the latter two at any time. A promotion does not read the changelog -- it moves a milestone between the two roadmap files -- so the changelog's checks run at the close and not at the promotion.
4. **A staged milestone is cleaned in place before the copy.** The end state is the same either way; in place leaves a sound staging file if the promotion is interrupted, and the copy lands a file that already passed the check.
5. **The maintenance run judges no task in `roadmap_future.md`.** Its size is a staging area's normal contents, and `milestone-start` grades the pool as it lands in `roadmap.md`. The run reports registration and link defects and holds the rest.
6. **The changelog is the third record, and the closed-entry checks read only the section a close has just written.** An entry is a historical claim; a path it names that no longer exists is true history, and correcting it rewrites the past into the present tense. Every entry closed before this design is read-only, and a finding against one is reported for the operator.
7. **A correction block closes the section it corrects, at level 3.** A milestone entry is then the only level-2 heading in its section, so a summary link can only resolve to a milestone.
8. **Supersession is a statement inside the entry.** The `[SUPERSEDED/REMOVED in M2.1]` suffix on the M1.4 heading broke that heading's own summary link; the removal is now a `### Superseded` block in the entry.

### The reversal this unit records

The design proposed a check that a landed row names the handover that landed it. It does not exist: `iteration_policy.md` `### Unconditional write-back` and `handover-maintenance.md` Step 6 own the pairing and both run commit-to-row, so the proposed check inverted an existing rule and then reported its absence as a gap. The rule was confirmed and its enforcement point identified -- `/wrapup` B11 tested the commit shape and never asked whether the commit left a row -- and that gap is now check (9).

## Decisions pending

- `recordTrees`, the three exempted closed-record trees, have no owner and no end condition, unlike `legacyFiles`. The roadmap row names the debt and the choice; nothing enforces a migration.
- The exempted trees hold 1,195 dead links. Re-path them or record an accepted baseline.

## Findings

- **The write-back rule did not fire on this session's own work.** Twelve handovers closed in the 2026-10-01 and 2026-10-02 runs with no paired row, and this unit landed with none either before the fold. The rule is stated; the close that should have caught it is now the place to look.
- **Two markdownlint facts cost this session real time and belong in the conventions doc**: config `globs` are added to command-line globs (`--no-globs` suppresses them), and `--config` merges with the config discovered by walking up from the working directory.

## Completed

The runbook's checks and schedule, both superseded files removed, the B11 gap closed, the three records corrected, and 29 dead links in the prompt and document surface fixed. The design record is deleted; its decisions are the Decisions table above.
