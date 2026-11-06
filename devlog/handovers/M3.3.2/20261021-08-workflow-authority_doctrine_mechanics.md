---
date: 2026-10-21
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire the authority doctrine's mechanics half

## Objective

Retire the half of the authority doctrine that forbids a skill or a prompt to hold a rule, so no policy-map or workflow-map surface contradicts a principle skill that holds a judgement.

## Scope

The M3.3.2 row **Retire the rule that a skill or a prompt can never hold a rule, in the policy map**, taken out of order. The row stays filed under M3.3.2 and the roadmap's `active-milestone` flips to M3.3.2 for as long as these rows run. It flips back to M3.3.4 when phase B resumes, which is the primary priority.

Why this row and no other. Its judgement half moved to M3.3.4 and landed in phase A, where `documentation_policy.md` `## Rule authority` now applies the norm-kind ledger instead of stating the doctrine. The mechanics half still stands, and the tree contradicts it: 22 principle skills hold rules, and five surfaces still say a skill may only inline one. Every phase B landing writes into a corpus that the doctrine forbids, so the contradiction grows with each row if this waits for M3.3.2's own turn.

Ruled out of scope, with a destination each. The malformed `Retire documentation_policy` row and the seven policy slices stay with M3.3.2 and come next in its own order. The `communication` survivor, the reach axis and the plain-wording promotion belong to the ordering decision that follows this unit. The ADR `policy_declarative_framing.md` keeps its account of the deleted authority section, because a record states the decision it took, not the tree's current state.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No surface states that a skill or a prompt holds no rule | `grep -rn "authoritative rule\|exists only in a skill\|stay in the policy\|inline rules from policy\|reference or inline rules"` over `docs/`, `workflow/`, `.agents/skills/` and `src/reasoning/providers/pi/config/agent/` returns nothing. Two drafts outside them still state it, recorded as a finding | Agent [x] |
| Every remaining fast-path rule names the home rather than the layer | `grep -n -A 2 "## A fast path names its home" docs/development/prompt-authoring-conventions.md` shows the section citing the skill and restating no condition | Agent [x] |
| The `documentation_policy.md#rule-authority` citation resolves to a section that states what the citing line claims | `grep -rn "rule-authority" docs/ workflow/` returns nothing; `sed -n '/^## Rule authority/,+4p' docs/policies/documentation_policy.md` shows the ledger applying `### Norm kinds` | Agent [x] |
| The three layer paragraphs agree with `### Norm kinds` | `grep -n "authoritative" docs/reference/agent_workflow.md` returns lines 121 and 164, both home claims about a record and a policy, and no layer claim. Read with `### Norm kinds` at line 60, the three paragraphs name a kind each | Agent [x] |
| The roadmap names the active milestone as M3.3.2 and states when it flips back | `head -2 devlog/roadmap.md` names M3.3.2, and `grep -n "active-milestone scalar follows the rows in work" devlog/roadmap.md` returns the decision bullet that sets it and states the return | Agent [x] |
| The umbrella and the suite are clean | `Lint: clean in 8s across 11 gates`; `1273 tests across 92 files, 1273 passed, 0 failed, 0 skipped` | Agent [x] |
| The ledger classifies every line this unit edits | `clean across 141 row(s), 24 gated, 14 reviewed, 63 judgement, 40 description, 14 homed`, and `--groups` reports `63 judgement line(s), 14 of them homed, 1 group(s) stated by 2+ document(s)` | Agent [x] |
| Every decision this iteration recorded is realized in the files | `grep -c "kind, not by the layer" docs/reference/agent_workflow.md docs/development/prompt-authoring-conventions.md` returns one in each; `head -3 devlog/roadmap.md` names M3.3.2; `grep -n "returns here when phase B resumes" devlog/roadmap.md` returns one line | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The home is decided by the kind and not by the layer, and that replaces the canonical-owner test | the kind answers whether anything detects a breach, which is what a home depends on; the layer answered nothing, and it forbade the corpus the milestone is building | `agent_workflow.md` `### Policy documents`, `### Skill files`, `### Prompt templates` and the Policy Map boundary note; `prompt-authoring-conventions.md` `## Identify the document type` |
| The fast-path section cites `principle-one-home-per-rule` instead of restating its two conditions | the section and the skill stated one rule twice, which the ledger surfaced as an ungrouped judgement. The convention keeps only what the skill does not state: label the copy where staleness would mislead | `docs/development/prompt-authoring-conventions.md` `## A fast path names its home` |
| The active-milestone scalar follows the rows in work | the operator's direction: M3.3.2's rows run out of order under its own scalar, and the scalar returns to M3.3.4 when phase B resumes, which is the primary priority | `devlog/roadmap.md` frontmatter and its `2026-10-21` decision bullet, which owns the setting rather than restating it beside the frontmatter |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `.agents/drafts/maintenance.md:18` still reads `The authoritative rules stay in the policy documents`, and `.agents/drafts/communication-principle-write-plainly/SKILL.md` describes its rules as copies held in policy | defect | two drafts state the doctrine this unit retires. No live surface reads them, so nothing observes the contradiction | the plain-wording promotion and M3.3.3's backlog triage, which distill or discard the drafts |
| The retired doctrine's own account survives in `docs/adr/policy_declarative_framing.md` | description | the ADR states the decision it took, which a record does; no action | nothing, deliberately |

## Completed

| File | Change |
|---|---|
| [`docs/reference/agent_workflow.md`](../../docs/reference/agent_workflow.md) | the three layer paragraphs, the Policy Map intro and its `Document` column, and the boundary note's kind test |
| [`docs/policies/documentation_policy.md`](../../docs/policies/documentation_policy.md) | the opening line, which said a skill or prompt only references or inlines policy rules |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the document-type section, the runbook, advisor and skill paragraphs, and the fast-path section, which now cites the skill |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | the standards-check line and the borrowed-rule invariant |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) and [`norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv) | regenerated and classified, with the document-type judgements grouped |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes, the scalar flips to M3.3.2, and a decision bullet records the setting and its return |
