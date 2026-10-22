---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - The norm's word is source of truth

## Objective

Give the object this corpus reasons about one name, `source of truth`, in the definition, the principle skill that states the law, and every live surface that names it.

## Scope

Operator direction: the vocabulary question was put as three options, the corpus's `home` short form with a declared equivalence, a full `home` pass, and a title-only change, and the operator chose the pass. The active-milestone scalar returns to M3.3.4 for it, which is the first use of the `2026-10-21` decision bullet that says the scalar follows the rows in work, and the roadmap gains the row this unit closes.

The word changes where it names where a norm or a durable artifact lives. A filesystem path, `$AGENT_HOME`, and the `--home` flag in the `active-tracker` convention are not that, so they keep the word, and the acceptance criterion lists them rather than absorbing them.

The unit also retires one surviving carrier of the ban that the previous unit removed: `doc-maintenance`'s diagnostic register reads `A rule in a skill or a prompt with no home in a policy: a consumer with no source`, which states the doctrine in words that no grep for its phrasing finds. It is inside the files this pass rewrites, so it is part of the task.

Ruled out of scope with a destination each. Records keep the names their time held, so closed handovers, discussions, ADRs and the changelog are not edited, and the closed roadmap rows that name the old skill keep the name they landed under. The drafts under `.agents/drafts/` keep the doctrine they state, because the finding filed against them covers it, but their pointers to the renamed skill do move.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The corpus names the object `source of truth` | `grep -rnw home docs/policies docs/reference docs/development .agents/skills src/reasoning/providers/pi/config/agent workflow` returns only three classes of line: a `/home/...` path, the provider's `config home`, and the `--home` flag `active-tracker` defines. Every line of the output falls in one class, and no line uses the word for a norm | Agent [x] |
| The definition is stated once | `grep -rn "The source of truth\." docs/` returns one line, `docs/reference/agent_workflow.md:113`, in `### Norm kinds` | Agent [x] |
| The skill carries the term | `ls src/reasoning/providers/pi/config/agent/skills` lists `principle-single-source-of-truth` and not `principle-one-home-per-rule`; `diff -r src/reasoning/providers/pi/config/agent/skills $AGENT_HOME/agent/skills` prints only `Only in` lines for the upstream skills the install carries | Agent [x] |
| The ledger names the column by the term | `head -2 scripts/lint/norm-ownership.tsv` shows the column; `bash scripts/check_norm_ownership.sh --check` and `--groups` print `clean`; `bash tests/test_norm_ownership.sh` prints `16 passed, 0 failed, 0 skipped` | Agent [x] |
| The surviving ban in `doc-maintenance` is retired | `grep -n "no home in a policy" workflow/coding-agent/skills/doc-maintenance/SKILL.md` returns nothing, and `sed -n '/Signs of duplication/p' workflow/coding-agent/skills/doc-maintenance/SKILL.md` shows the diagnostic naming a source of truth instead | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints `0 failed, 0 skipped` | Agent [x] |
| Every decision this iteration recorded is realized in the files | `grep -rc "source of truth" docs/ scripts/lint/ \| grep -v ":0"` names every carrier the three decisions reach, and `grep -rnw home` over the six roots returns only the three classes criterion 1 names | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The term is `source of truth` in full, in prose | the operator chose the pass over a declared short form, and a short form beside the term is two words for one object | every carrier in `## Completed` |
| The ledger's column, group prefix and messages carry the same term | a gate whose vocabulary disagrees with the rule it enforces states the rule twice in two languages | `scripts/lint/norm-ownership.tsv`, `norm-judgements.tsv`, `check_norm_ownership.sh` |
| A path, the provider `config home`, and the `--home` flag keep the word | they name a filesystem location, not where a norm lives, so the term would be false there | the 22 lines criterion 1 names |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The pass needed three sweeps, and each sweep found uses the previous pattern could not see, among them `documentation_policy.md:139` and two `prompt-authoring-conventions.md` lines that read `its only home` | result | the same limit the previous unit hit: a grep answers the string it was given, and a word used in ordinary prose hides in phrasings the pattern does not carry. The pass is complete only when the sweep runs against the finished tree and every survivor is read | the record-check backlog, which owns the audit findings that need a home |
| Two surfaces stated the ban in words no grep for it found, after the unit that closed it reported the surface clean: `doc-maintenance`'s diagnostic register, and the advisor prompt's list of bars, which read `a prompt is never the only home of a rule` | defect | `20261021-08`'s fifth criterion was too narrow to hold, because its verification listed the phrasings rather than the claim. Both are retired here | fixed in this unit |

## Completed

| File | Change |
|---|---|
| [`principle-single-source-of-truth/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md) | the directory, `name`, title, description and body; the skill is the term's home |
| [`agent_workflow.md`](../../docs/reference/agent_workflow.md) | `**The source of truth.**` and the eight lines that name the object |
| [`documentation_policy.md`](../../docs/policies/documentation_policy.md), [`documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md), [`discussion_policy.md`](../../docs/policies/discussion_policy.md), [`iteration_policy.md`](../../docs/policies/iteration_policy.md) | the norm-object uses |
| [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md), [`instruction-surface-conventions.md`](../../docs/development/instruction-surface-conventions.md), [`testing_policy.md`](../../docs/development/testing_policy.md) | the norm-object uses, and the section title |
| [`doc-maintenance`](../../workflow/coding-agent/skills/doc-maintenance/SKILL.md), [`document.md`](../../workflow/coding-agent/prompts/document.md), `scope.md`, `sidequest.md`, `milestone-close.md` | the wording, and the ban the diagnostic register still carried |
| [`keep-a-subject-near`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md), [`principle-approval-writes-the-artifact`](../../src/reasoning/providers/pi/config/agent/skills/principle-approval-writes-the-artifact/SKILL.md), [`setup-model-recommendations`](../../src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md), `pi-reviewer-dispatch` | the wording, and the old skill name |
| [`AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) and `doc-advisor-policy.md` | the provider layer's two norm-object uses, the shared marker text, and the ban the advisor's bar list still carried. The installed copies carry the same text |
| [`check_norm_ownership.sh`](../../scripts/check_norm_ownership.sh), [`norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv), [`norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv), [`test_norm_ownership.sh`](../../tests/test_norm_ownership.sh) | the column, the group prefix, the messages, and the test names that assert them |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes, the scalar returns to M3.3.4, the open row's citation follows the rename, and two stale line citations become section names |
