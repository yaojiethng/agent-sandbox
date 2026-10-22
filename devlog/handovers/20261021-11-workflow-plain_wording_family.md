---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - The plain-wording family

## Objective

Replace one policy section and one draft with three principle skills, so the plain-wording rules have a shipped owner each, and the section that would orphan them names those owners and states no rule of its own.

## Scope

The roadmap row **The plain-wording standard**, rewritten as **The plain-wording family**, and the M3.3.4 `Sequencing:` line, which placed phase B after M3.3.2's retirement and named a set that was not the section's open rows.

The row's premise changed while the unit was being scoped. The draft proposed one skill named `write-plainly`, and the operator rejected that name on two grounds. The name states the register of delivery, and a reader who takes a title as the whole instruction then thins the text. The territory also holds three judgements, and one title would have been a bridge over them.

Three skills, one iteration, one commit. The project convention proposes no split by default, and the three share one carrier set, so a split would have edited `docs/policies/documentation_policy.md` `### Simplified Technical English` three times and left it half assigned between commits.

The scalar moves to M3.3.4 with this row, per the `2026-10-21` decision bullet that the scalar follows the rows in work, and returns to M3.3.2 when the policy-member row opens.

Two rules left the corpus in this unit, both by operator direction, and both recorded under Decisions. A word-count cap on sentences, because a length limit and a work-per-word judgement pull in opposite directions. The banned-word gate, unfiled, because building its list needs a measurement this repository has no tool for.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Three skills are live in the shipped root, each with a claim the authoring convention's table holds | `bash scripts/check_skill_shape.sh` reports clean, and `bash scripts/check_skill_shape.sh --map` prints `maximize-conceptual-leverage`, `align-the-mental-model` and `single-train-of-thought` under `reader` | Agent [x] |
| The section names an owner for every rule it carries, and states none of them | `sed -n '/^### Simplified Technical English/,/^### Reserved terminology/p' docs/policies/documentation_policy.md \| grep '^- ' \| grep -v 'Literal-reader test' \| grep -vc 'skills/'` prints 0, so every phrasing-rule bullet in the section cites a skill path | Agent [x] |
| The census M3.3.2 closes on fell with this unit rather than standing still | `awk -F'\t' 'NR>2 && $3=="judgement" && $5=="none" && $2 ~ /^docs\/policies\// {c[$2]++} END {for (k in c) print c[k]"\t"k}' scripts/lint/norm-ownership.tsv` prints 19, against 26 before the unit | Agent [x] |
| No carrier still calls a policy document the standard, and the shipped and installed `AGENTS.md` trees agree | `grep -c 'The standard is \`docs/policies/documentation_policy.md\`' src/reasoning/providers/pi/config/agent/AGENTS.md /home/agentuser/.pi/agent/AGENTS.md` prints 0 twice, and `diff` of the two files is empty | Agent [x] |
| The draft is gone and nothing links it | `ls .agents/drafts/communication-principle-write-plainly` fails, and `bash scripts/check_markdown.sh` is clean | Agent [x] |
| The umbrella is clean | `bash scripts/lint.sh` prints `Lint: clean`, and `bash scripts/run_tests.sh` prints 1273 passed | Agent [x] |

## Decisions

