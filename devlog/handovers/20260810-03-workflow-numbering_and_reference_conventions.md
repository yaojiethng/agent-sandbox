# Agent Handover

**Session date:** 2026-08-10
**Milestone:** M2.6.6 -- Mount Model: Host-backed Sandbox
**Session type:** Workflow
**Status:** Closed

## Objective
Establish a general communication convention for numbering and cross-references that standardizes usage across chat turns, document records (handovers, discussions, roadmap), and code comments. Remediate the known instances of transient and context-heavy numbering.

## Scope
- **Operator ask (new session):** address the context-heavy numbering concern as a general communication rule, observed in writing and in chat turns:
 - Standardize numbering conventions between chat and documentation, including code comments
 - Discontinue transient chat numbering in document records
 - Discontinue transient numbering in discussion documents where the referenced document already has its own numbering -- qualified references only (e.g. "Open Question Q11 of [document]")
 - Use the descriptive name as the canonical reference (e.g. "loop-documentation structure + state diagram", not a question/finding number)
 - Context-aware numbering: an enumeration in one context (chat Q1..Q5, handover finding table) is never pointed to from another context without carrying the defining context
- **Convention home (to be proposed):** canonical section in `docs/operations/documentation_policy.md`; chat + code-comment clauses in `AGENTS.md`. Text proposed one section at a time, operator-approved before writing (governance gate).
- **Known instances to remediate (pending scope confirmation):**
 - `devlog/discussions/design_dual_layer_seam_testing.md` -- "Session 11b-11e" headings, "(11b)" inline refs, "M2.7 item 8/10/12" refs (dangling after M2.7 compaction)
 - `scripts/dry_run_reasoning.sh` L97, `tests/knowledge/knowledge_pi_config_cycle.sh` L23 -- "M2.7 item 8" comment refs (dangling)
 - `docs/operations/handover_policy.md` L203 -- "roadmap.md item 13" example (position-based reference)
 - Prior chat reply: "Finding 11 (loop-documentation structure + state diagram) -- M3" (context-heavy; behavior fix)
- **Not in scope:** the loop-documentation structure decision + state diagram (M3) itself; STE sweep; harness-sig; any other Deferred entry.

## Carried forward
| Item | From |
|---|---|
| (none active -- fresh operator-requested session) | -- |

## Acceptance criteria (draft - confirm at scope gate)
| # | Criterion | Verifiable by |
|---|---|---|
| 1 | Canonical numbering/reference convention written into the agreed home(s) with operator-approved text | read the section(s) |
| 2 | AGENTS.md gains chat + code-comment clauses (context-aware references; no transient numbering in records) with operator-approved text | read the clauses |
| 3 | All confirmed instances remediated per propagation checklist; zero dangling position/number refs in live docs | grep |
| 4 | This session's own records (handover, chat) use only descriptive names or qualified references | operator read |
| 5 | GOTCHAS entry "Session-relative finding numbers" updated to reference the general convention (state transition, if approved) | read the entry |

## Hot files
| File | Why in scope | Status |
|---|---|---|
| [docs/operations/documentation_policy.md](../../docs/operations/documentation_policy.md) | canonical convention section (pending proposal) | pending |
| [AGENTS.md](../../AGENTS.md) | chat + code-comment clauses (pending proposal) | pending |
| [devlog/discussions/design_dual_layer_seam_testing.md](../../devlog/discussions/design_dual_layer_seam_testing.md) | "Session 11b-11e" / "item 8/10/12" dangling refs | pending |
| [scripts/dry_run_reasoning.sh](../../scripts/dry_run_reasoning.sh) | "M2.7 item 8" comment | pending |
| [tests/knowledge/knowledge_pi_config_cycle.sh](../../tests/knowledge/knowledge_pi_config_cycle.sh) | "M2.7 item 8" comment | pending |
| [docs/operations/handover_policy.md](../../docs/operations/handover_policy.md) | "roadmap.md item 13" example | pending |
| [devlog/GOTCHAS.md](../../devlog/GOTCHAS.md) | reference the general convention | pending |

