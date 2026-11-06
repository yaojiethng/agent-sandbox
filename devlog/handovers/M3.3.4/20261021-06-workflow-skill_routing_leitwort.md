---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Give the routing skill the naming clauses and the leading word

## Objective

State in `principle-effective-skill-routing` how a skill's name is chosen and how one leading word steers an agent, so the next name and the next description are read from a rule instead of negotiated in a session.

## Scope

Continues the interrupted handover `20261021-05-workflow-inverse_defect.md`, which paused at the scope gate with the row **Name the inverse defect: a section that holds two unrelated concepts** unbuilt. This sidequest runs first because the clauses it lands govern the rename the parent proposes.

The skill `principle-effective-skill-routing` gains three clauses. A name states the judgement or the defect it prevents and carries the word the domain already holds. One leading word, repeated through the name, the description and the body, is what makes the text steer, and it comes from the domain the skill works in. Two linguistic errors cost the reader the same, invented jargon and vague generalities, and the domain exception runs the other way. The same skill's does-not-cover line widens, because a leading word lives mostly in the body and the line today excludes the body.

`prompt-authoring-conventions.md` `**Suggested skill name.**` becomes a pointer plus the repository's member scheme. Its judgement sentences move into the skill, so leaving it alone would ship the judgement twice, which is the defect the parent's row exists to name.

Ruled out of scope, with the destination named. The `metadata: leitwort` field and the gate rule that would read it belong to the row **Populate the leading words across the corpus**, because a field declared on one skill and checked by nothing is data with no reader. The defect glossary I proposed last message is withdrawn: the pattern table's negative column already enumerates the defects, so the glossary would state them a second time.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill states how a name is chosen, in a line a writer applies without reading the conventions doc | the skill's `**The name.**` part carries the judgement clause and the domain-word clause, and `bash scripts/check_skill_shape.sh` printed `skill shape: clean across 22 skill(s)` | Agent [x] |
| The skill states the leading word as a device with a rule, not as advice | `**The signpost.**` states what to repeat, where, and that no gate sees a thinking trace, and `**Linguistic fidelity.**` and `**The domain exception.**` carry the word-choice rules | Agent [x] |
| The skill practices its own rule | `grep -c signpost` returns 7, in the description, the title, the signpost part and the does-not-cover line. The identifier still reads `effective-skill-routing`, which is the deviation the findings record | Agent [x] |
| The judgement has one home | the two judgement sentences return 0, and the paragraph keeps the member scheme and names the skill for the judgement | Agent [x] |
| Both copies of the skill are identical | `diff` printed nothing | Agent [x] |
| The umbrella and the suite are clean | `Lint: clean in 8s across 11 gates`; `1273 tests across 92 files, 1273 passed, 0 failed, 0 skipped` | Agent [x] |
| Every decision this sidequest recorded is realized in the files | five decisions, each read against its file: the naming judgement in the skill and its pointer in the convention, the signpost part with its repetitions, the absence of a defect glossary, the domain word in the name, and the domain exception stated inside the skill | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The naming judgement lives in `principle-effective-skill-routing`, and the convention keeps the member scheme and points at the skill | the skill is read by whoever writes a skill, and the scheme is this repository's member list, which is the class-versus-members split the `linking` cleanup used | this table, and the skill's name part |
| The leading word is the corpus's linking layer, keyed to the pattern table's rows | the pattern table already enumerates the positive and negative cases, so one repeated word keys them without a new document | the skill's leading-word part |
| No defect glossary | it would restate the pattern tables' negative column with no decision attached | this table |
| The name carries the word the domain holds, and the signpost carries the leading word drawn from that domain | a name built on a general word loses the concept, and a leading word with no domain behind it anchors nothing | the skill's name part and signpost part |
| The domain exception is stated inside the skill rather than linked | a shipped skill cannot reach a repository path, and the link gate fails one that tries | the skill's domain-exception part |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The conventions doc and the routing skill state the same naming judgement today | result | `prompt-authoring-conventions.md` `**Suggested skill name.**` states the class-then-judgement rule that the skill's `**The name.**` part also states, so one of them must become a pointer | the scope, which reduces the paragraph to the member scheme and a pointer |
| The domain exception now stands in two places | result | the skill states it for a shipped corpus and `documentation_policy.md` states it for the repository's prose, so the rule has two carriers and no single home | the row **Decide how a shipped skill cites a rule that lives in this repository**, which decides whether a shipped skill restates a rule or names it |
| The skill's own identifier does not carry its leading word | result | the skill states that the leading word repeats through the name, the description and the body, and its identifier keeps `effective-skill-routing`, which carries no `signpost`. A rename reaches the files `grep -rl principle-effective-skill-routing` names | the roadmap row **Rename the routing skill so its identifier carries its leading word** |
| The corpus row this sidequest wrote carried four subjects and a literal count | result | the roadmap audit found the row holding the leading-word pass, the shipped-skill citation question, the domain-exception carrier question and the spelling fix, which is the lumping defect the parent row is naming, and it stated a corpus count the gate already prints | fixed in the write-back, which splits the row into three and leaves the count to `bash scripts/check_skill_shape.sh` |
| `communication-principle-write-for-the-reader` spells one word two ways | result | the file writes `judgment` in `**The same judgment on a prompt.**` while the corpus writes `judgement` four times | left open, outside this sidequest's scope, and reported to the operator at the pre-close gate |

## Completed

| File | Change |
|---|---|
| [`principle-effective-skill-routing/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-effective-skill-routing/SKILL.md) | the title, the description, `**The name.**` with its two clauses, `**The signpost.**`, `**Linguistic fidelity.**`, `**The domain exception.**`, the widened does-not-cover line, and the test's leading-word step |
| `$AGENT_HOME/agent/skills/principle-effective-skill-routing/SKILL.md` | the installed copy, identical to the repository copy |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | `**Suggested skill name.**` keeps this repository's member scheme and names the skill for the judgement |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv), [`norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv) | regenerated; the naming paragraph is a judgement homed to the skill, so the ledger reports 13 homed rows where it reported 12, and the judgement regroups as `j-home-principle-effective-skill-routing` |
| [`devlog/roadmap.md`](../roadmap.md) | three rows: the sidequest's outcome, the corpus-wide leading-word pass, and the row the citation question became. A fourth, for the identifier rename, follows the audit |
