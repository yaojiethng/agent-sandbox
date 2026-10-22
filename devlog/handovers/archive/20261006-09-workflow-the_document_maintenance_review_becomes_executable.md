---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Document-Maintenance Review Becomes Executable

## Objective

Make the documentation review executable. `documentation-pass.md` was a stub register: it named the smells and no method, so an agent given only it knew what wrong looked like and not how to find it. The method sat in a comparison report that recommended compiling the two into one pi-native procedure.

## Scope

The pass exists in three pieces and only one of them was written down. The register carried the diagnostic checklist. The comparison report carried the method and the output contract. The mechanical checks carried the decidable half, and until the previous unit the largest of them -- a link from a shipped document -- was ungated.

In scope: the one skill that holds the method and the register, the retirement of the register file, the references that pointed at it, the report's disposition line, and the roadmap write-back. Out of scope: the two remaining `/document` sub-items, and the disposition of the rest of `workflow/coding-agent/audits/`, which the milestone scope owns.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One executable procedure holds the method and the register | `workflow/coding-agent/skills/doc-maintenance/SKILL.md`, 7 steps and the register | Agent [x] |
| The procedure is dispatchable | the frontmatter gate parses it: 45 prompt, skill and policy files, was 44 | Agent [x] |
| The method names the implementation as the deciding source | Step 3, and the failure mode that a document is not a source | Agent [x] |
| The link step checks what the gate cannot | Step 4 follows a link and confirms the target carries the claim | Agent [x] |
| The register's two empty code spans are repaired | the non-ASCII item names U+00A7 and U+00B6 | Agent [x] |
| The register file is gone and nothing live cites it | a repo-wide grep for `documentation-pass` returns the skill's provenance comment alone | Agent [x] |
| The report reuses the record schema | `## Output shape`, and the `skill` row in `check-in/report-schema.md` | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` | Agent [x] -- 1118 tests across 76 files, 0 failed |
| Lint is clean | `bash scripts/lint.sh` | Agent [x] -- 8 gates clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/doc-maintenance/SKILL.md` | new: the method, the register, the output shape |
| `workflow/coding-agent/audits/documentation-pass.md` | removed; the register's home |
| `workflow/coding-agent/audits/documentation-audit-comparison.md` | the method's home; a disposition line added |
| `workflow/coding-agent/audits/surface-area-report.md` | the disposition row for the removed file |
| `workflow/coding-agent/skills/check-in/report-schema.md` | the `skill` field names the third auditor |
| `workflow/coding-agent/prompts/document.md` | Step 6 and the Non-goals bullet point at the skill |
| `docs/development/prompt-authoring-conventions.md` | two references |
| `docs/policies/documentation_policy.md` | the diagnostic-checklist reference |
| `devlog/roadmap.md` | the parent row rewritten, the sub-item closed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pass is a skill, not a prompt | it is a check run against a scope, and it reports rather than produces: that is the shape `roadmap-maintenance` and `handover-maintenance` already have, and a skill reaches every instruction root the same way | this handover |
| The report reuses `check-in/report-schema.md` | one report shape for the maintenance passes; a second shape is the duplication the pass itself hunts | `report-schema.md` |
| The skill reports and does not write | the two record auditors were made report-only by handover `20261004-10`, and a maintenance run holds no write authority | `## Non-goals` |
| The register's items stay diagnostic, the policy's stay prescriptive | the two registers serve different readers, and the split was already deliberate in the removed file | `## The diagnostic register` |
| The audit report is not deleted yet | the milestone scope names it, and the folder's disposition is that task's | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The pass had a method worth keeping and no home for it. The comparison report dated 2026-09-11 recommended the compilation and was itself the only record of the method; had it been deleted first, the method would have gone with it. | design gap | resolved by this unit |
| The report's recommendation read as open a month after it was satisfied: no row carried a state. The disposition line added here is the same defect the previous unit recorded, met a second time. | design gap | recorded in both handovers |
| The container-layout gate's collision check is the only thing that would notice a skill directory whose name a second root also holds. Adding `doc-maintenance` needed no manifest row, which is correct, and no test covers the case where it would have. | untested path | filed for the test work |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/doc-maintenance/SKILL.md` | new skill: purpose, triggers, the gate split, 7 steps, the register, the output shape, non-goals, failure modes |
| `workflow/coding-agent/audits/documentation-pass.md` | removed |
| `workflow/coding-agent/audits/documentation-audit-comparison.md` | a disposition line at the head |
| `workflow/coding-agent/audits/surface-area-report.md` | the removed file's row |
| `workflow/coding-agent/skills/check-in/report-schema.md` | `doc-maintenance` added to the `skill` field |
| `workflow/coding-agent/prompts/document.md` | Step 6 names the register; the Non-goals bullet names the skill |
| `docs/development/prompt-authoring-conventions.md` | two references point at the skill |
| `docs/policies/documentation_policy.md` | the diagnostic-checklist reference |
| `devlog/roadmap.md` | the parent row and the first sub-item |
| `devlog/handovers/archive/20261006-09-workflow-the_document_maintenance_review_becomes_executable.md` | this handover |
