# Agent Handover

**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Remove the stale Claude-chat `/mnt/user-data` reference from the project-level `AGENTS.md`, correct the model-resolution warning rule in the provider-layer `AGENTS.md`, and move the model recommendation into the project-level `AGENTS.md` so model choice is single-sourced per project.

## Scope

The M3.2.1 roadmap row `Prompt/AGENTS.md convention: single-source agent recommendations per role`. This iteration covers the agent-instruction bug half of that row: the stale interface reference and the model-recommendation relocation. It does not build the full per-role recommendation table or the prompts-retrieve-by-role machinery -- those stay on the row.

How the scope splits between the in-repo files and the installed copy is under Gate 1 confirmation; the provider-layer file lives at `~/.pi/agent/AGENTS.md` (outside the sandbox) and at its in-repo source `src/reasoning/providers/pi/config/agent/AGENTS.md`.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | `AGENTS.md` (project) has no `Claude Chat` or `/mnt/user-data`; its role table defines `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR` each with model + thinking level | `grep` count = 0; table rows present | Agent [x] |
| AC2 | Provider-layer `AGENTS.md` (repo source + installed copy) has no hardcoded model; resolves the startup default via `jq`; corrected warning rule; the two files byte-identical | `grep` = 0 per file; `jq` line present; `diff` identical | Agent [x] |
| AC3 | Five prompts/skills (`advisor` to `_ADVISOR`, `thermo-nuclear` to `_REVIEWER`, `auto` to `_IMPLEMENTER`, `review-pass`/`review-loop` to `_REVIEWER`) have no hardcoded model and reference the role | `grep` = 0 per file + role tag present | Agent [x] |
| AC4 | `thermo-nuclear` recommends one reviewer instance by default; multiple only when asked | read SKILL.md | Operator |
| AC5 | `parallel-auto.md` gains a pointer to `_IMPLEMENTER` for its worker tracks | read + grep pointer | Agent [x] |
| AC6 | `docs/concepts/sandbox_host_interface.md` has no `Claude Chat` mention | `grep` = 0 | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`AGENTS.md`](../../AGENTS.md) | project-level file: remove the stale Claude-chat `/mnt/user-data` paragraph; host the relocated model recommendation |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | in-repo source of the provider-layer file: drop the hardcoded model pair and the example dispatch command; fix the warning rule |
| `~/.pi/agent/AGENTS.md` | installed provider-layer file (outside the sandbox): same three corrections, if the operator approves editing it |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Underscore role tags (`_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`) | pi reserves `@` for file links; `#` collides with Markdown heading/anchor syntax; `_ROLE` collides with nothing | design doc + ADR `single_source_model_recommendations.md` |
| Role table lives in project-level `AGENTS.md` | provider layer loads for every project and must not dictate models; project layer is the single writable home | same |
| Fallback when a tag is absent: resolve startup default (`defaultProvider`/`defaultModel`/`defaultThinkingLevel`) from `~/.pi/agent/settings.json` with `jq`; a project-level `.pi/settings.json` override takes precedence | a missing tag must never be a dangling reference; advisor pass closed the gap | same |
| Recommendations carry model + thinking level; routing clause (`_ADVISOR`) precedes first-in-listed-order | dispatch and attribution need the level; advisor finding D3/D4 | same |
| Provider-layer warning rule corrected: `No models match pattern` means pi fell back to the startup default, not that the requested model ran | observed behavior; warning is not benign noise | same |
| Editing pi's own `AGENTS.md` always updates both the repo source and the installed copy (option A) | running agent context and shipped config must not diverge | project-level AGENTS.md instruction |

Model + level table (operator-confirmed 2026-09-29): `_IMPLEMENTER` = space-bunny-free at high, deepseek-v4-flash at medium; `_REVIEWER` = space-bunny-free at xhigh, deepseek-v4-flash at medium; `_ADVISOR` = glm-5.3-flash at high (documentation/language), deepseek-v4-flash at xhigh (code).

## Findings

| Finding | Type | Impact |
|---|---|---|
| `test-assertion-sweep-brief.md` `## Run record` lines are a factual record of the completed U7 run (deepseek-v4-flash xhigh), not a forward model recommendation; rewriting them to `_REVIEWER` would falsify what that run used. Operator ruling (option A, 2026-09-29): keep the record factual; exclude this file's Run record from AC3. Triage: Deferred items. | contradiction | current iteration |

## Completed

| File | Change |
|---|---|
| `AGENTS.md` | removed Claude Chat `/mnt/user-data` paragraph; added `## Model Recommendations` role table (`_IMPLEMENTER`/`_REVIEWER`/`_ADVISOR` with model+thinking), fallback (+ project-level `.pi/settings.json` precedence), and always-edit-both rule |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | subagent section cleaned of hardcoded models; jq default resolution; warning rule corrected to fallback semantics |
| `~/.pi/agent/AGENTS.md` | installed copy synced to the repo source (option A) |
| `src/reasoning/agent/prompts/advisor.md` | hardcoded model pair replaced with `_ADVISOR` routing-clause reference; example command genericized |
| `src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md` | `_REVIEWER` reference; one reviewer instance by default, multiple only when asked |
| `workflow/coding-agent/prompts/auto.md` | `_IMPLEMENTER` reference; example command genericized |
| `workflow/coding-agent/prompts/review-pass-run.md` | `_REVIEWER` reference; example genericized |
| `workflow/coding-agent/prompts/review-loop-run.md` | `_REVIEWER` reference; example genericized |
| `workflow/coding-agent/prompts/parallel-auto.md` | `_IMPLEMENTER` pointer added for worker tracks |
| `docs/concepts/sandbox_host_interface.md` | Claude Chat mention removed; "Mixed session types" reworded to `make apply`/`make draft` channels |
| `devlog/discussions/20260929-design-settled-single_source_model_recommendations.md` | settled design record (design decisions + fallback chain + role table) |
| `docs/adr/single_source_model_recommendations.md` | standing-principle ADR (R1-R6 + 2026-09-29 decision) |
| `devlog/handovers/20260929-02-workflow-agents_md_single_source_model_and_stale_interface.md` | this handover |

Not edited (record, option A): `workflow/coding-agent/audits/test-assertion-sweep-brief.md` keeps its factual `## Run record` (deepseek-v4-flash xhigh) as history.

## Deferred items

- The M3.2.1 convention row also names auditor and design roles for the role table; this iteration single-sourced only `_IMPLEMENTER`/`_REVIEWER`/`_ADVISOR` (the operator-named scope). The table is extensible; new roles are added when a prompt needs them. Whether this is a roadmap remainder is decided at pre-close write-back.
- The `fanout`, `gm`, and other non-hardcoding prompts were not touched; they dispatch subagents without naming models.

## What's Next

Context (resumed after this iteration): the task-queue prompt build remains an active M3.2.1 task; stub `parallel-auto` under M4.6. This iteration landed the single-source model-recommendation convention; the next task-queue prompt should read its per-role model from the `_IMPLEMENTER`/`_REVIEWER`/`_ADVISOR` tags in this project's `AGENTS.md`, not hardcode.

Forward deploy note: the provider-layer `AGENTS.md` edits require the pi image / installed config to be redeployed to take effect beyond this machine; this session synced `~/.pi/agent/AGENTS.md` directly (option A). Roadmap maintenance ran at close: the M3.2.1 single-source-model-recommendation row is marked `- [x]` done.
