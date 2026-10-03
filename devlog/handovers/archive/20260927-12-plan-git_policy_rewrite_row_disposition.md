# 20260927-12 - Plan: T1 git-policy-rewrite row disposition

**Type:** Plan
**Milestone:** M3
**Status:** Closed

## Scope

Land the residue of the T1 git-policy-rewrite row: the explicit body budget the operator ruled (subject aims for 50 characters; the body wraps at about 72 and carries at most 280), the enforcement moment (the delivery commit's message is presented alongside Gate 3 at pre-close), and the ghostty `writing-commit-messages` sample disposition. The row was already `[x]` with a landing note from the morning chore; this iteration extends its note rather than closes it.

## Files

| File | Change | Status |
|---|---|---|
| `docs/operations/git_policy.md` | Commit Message Format gains the budget paragraph: subject aim 50, body max 280 characters, wrap at 72, blank-line separation | done |
| `docs/operations/iteration_policy.md` | Step 7 gains the commit-message presentation item; the Gate 3 table row and section require the message visible with the body within budget | done |
| `devlog/roadmap.md` | the row's landing note gains the budget, the Gate 3 presentation, and the ghostty disposition | done |
| `devlog/handovers/archive/20260927-12-plan-git_policy_rewrite_row_disposition.md` | this record, rides the commit | done |

## Assessment (recorded)

| Question | Finding | Type |
|---|---|---|
| Is the row's work already landed? | Yes: `e775af2` (docs: bind the commit body to why) wrote the Body/footer paragraph the row asks for, verbatim on all three asks | staleness |
| Does any ossrules sample achieve the outcome? | One partial: ghostty `writing-commit-messages` (why-not-what, less-is-more budget, omit-empty references); it does not cover handover redundancy, and its rules are softer than the policy's current text | coverage |
| Row state mismatch | The operator's new-iteration quote showed the row `[ ]`; the tree already carried it `[x]` with the morning chore's landing note. The iteration extends the note. | record state |

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | The Commit Message Format section carries the budget: subject aim 50, body max 280 characters, wrap at 72, blank-line separation | read the section | Agent [x] accepted |
| AC2 | Step 7 presents the delivery commit's message; Gate 3 requires it visible with the body within budget | read the gate text | Agent [x] accepted |
| AC3 | The roadmap row's landing note names the budget, the Gate 3 presentation, and the ghostty disposition | read the row | Agent [x] accepted |
| AC4 | Lint clean, suite green | `lint.sh`, `run_tests.sh` | Agent [x] accepted: lint clean across 3 gates, 1001 passed, 0 failed |

## Findings

| Finding | Type | Impact/resolution |
|---|---|---|
| None. | | |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Body budget: subject aims for 50 characters; the body wraps at about 72 and carries at most 280 | the operator's ruling, shaped on the classic git commit template | `git_policy.md`, Commit Message Format |
| The enforcement moment is the Gate 3 presentation, not a commit-msg hook | the operator chose the human-visible gate; a hook is gate surface that waits for a recurrence | `iteration_policy.md`, Gate 3 |
| The ghostty sample is reviewed and not adopted | its budget ("a handful of paragraphs") and references rule are softer than the landed text | `roadmap.md`, the row's landing note |

## What's Next

Gate 1: operator releases the disposition.
