---
date: 2026-11-20
milestone: M3.3.7 - The principle corpus admission
type: Workflow
status: Closed
---

# Handover - The prose skill reaches the writing it governs

## Objective

Make `writing-for-agents` fire on the writing it already claims, and put one read-back in the path so its rules run before the operator reads the text.

## Scope

Operator-raised, from a count of how often the two prose principles were named across the session records: 148 matches in 11,102 operator turns. The count could not serve as a correction rate, because 81 of them are the operator reasoning about the corpus and 24 are slash loads, and the two cards' wording showed no regression across the change that was suspected. What the count did show is that nothing sits between an agent's draft and the operator's read, so the correction always arrives as an interruption.

Two trigger defects follow, one in the vendored skill and one in `AGENTS.md`:

- the description fires on skills and `AGENTS.md` while the body claims any document an agent consumes;
- `AGENTS.md` asks for format compliance and names nothing that reads the text back.

`writing-for-agents` is a fork of `mattpocock-skills`, so both are local divergences recorded against the store edge. The pinned upstream carries the same narrowing and none of the new paragraph, so a bump re-applies them.

The two prose principles' own text is out of scope: the same measurement cleared it, and `communication-principle-rewrite-syntax-never-semantics` forbids a rewrite on a hunch.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The description names the writing it governs | `grep -c 'a PR description, a commit message'` in the skill is 1 | Agent [x] |
| The body states the PR and commit case once, and excludes Diataxis with its owner named | `grep -c '## What it governs'` is 1; `grep -c 'do not paste swarm logs'` is 1; `grep -c 'organize-by-diataxis'` is 1 | Agent [x] |
| The fork records both changes with the reason a bump needs them | `grep -c 'upstream carries the same narrowing'` is 1 and `grep -c 'a briefing rather than a log dump'` is 1 in `mattpocock-skills.json` | Agent [x] |
| `AGENTS.md` puts one read-back before the operator reads any output | `grep -c 'read the text once against'` is 1; `grep -c '`writing-for-agents`'` is 1 | Agent [x] |
| The upstream narrowing is confirmed rather than assumed | the file at both pins `a496f55` and `5beb35b` carries the same description and the same opening sentence | Agent [x] |
| Every decision this iteration recorded is realized in the files | read the Decisions table against the diff at pre-close | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The fix is to the trigger, and the body's scope sentence stands | The body already claims any document an agent consumes, so the description was the defect; rewriting the body would restate a scope it states | this handover |
| The read-back names `writing-for-agents` rather than the two principles | Operator ruling: that skill governs all writing, and its pruning and leading-word sections already cite `communication-principle-cut-metadiscourse`; one home for the prose rule | this handover |
| The prose skill and the prose clause ship as their own iteration | Operator direction: the prose skill and one home per fact are different subjects, and a commit carrying both can be reviewed as neither | this handover |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None. | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The vendored description fires on skills and `AGENTS.md` while its body claims any document an agent consumes. | Evidence | The file is reached less often than its own scope asks, so its rules fire only when a reader already knows to open it. Raised by the operator. | Description sharpened to the body's scope, and the paragraph written; the fork record carries both. |
| Both upstream pins carry the same description and opening, and neither mentions a readme, an RFC, a PR description or a commit message. | Record | The narrowing is inherited rather than introduced here, so this is a divergence from upstream; the fork record states it so a bump re-applies it. | `mattpocock-skills.json` `rewritten` and `added`. |
| A pointer narrower than its target fails silently, because the material is reached only when the pointer fires. | Record | Second instance this session: `cut-metadiscourse` has carried three names, so a reader searching a retired name finds nothing. | One class to check at any review of a description or a routing line. |
| The invocation count cannot be read as a correction rate. | Record | 148 matches over 11,102 operator turns, of which 81 are the operator reasoning about the corpus and 24 are slash loads; the drop the operator felt has no series behind it, and neither card's wording regressed across the change that was suspected. | The measurement's instrument is session-local and gone; the class it names is that a name count measures naming, not correction. |

## Completed

| File | Change |
|---|---|
| [`writing-for-agents/SKILL.md`](../../../src/reasoning/agent/skills/writing-for-agents/SKILL.md) | The description names docs, RFCs, readmes, PR descriptions, commit messages, skills and `AGENTS.md`; `## What it governs` states the PR and commit case and excludes Diataxis by name. |
| [`mattpocock-skills.json`](../../../.agents/registry/sources/mattpocock-skills.json) | `rewritten` and `added` record both divergences and why a bump must re-apply them. |
| [`AGENTS.md`](../../AGENTS.md) | Every output takes one read-back against `writing-for-agents` before the operator reads it. |
| [`devlog/roadmap.md`](../../roadmap.md) | The row closes with its outcome and this handover. |