## Decisions made this session
| # | Decision | Notes |
|---|---|---|
| 1 | Numbered lists allowed when order matters or readers refer by number; numbering scope = defining context | Operator-approved rule set |
| 2 | Cross-context references use descriptive name or link; bare position refs banned in persistent records | "item 13", "M2.7 item 8" are position refs |
| 3 | Chat enumeration may be referenced in-conversation (grill-me, scope, questions); rename descriptively when promoted to a record | Operator's pinpointing use case preserved |
| 4 | Frequently-referenced list items promoted to headings to create anchors | Operator's "cleaner reference" idea |
| 5 | Em-dash rule lifted: write ` - ` (headings / space-separated) or `--` (prose); en-dash ranges use plain `-` | Operator-directed; sweep of touched files done, full repo sweep deferred |
| 6 | Positive prescription over prohibition for encoding rules (avoid rephrasing-obsession) | Applied to the dash rule; not yet codified in STE section |

## Mid-session findings
None.

## Completed this session
| File | Change |
|---|---|
| [docs/operations/documentation_policy.md](/home/agentuser/sandbox/docs/operations/documentation_policy.md) | New `### Numbering and cross-references` section; `### Character set` em-dash rule rewritten (lift ban, prescribe ` - ` / `--`) |
| [AGENTS.md](/home/agentuser/sandbox/AGENTS.md) | Added `**Context-aware numbering.**` (Collaboration Protocol) + code-comment transient-numbering clause (Output Format) |
| [devlog/discussions/design_dual_layer_seam_testing.md](/home/agentuser/sandbox/devlog/discussions/design_dual_layer_seam_testing.md) | Dropped "Session 11b-11e" prefixes + "(11b)"-style inline refs; "item 12/8/10" → descriptive names |
| [scripts/dry_run_reasoning.sh](/home/agentuser/sandbox/scripts/dry_run_reasoning.sh) | Comment "M2.7 item 8" → "the M2.7 config bind-mount change" |
| [tests/knowledge/knowledge_pi_config_cycle.sh](/home/agentuser/sandbox/tests/knowledge/knowledge_pi_config_cycle.sh) | Comment "M2.7 item 8" → "(M2.7 config change)" |
| [docs/operations/handover_policy.md](/home/agentuser/sandbox/docs/operations/handover_policy.md) | "roadmap.md item 13" → descriptive-only routing example |
| [devlog/discussions/investigation_harness_sig_requirements.md](/home/agentuser/sandbox/devlog/discussions/investigation_harness_sig_requirements.md) | "M2.7 item 5" → "M2.7 (container-sig settled)" |
| [devlog/discussions/design_provider_config_ownership_and_loading.md](/home/agentuser/sandbox/devlog/discussions/design_provider_config_ownership_and_loading.md) | "M2.7 item 8" → "the M2.7 config bind-mount change" |
| [devlog/discussions/story_windows_filesystem_incompatibilities.md](/home/agentuser/sandbox/devlog/discussions/story_windows_filesystem_incompatibilities.md) | "M2.7 item 8" → "the M2.7 config bind-mount change" |
| [devlog/changelog.md](/home/agentuser/sandbox/devlog/changelog.md) | "M2.7 item 11b" → "M2.7" (historical CORRECTION entry, minimal fix) |
| [src/reasoning/agent/drafts/roadmap-audit.skill.md](/home/agentuser/sandbox/src/reasoning/agent/drafts/roadmap-audit.skill.md) | Example row "M2.7 item 8" → "M2.7 pre-flight checks" |
| [devlog/GOTCHAS.md](/home/agentuser/sandbox/devlog/GOTCHAS.md) | Entry → state probation; durable fix + remediation recorded |
| All 12 tracked touched files + handover | Mechanical em/en-dash sweep (em-dash to ` - `/` -- `, en-dash to `-`); zero non-ASCII dashes remain |

## Deferred items
| # | Item | Reason / next home |
|---|---|---|
| 1 | Full repo em-dash sweep (non-touched files) | Deferred by operator; mechanical pass when convenient |
| 2 | Positive-prescription principle codified in STE section | Optional; not yet applied |
| 3 | Loop-documentation structure decision + state diagram (M3) | `roadmap_future.md` M3 (unchanged this session) |
| 4 | STE-clean sweep of remaining docs | `roadmap_future.md` Deferred (Unplanned) |
| 5 | Harness-sig host-side staleness detection | `roadmap_future.md` Deferred (Unplanned) |

## Next session
Sub-milestone M2.6.6 (or current). The numbering-and-cross-references convention is established: canonical section in `documentation_policy.md`, AGENTS.md chat + code-comment clauses, known instances remediated, dash sweep applied to touched files. Open items: full repo em-dash sweep (mechanical, non-touched files), optional STE positive-prescription note, loop-documentation structure + state diagram (M3), STE sweep (M3), harness-sig. No carried-forward items from this session.
