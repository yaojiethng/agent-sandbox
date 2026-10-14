---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Documentation
status: Closed
---

# Handover - Close the Documentation Audit Findings

## Objective

Resolve the verified defects the documentation audit recorded against the reference and maintenance documents, and leave nothing known-stale behind.

## Scope

`workflow/coding-agent/audits/documentation-audit-comparison.md`, dated 2026-09-11, lists 13 findings it verified against the implementation. Nothing had acted on them. The iteration re-verified every finding against the current tree before touching anything: eleven were already resolved upstream, and four were not.

The four that remained.

- `security.md` named the wrong system in its own overview, calling it the OpenCode containerized coding agent system.
- `security.md` carried six invariants while `system_overview.md` points at that list as authoritative for a guarantee the list did not hold, the two-layer agent nesting limit.
- Four documents wrote a repository path as `providers/<n>/`, which resolves under no root. Nine sites were corrected to `src/reasoning/providers/<n>/`, the form `tool_interface.md` and the provider guide already used.
- `project_onboarding_guide.md` described the provider environment stub as `.env.example`. That mechanism has never existed. `onboard.sh` renames `config/env.stub` to `.env`.

In scope: those four corrections, and the handover. Out of scope: the audit's own consolidation, which recommends one compiled pi-native audit prompt absorbing `documentation-pass.md` and `architecture-doc-reviewer.skill.md`, and the retire-next skill, which the doc-maintenance unit owns.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The audit's findings are re-verified, not assumed | each of the 13 was checked against the code or the tree, and the eleven already-resolved ones are named in this handover | Agent [x] |
| No document names the wrong system | `grep -rn "OpenCode" docs/development/security.md` returns only the example runtime in the trust-boundary paragraph | Agent [x] |
| The authoritative invariant list is complete | `system_overview.md`'s four guarantees each appear among `security.md`'s invariants | Agent [x] |
| No repository path is written as `providers/<n>/` | a repo-wide grep for the shorthand returns only `src/reasoning/providers/<n>/` forms | Agent [x] |
| The onboarding guide names the real mechanism | the stub paragraph names `config/env.stub` and the rename `onboard.sh` performs | Agent [x] |
| The suite is green | `bash scripts/run_tests.sh` | Agent [x] -- 1117 tests across 76 files, 0 failed |
| Lint is clean | `bash scripts/lint.sh` | Agent [x] -- 8 gates clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `docs/development/security.md` | the wrong system name, and the missing nesting invariant |
| `docs/reference/system_overview.md` | the guarantee whose authoritative home lacked it, and the path shorthand |
| `docs/reference/agent_workflow.md`, `docs/reference/execution_model.md`, `docs/reference/provider_lifecycle.md` | the path shorthand |
| `docs/reference/project_onboarding_guide.md` | the retired `.env.example` mechanism, and the path shorthand |
| `workflow/coding-agent/audits/documentation-audit-comparison.md` | the finding list this iteration closes |
| `devlog/AGENT_FEEDBACK.md` | a recurrence on the mechanical-edit entry |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The eleven resolved findings stay closed without an edit | each was verified against the tree, and re-editing a fixed document is churn | this handover |
| The nesting invariant is added to `security.md` rather than removed from `system_overview.md` | the nesting limit is a real host-protection property, and `system_overview.md` already states that no operational enforcement exists yet, so the authoritative list is the right home and the caveat travels with it | this handover |
| The path shorthand is corrected at every site rather than defined once | nine sites in four documents is few enough that a definition buys nothing, and a reader who lands on one site has no other | this handover |
| The audit's own consolidation is left for the doc-maintenance unit | it recommends an audit prompt that the doc-maintenance skill absorbs, and building it here would duplicate that unit | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Eleven of the thirteen audited findings were already resolved upstream, and the audit report that listed them was never marked. A findings list with no state per row reads as entirely open a month later. | design gap | `documentation-pass.md` when it becomes the skill: each row carries a state |
| A folder rename left the word `architecture/` in the repository, and a blanket replacement hit the skill directory `improve-codebase-architecture/`. Recorded as a recurrence on the mechanical-edit entry. | agent mistake | `devlog/AGENT_FEEDBACK.md`, recurrence added |
| Two ADRs still name the retired `docs/operations/` folder, one live and one archived. The live one was updated by the rename; the archived one keeps its account; no rule states whether a path inside a dated ADR entry follows a rename. | design gap | proposed for `adr_policy.md` at the operator's word |

## Completed

| File | Change |
|---|---|
| `docs/development/security.md` | the overview names the harness, and the invariant list gains the nesting limit with its enforcement caveat |
| `docs/reference/system_overview.md` | the path shorthand |
| `docs/reference/agent_workflow.md` | two path shorthands |
| `docs/reference/execution_model.md` | two path shorthands |
| `docs/reference/provider_lifecycle.md` | three path shorthands |
| `docs/reference/project_onboarding_guide.md` | the `.env.example` claim replaced by the `config/env.stub` mechanism |
| `devlog/AGENT_FEEDBACK.md` | a recurrence on the mechanical-edit entry, for the unanchored replacement |
| `devlog/handovers/20261006-07-docs-close_the_documentation_audit_findings.md` | this handover |
