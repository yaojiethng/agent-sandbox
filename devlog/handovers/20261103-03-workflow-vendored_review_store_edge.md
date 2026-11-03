---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the vendored review copy gets its store edge

## Objective

Give the vendored `thermo-nuclear-code-quality-review` runbook a store edge that resolves against the tree, and make its adaptation record true: a maintainer running a bump reads the edge and knows what the local copy kept, changed and left out, without diffing by hand.

## Scope

The roadmap row **The code-review runbook's vendored copy has no store edge** under M3.3.3, raised while landing `20261103-02`.

Established before the first edit, against the upstream rather than the provenance line: `cursor/plugins` at `6e3d2ea56d7d446b955eaae6ac4c8eef8bf504cf` is reachable, the file at `cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md` is the source, and the local copy differs from it in 35 diff lines -- the added frontmatter and source line, and five paragraphs joined onto one physical line each. The body is otherwise identical.

Out of scope, each with its reason: the runbook's review text stays as upstream wrote it, because this row records the adaptation and does not make one; and the review shell's reading path closed with `20261103-02`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `.agents/registry/sources/cursor-plugins.json` holds one edge whose `local_path` is the runbook directory and whose `parent` is the `code-review` skill | `node scripts/skill_store.mjs check` / `bash scripts/check_skill_sources.sh` | Agent [x] |
| The edge's `record` states kept, rewritten, added and dropped, and each claim is checkable against `6e3d2ea5` | diffed the upstream blob against the local file: 35 lines, all of them frontmatter, the deleted source line and five joins | Agent [x] |
| The vendored file carries no claim the upstream contradicts | `grep -n "Source:"` over the file misses; the claim now lives in the edge's `record` | Agent [x] |
| No claim in the tree asserts an artifact carries a source line | `grep -rl "> Source:" --include='*.md' src workflow .agents` returns nothing; the gate fails a file that reintroduces one | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The edge is written from the upstream revision, not from the provenance line | The line's `_REVIEWER` claim is false for that path, so the line cannot be the fact the edge rests on | this record, the edge's `record.source` |
| The policy needed no amendment: the store was always the only home, and the two provenance lines were drift | `docs/development/source_tracking.md` and the ADR's R2 both already say no artifact carries a provenance line, so the honest change was to delete the lines and close the gap that let them stand | `source_tracking.md`, `skill_source_catalog.md` R2, unchanged |
| The gap was enforcement, so the store's gate gains the finding | Two files contradicted the policy and nothing reported it; a rule with no check was the pipeline defect the operator asked to fix rather than carve out | `scripts/skill_store.mjs` `validateProvenanceLine`, `tests/test_skill_sources.sh` |
| Both provenance lines go, not just this runbook's | `writing-for-agents` carried the same line under the same policy; leaving one is the inconsistency the operator named | this iteration |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The provenance line said a paragraph naming this repository's `_REVIEWER` role was removed, and no such paragraph exists: `git log -S _REVIEWER` over that path returns nothing, and the `6e3d2ea5` body matches the local body verbatim | defect | a provenance claim that upstream contradicts is worse than none: it sends a maintainer looking for a change nobody made | this iteration: the line is gone and the edge's `record` states the real diff |
| Both vendored files in the tree (`writing-for-agents`, this runbook) carried a `> Source:` line, while the policy in `source_tracking.md` and the ADR's R2 both say no artifact carries one | record | a policy two live files contradict, with no gate to report it, is the defect the operator asked to fix in the pipeline rather than exempt | this iteration: both lines deleted, the gate now reports one |
| Upstream also ships `cursor-team-kit/agents/thermo-nuclear-code-quality-review.md`, an agent definition the local copy does not take | measured | the edge describes a skill only, so a reader is not sent looking for an agent that was never vendored | the edge's `record.dropped` |

## Completed

| File | Change |
|---|---|
| `.agents/registry/sources/cursor-plugins.json` | new source: MIT, Cursor, one runbook edge at `6e3d2ea5` with its adaptation record |
| `workflow/coding-agent/skills/code-review/runbooks/thermo-nuclear-code-quality-review/SKILL.md` | the false provenance line removed; the review text untouched |
| `src/reasoning/agent/skills/writing-for-agents/SKILL.md` | its provenance line removed under the same policy |
| `.agents/skills/skill-fork/SKILL.md` | the store is the only record, the gate holds it, and the reason is the drift that occurred |
| `scripts/skill_store.mjs` | `validateProvenanceLine`: a source line in an artifact is a finding |
| `tests/test_skill_sources.sh` | one case for it; 11 pass |
|---|---|
