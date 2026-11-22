---
date: 2026-11-22
milestone: M3.3.7 - The principle corpus admission
type: Documentation
status: Closed
---

# Handover - align-the-mental-model split between its two claimants

## Objective

Settle whether `communication-principle-align-the-mental-model` states a judgement of its own, by scanning its cases against `define-terminology-before-use` and `maximize-conceptual-leverage`, and place the survivors.

## Scope

The three skills, the carriers that name the split one, and the roadmap row. Not in scope: the `thing` sweep, the pointer-trigger wording, and the naming-rule gate, each of which holds its own row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The many-meanings rows are in `define`'s table | the table reads "one word carrying two meanings" and "a word whose meaning the reader supplies" | Agent [x] |
| The one-word rows and the metaphor rows are in `maximize`'s table | the table reads all four, verbatim | Agent [x] |
| The skill is gone | `test ! -e .../communication-principle-align-the-mental-model` | Agent [x] |
| No live carrier names it | `grep -rn align-the-mental-model` over `src/`, `.agents/`, `workflow/`, `docs/`, `AGENTS.md`, the roadmap returns nothing | Agent [x] |
| The two claimants are neighbours | `node scripts/principle_inventory.mjs` shows the edge both ways | Agent [x] |
| The corpus carries one fewer principle | `bash scripts/check_principle_frontmatter.sh \| tail -1` reads 27 | Agent [x] |
| Every decision recorded is realized in the files | the two tables against `## Decisions` | Agent [x] |
| The residue is merged, not lost | `define` carries the concept/term pairing, the two failure bullets and the drift `Why.` | Agent [x] |
| The boundary line is no longer false | `define`'s "What it does not cover" no longer says naming is out of scope | Agent [x] |
| Gates hold | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The mapping is stated once, as one-to-one between a concept and a term. | One term for two concepts and two terms for one concept are one error, so one rule covers both directions. The terminology field's own pair carries the rigor without formal notation, which an advisor writing about definitions would never use. | `define` |
| Disposition is remove, with the rows distributed to the two claimants. | Every row and both of the skill's own tests are claimed by a neighbour: the many-meanings rows by `define-terminology-before-use`, the one-word-for-one-thing rows and the metaphor row by `maximize-conceptual-leverage`. Two sources for one judgement is the fault `principle-single-source-of-truth` names. | This record; the two skills |

## Decisions pending

| Decision | Options | Where it will land |
|---|---|---|
| Whether the name survives as a router. | Resolved at the scope gate: removed outright, because nothing routes by that name. | This record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Three live carriers name the skill: the shipped `AGENTS.md` principle list, `scope.md`'s phrasing list, and `principle-vacuous`'s boundary. | Propagation | A removal that misses one leaves a dangling pointer. | This iteration |
| `maximize-conceptual-leverage` and `define-terminology-before-use` are not neighbours today. | Corpus | They inherit a shared case from the split and would answer it without an edge. | This iteration |
| The moved rows and two of `define`'s own sentences carry `thing`, which the terminology registry bans. | Content | The ban is stated and the rows predate it; the wording was kept as written, per the operator's instruction. | The roadmap row for the `thing` sweep |

## Completed

| File | One-line change summary |
|---|---|
| [`communication-principle-define-terminology-before-use/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-define-terminology-before-use/SKILL.md) | Gains the two many-meanings rows, a table for them, and the edge to `maximize`. |
| [`communication-principle-maximize-conceptual-leverage/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md) | Gains four rows verbatim and the edge to `define`. |
| `communication-principle-align-the-mental-model/SKILL.md` | Removed. |
| [`principle-vacuous/SKILL.md`](../../../src/reasoning/agent-runtime/pi/config/agent/skills/principle-vacuous/SKILL.md) | The boundary line points at `define`. |
| [`AGENTS.md`](../../../src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | The principles list drops the entry. |
| [`scope.md`](../../../workflow/coding-agent/prompts/scope.md) | The phrasing list drops it. |
| [`devlog/roadmap.md`](../../roadmap.md) | The iteration row closes. |
| `define-terminology-before-use` boundary | Its "does not cover" sentence that called naming out of scope is replaced, since the skill now decides the term. |
| [`20261122-10-docs-align_split.md`](20261122-10-docs-align_split.md) | This record. |
