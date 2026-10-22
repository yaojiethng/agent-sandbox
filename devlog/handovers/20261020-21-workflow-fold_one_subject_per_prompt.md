---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - one subject per prompt folds into scope ownership

## Objective

Resolve class-2 candidate 1, the rule that a prompt owns one subject, by filing it under `principle-own-the-scope-you-declare` rather than inventing a sixth skill.

## Scope

The candidate row, the home skill in both copies, the ledger and grouping the edit moves, and this record.

Out of scope: the other three candidates, and the map question about whether a pointer row belongs in the pointer group.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The home states where a document's scope ends | read `## The pattern` | Agent [x] |
| The rule carries its escape for a dispatcher | read the second sentence of the amendment | Agent [x] |
| The term `class of work` is gone from the rule and the pointer | `grep -n "class of work"` over both files | Agent [x] |
| The description routes the widened rule | read the skill's `description` | Agent [x] |
| Both skill copies are byte-identical | `diff -q` over the two files | Agent [x] |
| The ledger, the grouping and the gates are clean | `--check`, `--groups`, `scripts/lint.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule folds into `principle-own-the-scope-you-declare` | the scope's boundary is what that skill owns, and the proposed alternative, `principle-sequence-verifiable-units`, holds a different rule and lives only in the installed tree | the home skill, and the pointer line |
| The boundary is the artifact and its next step, not the class of work | `class of work` names an abstraction over situations, so no writing-desk check reads it; the artifact and the step are on the page | the home skill, the amendment sentence |
| The boundary is not the number of decisions | `/iter` takes several decisions and hands on one commit, so a decision-count boundary would condemn the loop's own prompt | this record |
| The dispatcher escape stays | the loop prompts each hold several sub-cases and each declares its dispatch, so a rule without the escape forbids them | the home skill, second sentence |
| The description gains the boundary | the description routes the skill, so a reader holding a two-artifact prompt must match it from the list entry | the home skill's `description` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The proposed fold target `principle-sequence-verifiable-units` does not exist in the repository | fact | filing there would lose the judgement at an image rebuild, the same defect `principle-check-placement` already carries | this record |
| The operator challenged `class of work` as unreadable at the writing desk | operator correction | the rule now names the artifact and the next step, and both terms appear in the source document already | the home skill |
| Classification must precede regrouping | process | `--regroup` adds a line only after it is classed a judgement, so the reverse order leaves an ungrouped judgement that `--groups` rejects | this record |
| A pointer row sits ungrouped by default while the seven copy rows sit in `j-copy-points-to-its-source` | map question | both cannot be right, and the operator owns the ruling, so this landing followed the majority and left the question open | the filing |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-own-the-scope-you-declare/SKILL.md` | the boundary sentence, and a description that routes it |
| `~/.pi/agent/skills/principle-own-the-scope-you-declare/SKILL.md` | the installed copy, byte-identical |
| `docs/development/prompt-authoring-conventions.md` | the row becomes a pointer with the boundary stated in the prompt's terms |
| `scripts/lint/norm-ownership.tsv` | the edited line classified as a judgement |
| `scripts/lint/norm-judgements.tsv` | the orphaned hash dropped, the new one added local |
| `devlog/handovers/20261020-21-workflow-fold_one_subject_per_prompt.md` | this record |

> [CORRECTION -- 2026-10-20] The amendment first read "A document hands one artifact to one next step". The operator challenged the noun. In this repository `document` means documentation, since `documentation_policy.md` states that skill files and prompt templates are not documentation, so the sentence pointed at the wrong class. `workflow document` and `prompt or skill` were both rejected as the replacement, the first because it includes reference-only principle skills, which hand nothing on. The sentence now takes the declared scope as its subject: the scope names one artifact and one next step, and a scope naming two is two scopes. The scope is a term this skill already defines, so no class noun is needed and a principle skill needs no exemption. The pointer line in `prompt-authoring-conventions.md` is unchanged.
