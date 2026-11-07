---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the cut test carries the pass, not only the judgement

## Objective

The four passes this session ran on `/iter` and its three siblings used four things the corpus did not hold: the three classes a sentence fails, the keep test's second prong for guards, and the audit of removed lines that catches a rule cut with its rationale. All four belong to the principle that decides them, not to a runbook beside it, so a later agent reading `cut-what-serves-nothing` runs the pass rather than re-inventing it.

## Scope

The principle gained three parts and one row-pair:

- **the three classes**, in the table: an explanation inside a how-to, a rationale tail after an imperative, and a boundary the document already states. The first was there; the second and third are the ones a reader would otherwise reconstruct by taste;
- **`What stays`**, the keep test's second prong: a guard changes no step, so ask what wrongly proceeds without it. This is the correction to the action test the principle's earlier text carried alone, and the reason guards survived the four passes;
- **`After a removal pass`**, the audit: read the removed lines for an imperative and find each in what remains. This is the check that caught the one rule loss on `/iter`, and it is the principle's own failure mode rather than a neighbouring one.

Ruled out of scope, on the operator's route: a runbook. A second document stating how to apply this principle is the duplication the principle exists to remove.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The three cut classes are in the principle | `rg -c 'rationale tail after an imperative\|a boundary the document already states\|an explanation inside a how-to' .../cut-what-serves-nothing/SKILL.md` prints 3 | Agent [x] |
| The keep test carries the guard prong | `rg -n 'What wrongly proceeds without the line' .../SKILL.md` prints the part, and `**The test.**` names both prongs | Agent [x] |
| The audit is a named part after the removal pass | `rg -n '^**After a removal pass.**' .../SKILL.md` prints one line, and its imperative list is present | Agent [x] |
| The shape the principle gate enforces holds | `bash scripts/check_document_shape.sh` reports 25 principle skills clean | Agent [x] |
| The seed and the installed copy are the same text | `diff -q` between them exits 0 | Agent [x] |
| Every decision this unit recorded is realized in the file | the `## Decisions` table read against the file | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The three classes go in the table, not in a section of their own | each class is an instead-of/give pair, which is the table's shape, and a prose section would state them a second time | the skill |
| The keep prong is a named part, `**What stays.**` | it corrects the action test rather than extending it, and a correction buried in `**The test.**` reads as a footnote | the skill |
| The audit is the principle's own part, not a runbook step | a rule cut with its rationale is this principle's failure mode, and the check for a failure belongs where the failure is stated | the skill |
| No runbook | a second document on applying the principle is the duplication the principle removes | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The principle stated the action test alone, so a pass run from it alone would cut guards -- preconditions, stops and exit conditions change no step | defect, text | the four passes this session survived only on a test the agent improvised in chat, which is not repeatable | this unit |
| The four passes' method lived in one session's chat: the classes, the guard prong and the audit were nowhere in the corpus, so a later agent re-derived them or skipped them | gap | the same pass run twice would give different results, and the difference would be invisible | this unit |

## Completed

| File | Action |
|---|---|
| [`src/reasoning/providers/pi/config/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md`](../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md) | two table rows, `**What stays.**`, `**After a removal pass.**`, and `**The test.**` carrying both prongs |
| `/home/agentuser/.pi/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md` | the installed copy, edited to the seed's text; it delivers nothing |
