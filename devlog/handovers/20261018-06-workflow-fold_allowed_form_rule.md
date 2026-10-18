---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Fold the allowed-form rule into the reader principle

## Objective

Move the allowed-form rule out of `documentation_policy.md` and into the principle that judges it, leaving a pointer where the rule was.

## Scope

The fold was assessed and left unwritten pending release, and the operator released it. This applies the authority doctrine already in force: a judgement's only home is the principle skill that states it, and the census recorded the policy line as a judgement with no observer, which the doctrine forbids.

The fold is not a merge. `write-for-the-reader` covers a reader who lacks the session; this rule covers a reader who lacks the writer's intent, so a prohibition with no counterpart leaves the reader to invent one. The skill gained that case as a section of its own and a fourth test question in handover `20261018-02`, because a test and the section it tests are one unit. This unit moves the policy line and leaves the pointer where the rule was.

The correction pass that followed the fold is folded in rather than landed separately, because both commits wrote and then replaced the same three lines. What survives is the second version of each: the pointer states the instruction and the skill name, with no doctrine clause; the skill section is one reason clause, the action and the examples, with no claim about how the defect arose.

Applied ahead of the M3.3.2 slice that retires `documentation_policy.md` wholesale. One line moves early, on operator direction, and the slice's remaining scope is unchanged.

Ruled out of scope. No other prose rule is moved. The archive handover `20260930-05` that discusses the rule is history and is not rewritten.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy states the instruction and points at the rule's home | `documentation_policy.md` line 64 | Agent [x] |
| The policy states no judgement of its own in the line | the ledger classifies the line `model`, observer `none` | Agent [x] |
| The pointer does not re-argue the doctrine the document states once | the line names the skill and stops | Agent [x] |
| The worked examples have one home, in the skill | the two examples appear in the skill and in no policy line | Agent [x] |
| The skill states the case as one reason clause, the action and the examples | landed in handover `20261018-02` | Agent [x] |
| The skill states no claim about the project's history | the section names no defect and no origin | Agent [x] |
| The closing test covers the case | `**The test.**` asks four questions, landed in handover `20261018-02` | Agent [x] |
| The description carries no phrase the reader must decode | `SKILL.md` frontmatter | Agent [x] |
| The installed copy matches the source | `diff -q` on both paths | Agent [x] |
| Every gate passes | `scripts/lint.sh`, 10 gates, ledger 168 rows | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The policy keeps the instruction and the skill carries the examples | The instruction is what a writer reads while drafting in the policy's own register; the examples settle a borderline case, and a judgement's examples belong with the judgement. | the policy line; the skill section |
| The pointer names the skill and stops | The name is the directory, so it resolves. The path and the doctrine clause both restate what the document says at its own line 174, and a pointer that argues its own authority is a paragraph where a line will do. | the policy line |
| The skill keeps the reason and drops the origin | "The reader holds only the form the sentence gives" is why the rule is a rule and a writer can use it. A claim about how the defect arose is history the writer cannot act on and nothing verifies. | the skill section, landed in handover `20261018-02` |
| The case is a section of its own rather than a table row | The table rows are ways a sentence refers to something the reader lacks. This is a way a sentence omits something the reader needs, which fails for the opposite reason and would read as a misfit in a table about references. | the skill `## Where the sentence names only the prohibition`, landed in handover `20261018-02` |
| Classify the pointer `model` rather than `judgement` | It carries no judgement of its own, which is the point of a pointer. The existing pointer to the same skill at line 174 is classified the same way, so the census has one shape for a pointer. | `scripts/lint/norm-ownership.tsv` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None | -- | -- |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The single bullet held two rules with different homes: one a judgement the principle owns, the other an instruction a writer acts on. Splitting by kind rather than by topic is what made the fold one line and one section | judgement | the test for the remaining lines in the M3.3.2 slice: ask which kind a line is before deciding whether it moves |
| The correction pass reproduced the defect it was correcting. The pointer rebutted a claim nobody made about its authority, and the principle narrated an origin nobody asked about. A correction concentrates this error because it is written for the reviewer of the correction | agent experience | stated as the rule in the scope section: one judgement, one reason, the action; a causation claim is its own judgement and lives in the record |
| The house style already encoded that rule in the sibling sections of the same file, and it was not used as the template | process | apply the sibling section as the template when adding one, rather than writing free prose and checking it after |
| Two delivery subjects exceeded the policy's 50-character limit, at 56 and 55, and both were amended after the commit landed | agent experience | recurrence recorded on `devlog/AGENT_FEEDBACK.md` `[A] 2026-10-05`, with the subject measured separately from the body and the `legacy:` field set to the prior fix |
| The census moved with the fold, 83 judgement to 82 and 41 model to 42, so the doctrine's measure of policy-held judgement reflects this line | process | recorded so the next reader knows the movement is this fold and not a regression |

## Completed

| File | Change |
|---|---|
| `docs/policies/documentation_policy.md` | the allowed-form bullet states the instruction and names the skill, with the worked examples removed |
| `devlog/AGENT_FEEDBACK.md` | a recurrence on the `[A] 2026-10-05` commit-budget entry, with `legacy:` set to the prior mitigation |
| `scripts/lint/norm-ownership.tsv` | regenerated; the folded line classified `model` with observer `none` |
| `devlog/handovers/20261018-06-workflow-fold_allowed_form_rule.md` | this record |
