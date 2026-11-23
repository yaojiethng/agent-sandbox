---
date: 2026-11-22
milestone: M3.6.5 - The OpenCode provider is removed
type: Plan
status: Closed
---

# Handover - OpenCode becomes a dispatch option only

## Objective

Reconcile the roadmap and the records with the operator's direction that OpenCode is not a first-class session runtime: it stays reachable only as the dispatch CLI, and every carrier that asserts, builds or documents it as a provider is either retired, reframed or re-filed.

## Scope

The subject is the boundary between two OpenCode roles the tree currently conflates: the provider image that hosts an interactive or served session, and the CLI that `scripts/dispatch.sh` invokes as an agent-runtime. The provider role goes; the dispatch role stays. The plan covers `roadmap.md` M3.6.5 and the rows beneath it, the ADRs and reference documents that state OpenCode as a base-level provider, the provider image and its build inputs, the generated OpenCode instruction transport, the tests that use OpenCode as a second provider fixture, the `roadmap_future.md` W1 rows that promise OpenCode or hermes as a session runtime, the provider onboarding guide, and the archived discussion records that exist only to choose an OpenCode replacement. The implementation decomposition is not written here; the deletion runs in the iteration after this plan closes, and the generic provider base and dispatch transport are M3.6.7.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `roadmap.md` carries M3.6.5 as the provider removal, adds M3.6.7, moves the dispatch defects to M3.6, and corrects the parent, the M3.6.4 clause and the M3.2.2 pointer. | `grep -n "M3.6.5\|M3.6.7\|six dispatch harness defects\|hermes re-integration" devlog/roadmap.md` | Agent [x] |
| `roadmap_future.md` W1 is sandbox-only and carries no hermes or MCP task rows. | The `## W1` section of `devlog/roadmap_future.md` lists only the sandbox-only validation and the execution-model update. | Agent [x] |
| The three ADRs carry a current 2026-11-22 entry for the removal. | `grep -n "Current:\*\* 2026-11-22\|## 2026-11-22" docs/adr/opencode_runtime_dispatch.md docs/adr/reasoning_layer_tiers.md docs/adr/instruction_surface_declaration.md` | Agent [x] |
| The invalidated provider-replacement discussion records are gone, and the kept MCP and workspace studies carry no parent-story link. | `ls devlog/discussions/archive/20260312*` lists the MCP and workspace studies only; `grep -rn "provider_knowledge_store" devlog/discussions/archive` prints nothing. | Agent [x] |
| The handover records the plan, its decisions and the deletion sequence. | This record's Decisions table names the reframe, the removal, the deferred M3.6.7 and the deletions. | Agent [x] |
| The gates pass. | `bash scripts/check_handover_format.sh devlog/handovers/M3.6.5/20261122-01-plan-opencode_dispatch_only_reconciliation.md`, `bash scripts/check_record_citations.sh`, `bash scripts/check_references.sh`, `bash scripts/lint.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.6.5 is reframed in place rather than dissolved or split. | It is the smallest roadmap change that states the reversal honestly, keeps the dispatch rows under the milestone that owns dispatch, and avoids a milestone whose only content is deletion. | This record; the roadmap write-back |
| The OpenCode provider is removed entirely, not demoted to dormant. | A dormant provider is still a session runtime the build, gates and documents must carry, so it does not meet the direction; the dispatch CLI is independent of the provider image. | This record; the roadmap write-back; the ADR entry |
| The dispatch instruction transport is rebuilt on the neutral base in M3.6.7. | A dispatched OpenCode worker keeps the instruction base a pi worker gets; the new transport emits `instructions` and `skills.paths` for provider-neutral cells and drops the interactive `command` and `references` surfaces. | This record; deferred to the generic-provider-base work |
| The provider-neutral always-loaded fragment is the dispatch base, built in M3.6.7. | It becomes the instruction base every dispatched worker reads, so the neutral sandbox properties are written once and no pi-provider assumption reaches a worker. | This record; deferred to the generic-provider-base work |
| The deletion lands first; the generic provider base and the OpenCode dispatch transport come much later. | The provider image can be removed without waiting for the dispatch transport, because the CLI and its pin are independent of the provider image; the transport is rebuilt on the neutral base rather than on a provider config. | This record; the roadmap write-back |
| The deferred slice is a new not-started M3.6.7, "The generic provider base and dispatch parity". | It is a direct follow-on to M3.6.5, keeps the generic-base decision attached to the milestone that produced it, and M3.6 already carries a not-started sibling. | This record; the roadmap write-back |
| The plan's write-back is the roadmap, three ADR entries, and this handover; no separate discussion record. | The ADR is the durable seat for the standing decision, and the roadmap carries the work; a discussion record would be a second source. | This record; the roadmap; the ADRs |
| Content invalidated by the removal is deleted rather than annotated. | A removal note preserves the thing it removes; the roadmap, documents and records should state the live shape only. | This record; every write-back artifact |
| The invalidated provider-replacement discussion family is deleted. | The parent story and its Claude Code, Claude Desktop, Hermes and Pi studies exist to choose an OpenCode replacement; OpenCode and the replacement search are both gone. The MCP and workspace-input studies stay, because they carry the two-layer model and live citations. | This record; `devlog/discussions/archive/` |
| The hermes return is dropped from W1. | No future provider return is planned; keeping the row promises a source-built runtime the direction no longer wants. | This record; the roadmap_future write-back |
| W1's OpenCode MCP-client row is removed rather than retargeted. | The vault prototype does not need a second runtime named; the row's OpenCode-specific validation has no runtime. | This record; the roadmap_future write-back |
| W1's MCP enhancement is dropped; it becomes sandbox-only vault validation. | Removing the client row leaves the MCP path with no owner, and W1's prototype is valid sandbox-only; this removes the last W1 promise of a second runtime. | This record; the roadmap_future write-back |
| The provider onboarding guide is deleted. | The provider contract stays in `tool_interface.md`, the manifest and the layout gate; a guide has no current consumer with one provider. | This record; the deletion iteration |
| The neutral always-loaded base is `src/reasoning/agent/AGENTS.md`, composed into pi's seeded `AGENTS.md` at build and emitted by the dispatch generator. | It is the only option that writes a sentence true of every runtime once, and it gives the dispatch worker a base that does not assume pi. | This record; the roadmap write-back; the ADR entry |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| M3.6.5's objective is the inverse of the direction: it exists to make OpenCode a provider on pi's terms. | record | The sub-milestone cannot close as written; its dispatch rows need a new home and its provider rows retire. | This plan |
| The tree states OpenCode as a base-level provider in ADRs, the provider lifecycle, the provider guide and the tool interface, not only in the roadmap. | record | The decision needs an ADR entry and a propagation checklist, not a roadmap edit alone. | This plan |
| The provider image is discovered from `src/reasoning/agent-runtime/opencode/`, so removing that directory removes the provider from the build, compose and start paths together. | code | The code retirement is one directory plus its manifest rows, overlays and fixtures. | This plan |
| W1 carries an `Configure OpenCode to connect to MCP server` row alongside the hermes return row. | record | Dropping the OpenCode session runtime invalidates that row too; it needs a destination or a runtime retarget. | This plan |
| The provider onboarding guide documents two providers and an OpenCode-shaped flow. | record | It is stale with one provider; it is deleted and rebuilt when a second provider is planned. | This plan; the deletion iteration |
| The archived `20260312` provider-knowledge-store family exists to choose an OpenCode replacement. | record | The parent story and its provider-replacement studies are invalidated; the MCP and workspace-input studies remain because they carry the two-layer model and live citations. | This plan |
| The decision-records evolve pattern licensed condensing a demoted entry, and this plan's ADR entry did. | instruction | The pattern now forbids rewriting a historical rationale; a dated correction line is the only edit. | This plan |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | M3.6.5 reframed as the provider removal; M3.6.7 added; the dispatch defects moved to M3.6; the parent, M3.6.4 clause and M3.2.2 pointer corrected. |
| `devlog/roadmap_future.md` | W1 rewritten as sandbox-only vault validation; the hermes return and the MCP path deleted. |
| `docs/adr/opencode_runtime_dispatch.md` | New current entry: OpenCode is a dispatch agent-runtime only; the provider image and its instruction surface are removed; the dispatch transport is deferred to M3.6.7. |
| `docs/adr/reasoning_layer_tiers.md` | New current entry: the provider set is pi only; the CLI stays in `agent-runtimes`; the hermes return is dropped; R6 revised. |
| `docs/adr/instruction_surface_declaration.md` | New current entry: the OpenCode reader is removed with the provider; the dispatch transport is rebuilt on the neutral base in M3.6.7. |
| `devlog/discussions/archive/20260312-story-settled-provider_knowledge_store.md` | Deleted: the parent story for the OpenCode replacement search. |
| `devlog/discussions/archive/20260312-study-settled-claude_code.md` | Deleted: an OpenCode replacement candidate. |
| `devlog/discussions/archive/20260312-study-settled-claude_desktop.md` | Deleted: an OpenCode replacement candidate. |
| `devlog/discussions/archive/20260312-study-settled-hermes.md` | Deleted: an OpenCode replacement candidate and the hermes return. |
| `devlog/discussions/archive/20260312-study-settled-pi.md` | Deleted: an OpenCode replacement candidate. |
| `devlog/discussions/archive/20260312-study-settled-mcp_server.md` | Parent-story lines removed; the study stays for the two-layer model. |
| `devlog/discussions/archive/20260312-study-settled-workspace_input_channel.md` | Parent-story lines removed; the study stays. |
| `.agents/skills/decision-records/SKILL.md`, `.agents/skills/decision-records/patterns/evolve.md` | The historical-entry rule now forbids condensing or rewriting a demoted entry's rationale. |
| `devlog/handovers/M3.6.5/20261122-01-plan-opencode_dispatch_only_reconciliation.md` | This record. |
