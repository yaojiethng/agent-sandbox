---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Documentation
status: Closed
---

# Handover - Split the framing ADR

## Objective

Split `docs/adr/policy_declarative_framing.md` by subject, so its one live principle is filed under its own name, its second live principle is filed where it is cited, and its retired entries stop sitting in a current ADR.

## Scope

`M3.3.2 - Retire the policy form`. Not a roadmap row: it is the record correction that `Retire iteration_policy` (handover `20261022-12`) raised and the operator directed, and the write-back outcome is recorded here as the protocol's nullable-value invariant allows.

The file held four entries on two subjects. Read against the archive and the citations:

| Entry | Disposition |
|---|---|
| 2026-10-17 -- a norm is a rule when an observer detects its violation | the live principle; becomes `docs/adr/norm_kinds.md` |
| 2026-09-30 -- rules are authoritative only where a policy canonically states them | already marked superseded by 10-17; stays as that entry's predecessor |
| 2026-09-30 -- discussion-family records are reference-durable | a different principle, live, filed nowhere else but citing `documentation_taxonomy.md ## Durability`; becomes `docs/adr/record_durability.md` |
| 2026-07-21 -- policies state rules declaratively | retired with the policy form, and already archived in full at `docs/adr/archive/20260721-adr-settled-policy_declarative_framing.md`; dropped from the live set |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The live principle is filed under its own name | `test -f docs/adr/norm_kinds.md` and `**Current:** 2026-10-17` | Agent [x] |
| The second live principle has its own file | `test -f docs/adr/record_durability.md` | Agent [x] |
| The retired file is gone | `test ! -e docs/adr/policy_declarative_framing.md` | Agent [x] |
| No live surface names the old file except as archived history | `grep -rn policy_declarative_framing docs scripts src workflow .agents AGENTS.md tests` prints only archive paths and records | Agent [x] |
| The ledger clause names the live sources | `grep 'skills/docs/SKILL.md' docs/adr/norm_kinds.md` | Agent [x] |
| The taxonomy no longer lists the policy type as live | `grep -c 'retired 2026-10-22' docs/reference/documentation_taxonomy.md` is 1 | Agent [x] |
| The lint config's legacy list names no deleted file | every path in `.markdownlint-cli2.mjs` exists | Agent [x] |
| Lint, ledger and suite clean | the three scripts | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The file is split rather than archived whole | Its 10-17 entry is the argument for a live rule that `agent_workflow.md ### Norm kinds` states, so archiving it would leave the definition without its argument | this record |
| The durability entry gets its own file | It is the argument for the live classification in `documentation_taxonomy.md ## Durability`, and sharing a file with the norm-kind principle is two subjects in one ADR | this record |
| The 07-21 entry is dropped from the live set rather than restated | The archive holds it in full, so the live copy was a summary of an archived record | this record |
| The protocol cites the archived framing by path | The shape it cites is that decision's, and the decision retired with the policy form. A shipped document cannot link `docs/adr/`, so it names the path in a code span and states the retirement beside it | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The ADR's title named its only retired entry, and its two live entries belonged to different principles | defect | a reader looking for the norm-kind argument found it under a dead name, and the record for discussion durability sat in a policy-framing file | split into `norm_kinds.md` and `record_durability.md` |
| `iteration_protocol.md` cited a retired decision for a live shape | defect | the one argument behind the protocol's invariant/runbook split pointed at a decision whose subject no longer exists | the citation now names the archived record and states that the shape outlived it |
| `documentation_taxonomy.md` still listed `docs/**/*_policy.md` as a live document type | defect | the taxonomy described a type with no member, one commit after the last member was deleted | the row is marked retired and names `norm_kinds.md` for what a rule is |
| Two entries in the lint config's `legacyFiles` list named deleted files, one of them deleted by this milestone | defect | an exemption list that names files nothing can lint is a list a reader cannot trust | both dropped; every remaining path resolves |

## Completed

| File | Change |
|---|---|
| `docs/adr/norm_kinds.md` | new: the 10-17 principle with its superseded predecessor, and the ledger clause retargeted to the live sources |
| `docs/adr/record_durability.md` | new: the 09-30 discussion-durability decision, verbatim |
| `docs/adr/policy_declarative_framing.md` | deleted; its 07-21 entry stays in the archive |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | two citations: the separation rule names `norm_kinds.md`, the rationale names the archived framing |
| [`docs/adr/principle_skill_shape.md`](../../docs/adr/principle_skill_shape.md) | the rule test names `norm_kinds.md` |
| [`docs/reference/iteration_protocol.md`](../../docs/reference/iteration_protocol.md) | the shape's argument names the archived framing and states the retirement |
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | the policy document row is marked retired |
| [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) | two `legacyFiles` entries for deleted files dropped |
