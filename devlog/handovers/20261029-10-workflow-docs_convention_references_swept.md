---
date: 2026-10-29
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the retired `docs` convention name leaves every live carrier

## Objective

Sweep the retired `docs` convention name out of the instruction surface, so every live carrier names `project-documentation`.

## Scope

Continues the rename recorded by handover `20261027-03` and commit `c1b212ed`, which renamed the convention but left the old name in the prompts and skills that cite it. The iteration took the directive from the operator while `/iter` was scoping the M3.3.3 row **Fork-and-strip convention**; the sweep runs first, on operator direction.

Out of scope, one sentence each with the reason: the historical handovers and discussions keep the old name because a closed record states what was true when it was written; the commit type `docs`, the branch prefix and the `docs/` folder path keep their names because they are not the convention; and the frozen eval fixture's provenance note keeps the old path because it records how that fixture was captured.

Roadmap write-back: no task row, because the iteration corrects a closed rename. The two record-check findings land on existing M3.3.3 rows, recorded in Completed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The two prompts name `project-documentation` and no longer name `docs` | `rg -n '^- .task-list.' workflow/coding-agent/prompts/{iter,bootstrap}.md`; ``rg -n '`docs`'`` on both prints nothing | Agent [x] |
| `write-locations` names `project-documentation` in both places | `rg -n 'project-documentation' src/reasoning/agent/skills/write-locations/SKILL.md` prints 2; ``rg -n '`docs`'`` prints nothing | Agent [x] |
| The vendored review's provenance block names the convention correctly | `rg -n 'docs convention'` on the file prints nothing; `project-documentation` prints 1 | Agent [x] |
| The live ADR's convention list names `project-documentation` | read the `Edge cases / drivers` line; no `docs` in the list | Agent [x] |
| The two lint comments name the convention correctly | `rg -n 'docs skill' .markdownlint-cli2.mjs scripts/lint/doc-ascii.mjs` prints nothing; both name `project-documentation` | Agent [x] |
| No live instruction-surface file names the convention `docs` | ``rg -n '`docs`\|docs convention\|docs skill' workflow .agents/skills src/reasoning \| rg -v 'git-discipline/references/(commit-types\|branching)\.md\|work-log/SKILL\.md\|eval/scripts/measure_commit\.sh'`` prints nothing | Agent [x] |
| The excluded uses still carry `docs` | `git diff --name-only -- 'devlog/handovers/*.md' 'devlog/discussions/*.md'` prints nothing; the work-log type table and `commit-types.md` still show `docs` | Agent [x] |
| Every decision this iteration recorded is realized in the files | read the Decisions table against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The sweep replaces the fork-and-strip row for this iteration | The operator directed the sweep while the iteration was being scoped, and the rename correction is smaller and makes the instruction surface name the same convention throughout | this record |
| The historical records keep `docs` | A closed record is a log of what was true then, not a pointer that must resolve now; the earlier rename made the same ruling | this record |
| `docs` survives as a commit type, a branch prefix and a folder path | The rename removed the collision between the convention and those three uses; only the convention name changes | this record |
| The live ADR is corrected in place | An ADR holds the live decision and its history, and a name correction does not change the decision | this record |
| The frozen eval fixture's source note is left alone | It maps the fixture to the path it was captured from, so rewriting it would misstate the capture | this record |
| The vendored review's provenance block is corrected, not the review | The block is this repository's note about the upstream, and the name it cites is ours to keep current | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The grill-me input contract had two roadmap rows: M3.3.3 `The grill-me input contract is stated` and M3.6.6 `State the grill-me skill input contract` | roadmap | the active milestone's row could close while the more specific requirement in the other row was never read | merged into the M3.3.3 row; the M3.6.6 copy deleted |
| `State what absorbs a discussion record` sat under M3.6.6 and stated that M3.3.3 owned it | roadmap | a row filed under a milestone that does not own it is not read by the owner | moved under M3.3.3's authoring-surface list |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | the convention block names `project-documentation` |
| [`workflow/coding-agent/prompts/bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | the convention block names `project-documentation` |
| [`src/reasoning/agent/skills/write-locations/SKILL.md`](../../src/reasoning/agent/skills/write-locations/SKILL.md) | both references retarget to `project-documentation` |
| [`workflow/coding-agent/skills/code-review/runbooks/thermo-nuclear-code-quality-review/SKILL.md`](../../workflow/coding-agent/skills/code-review/runbooks/thermo-nuclear-code-quality-review/SKILL.md) | the provenance block names `project-documentation` |
| [`docs/adr/coding_agent_project_bindings.md`](../../docs/adr/coding_agent_project_bindings.md) | the convention list names `project-documentation` |
| [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) | the disabled-rule comment names `project-documentation` |
| [`scripts/lint/doc-ascii.mjs`](../../scripts/lint/doc-ascii.mjs) | the box-drawing comment names `project-documentation` |
| [`devlog/roadmap.md`](../roadmap.md) | merged the grill-me duplicate into the M3.3.3 row and moved the discussion-record row under M3.3.3 |
| [`devlog/handovers/20261029-10-workflow-docs_convention_references_swept.md`](20261029-10-workflow-docs_convention_references_swept.md) | this record |
