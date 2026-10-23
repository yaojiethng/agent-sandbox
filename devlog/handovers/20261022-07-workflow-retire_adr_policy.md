---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire adr_policy

## Objective

Move the ADR rules into the `decision-records` convention-skill and the `document` procedure, then delete `docs/policies/adr_policy.md` and retarget every pointer to it.

## Scope

The third policy slice under `Retire the policy form`, after `handover_policy` and `roadmap_policy`, and the next in the design record's order after the `testing_policy` slice.

In scope: `docs/policies/adr_policy.md` (deleted after its content moves); `.agents/skills/decision-records/` (the seeded stub becomes the convention home, with an asset and two patterns); `workflow/coding-agent/prompts/document.md` (the operation and the convention entry); the pointers in `AGENTS.md`, `iter.md`, `plan.md`, `bootstrap.md`, `documentation_taxonomy.md`, `discussion_policy.md`, `documentation_policy.md` and `domain-model/ADR-FORMAT.md`; the generated norm ledger; the roadmap rows.

Out of scope: the `discussion_policy` slice, next in the design record's order; the historical mentions in `docs/adr/` and `devlog/` records, which state what was true when written.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The policy file is deleted | `test ! -e docs/policies/adr_policy.md` | Agent [x] |
| No markdown link targets it | `grep -rn '](.*adr_policy\.md)' docs workflow src .agents AGENTS.md` prints nothing | Agent [x] |
| No live surface outside `docs/adr/` and `devlog/` names it | the same grep without `](`, excluding `docs/adr/` | Agent [x] |
| The skill holds the record set, the spawn judgement, the entry rules, the statuses, the archive and the naming | `grep -n` each heading | Agent [x] |
| The template ships as an asset | `grep -c '^\*\*Current:\*\*' .agents/skills/decision-records/assets/adr.md` returns 1 | Agent [x] |
| The two patterns exist and are indexed from the skill | `test -s` both; `grep -n` both index rows | Agent [x] |
| `document` names the convention and states the operation | `grep -n 'decision-records'` and the operation phrase | Agent [x] |
| `bootstrap.md` no longer lists it | `grep -c 'adr_policy' workflow/coding-agent/prompts/bootstrap.md` returns 0 | Agent [x] |
| The taxonomy points at the skill | `grep -c 'decision-records' docs/reference/documentation_taxonomy.md` returns 3 | Agent [x] |
| The norm ledger is consistent | `bash scripts/check_norm_ownership.sh --check` clean | Agent [x] |
| Lint and suite clean | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] |
| The handover gate is clean | `bash scripts/check_handover_format.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The settled row's four mechanism sections resolve to a pointer in `document` plus the skill, not to prose in `document` | `document` forbids being a rule's source of truth, and the four sections describe the record rather than the session. The design record permits a straddling section to be resolved in the slice that moves it | this record |
| The template ships as an asset and the two procedures as patterns | The shape the `testing` skill settled: a fill-in form is copied, a mechanical procedure is opened when its situation arrives, and the `SKILL.md` stays the index | this record |
| `domain-model/ADR-FORMAT.md` keeps its working summary and retargets only its authority line | That skill ships beyond this project, so it keeps a readable summary while naming the one authority | this record |
| The historical mentions in `docs/adr/` and `devlog/` stay | They state what was true when written, and the project does not rewrite a rationale | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `document.md` Non-goals claimed a rule governing documents lives only in a policy document under `docs/`, which the new skill home makes false | defect | the prompt asserts a home the change removed, so a reader looks in the wrong place | fixed in this unit |
| The skill's `description` carried a colon, which YAML read as a nested mapping and the frontmatter gate rejected | defect | the skill's frontmatter does not parse, so the skill never loads | fixed in this unit |
| Links from `docs/` into `.agents/` fail the reach gate, because a shipped document's targets must exist in the image | defect | a shipped document points at a target absent from the image, and the reach gate fails | fixed in this unit; the shipped documents use the code-span form |

## Completed

| File | Change |
|---|---|
| `docs/policies/adr_policy.md` | deleted |
| `.agents/skills/decision-records/SKILL.md` | the stub became the convention home |
| `.agents/skills/decision-records/assets/adr.md` | new, the template |
| `.agents/skills/decision-records/patterns/distil.md` | new, the distillation procedure |
| `.agents/skills/decision-records/patterns/evolve.md` | new, the editing procedure |
| [`workflow/coding-agent/prompts/document.md`](../../workflow/coding-agent/prompts/document.md) | the convention entry, the operation, two retargets, the corrected Non-goal |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | one retarget |
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md) | one retarget |
| [`workflow/coding-agent/prompts/bootstrap.md`](../../workflow/coding-agent/prompts/bootstrap.md) | the policy set loses the file, two lists |
| [`AGENTS.md`](../../AGENTS.md) | the Iteration Start table row retargets and its heading widens |
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | three pointers retarget, the promotion sentence widens |
| [`docs/policies/discussion_policy.md`](../../docs/policies/discussion_policy.md) | two retargets |
| [`docs/policies/documentation_policy.md`](../../docs/policies/documentation_policy.md) | two retargets |
| [`src/reasoning/agent/skills/domain-model/ADR-FORMAT.md`](../../src/reasoning/agent/skills/domain-model/ADR-FORMAT.md) | the authority line retargets, the summary stays |
| [`scripts/lint/norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | regenerated and the two new rows marked |
| [`devlog/roadmap.md`](../roadmap.md) | the slice closed, the parent row text updated |
