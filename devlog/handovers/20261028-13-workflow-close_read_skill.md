---
date: 2026-10-28
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - the close read becomes a skill

## Objective

Give the operator a durable way to direct another close read: an operator-fired skill that runs the file-by-file knowledge transfer the September read-through proved, without the agent-run measurement half that was never executed.

## Scope

The close-read procedure, rescued from `.agents/drafts/read-through-run.md` and from the record the September run left, and shipped as `workflow/coding-agent/skills/close-read/`. This iteration is the skill and its two supporting files.

Deferred on operator direction, 2026-10-28: retiring the `-run` family and disposing of its reports, which is the next iteration and now holds a roadmap row. `read-through-run.md` therefore stays in `.agents/drafts/` this iteration, superseded but not yet deleted, and the row that names it is untouched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill parses and is not model-invoked | `sed -n '1,5p'` shows `name`, `description` and `disable-model-invocation: true` | Agent [x] |
| The skill carries no procedure it should not | `grep -n '^## '` on `SKILL.md` shows no mutation, bite, fan-out or register-integrity section, and the only mention of mutation is the boundary in `## Does not judge` | Agent [x] |
| The style section constrains rather than describes | read `## Communication style`: every line names something the writer would otherwise do wrong, and a shape block follows | Agent [x] |
| The register format is closed | `references/register.md` states six keys and seven classes and admits no other value | Agent [x] |
| The exemplar is evidence, not invention | it quotes the 2026-09-24 turn, and the style section cites it | Agent [x] |
| The roadmap records the work and the deferral | `git diff <iteration-base> -- devlog/roadmap.md` carries the new closed row and the open retirement row | Agent [x] |
| Every decision recorded here is realized in the files | the decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The close read ships as a skill, not a prompt | a register schema, a style table and an exemplar are three artifacts, and a prompt has nowhere to put them | `workflow/coding-agent/skills/close-read/SKILL.md` |
| It sets `disable-model-invocation: true` | only the operator fires a close read, so the model must neither discover nor self-fire it | `SKILL.md` frontmatter |
| The operator's September steering is preserved in the skill | "knowledge transfer", the operator reading, the readable chat window: the wording is what produced the outcome, so it is kept rather than paraphrased | `SKILL.md` `## Intent` and `## Communication style` |
| BDD is a learning frame and a checkable description, not a reporting format | Given, When and Then are the precondition, the invariant and the postcondition, and they build the reader's model of the code; the block goes back into the test file because it is worth keeping | `SKILL.md` `## Per file`, `## Writing the BDD block back` |
| The skill inlines the BDD and TDD frame and carries no conventions block | the read writes no project record, and the write-back is a comment above a unit, so the `testing` convention governs none of it | `SKILL.md` `## The BDD frame` |
| The fragment precedes its description | the reader verifies the description against the code instead of trusting it | `SKILL.md` `## Communication style` |
| Findings go to a JSONL register; the record carries no count, status line or roll-up | the September record's aggregates went stale as the run progressed and confused it, and that run is the predecessor of `principle-only-derive-what-you-own` | `SKILL.md` `## The record and the register`, `references/register.md` |
| `class` is a closed enum of seven | free text produced about 110 distinct class values across 319 rows, two of them `-` | `references/register.md` `## The classes` |
| A correction rewrites one line | each JSONL line stands alone, so the edit-anchor duplication and the out-of-order table tail cannot recur | `references/register.md` `## Appending and correcting` |
| The record and register live under `workspace/output/close-read/` | a read then commits nothing but the BDD blocks, and nothing pushes a write-back during the read | `SKILL.md` `## The record and the register` |
| No query script ships this iteration | the register is JSONL and one command derives the view; a script would cost a test, a registration and a maintenance surface for a per-set derivation | `references/register.md` `## Deriving a view` |
| The `-run` retirement is the next iteration | the operator separated writing the skill from disposing of the briefs and their reports | `devlog/roadmap.md`, the retirement row |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `read-through-run.md` is 166 lines of imperative procedure and code snippets, written to make the pass agent-runnable, and it has run zero times since it was written | process | the artifact that was persisted is not the one that produced the value | the retirement row, next iteration |
| The close-read procedure survived only in a session log and a retrospective paragraph; nothing an operator could invoke existed | process | the procedure was one deletion away from being lost | landed here as the skill and its exemplar |
| The settled register's `class` field is free text: about 110 values over 319 rows, including `-` twice | data | the field cannot group, so no view can be derived from it | `references/register.md` `## The classes` |
| The September record's aggregation metrics and status updates went stale as the run progressed | data | the reader and the agent disagreed about the state of the read | `references/register.md`, and the no-count rule in the skill |
| The markdown findings table was clobbered by edits, which is why JSONL replaced it | tooling | append-only is the property that made the register usable | `references/register.md` `## Appending and correcting` |
| Both `-run` drafts carry no frontmatter block, so neither loads with a description (roadmap `:228`) | defect | the model cannot discover either one | the retirement row, next iteration; the skill supersedes the first |
| The iteration that records this handover is one work unit and one commit, with the deferral written to the roadmap rather than carried in prose | process | the next iteration starts from a row, not from this record | `devlog/roadmap.md` |

## Completed

| File | Change |
|---|---|
| [`workflow/coding-agent/skills/close-read/SKILL.md`](../../workflow/coding-agent/skills/close-read/SKILL.md) | new: intent, scope, order, per-file returns, the BDD write-back, the communication style, the register rule and the boundaries |
| [`workflow/coding-agent/skills/close-read/references/register.md`](../../workflow/coding-agent/skills/close-read/references/register.md) | new: the six-key line, the seven classes, appending and correcting, the derivation command, the naming |
| [`workflow/coding-agent/skills/close-read/assets/exemplar.md`](../../workflow/coding-agent/skills/close-read/assets/exemplar.md) | new: the 2026-09-24 turn, trimmed to the opening, the contract and a function, one unit and the close |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the close-read row closed, and the `-run` retirement row filed open for the next iteration |
