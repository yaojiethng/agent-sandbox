---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - Bundle the Operations Policy and Resolve Prompt References

## Objective

Ship `docs/operations/` into every provider image at `/opt/sandbox/docs/operations/`, and give every prompt reference one form that resolves at the path the prompt runs from.

## Scope

This iteration works the M3.3.1 rows `Establish the dependency convention for seeded documents` and `A shipped prompt reaches a repository path by a form that resolves`, consolidated into one unit at the operator's direction of 2026-10-05: the form and its application are one move, because the form depends on what ships. Continues handover `20261004-12`, which measured the references.

The operator's direction: bundle `docs/operations/` now, and close the sub-milestone with it unbundled, the policy content shuffled to sit with the skill that determines its workflow. The interim bundle is a build artifact of the repository copy, and a container copy is never hand-edited.

The form this iteration settles, subject to the gate: a prompt references a shipped document by its absolute path in the image, which is the same text from both instruction roots, so one rule covers both and no depth arithmetic is involved. Labels and fragments survive the retarget.

The link check changes with it. `scripts/lint/record-links.mjs` resolves every target against the repository tree, which is the wrong space for a file that ships: for a shipped file it resolves the target against the path the file has in the image, and maps the image prefix back to the repository source to test existence. The map is small and declared here; generalizing it is a T1 row raised this iteration.

Out of scope, with its reason:

