---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Two AGENTS.md Layers: Scope and References

## Objective

Give each `AGENTS.md` layer a statement of its own scope and a what-is-where list for that scope, and make every reference in the provider layer resolve where that layer runs.

## Scope

Two roadmap rows under M3.3.1 are candidates, and the operator ruled on their scope:

- **The provider AGENTS.md deep-links one project's `docs/` from a file titled global** -- the subject. The row asks two questions per mention: is the mention in the right place, and is it necessary.
- **The project AGENTS.md names one loop prompt out of eight** -- ruled out of this iteration at the scope gate. The operator deferred the prompt-set pointer to a later iteration, so the row stays open and the project layer's scope section carries no entry for the loop prompts.

Two files carry the work: the provider layer at [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md), whose live copy is `~/.pi/agent/AGENTS.md`, and the project layer at [`AGENTS.md`](../../AGENTS.md), whose live copy is `sandbox/AGENTS.md`.

Operator steering, stated at the scope gate: each layer's scope differs, and each layer should state its own. The provider layer states its scope; the project layer states the additional scope it adds.

Ruled out of scope: the retirement of the interim `docs/operations/` bundle and the shuffle of its content to sit with the skill that determines its workflow -- the M3.3.1 goal row. That work changes the paths this iteration would state, so it runs after this one.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The provider layer states its own scope: what the layer covers, where it runs, and what it reaches | read the section; the runtime paths it names match the image | Agent [x] -- a `## Scope` table of 11 paths; the gate now fails a `## Scope` table that names anything the folder files do not declare |
| The project layer states the additional scope it adds, without restating the provider layer | read the section against the provider layer; no path appears in both as a new subject | Agent [x] -- one row, the working tree; the gate fails a double claim |
| Every reference in the provider layer resolves at the path that layer runs from, with 0 that resolve to no path | the link check over the file, in the image's path space | Agent [x] -- the one link that stays takes the image path; the old form is a fixture case that fails |
| The classification of each of the five references the row names is recorded: in place or moved, necessary or dropped, with its reason | read the classification; five entries | Agent [x] -- four leave with the bullet they sit in, one stays as the bundled image path; the fold rule moves to `git_policy.md` `## Amending` |
| The live copy `~/.pi/agent/AGENTS.md` carries the same text as the repository source | `diff` the two files | Agent [x] -- identical |
| The link check resolves a file in the provider layer's config root in the image's path space, so the old form fails it | `bash scripts/check_markdown.sh`; a fixture case in `tests/test_record_links_rule.sh` | Agent [x] -- the root is a registered instruction root, with the fixtures named in the criterion |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands | Agent [x] -- lint clean across 7 gates; 1078 tests, 0 failed |
| The what-is-where shape is accepted, and each layer's section reads as its own scope | operator acceptance at the release gate | Operator [x] -- released at the scope gate: generic provider layer, container-bundled references stay links, grain (b) |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the provider layer: its scope statement, and five references that resolve to nothing where it runs |
| [`AGENTS.md`](../../AGENTS.md) | the project layer: the additional scope, and the prompt-set pointer row 189 carries |
| `~/.pi/agent/AGENTS.md` | the live copy of the provider layer, which repository discipline requires to change with the source |
| [`scripts/lint/record-links.mjs`](../../scripts/lint/record-links.mjs) | holds the image path map; the provider layer's config root is not yet an instruction root to it |
| [`tests/test_record_links_rule.sh`](../../tests/test_record_links_rule.sh) | the fixture cases for the resolution rule |
| [`docs/operations/git_policy.md`](../docs/operations/git_policy.md) | `## Amending`, which gains the one sentence that gives the closed-iteration fold its policy home |
| [`workflow/coding-agent/prompts/record-correction.md`](../../workflow/coding-agent/prompts/record-correction.md) | states that the ADR owns the policy; after this iteration the policy is `git_policy.md` and `documentation_policy.md`, and the prompt ships |
| [`devlog/roadmap.md`](../devlog/roadmap.md) | the row, and the write-back |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The provider layer stays generic: it carries no agent-sandbox policy statement. A reference to a document the container bundles stays a link, at the image path. | the layer is titled global and applies regardless of the project, so a project's commit policy does not belong in it. A bundled document is part of the container the layer runs in, so a link to it resolves for any install of that image, which is what separates it from a repository path. Operator ruling. | the provider layer's scope section |
| Each layer's scope list is a view over the `CONTEXT.md` always rows, held by `check_instruction_context.sh` | the folder files already declare the always-reachable set, and the gate already compares it; a second hand-maintained list would drift from it. Operator ruling. | the two scope sections, and the gate |
| The closed-iteration fold rule's home is `docs/operations/git_policy.md` `## Amending`, and the ADR `closed_record_corrections.md` stands as the decision record behind it | every policy statement then resolves for a reader in the repository and in the container, while the ADR stays citable for its decisions. Operator ruling. | `git_policy.md` `## Amending`; `record-correction.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The live copy `~/.pi/agent/AGENTS.md` is byte-identical to the repository source, and repository discipline requires the two to change together. The live copy sits outside `sandbox/`, which the provider layer itself tells the agent not to modify. This iteration writes both and records the exception. | steering | current iteration | Triaged to: the provider layer's key behavioral rules, which now name `$AGENT_HOME/` as the one exception |
| The five references in the provider layer pass the link check today, and the check is the reason: it resolves files in `src/reasoning/agent/prompts/`, `src/reasoning/agent/skills/` and `workflow/coding-agent/prompts/` in the image's path space, and the provider layer's config root is not among them. Six levels up from that root reaches the repository root, so the dead form reads as a valid repository link. Adding the config root to the check is part of this iteration, or the defect survives the fix. | bug | current iteration | Triaged to: `scripts/lint/record-links.mjs`, `instructionRoots` |
| The image path map now has a fourth pair: this iteration added the provider config root to `scripts/lint/record-links.mjs`, on top of the three instruction roots and the two docs subtrees already there. The open M3.3.1 row that derives the map once gains a datapoint: every consumer hand-copies it. | scope change | roadmap | Triaged to: `devlog/roadmap.md`, the map-generalization row |
| A file entered scope that no criterion named: `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` links a `devlog/discussions/` report eight levels up, and the new instruction root made the link check report it. The link became a name, per the same rule as the other references. | scope change | current iteration | Triaged to: the file, whose link became a name |
| `workflow/coding-agent/prompts/record-correction.md` stated that the ADR owns the policy. Moving the fold rule to `git_policy.md` made that sentence wrong, so the prompt now names `git_policy.md` and `documentation_policy.md` at the image path. | contradiction | current iteration | Triaged to: `record-correction.md` |
| The iteration closed without the release gate. The scope gate released the scope and the `git_policy.md` sentence; the Step 7 pre-close summary was never presented, so the operator had no release point before the delivery commit landed. The two-gate model holds; nothing enforced its second stop. | obstacle | next iteration | Triaged to: `devlog/AGENT_FEEDBACK.md`, the `[O] 2026-09-29` gate-discipline entry |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | gains `## Scope`, covering 11 container paths; the bullet mixing project commit policy, the fold rule and a dead ADR link leaves; `$AGENT_HOME/` becomes the one exception to the no-writes-outside-`sandbox/` rule; the one reference that stays takes the image path; the new-document sentence leaves, since the project layer's trigger table owns it |
| `~/.pi/agent/AGENTS.md` | the live copy, written with the source; byte-identical |
| `AGENTS.md` | gains `## Scope`, one row for the working tree, the additional scope the layer adds |
| `docs/operations/git_policy.md` | `## Amending` gains the closed-iteration fold rule, with the record forms and the principle linked in policy |
| `workflow/coding-agent/prompts/record-correction.md` | names `git_policy.md` `## Amending` and `documentation_policy.md` as the rule's owners, at the image path |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` | a `devlog/discussions/` link becomes a name, since the file ships and the report does not |
| `scripts/check_instruction_context.sh` | checks each layer's `## Scope` table against the always-reachable set: a row outside it, an uncovered row, a doubly covered row and a missing heading all fail |
| `scripts/lint/record-links.mjs` | the provider config root is a registered instruction root, mapped to `$AGENT_HOME/agent/` |
| `tests/test_instruction_context.sh` | 4 cases for the layer tables; the conforming fixture gains the two layer files |
| `tests/test_record_links_rule.sh` | a case at the provider config root: the repository form fails, the image path passes |
| `docs/development/instruction-context-template.md` | a `## The layers` section, and the gate's list gains the layer checks |
| `devlog/roadmap.md` | the row resolved, and a datapoint appended to the map-generalization row |
