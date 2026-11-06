---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - deconflict the communication instruction surfaces

## Objective

Make one rule ship once. Each communication rule keeps one owner, and every other surface that carried it becomes a pointer that names that owner.

## Scope

The roadmap row **The communication-surface filing**, widened on operator direction from three surfaces to five: `documentation_policy.md` `## Communication Standards`, `prompt-authoring-conventions.md`, `skill-scaffolder`, and the two `AGENTS.md` layers. Two further changes came in on operator direction during the design: reference handling leaves the policy for a new `linking` convention, and `communication-principle-one-addressing-axis` comes into the repository with a writing pass.

Out of scope: rewording the nine filed principles, the home of the plain-wording rules, the layer question for the two rules that have no home outside the provider `AGENTS.md`, and the census scan set. Each is a finding below.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No communication rule is stated at two sites | read of the five surfaces against the deconfliction table in this record | Agent [x] |
| Every non-owning site names its home | `grep -n '^- ' src/reasoning/providers/pi/config/agent/AGENTS.md` -- each bullet in the section carries a skill name, a policy section or a convention path | Agent [x] |
| The renamed gate holds its name end to end | `bash scripts/lint.sh` prints `linking coverage`, and `bash tests/test_linking.sh` passes 23 cases | Agent [x] |
| The census matches the tree | `bash scripts/check_norm_ownership.sh --check` clean across 148 rows, 15 homed | Agent [x] |
| The running context and the shipped config agree | `diff -q` over the repo source and the installed `AGENTS.md`, and over both skill directories | Agent [x] |
| The suite is green | `bash scripts/lint.sh` clean across 10 gates; `test_linking.sh`, `test_norm_ownership.sh`, `test_numbering.sh` and `test_lint_umbrella.sh` all pass | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The provider `AGENTS.md` keeps seven pointer bullets and two structure pointers, and states no rule of its own | the section restated the policy's phrasing rules with no home named, so a reader met one judgement up to four times. A pointer that names its home is a fast path; a statement with no home is a second owner. The two rules with no other home stay as statements | `## Communication Standards` in both copies |
| Reference handling gets a convention of its own, not a section in `docs` | `numbering` is the precedent: a project convention that spans every surface, chat included, with its own gate. Reference handling is the same shape, because "a link resolves where its document is read" is a fact about the surface rather than about the tree. `docs` stays a navigator | `.agents/skills/linking/SKILL.md`, this record |
| The convention is named `linking` and the gate follows it | `numbering` pairs a gerund subject with `check_numbering.sh`, `lint/numbering.mjs` and `test_numbering.sh`. `record-links` named a subset of what it checked, every link in every Markdown file. The gate has no `check_linking.sh`, because the Markdown gate is its entry | `scripts/lint/linking.mjs`, `tests/test_linking.sh` |
| The gate's failure messages name the repair | a message that names only the breach leaves the writer to work out the rule, and the rule is not in their context at that moment. The repair is the one sentence the skill states | the three `detail:` strings |
| `one-addressing-axis` wins over the policy and links to the convention | on operator direction: where the principle and a document disagree the principle is the source, and where it and another skill disagree it links. So the heavily-cited-item rule left `### Numbering` for the skill, and the numbering scheme stays with its own convention | `docs/policies/documentation_policy.md` `### Numbering` |
| The two rules with no other home stay in the provider layer for now | moving them is a layer decision, and a deconfliction pass is the wrong diff to decide it in | Findings, below |

| The section splits by when the judgement fires, not by what it is about | a bullet is a sentence-level judgement a writer reaches for mid-sentence; a second paragraph carries the four that fire on a whole artifact, because four more bullets would have doubled the list without changing how it reads. The split also gave `show-dont-describe` its only live path, which it had lost | `## Communication Standards` in both copies |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The twelve reference-handling lines left the census scan set, so the ledger reports 148 rows where it reported the same block plus those | consequence of the move | a rule moved to a skill stops being counted, which is the limit handover `20261020-30` recorded | the closed row **The ledger cannot see a judgement stated in a convention skill**, whose stated limit this is |
| `unslop` bans words by name and `/technical-writing` restates the plain-wording rules, and both live only in the agent config home | duplicate, no repository carrier | a shipped rule competes with an unmanaged one, and no diff can reach it | roadmap row **The plain-wording standard** |
| `initialize` seeds seven convention stubs and this tree carries nine, so a fresh project gets neither `numbering` nor `linking` | gap in the seeded payload | the handoff at `.agents/skills/<convention>/SKILL.md` fails on a fresh project with no message that says why | new roadmap row **The seeded convention corpus is short of the project's own** |
| The principle corpus uses two document shapes for the same four parts | record inconsistency across ten files | a writer filing a principle has no single exemplar, and M3.3.4's shape criterion cannot be read against two | new roadmap row **The principle corpus carries two document shapes** |
| "No capacity claim without a signal" and "follow the target document's own conventions" have no home outside the provider `AGENTS.md`, which is the layer that carries no project policy | placement defect, one declaration in the wrong layer | a project rule ships to every project the provider serves | the M3.3.4 task list keeps both in place; the layer question is unowned and needs a row when the plain-wording row settles the policy remainder |

## Completed

| Artifact | Change |
|---|---|
| `.agents/skills/linking/SKILL.md` | new convention: what to link and what to name, where a link resolves, handoff links, link form, the stories table, and `## The check` naming the gate |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-one-addressing-axis/` | new to the repository: the skill after its writing pass, and a `MAINTENANCE.md` |
| `$AGENT_HOME/agent/skills/communication-principle-one-addressing-axis/` | the installed copy, byte-identical |
| `scripts/lint/record-links.mjs` to `scripts/lint/linking.mjs` | renamed; header corrected to the rule's real scope; three messages name the repair |
| `tests/test_record_links_rule.sh` to `tests/test_linking.sh` | renamed; the config key follows; two skill-shape tests added, so the skill's story claim is enforced |
| `.markdownlint-cli2.mjs`, `scripts/check_markdown.sh`, `scripts/lint.sh`, `scripts/lint/doc-wrap.mjs`, `scripts/check_container_layout.sh`, `tests/test_lint_umbrella.sh`, `tests/test_norm_ownership.sh` | the rule's name and its comment references |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` and its installed copy | `## Communication Standards` reduced to seven pointer bullets, one paragraph naming the four whole-artifact judgements, two structure pointers and the two rules with no other home; all ten `communication-principle-*` skills are now named, and the duplicate line-wrap statement under it is gone |
| `docs/policies/documentation_policy.md` | `### Reference handling` became a pointer to `linking`; `### Numbering` gave its carried rule to the principle; the hedging caveat arrived from the provider layer |
| `docs/reference/agent_workflow.md` | the document-reference rules moved to their own row, naming `linking` |
| `scripts/lint/norm-ownership.tsv`, `norm-judgements.tsv` | regenerated and regrouped; the changed lines reclassified, and two homes derived |
| `.agents/drafts/communication-domain-taxonomy-run.md` | the origin link follows the archived spec |
| `devlog/discussions/archive/20261019-design-draft-prose_standards_specs.md` | archived, as the rejected plan it is |
| `devlog/roadmap.md` | the filing row closed with its landing note; three rows filed: the malformed `Retire documentation_policy` entry, the seeded corpus gap, and the corpus shape split |
