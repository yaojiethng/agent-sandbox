# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Refactor
**Status:** Closed

## Reopened correction

Iteration reopened (operator direction) after a premature close: the release gate was not presented before the commit, and the operator flagged the missing acceptance gate. A reconciliation review (`space-bunny-free`, thinking resolved to high, provider `opencode-go`) ran against report 1 (`/tmp/doc_policy_reorg_proposal.md`) and report 2 (`/tmp/second_report_doc_policy.md`); its catalogue, per-entry resolution and structure feedback (`SF-1`..`SF-13`) were triaged and the reorganization folded into the reopened commit. **Release gate cleared 2026-09-30:** the operator granted release; the iteration closes.

## Objective

Restructure `documentation_policy.md` so its headings name their content and each section is a single concern, and reconcile the `Folder Structure` table with `devlog/`.

## Scope

Targets the deferred `documentation_policy.md` structural pass recorded in handovers `20260930-07` and `20260930-08` (roadmap task `documentation_policy.md structural pass (post-refactor)`). Exact final shape pending operator confirmation at the scope gate.

## Carried forward

| Item | From handover |
|---|---|
| Promote `### Rule authority` out of the mis-titled `## Document Types`; the rule-vs-model premise precedes sections that depend on it | `20260930-07`, `20260930-08` |
| Re-form `## Record Lifecycle` as a true lifecycle (currently a catch-all: placement, skeleton, records-state, header format, corrections, missing-documents) | `20260930-07`, `20260930-08` |
| Split the `## Enforcement Rules` / `## Communication Standards` grab-bags | `20260930-07`, `20260930-08` |
| Rename `### Read pass economics` and `### Document depth and verbosity` to name their content | `20260930-07`, `20260930-08` |
| Drop or re-source the `### Markdown lint gate` roadmap-iteration citation (self-violating Records state) | `20260930-07`, `20260930-08` |
| Reconcile the `Folder Structure` table's "exactly one of the following" claim against `devlog/` (the table covers only `docs/`), deconflicting with `discussion_policy` | `20260930-07`, `20260930-08` |

## Acceptance criteria

