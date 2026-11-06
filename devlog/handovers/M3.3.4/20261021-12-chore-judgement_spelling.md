---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Housekeeping
status: Closed
---

# Handover - One spelling for the corpus's word for a judgement

## Objective

Make the two copies of `communication-principle-write-for-the-reader` spell its word for a judgement the way the rest of the corpus spells it, so a reader who greps for the word finds every carrier.

## Scope

The roadmap row **One shipped skill spells one word two ways**, which is one heading in one skill, in the repository copy and the installed copy.

The scope is the skill and not the tree, and the row now says so. `grep -rn judgment` also matches four places outside the corpus: `.agents/drafts/precommit-gate-runbook.md`, where `judgment` is the name of a 2026-10-02 reflection reviewer and not prose; `.agents/audits/test-assertion-sweep-brief.md`; `workflow/knowledge-vault/story.md`, which the manifest does not ship; and closed `devlog/` records. None is the shipped corpus, and the first must never be respelled.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both copies spell the heading `judgement` | `grep -c "The same judgement on a prompt"` on `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md` and on the `$AGENT_HOME` copy returns 1 for each, and `grep -c "The same judgment on a prompt"` returns 0 for each | Agent [x] |
| The two copies are identical | `diff` over the pair prints nothing | Agent [x] |
| The row names the residue outside the corpus, so a later reader does not read it as an unfinished sweep | `sed -n '/One shipped skill spells one word two ways/p' devlog/roadmap.md` names the reviewer's name, the audit brief, `workflow/knowledge-vault/story.md` and the closed records | Agent [x] |
| The ledger still balances | `bash scripts/check_norm_ownership.sh --check` prints `clean across 139 row(s)` | Agent [x] |
| The umbrella is clean | `bash scripts/lint.sh` prints `Lint: clean` | Agent [x] |

## Decisions

None. The corpus spelled the word `judgement` in every other principle skill and in the two convention documents, so this unit is one file catching up rather than a spelling being chosen.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `workflow/knowledge-vault/story.md:56` writes `judgment` in prose, and the manifest does not ship that tree | scope | the same word in a third spelling, in a tree the image does not carry and in a document whose own subject is a project's vault. Respelling it here would widen the row past the skill it names, and the residue now reads as decided rather than missed | named in the row's own text, in this unit |
| `.agents/drafts/precommit-gate-runbook.md` writes `judgment` eleven times as the name of a reflection reviewer | scope | a directory name is an identifier, not prose, and a sweep that respelled it would break every citation of that reviewer's proposals | the same row text, which states that the draft's matches are a name |

## Completed

| File | Change |
|---|---|
| [`communication-principle-write-for-the-reader/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md) | the heading `**The same judgment on a prompt.**` spelled `judgement` |
| the `$AGENT_HOME` copy of the same skill | the same correction, and the pair verified identical with `diff` |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed as an outcome, with the residue outside the corpus named so a later reader does not read it as an unfinished sweep |
