---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - file the handoff principle

## Objective

File `communication-principle-hand-off-by-naming-the-boundary` as the judgement's only home, and leave the conventions pointing at it.

## Scope

The roadmap row **File `communication-principle-hand-off-by-naming-the-boundary`**. One landing, with its own propagation.

Out of scope: the other four landings, and the two folds that the next grill session decides.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The repository copy and the installed copy are byte-identical | `diff -q` over the two `SKILL.md` files | Agent [x] |
| The skill carries the approved four parts | read it: the pattern, why, and the test | Agent [x] |
| The two source lines that stated it now point at it | `grep -c hand-off-by-naming-the-boundary docs/development/prompt-authoring-conventions.md` returns 2 | Agent [x] |
| The detail moved rather than being restated | the four moves appear in the skill and nowhere in the conventions | Agent [x] |
| The ledger and the grouping map agree with the sources | `check_norm_ownership.sh --check` and `--groups` are clean | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pointer follows the house form, `the X skill at $AGENT_HOME/agent/skills/X/SKILL.md` | six existing pointers in the two documents use that form, so the seventh matches them | the edited lines |
| The six lines stating the four moves were deleted, not rewritten as one pointer | the moves are a sequence, and a sequence has one home; keeping them beside the pointer would leave the copy that drifts | the conventions diff |
| The four prompts that apply the shape stay named in the conventions | they are carriers, not the rule, and a reader checking the rule benefits from knowing where it is applied | the edited section |
| Regrouping became a script mode rather than a repeated procedure | five landings repeat the same mechanical step, so it earns a lever; the negative test drops a stale row and restores the map byte-identical | `check_norm_ownership.sh --regroup` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `principle-sequence-verifiable-units` and `principle-encode-lessons-in-structure` do exist, in `$AGENT_HOME/agent/skills/`, and not in the repository tree | correction to a finding in `20261020-13` | the defect is narrower than recorded: those skills are installed and not shipped, so a rebuild of the image would lose them | this record, and a correction tag on `20261020-13` |
| The handoff section closed by linking to `#a-workflow-document-owns-one-step-and-owns-it-whole`, which the next landing replaces | carrier of a removed anchor | the closing sentence went with the section it belonged to, so no dead anchor remains | this record |
| `--generate` marks a new pointer line UNCLASSIFIED | mechanism | a landing has to classify the pointer, which keeps a reader in the loop about what the line now says | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` | new: the four moves, why, and the test |
| `~/.pi/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the step-5 line and the handoff section point at the skill; the six lines stating the moves are gone |
| `scripts/lint/norm-ownership.tsv` | regenerated: 157 rows, two pointers classified as judgements |
| `scripts/lint/norm-judgements.tsv` | regrouped: six rows dropped, two added with a local note |
| `scripts/check_norm_ownership.sh` | new `--regroup` mode, so a landing does not hand-edit the map |
| `devlog/handovers/20261020-14-workflow-file_hand_off_principle.md` | this record |
