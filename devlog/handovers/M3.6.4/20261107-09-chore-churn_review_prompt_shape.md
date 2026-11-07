---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Housekeeping
status: Closed
---

# Handover - The churn-review prompt takes the shape the document lint reads

## Objective

Give the churn-review prompt a top-level heading and one paragraph per physical line, so the document lint accepts it and the two gates it blocked run green.

## Scope

Repairs an inherited defect, not an M3.6.4 row. Upstream commit `5e18e9aa` added the prompt with no heading and a paragraph wrapped across two lines, and the base branch that this branch rebases onto carries it. The prompt's text is the operator's, so the repair adds the heading and joins the wrap without rewording it.

Out of scope: the prompt's content, which is the operator's to change; and the two other mutation runners, which pin their own copy of the same path.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt's own lint is clean | `markdownlint-cli2 workflow/coding-agent/skills/code-review/runbooks/test-review/churn-review.md`; 0 issues | Agent [x] |
| The lint umbrella is clean | `bash scripts/lint.sh`; clean across 24 gates | Agent [x] |
| The wrap gate's own test is green again | `bash tests/test_doc_wrap_legacy_gate.sh`; 5 passed | Agent [x] |
| The prompt still says what it said | the diff is one heading, one joined paragraph and one stripped trailing space | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The paragraph is joined rather than reworded, with one heading above it | the text is the operator's; the lint reads shape, so shape is what changes | this record |
| The repair lands as its own commit on this branch rather than waiting for the base | the gate is red on the branch's own tree, and a red gate blocks every delivery behind it | this record |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| The defect arrived through a rebase onto `aeda944d`, so it is not visible in this branch's own history | recorded here; the base branch owns the commit that introduced it |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/runbooks/test-review/churn-review.md` | a top-level heading, the paragraph joined to one physical line, the trailing space removed |
| `devlog/handovers/M3.6.4/20261107-09-chore-churn_review_prompt_shape.md` | this record |
