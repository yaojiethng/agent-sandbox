# Agent Handover

**Session date:** 2026-03-25
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Investigation

## Objective
Complete the Claude Desktop provider investigation and close it with a recommendation.

## Scope
Provider investigations from prior handover Next session:
- `investigation_claude_desktop.md` — Claude Desktop provider (completed this session)
- `investigation_claude_code.md` — Claude Code provider (not in scope this session)

## Acceptance criteria

- [x] `investigation_claude_desktop.md` — status Resolved, recommendation recorded, open questions documented
- [ ] A second provider can be added under `providers/<n>/` with no changes to `scripts/` or `libs/` — carried from M2.2 implementation sessions; not addressed this session

## Hot files

| File | Why in scope |
|---|---|
| [`docs/discussions/investigation_claude_desktop.md`](docs/discussions/investigation_claude_desktop.md) | Investigation completed and closed this session |
| [`docs/discussions/story_provider_knowledge_store.md`](docs/discussions/story_provider_knowledge_store.md) | Claude Desktop table row and note updated to reflect resolved status |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Claude Desktop is viable as reasoning layer, pending prototype | All harness invariants preserved without codebase changes; `make apply` unchanged; session lifecycle becomes manual | `investigation_claude_desktop.md` — Resolution |
| Operator model: `make sandbox` + `make apply` | Sandbox container owns diff generation; Claude Desktop owns MCP filesystem container; apply pipeline unchanged | `investigation_claude_desktop.md` — Finding 4 |
| MCP server container start trigger deferred | Likely Claude Desktop owns MCP container lifecycle, operator owns sandbox; procedure for reconnection after sandbox restart needs further investigation | `investigation_claude_desktop.md` — Open Question 2 |
| Operator procedure formalisation deferred | Wrapper scripts and edge cases (e.g. forgetting to stop sandbox before applying) to be defined at implementation planning time | `investigation_claude_desktop.md` — Open Question 3 |
| No codebase changes from this investigation | Investigation is findings-only; changes arise at prototype/implementation stage | This handover |

## Completed this session

| File | Change |
|---|---|
| `docs/discussions/investigation_claude_desktop.md` | Created; status Resolved; full findings on mount path compatibility, apply pipeline, session lifecycle, MCP reconnection behaviour, server upgrade detection, and host security |
| `docs/discussions/story_provider_knowledge_store.md` | Claude Desktop table row updated from "Not started" to "Resolved — viable, pending prototype"; Note on Claude Desktop corrected to reflect investigation findings |

## Deferred items

- `investigation_claude_code.md` — Claude Code provider investigation not started this session. Carries forward as the remaining open investigation under Direction 1.
- `onboard.sh` multi-provider support — carried from prior session; depends on provider investigation outcomes. Still pending.
- Operator procedure formalisation for Claude Desktop (`make sandbox` cycle, reconnection steps) — deferred to implementation planning.
- MCP server container start trigger (Claude Desktop vs operator ownership) — deferred; needs prototype to confirm ergonomics.
- Acceptance criterion 3 (second provider verified) — Trigger B still cannot fire until `investigation_claude_code.md` is resolved and the criterion is met.

## Next session
**M2.2 — Reasoning Layer Modularisation — Claude Code provider investigation.**

Trigger B does not fire until `investigation_claude_code.md` is resolved and acceptance criterion 3 is met.

**Watch-out items:**
1. `investigation_claude_code.md` exists as a stub — confirm its current status before starting the investigation proper.
2. Claude Code runs as an MCP server (`claude mcp serve`) when used from Claude Desktop; the directory restriction behaviour in MCP serve mode has a known issue (see GitHub issue #3139) — this is relevant to the Claude Code investigation.
3. Once both provider investigations are closed, `onboard.sh` multi-provider support can be scoped.