| Decision | Reason | Home |
|---|---|---|
| The skill family replaces the one-skill draft, and the name `write-plainly` is not used | the name states the register of delivery, and the register is the half of the judgement that loses a distinction. The territory holds three objects, one word, one mapping, one line of reasoning | the three skills, and the roadmap row |
| A sentence's length is judged by what each word carries, not by a word count | a word-count cap and a work-per-word judgement pull in opposite directions, so holding both puts a rule and its contradiction in the corpus | `communication-principle-maximize-conceptual-leverage` |
| The banned-word gate is not filed | building the list needs a measurement of this repository's verb distribution, and no tool here takes it | this record |
| No idioms, no metaphors and no unmarked hedging are one judgement, and the marked-inference permission is not restated | `## The principle claims` already states that a claim says it is an inference, so the policy's clause was a copy of the claim table | `communication-principle-maximize-conceptual-leverage`, and the claim table |
| `one term, one meaning` lands inside the mapping skill rather than as its own skill | the 2026-10-20 rejection held against a synonym ban as the test. The mapping skill tests variance between the two models, and a synonym rotation fails that test as one thing held by two words | `communication-principle-align-the-mental-model` |
| The alignment goal is stated where the claims are declared, not in a skill | a skill holding the goal and naming the members that serve it is a bridge document, and this corpus rejects those | `docs/development/prompt-authoring-conventions.md` `## The principle claims` |
| The leading-word concept moves to the leverage skill, and the routing skill keeps placement | the choice of a leading word is the word-choice judgement, and a second statement in the routing skill would be the copy this milestone removes. The routing skill now says which word leads is the leverage skill's question, and keeps where the word goes and the test that finds it | `communication-principle-maximize-conceptual-leverage`, with `principle-effective-skill-routing` linking it |
| `/technical-writing` keeps its name, its wider reach and its provenance | the collision with the upstream skill name was an artefact of a scope that proposed subsuming it. It now defers documentation prose to the family and keeps READMEs, RFCs and commit messages | that skill, outside this repository |
| `.agents/skills/docs/SKILL.md` is out of this unit | a fourth pointer to the same standard is a copy that can go stale, and the provider `AGENTS.md` already carries the pointer a mounted project reads | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The ledger derives a source of truth only from the path form `skills/<name>/`, so the section's seven citations in the form `Judgement: \`name\`` all recorded `none` and would have held the census open after the rules had an owner | defect | a section can cite every owner it has and still count as orphaned. The rewritten section uses the path form on every line | corrected here, and the mechanism is the ledger's own derivation |
| The conformance requirement is a rule with no observer, so it cannot be a rule row, and as a judgement with no owner it would have held the census open until the file was deleted | defect | the ledger scans `docs/` only, so the sentence would have left the census at M5 by leaving the file rather than by acquiring an owner. The unit places it in a skill, which is what the delete-then-orphan order would otherwise have lost | `communication-principle-maximize-conceptual-leverage`, with the reasoning in its why |
| The roadmap maintenance check ran twice, before the scope and at pre-close, and returned eleven findings then five | result | the five are the classes `devlog/roadmap.md` **The record-check backlog** already names: `file:line` references, rows addressing a sibling by row number, version literals, a standalone ordering block repeating `Depends on`, and rows that share a subject. Two closed rows in the class-2 section still named the row this unit renamed, and the unit repoints them | the record-check backlog for the five classes, which is the row that owns them |
| `single-train-of-thought` carries no leading word | gap | **Populate the leading words across the corpus** asks for one per principle, and forcing one here would pre-empt the pass that judges all of them together | `devlog/roadmap.md` **Populate the leading words across the corpus**, which reads the corpus at that point |

## Completed

| File | Change |
|---|---|
| `.../skills/communication-principle-maximize-conceptual-leverage/SKILL.md` | new. Leitwort `leverage`, claim `reader`. The word trade, the lossless constraint, and the rows for the domain term, the ornate verb, the metaphor and the unmarked hedge. Holds the ASD-STE100 conformance requirement, and its why carries the direction the trade runs in |
| `.../skills/communication-principle-align-the-mental-model/SKILL.md` | new. Claim `reader`. The mapping test, and one clause naming scoping and acceptance criteria as the same judgement outside prose |
| `.../skills/communication-principle-single-train-of-thought/SKILL.md` | new. Claim `reader`. The document-grain test, and no forced leitwort |
| `docs/policies/documentation_policy.md` | `### Simplified Technical English` keeps its heading and replaces every phrasing rule with a pointer to the skill that owns it. The short-sentence line and the hedging clause leave |
| `.../skills/principle-effective-skill-routing/SKILL.md` | its copy of the word-choice judgement leaves: the domain exception, the two-error fidelity section, the `carry the domain's precision` line and the instruction to draw the word from the domain. It keeps the signpost, the placement of the leading word, the name-collision cost and its own test, and links the choice to the leverage skill |
| `docs/development/prompt-authoring-conventions.md` | `## The principle claims` gains the alignment goal, two sentences, as what the five claims serve |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` and `~/.pi/agent/AGENTS.md` | `## Communication Standards` names the corpus as the standard rather than a policy document, and adds the three judgements to its pointer list. Both trees in one commit |
| `/home/agentuser/.pi/agent/skills/technical-writing/SKILL.md` | one deferral paragraph for documentation prose, keeping its wider reach |
| `.agents/drafts/communication-principle-write-plainly/` | both files and the directory deleted |
| `/home/agentuser/.pi/agent/skills/` | the three new skills copied in, so the running agent reads the corpus it now points at. The installed copy is not in this repository and no gate reads it |
| `scripts/lint/norm-ownership.tsv` and `norm-judgements.tsv` | regenerated, the new rows classified, regrouped. `bash scripts/check_norm_ownership.sh --check` decides the row and source counts, and prints them |
| `devlog/roadmap.md` | the row rewritten and closed, the M3.3.4 `Sequencing:` line replaced by the unit order, two M3.3.2 clauses renamed from the standard to the family, the scalar moved to M3.3.4, and **Populate the leading words across the corpus** repointed at the two skills that decide the word and its placement |