- The restructured `documentation_policy.md` borrows report 1's grouping (with `## Communication Standards` kept as the prose header): Rule authority / Folder Structure / Communication Standards / Format / Drafting / Prohibited content / Tooling checks / Document Types / Record maintenance.
- The PR gate is deleted; `Record invariant shifts` moved to `iteration_policy.md`; the speculative pair merged; `ADR obligations` heading restored; ShellCheck/`make lint` dropped from the document-lint tooling section; stale examples states the current-expectation (no session-cadence framing).
- Every inbound heading reference (taxonomy doc, workflows) still resolves; no stale `Document depth and verbosity` / `Read pass economics` / `#audit-checks` / `Rule locality` references remain.
- Markdown lint clean.

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/documentation_policy.md` | the structured pass: section reorganization, heading renames, lint-gate provenance |
| `docs/operations/discussion_policy.md` | the `devlog/` / `docs/` deconflict owner |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Delete the PR gate | the project defines no pull-request convention; the agent never opens a PR; the rule's intent is covered by the dispatched invariant-shift rule and stale-examples prohibition | this handover |
| Dispatch `Record invariant shifts` to `iteration_policy.md` `### Record-state invariants` | it is a workflow timeliness rule (when in the loop to record), not a documentation-prose rule | `iteration_policy.md` |
| Restructure by concern per report-1's how/forbidden/tooling frame, with `Rule authority` promoted to the top as the foundation | functional groups make each section single-purpose | this handover |
| Collapse `ADR obligations` into a one-line pointer and fold its concept link-rule into `Concept document obligations` | it was a near-empty pointer duplicating `adr_policy.md` and `Concept obligations` | this handover |
| Borrow report 1's outline but keep `## Communication Standards` as the prose header: add a `## Format` parent (header format, character set, wrapping, reference handling, numbered-vs-bulleted, grep navigation); slice the `Document structure` grab-bag into Format (format rules), Communication Standards (rule placement) and Drafting (folder placement, skeleton, records-state); merge the speculative prohibitions; restore `### ADR obligations`; split Post-close into `####` subclaims | report 1 supplies the target shape for most reconciliation flags (SF-2/3/4/5/7/8); the operator chose to keep the Communication Standards header | this handover |
| Stale code examples states the expectation that examples are current, without session-cadence framing | "before closing a session" was the wrong framing; the rule is that examples match the implementation | this handover |
| Tooling checks covers document lint only (linter choice, disabled rules, added rules); ShellCheck and `make lint` dropped as code gates | ShellCheck is not a document lint concern | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The unrestricted `PR gate` rule referenced a pull-request convention the project does not define; the agent works on type-prefixed branches merged via review (git_policy) and diffs applied by the operator, never opens a PR | vestigial rule | removed this iteration - its intent is owned by the invariant-shift rule and the stale-examples prohibition |
| `agent_workflow.md` linked `#audit-checks`, a section that does not exist in `documentation_policy.md`; the canonical-owner test lives under Rule authority | dead link | repaired this iteration - anchor now `#rule-authority` |
| `Document depth and verbosity` and `Read pass economics` headings did not name their content, and the former's canonical-owner test sat outside the authority section | misnaming / misplacement | renamed and reorganised this iteration |
| The `Folder Structure` open claimed "exactly one" while covering only `docs/`, omitting `devlog/` | scope gap | fixed this iteration - the claim now scopes to `docs/` and names `devlog/` |
| Reconciliation (`space-bunny-free`): of report 1's 46 findings, 17 resolved / 16 partial / 13 not; of its 24 decisions, 8 resolved / 6 partial / 5 not / 3 superseded; of report 2's 38 entries, 22 met / 13 partial / 3 not. The residuals the reports named (merge the speculative pair, split coarse headings, stop the policy contradicting its own Rule authority) were folded into the report 1 borrow | process | current iteration - report 1's outline supplied the target shape for SF-2/3/4/5/7/8/11 |
| Reconciliation SF-12: the "before closing a session" / "before an iteration closes" cadence was workflow-timing framing misplaced in content and tooling rules | misplaced framing | resolved this iteration - stale examples restated as a current-expectation; the document-lint tooling section dropped the ShellCheck/`make lint` code gates |

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | restructured per the report 1 borrow: `## Rule authority` promoted (canonical-owner + folded no-bridge); `## Folder Structure` scoped to `docs/` with a `devlog/` note; `## Communication Standards` kept for prose (Rule placement, STE, Reserved terminology); new `## Format` (header format, character set, line wrapping, reference handling, numbered-vs-bulleted, grep navigation); `## Drafting` (folder placement, skeleton, records-state); `## Prohibited content` (merged speculative/TODO rule, stale examples as current-expectation); `## Tooling checks` document-lint only (gate + rule set; ShellCheck/`make lint` dropped); `## Document Types` with `### ADR obligations` restored and `####` subclaims on Concept obligations; `## Record maintenance` with Post-close split into `####` and the changelog-def duplicate removed |
| `docs/operations/iteration_policy.md` | added "record a document-relevant change when you make it" to `Record-state invariants` (the dispatched invariant-shift rule) |
| `docs/concepts/agent_workflow.md` | Documentation-rules row wording updated to rule placement/grep navigation; broken `#audit-checks` link repointed to `#rule-authority` |
| `docs/development/prompt-authoring-conventions.md` | heading reference updated to `### Rule placement` |
| `workflow/coding-agent/audits/documentation-pass.md` | canonical-owner-test reference updated to `### Rule authority` |

## Deferred items

| Item | Reason | Where it goes next |
|---|---|---|
| Reconciliation SF-1 half: move the descriptive folder *purposes* to the concept doc | kept in the policy table as the placement rule's operand (report 1 section 1.1 also kept it verbatim); moving would widen to a concept-doc content change | next concept-doc pass (reconciliation SF-9) |
| Reconciliation SF-3 half: split `Records state, not session history` into a prohibition + settled-design guidance | the heading is an inbound anchor from `documentation_taxonomy.md`; splitting needs a coordinated taxonomy update | a dedicated follow-up |
| Reconciliation SF-9: concept-doc gaps (no folder-taxonomy section; no "gates and lint" stage in the lifecycle view; two obligations restated rather than linked) | the concept doc `documentation_taxonomy.md`, out of this iteration's policy scope | the Docs-and-ADR consolidation group |

## What's Next

Docs-and-ADR-consolidation group; the reconciliation's concept-doc gaps (SF-9) and the deferred `Records state` split are the leading items.

**Conclusions:** `documentation_policy.md` borrows report 1's outline with `## Communication Standards` kept: Rule authority -> Folder Structure -> Communication Standards -> Format -> Drafting -> Prohibited content -> Tooling checks -> Document Types -> Record maintenance. The reconciliation's residual flags (merge the speculative pair, split coarse headings, stop the Rule-authority self-contradiction, format-home, tooling children) are folded. The PR gate is gone (vestigial); the workflow-timeliness rule moved to `iteration_policy.md`; the document-lint tooling section no longer carries code gates; stale examples states a current-expectation. All inbound section references resolve; lint clean. Release gate pending operator release.
