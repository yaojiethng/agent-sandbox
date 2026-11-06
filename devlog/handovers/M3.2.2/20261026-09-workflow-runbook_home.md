---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - One home for the review runbooks

## Objective

Put every runbook of a review family in one place, so that the shape of the tree says what a runbook is. `code-review` had runbooks in three places: two nested beside its own `SKILL.md`, one at the agent's skill root because it was imported there years ago, and a fourth payload about to land at that root for the same reason.

The home is `workflow/coding-agent/skills/code-review/runbooks/`, one directory per runbook, each keeping its `patterns/` beside it.

## Scope

In scope:

1. the four code runbooks under `code-review/runbooks/`: `code-review-bash`, `code-review-container`, `kelsey-code-reviewer`, `thermo-nuclear-code-quality-review`.
2. `code-review`'s shell stating the home in one sentence.
3. the two imported files reflowed to the repository's docs convention, which is what their exemption from it was waiting on, and the exemption itself removed.
4. every live citation of the old nesting repointed.
5. the roadmap row that holds this work, which did not exist before this iteration.

Out of scope: the agent's own role files, which stay at the agent skill root because they belong to the agent and not to a review. `prose-review`'s runbooks, which do not exist yet.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every code runbook is under `runbooks/` | `ls workflow/coding-agent/skills/code-review/runbooks/` names four directories and nothing else | Agent [x] -- `code-review-bash`, `code-review-container`, `kelsey-code-reviewer`, `thermo-nuclear-code-quality-review` |
| Nothing remains at the old nesting | `ls workflow/coding-agent/skills/code-review/` names `SKILL.md` and `runbooks/` only | Agent [x] -- and the agent skill root lost the two imports |
| No live document cites the old nesting | a grep for each old path across live files prints nothing but the records | Agent [x] -- sixteen live files repointed; the closed records and the eval fixture keep what they said |
| The two imported files conform to the docs convention | the gate is clean with their exemption removed | Agent [x] -- five paragraphs joined, exemption entry deleted |
| The shell states the home | one sentence in `code-review/SKILL.md`, naming `runbooks/` and the `patterns/` directory beside a runbook | Agent [x] -- stated, with the patterns directory named in the same sentence |
| The roadmap holds the work | the row exists and is ticked in the iteration that landed it | Agent [x] -- filed and ticked under the M3.2.2 tree |
| The gate is clean and the suite passes | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] -- the gate is clean across 13; the suite passes 1321 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The home is `runbooks/`, not `prompts/` | a prompt is a document an operator invokes, and every file in `workflow/coding-agent/prompts/` is one. A runbook is read by a reviewer that was dispatched to it and is invoked by nobody, so the two are different kinds and get different directories | this handover |
| The imported files are reflowed rather than re-exempted | the exemption listed them as live files not yet reflowed, and its own rule is that grandfathering lasts until the file is next touched. A move is a touch, so re-exempting would have bought a second extension by way of a path change | `thermo-nuclear-code-quality-review/SKILL.md`, the source note |
| The agent's role files stay where they are | `model-recommendations.md` and the `dispatch` skill are the agent's own machinery, and a runbook is a review's. Moving them would say the review family owns the agent's model routing | this handover |
| The reflow is recorded in the file's own source note | the note claimed the file was verbatim apart from one removal, and a reader comparing it with upstream has to be told that five paragraphs now sit on one line each | `thermo-nuclear-code-quality-review/SKILL.md` |

## Decisions pending

| Code | Item | State | Ruling |
|---|---|---|---|
| N1 | None open | Closed | The two questions this work raised are `L1` and `L2` on the payload handover, and both wait on a code review rather than on this move |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| No roadmap row held the runbook home, so three placements had accumulated unrecorded | finding | the tree's shape was decided by whichever iteration happened to create a file, which is why an imported runbook sat at the agent root and a new one landed beside it | this iteration's roadmap row |
| The docs-convention exemption was scoped to a path rather than to a file | finding | a move re-triggers the rule and silently re-exempts the file, which is how an exemption outlives the reason for it. The five paragraphs are joined and the exemption is gone | `.markdownlint-cli2.mjs` |

## Completed

| File | Change |
|---|---|
| `code-review/runbooks/` | four runbook directories, `code-review-bash`, `code-review-container`, `kelsey-code-reviewer`, `thermo-nuclear-code-quality-review`, the last two moved from the agent skill root |
| `code-review/SKILL.md` | one sentence stating the home, and the payload row repointed |
| `runbooks/thermo-nuclear-code-quality-review/SKILL.md` | five paragraphs joined onto one physical line each, and the source note now states both departures from upstream |
| `.markdownlint-cli2.mjs` | the exemption entry removed, since the file conforms |
| fifteen live files | citations of the old nesting repointed: the surface-area report, the two pattern-set READMEs, two ADRs, `AGENTS.md`, `conventions.md`, the friction log, the roadmap, the dispatch draft, and the lib-contract script's header |
| `devlog/roadmap.md` | the row this work needed, ticked, naming the home and what moved |
