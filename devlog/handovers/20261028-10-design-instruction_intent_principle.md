---
date: 2026-10-28
milestone: M3.3.6 - The instruction corpus
type: Design
status: Closed
---

# Handover - the instruction-giving principle, designed

## Objective

Settle the domain, the leading word and the family for the judgement that an instruction states what it wants and leaves the method to the party doing the work, then land the principle under that shape.

## Scope

Targets the M3.3.6 row **A principle states the outcome over the method**, reopened when the operator rejected the `principle-prompt-the-outcome` attempt at `3a272b1a`.

Out of scope, by operator direction:

- The claim field. The operator's first point is read as the *declarative-mechanism* argument, not the `metadata.claim` field. If the field itself is the target, it is a governance unit of its own.
- `principle-prose-entrypoint-over-mechanism`, which the operator has ruled a `skill-scaffolder` pattern rather than a principle. Moving it is its own unit and gets a roadmap row this iteration.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The principle sits under the `communication-principle-` prefix with a trigger-bearing description and the fixed part order | `check_document_shape.sh` | Agent [x] |
| `subsidiarity` carries the description and the body, and the body defines it once | `grep -o subsidiarity` gives 6; read | Agent [x] |
| The body separates the instruction phase from the acceptance phase and names `principle-say-what-done-looks-like`, which links back | read both files | Agent [x] |
| A writer reaches the principle from the prompt conventions | the `## State the intent, delegate the method` section | Agent [x] |
| Both landings cite it | `grep` in `instruction-cleanup.md` and `churn.md` | Agent [x] |
| The rejected attempt leaves no artifact | `ls` + `grep` | Agent [x] |
| The `prose-entrypoint-over-mechanism` misfiling is a roadmap row | `grep` the row | Agent [x] |
| Every decision recorded is realized in the files | the decisions table | Agent [x] |
| The gates pass | markdown, doc shape, handover format, instruction surfaces, lint, suite | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The domain is delegation, not declarative programming | the principle governs one party asking another to do work; SQL, Terraform and React already hold the mechanism and do not need the principle, so the programming analogy narrows the reach instead of widening it | this record |
| `subsidiarity` is the leitwort | it carries both halves of the rule, the decision belonging to the closest party and returning upward only where that party cannot, so the token imports the fixed-order exception; it is a borrowed domain term like `sediment`, and the body defines it once and repeats it | this record |
| The family is `communication-principle-*` | operator direction: the judgement is about what an instruction says to the party reading it | this record |
| The claim stays `authority` | the writer owns the objective, the bound and the evidence; the route belongs to the party holding the state | the principle's frontmatter |
| The principle is a sibling of `principle-say-what-done-looks-like`, with links both ways | one brief fails in two directions: no stated finish, and no latitude. The pair names both, and today only one direction is linked | this record |
| The two skills stay separate | `say-what-done-looks-like` owns the acceptance phase and its evidence rules; this one owns the instruction phase. A merge would dilute the evidence rules to gain one cross-reference | this record |
| `principle-prose-entrypoint-over-mechanism` is a scaffolder pattern, misfiled | it governs how a skill wraps a script, which is skill authoring, not a general judgement | a new roadmap row, filed after the gate |
| `autonomy` is one line in the Why, not the leitwort | in this repository it already means an agent acting without the operator, so a handle built on it collides with the runtime meaning | this record |
| A fixed procedure is asked for as a deliverable, not dictated as steps | the design stays with the doer even where the method matters: the writer states the constraints, the doer designs the sequence and then runs it | the principle body |
| The handle is `state-intent-delegate-method` | the family's long form mirrors `rewrite-syntax-never-semantics`, and it carries both halves; `delegate-the-method` alone still read as "hand the method over", and `intent-not-method` named no act | this record |
| The sibling overlap is cut to one part, not merged | a merge would put the evidence discipline over a rule that has no instrument, while the duplicate bound/evidence list is four lines | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Triaged to |
|---|---|---|
| The judgement landed twice before it was named: on 2026-10-28 the instruction-cleanup diet and the churn read-back both applied it with no skill to cite | history | this handover |
| The declarative framing narrows the principle to programming languages, which already hold the mechanism | design | this handover, Decisions |
| `instruction-cleanup.md` named the `docs` convention in a plain-text line, invisible to the earlier rename because no link broke | defect | fixed in this iteration; the convention is `project-documentation` |

## Completed

| File | Change |
|---|---|
| this handover | opened |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-state-intent-delegate-method/SKILL.md` | new principle: the micro-management table, the subsidiarity why, the fixed-order case, the sibling pointer, the test |
| `docs/development/prompt-authoring-conventions.md` | new `## State the intent, delegate the method` router section |
| `src/reasoning/providers/pi/config/agent/skills/principle-say-what-done-looks-like/SKILL.md` | the brief's other half, linking back |
| `workflow/coding-agent/prompts/instruction-cleanup.md` | landing citation in `## The wording`; the stale `docs` name corrected |
| `workflow/coding-agent/skills/code-review/references/churn.md` | landing citation in the intro |
| `devlog/roadmap.md` | the outcome row closed; the prose-entrypoint scaffolder row filed |