- Moving the policy content under its skill is the second half of the operator's goal and needs its own unit: the shuffle changes the seeding set, the gates and `AGENTS.md`. It is written back as the end-of-sub-milestone goal row.
- Deriving the path map once instead of declaring it per gate is a T1 row raised this iteration, since it unifies checks rather than settling an instruction-surface convention.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `docs/operations/` reaches all three provider images at `/opt/sandbox/docs/operations/`, with the same file set as the repository directory | the three `COPY` lines; the two basename sets compared | Agent [x] -- `COPY docs/operations/ /opt/sandbox/docs/operations/` in the pi, hermes and opencode dockerfiles, beside the two subtrees already bundled |
| Every reference in an instruction root resolves at the path the prompt runs from; the count of references that resolve to no path in the image is 0 | a resolution check over both roots, printing the count | Agent [x] -- 71 references retargeted, 21 converted to names, 2 sibling links corrected; `check_markdown.sh` reports no link finding, and its coverage line prints the file count |
| The Markdown gate resolves a shipped file's targets in the image's path space: every reference in `workflow/coding-agent/prompts/`, `src/reasoning/agent/prompts/` and `src/reasoning/agent/skills/` passes `bash scripts/lint.sh`, with no new ignore list and no exemption tree | `bash scripts/lint.sh` over the retargeted roots | Agent [x] -- lint clean across 7 gates; `.markdownlint-cli2.mjs` unchanged, so the record-tree list gains nothing |
| `prompt-authoring-conventions.md` states the form and the per-root target rule, and its justification that the record-links gate does not scan `src/` -- which is false -- is corrected | read the section; the false sentence returns no match | Agent [x] -- the section is now `## A reference resolves where the prompt runs` |
| The five `CONTEXT.md` files list `/opt/sandbox/docs/operations/` in the always-reachable set, and the instruction-context gate passes | `bash scripts/check_instruction_context.sh` | Agent [x] -- the gate reports clean across 5 files, which is its own check that the always rows agree |
| The end-of-sub-milestone goal is written back: an M3.3.1 row stating that `docs/operations/` is no longer bundled at sub-milestone close, with the check for that end state, and the milestone acceptance block carries it | `grep -n` the row and the criterion | Agent [x] -- roadmap row and the amended criterion |
| The map generalization is written back as an M3.3.1 row naming both consumers, `scripts/check_instruction_context.sh` and `scripts/lint/record-links.mjs` | `grep -n` the row | Agent [x] |
| M3.3.1's milestone acceptance criterion is amended, since it forbids what this direction requires | read `devlog/roadmap.md`; operator acceptance | Operator [x] -- released at the scope gate |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/development/prompt-authoring-conventions.md`](../docs/development/prompt-authoring-conventions.md) | holds the rule, its scope sentence and a false justification |
| `src/reasoning/providers/pi/provider.dockerfile` | carries two of the bundled docs subtrees |
| `src/reasoning/providers/hermes/provider.dockerfile` | same |
| `src/reasoning/providers/opencode/provider.dockerfile` | same |
| [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) | declares the record trees, whose exemption this change does not extend |
| [`scripts/lint/record-links.mjs`](../../scripts/lint/record-links.mjs) | resolves every link against the repository tree; a shipped file needs the image's path space |
| [`workflow/coding-agent/prompts/`](../../workflow/coding-agent/prompts/) | the shipped root: 13 files, 86 references |
| [`src/reasoning/agent/prompts/`](../../src/reasoning/agent/prompts/) | the seeded root: `defer.md` and `propagation-check.md` |
| [`src/reasoning/agent/prompts/CONTEXT.md`](../../src/reasoning/agent/prompts/CONTEXT.md) | the reachable set gains the bundle |
| [`docs/operations/`](../docs/operations/) | the bundle's source, and the milestone goal's subject |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | the amended criterion and the goal row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `docs/operations/` ships at `/opt/sandbox/docs/operations/`, beside the two documentation subtrees already bundled | the pair of subtrees there shows the bundle root the image uses; a second root at `/opt/docs/` would have matched no existing layout | the three provider dockerfiles |
| A reference from an instruction root takes the absolute path the document has in the image | the same text resolves from every instruction root, so one rule covers the seeded and shipped roots and no depth arithmetic enters the prompt | `docs/development/prompt-authoring-conventions.md` `## A reference resolves where the prompt runs` |
| A document that does not ship is named, not linked | a link to it passes no reader in the container, and the link check now reports it as a finding | the same section |
| The link check resolves links in the instruction roots in the image's path space, and leaves every other file in the repository's | the instruction roots run in the container; a bundled document is read by a repository reader first, and its links to an ADR or a roadmap would otherwise demand that every record ship too | `scripts/lint/record-links.mjs` |
| `docs/operations/` is unbundled at sub-milestone close, its content moved to sit with the skill that determines its workflow | the interim bundle exists so a reference resolves today; the end state is that no instruction root references a path outside its own tree | the M3.3.1 goal row, and the milestone acceptance block |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The rule's justification is false. `prompt-authoring-conventions.md` `## A prompt names a record, it does not link it` states "The record-links gate does not scan `src/`". `.markdownlint-cli2.mjs` ignores only `**/node_modules/**`, and the Markdown gate lints the tree, so `src/**/*.md` is scanned; the two seeded links pass only because they resolve inside the repository. | contradiction | current iteration |
| `docs/operations/` is absent from all three provider images while shipped prompts reference its policies 86 times. The two docs subtrees beside it are bundled, so the omission reads as accidental rather than chosen. | bug | current iteration |
| M3.3.1's milestone acceptance criterion, written at milestone start, requires that a prompt or skill carries no link into a tree absent from `AGENT_HOME`. The bundling direction supersedes it, since `docs/operations/` is then present in the image. | contradiction | current iteration |
| A roadmap row filed under a track instead of the active sub-milestone. The retired-transport sweep went to T10 on subject matter, and the path-map row to T1. `roadmap_policy.md` `### Filing rules` `**Roadmap task placement**` states the default: a row lands in the current sub-milestone's task list unless the operator directs otherwise. The operator redirected both. | steering | current iteration |
| The link check resolves every target against the repository tree, so a file that ships is checked in a path space it never runs in. That is why the 86 references passed the gate while resolving to nothing in the container. Operator direction: a file meant to ship resolves against the in-container path. | bug | current iteration |
| The measurement at scope time was short. It counted repository-relative references under one prompt root: 86 over 13 files. Resolution at implementation found 94 references over 15 files -- 71 repository-relative references into `docs/operations/`, 21 references to a document that ships nowhere, and 2 links between instruction roots that resolve as siblings in the image. The first lint run after the retarget reported 71 findings, and the run after the check change reported 23. | scope change | current iteration |
| 21 references now name a document that ships nowhere: `prompt-authoring-conventions.md`, `testing_policy.md`, two ADRs, `documentation-pass.md`, two drafts, `devlog/roadmap.md`, `devlog/roadmap_future.md` and the project `AGENTS.md`. Naming is the form the rule gives them, and each is a reference to a tree the end state excludes. Whether the rule behind each is restated where the agent reads, or the reference is dropped, is the shuffle's work. | bug | roadmap |
| The hermes and opencode images carry the same three prompt and skill roots as pi, so the bundle line and the reference form apply to all three. Anything the pi-only rows assume about the shipped set holds for the other two. | contradiction | next iteration |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/provider.dockerfile` | bundles `docs/operations/` at `/opt/sandbox/docs/operations/` |
| `src/reasoning/providers/hermes/provider.dockerfile` | same |
| `src/reasoning/providers/opencode/provider.dockerfile` | same |
| `scripts/lint/record-links.mjs` | resolves a link in an instruction root in the image's path space, back-mapping the image path to the repository source that populates it |
| `docs/development/prompt-authoring-conventions.md` | replaces `## A prompt names a record, it does not link it` with `## A reference resolves where the prompt runs`, and drops the false claim that the link check skips `src/` |
| `workflow/coding-agent/prompts/document.md` | 6 references to `prompt-authoring-conventions.md`, and one each to the project `AGENTS.md`, the provider-layer `AGENTS.md` and `documentation-pass.md`, become names; their `docs/operations/` links take the image path |
| `workflow/coding-agent/prompts/iter.md` | the project `AGENTS.md`, `testing_policy.md` and `coding_agent_loop_workflow.md` become names; the policy links take the image path |
| `workflow/coding-agent/prompts/backlog-triage.md` | the two drafts and the two roadmap records become names; the policy links take the image path |
| `workflow/coding-agent/prompts/plan.md` | the `grill-me` skill and `propagation-check.md` links resolve as image siblings; the policy links take the image path |
| `workflow/coding-agent/prompts/record-correction.md` | `closed_record_corrections.md` becomes a name; the policy links take the image path |
| `workflow/coding-agent/prompts/milestone-close.md` | policy links take the image path |
| `workflow/coding-agent/prompts/milestone-start.md` | same |
| `workflow/coding-agent/prompts/sidequest.md` | same |
| `workflow/coding-agent/prompts/wrapup.md` | same |
| `src/reasoning/agent/prompts/defer.md` | the `iteration_policy.md` link takes the image path |
| `src/reasoning/agent/prompts/propagation-check.md` | the project `AGENTS.md` becomes a name |
| `src/reasoning/agent/prompts/CONTEXT.md` | the reachable set gains the operations bundle; the not-reachable bullets follow |
| `src/reasoning/agent/skills/CONTEXT.md` | same |
| `src/reasoning/providers/pi/config/agent/prompts/CONTEXT.md` | same |
| `src/reasoning/providers/pi/config/agent/skills/CONTEXT.md` | same |
| `workflow/coding-agent/skills/CONTEXT.md` | same |
| `tests/test_record_links_rule.sh` | 5 cases: an image path that resolves, an image path nothing populates, the repository-relative form from a shipped file, a bundled document's own tree, a link between instruction roots |
| `devlog/roadmap.md` | two M3.3.1 rows closed, the goal row and the map row open, and the milestone acceptance block amended |
