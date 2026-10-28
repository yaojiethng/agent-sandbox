---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Housekeeping
status: Closed
---

# Handover - the read-through brief, its record and its register retire

## Objective

Remove the read-through's abandoned artifacts from the tree, so nothing live points at a file that no longer exists and the rules they carried survive in the conventions that own them.

## Scope

The `-run` family's last member and the September pass's two records: `.agents/drafts/read-through-run.md`, `devlog/discussions/archive/20260927-report-settled-test_suite_readthrough.md` and its `.jsonl` register, the rename of `fanout-run` to `fanout`, and every live carrier of those names. The mutation corpus is explicitly out of scope: it is not touched, and its drift is recorded on the row that owns it.

Out of scope, one sentence each with the reason: `fanout`'s own rewrite stays with the fan-out adoption row, because only its dangling pointer is a carrier of this deletion; the eight archived citations to the deleted pair stay, on the `20260927-01` precedent that a compaction record carries the loss.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The brief is gone | `ls .agents/drafts/read-through-run.md` prints nothing | Agent [x] |
| No live file links to it | `grep -rn '](.*read-through-run' --include='*.md' .` prints nothing; the name survives only in backticks, as a retirement statement | Agent [x] |
| The fan-out brief stands alone | `head -10 .agents/drafts/fanout.md` names `close-read` and no deleted file | Agent [x] |
| The record and register are gone | `ls devlog/discussions/archive/20260927-report-settled*` prints nothing | Agent [x] |
| Every live citation resolves | `bash scripts/check_markdown.sh` clean, and the three repointed carriers read without a link to a missing file | Agent [x] |
| The ADR names no live member and links none | `grep -c '](.*fanout\|](.*read-through-run' docs/adr/coding_agent_loop_workflow.md` prints `0`, and its `-run` bullet records the retirement | Agent [x] |
| The rules have a home | `grep -c '^## Pin the contract, not the accident$\|^## A rename is not a rewrite$' .agents/skills/testing/patterns/assertions.md` prints `2` | Agent [x] |
| The corpus is untouched | `git diff --stat -- tests/mutations scripts/mutations_run.sh` prints nothing | Agent [x] |
| The drift measurement is recorded | the corpus's row names `7 of 244`, the date, and the two classes of drifted row | Agent [x] |
| Every decision recorded here is realized in the files | the decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The record and the register are deleted rather than archived | every row was dispositioned and its fixes landed, so the pair held evidence for closed rows only; the operator directed the deletion | `devlog/roadmap.md`, the closed retirement row |
| The three live citations are repointed rather than left dangling | `changelog.md`, `roadmap.md` and the close-read register reference are read today, and a closed record's link to a missing file is a defect in the record | those three files |
| `fanout-run` is renamed `fanout` and the ADR stops naming it | it is a draft under `.agents/drafts/` owned by M3.2.3, not a member of the loop taxonomy, so the ADR's only business with it was the family it belonged to | `.agents/drafts/fanout.md`, `docs/adr/coding_agent_loop_workflow.md` |
| The ADR bullet is rewritten, not deleted | the churn survey's landing and the retirement of `review-loop-run` and `review-pass-run` are facts recorded there and nowhere else | `docs/adr/coding_agent_loop_workflow.md` |
| The open feedback entry is repointed, not closed | its unresolved half is the absent gate for the class, which deleting the file that scoped it does not supply | `devlog/AGENT_FEEDBACK.md` |
| The intent principle, `communication-principle-state-intent-delegate-method`, gains two pointers and no rule of its own | it had one entry point, the prompt-authoring router, so the `/iter` session that writes a roadmap row never met it; both files cite the skill and restate nothing | `src/reasoning/providers/pi/config/agent/AGENTS.md`, `workflow/coding-agent/prompts/iter.md` |
| The three `fanout` rows consolidate into one row under M3.2.3, on operator direction | the doc pass, the adoption as a dispatch shape and the dispatch-and-merge redesign are one outcome for one draft, and the row states the intent while leaving the method to the work | `devlog/roadmap.md` `#### M3.2.3` |
| The corpus is not touched, and its drift is classified on its own row | three of seven drifted rows are re-pointable and four were invalidated by later rewrites, so a refresh is not mechanical and belongs to the row that owns the decision | `devlog/roadmap.md`, the corpus's row |
| The three rules land in `assertions.md` alone, with the wait-for-contract rule folded into pin-the-contract | one judgement with one owner: you cannot pin what has not been decided, so the wait is the same rule's second half | `.agents/skills/testing/patterns/assertions.md` |
| Net instruction length falls | 166 lines of procedure leave the tree and about fifteen arrive, which is the "add by replacing" rule satisfied by the deletion itself | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The brief's method survives as three rules in `assertions.md` and five in `mutation-evidence.md`; everything else in it was mechanics for a pass that no longer runs | process | the deletion loses no rule that had no home | landed here |
| The mutation corpus has no generator, and its drift has held at 7 of 244 across two measurements five weeks apart | data | the corpus is usable and its decay is slow, so the generator decision is not urgent | the corpus's row |
| Four of the seven drifted rows mutate a claim that a later rewrite deliberately changed, so re-pointing them would assert the opposite of a decision | data | a mechanical refresh would produce four rows that prove nothing | the corpus's row |
| 23 archived handovers cite the register by its pre-rename filename, which `20260927-01` already stranded | record | the archived chain is already tolerant of a resolved-name citation | left as history, on that precedent |
| The close-read register reference's claim about the old register's 319 rows was the last live dependence on a file this iteration deletes | docs | the rule stands without the archaeology, so the reference states the failure and not the file's measurements | `close-read/references/register.md` |
| `fanout` is the `-run` family's only surviving member, and it still carries no frontmatter block | defect | the model cannot discover it; the row that owns the defect now names one subject | `devlog/roadmap.md` |
| The `-run` family ended with one member reaching adoption and two retired into the `code-review` shell | process | the family's lifespan is one draft that earned a home and three that did not | `docs/adr/coding_agent_loop_workflow.md` |

## Completed

| File | Change |
|---|---|
| `.agents/drafts/read-through-run.md` | deleted |
| [`.agents/drafts/fanout.md`](../../.agents/drafts/fanout.md) | renamed from `fanout-run.md`; title, status and purpose repointed at `close-read` |
| `devlog/discussions/archive/20260927-report-settled-test_suite_readthrough.md` | deleted |
| `devlog/discussions/archive/20260927-report-settled-test_suite_readthrough.jsonl` | deleted |
| [`devlog/changelog.md`](../../devlog/changelog.md) | the closed entry's link replaced with a pointer to this handover |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the retirement row closed; the frontmatter row narrowed to `fanout`; the read-through row's record link replaced; the corpus row gains the dated drift measurement and its two classes; three `fanout` rows fold into one under M3.2.3 |
| [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) | the open entry's scope line and cross-reference repointed at `mutation-evidence.md` pattern 3 |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | the `-run` bullet records the family's retirement and names no member |
| [`workflow/coding-agent/skills/close-read/references/register.md`](../../workflow/coding-agent/skills/close-read/references/register.md) | the class rule states the failure without the deleted register's counts |
| [`.agents/skills/testing/patterns/assertions.md`](../../.agents/skills/testing/patterns/assertions.md) | two sections: pin the contract not the accident, and a rename is not a rewrite |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | a `## Communication Standards` bullet for the intent principle |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | the write-back bullet states that a row is written intent-first |
