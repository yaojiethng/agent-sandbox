---
date: 2026-11-04
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the proposal-first prompt

## Objective

Ship the proposal-first mode as a harness prompt that carries the interview's preamble inline and, at each step, states back the agent's read of the operator's intent, offers the options with their benefits and tradeoffs, and recommends one.

## Scope

Delivers the roadmap row **The proposal-first prompt**, filed under M3.3.3 beside the two closed `grill-me` rows. The operator's rule is to file it in the milestone that already handles `grill-me`, and M3.3.3 is that milestone: it holds **The `grill-me` input contract is stated** and the source bump that took in `grilling`.

The subject is the mode the operator calls proposal-first, seeded by the installed one-line prompt `propose.md` (`can you propose a few forms of the instruction? for us to brainstorm over.`) and grown out around the two words that prompt uses, propose and brainstorm. The grill-me discussion is the occasion and not the subject. The mode has to hold for a document, a section, an interface, a test or a plan as well.

In scope: the shipped prompt, the design record that settles it, the roadmap row, and one read of the `garrytan/gstack` corpus at `068087f3` for its workflow, its turns of phrase and the problems its changelog records.

Out of scope, one sentence each with the reason: the installed `propose.md` is not overwritten, because the operator cannot say what a parallel write would clobber and a file outside version control has no undo, so the shipped command is the maintained copy and the personal one is removed or renamed at import; no `GRILL.md`-style configuration file is read, parsed or gated, because the operator reads it as possibly an inferior method; `grilling` and `grill-me` keep their text, because this prompt restates their preamble rather than editing it, and an edit to the vendored skill diverges a fork whose upstream is changing this surface now; nothing is vendored from gstack, because the corpus is read for evidence.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The prompt ships at the harness prompt root, whose cell the manifest already declares | `test -f src/reasoning/agent/prompts/propose.md`; `rg -c '"src/reasoning/agent/prompts/"' src/build/container-interface.json` returns 2 | Agent [x] |
| The preamble is inlined: the three-part problem and the tree with its frontier | `rg -c 'Establish the design space' src/reasoning/agent/prompts/propose.md` returns 1; `rg -c 'The frontier is'` returns 1 | Agent [x] |
| A step opens by stating back the read of the operator's intent, and an unknown read is said aloud | `rg -c 'state back your read'` returns 1; `rg -c 'say you do not know'` returns 1 | Agent [x] |
| Each option carries its benefits and its tradeoffs | `rg -c 'benefits and the tradeoffs of each'` returns 1 | Agent [x] |
| One option is recommended with its reason, and a reply that is not a pick is not acceptance | `rg -c 'recommend one and say why'` returns 1; `rg -c 'do not take it as acceptance'` returns 1 | Agent [x] |
| No message format, no option count and no link to another artifact are prescribed | `grep -c '^```'` returns 0; `rg -c '\]\('` returns 0; `rg -n '[0-9]' src/reasoning/agent/prompts/propose.md` returns nothing | Agent [x] |
| A clarification re-derives the branch and names what changed in the read of the intent | `rg -c 'update your priors'` returns 1; `rg -c 're-derive the branch'` returns 1 | Agent [x] |
| The end condition is stated, in a section of its own | `rg -c 'frontier is empty'` returns 1; `rg -c '^## The close'` returns 1 | Agent [x] |
| The design record carries the six sections, and every question in it carries at least two options with a rejection reason | `rg -n '^## ' devlog/discussions/20261104-design-settled-proposal_first_prompt.md` returns six headings; read `## Options Considered` | Agent [x] |
| The roadmap row is filed under M3.3.3 and names the design record | `rg -n 'proposal-first' devlog/roadmap.md` | Agent [x] |
| No path to this handover appears in the roadmap row or the design record | `rg -c '20261104-01' devlog/roadmap.md devlog/discussions/20261104-design-settled-proposal_first_prompt.md` returns nothing | Agent [x] |
| The tree gates are clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |
| Every decision this iteration recorded is realized in the files | read `## Decisions`, check each destination | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The mode ships as a harness prompt under `src/reasoning/agent/prompts/` | Operator direction: a command any session may invoke belongs in the harness prompt root, which the manifest already declares and the image already copies | `src/build/container-interface.json`; design record `## Options Considered` |
| The iteration types as `Workflow`, not `Design` | A design handover does not cover an implementation commit, and the delivery is the prompt. Precedent is `20261019-12`, which shipped the classifier-models prompt | this handover |
| The interview's preamble is inlined, and the prompt cites nothing | Operator direction. It also leaves the text the operator's to shape without a fork's release cycle, and it removes a dependency whose premise the first design got wrong | design record `## Options Considered` |
| A step opens by stating back the read of the operator's intent | Operator direction, applying the read-back move to each branch so the options answer the operator's concern rather than the agent's guess at it | `src/reasoning/agent/prompts/propose.md` |
| No message format, no option count and no reply vocabulary are prescribed | Operator correction: the first design specified registers, lettering, positions, prices and reply tokens, and the move at every branch is the same | this handover; design record `## Context` |
| A clarification re-derives the branch and names what changed | Operator rule: a clarification moves the priors, and an option the new premise overtook must not be left standing | `src/reasoning/agent/prompts/propose.md` |
| gstack is read for its failure history, and nothing is vendored | Its decision-brief and ask formats are the over-prescribed end of the space, and its changelog records that a format decays into a report | design record `## Options Considered` |
| No ADR | The decision governs one prompt artifact and is stated where that artifact's writer reads it; no other component must match a standing principle | this handover |
| The roadmap row and the design record name no handover path | The operator renumbers this record when the change is brought in, so a path to it is a link that breaks on import; the record is found by date, and the handover may link outward | this handover |

## Decisions pending

None.

## Findings

- **The first design over-prescribed the mode.** The agent read a discussion as a message format and specified two registers, a lettered item, a fixed recommendation position, priced alternatives, a reply vocabulary and a stop. The operator rejected it at the gate and restated the move as brainstorm plus one recommendation, with the number, the wording and the layout left to the agent. Impact: the design record's `## Context` carries the correction, and every one of those rules is gone from the prompt.
- **The second correction put the method back in the prompt.** The operator asked for the design-space preamble to be inlined rather than linked, and for each step to open with a read-back of the operator's intent before the options. Impact: the prompt now carries the three-part problem, the tree and the frontier, and a three-move step, and it cites no skill.
- **A premise behind an earlier decision was false.** The first design kept the prompt from citing `grilling`, on the stated reason that the skill ships nowhere the prompt reaches. `src/reasoning/agent/skills/` and `src/reasoning/agent/prompts/` are two folders of the same pi package, so both are in the image. Impact: the false reason is retired. The prompt still inlines on operator direction, and the design record states the reason that actually holds.
- **The proposal-first form decays into a report.** gstack's changelog records the measured instance at `v1.6.4.0`, where plan reviews on one model "silently stopped asking questions one at a time" and became "here are 6 findings, end of turn", and its Phase 4 gate exists because "writing the recommendation in prose and continuing is the failure this gate prevents". Impact: the prompt ends the turn at the recommendation, and the design record states the failure it answers.
- **The shipped `propose` collides with the operator's installed copy.** Pi resolves a prompt name first-wins and reports a prompt collision only in the interactive interface, so a print-mode, JSON, RPC or dispatched run never sees one. Impact: the personal `$AGENT_HOME/agent/prompts/propose.md` is removed or renamed when the change is imported, and the design record's `## Consequences` states it.
- **The harness prompt root states no budget.** This prompt adds a fifth file to `src/reasoning/agent/prompts/`, and no rule states what the root may hold. Impact: no row is filed, because M3.3.3's own text already places the instruction corpus's budget with M3.3.6, which is in progress.

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/prompts/propose.md` | The shipped command: the inlined preamble, the read-back of intent, the options with benefits and tradeoffs, the recommendation, and the re-derive on a clarification |
| `devlog/roadmap.md` | Files the row under M3.3.3 and marks it `[x]` |
| `devlog/handovers/20261104-01-workflow-proposal_first_prompt.md` | This record |
