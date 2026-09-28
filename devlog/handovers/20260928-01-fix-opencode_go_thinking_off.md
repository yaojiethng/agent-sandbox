# Agent Handover

**Date:** 2026-09-28
**Milestone:** M3 (provider infrastructure, operator fast-tracked; off-roadmap regression fix, not an M3.1 row)
**Type:** Implementation
**Status:** Closed

## Objective

Make thinking "off" produce no visible thinking on the opencode-go deepseek-family models (`deepseek-v4-flash`, `deepseek-v4-pro`, `deepseek-v4.1-flash`), and stop `space-bunny-free` from silently accepting an off it cannot honor. `space-bunny-free` is an opencode-go model but is not deepseek-family; the three deepseek models and space-bunny are handled separately. [CORRECTION -- 2026-09-28] The original Objective read "opencode-go deepseek-family models, and stop space-bunny-free"; it did not state that space-bunny-free is not deepseek-family. The model is an opencode-go model served through the same gateway but belongs to a different family.

## Scope

One off-roadmap regression fix, per operator direction. Four changes:

- A: `models.json` opencode-go overrides for `deepseek-v4-flash`, `deepseek-v4-pro`, `deepseek-v4.1-flash` -- map off to `reasoning_effort: "none"` and move the model off the baked "deepseek" thinking format.
- B: `models.json` override for `space-bunny-free` -- mark off and minimal unsupported (`null`).
- C: overlay `thinkingLevelMapFromEffort` -- emit explicit `null` for unadvertised levels.
- D: remove the trailing comma in `models.json`.

## Carried forward

None.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| opencode-go `deepseek-v4-flash` / `-pro` / `-v4.1-flash` at thinking off emit `reasoning_effort: "none"` (was `thinking: {"type":"disabled"}`, ignored by the gateway, or a silent clamp to low) | replay of pi 0.87.1 transport logic against the edited `models.json` | Primary [x] - sim shows `{"reasoning_effort":"none"}` for all three at off |
| `space-bunny-free` at off clamps to `low` and sends a valid effort (no silent "off sends nothing") | sim against edited `models.json`; edited extension load | Primary [x] - sim shows `{"reasoning_effort":"low"}`; extension rebuild emits `off: null` |
| The edited overlay still loads: offline phase returns the 30 baked models, online phase emits `space-bunny-free` with `off: null` and `gpt-6-luna` with `off: "none"` | node strip-types load of the edited extension with live fetch | Primary [x] |
| The gateway honors the new off signal: `reasoning_effort: "none"` on `deepseek-v4-flash` and `deepseek-v4.1-flash` returns no reasoning_content | direct probes against `https://opencode.ai/zen/go/v1` | Primary [x] - both return content with no reasoning |
| `models.json` parses as strict JSON | `JSON.parse` | Primary [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/models.json`](src/reasoning/providers/pi/config/agent/models.json) | carries the off-level wiring and the unsupported-level marks |
| [`src/reasoning/providers/pi/config/agent/extensions/opencode-go.ts`](src/reasoning/providers/pi/config/agent/extensions/opencode-go.ts) | builds the live-only model maps; its header asserted a false off behavior |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Fix the deepseek off signal in `models.json` overrides, not in the overlay compat | the overlay must keep omitting `supportsReasoningEffort`; the wire change is per-model transport, which overrides own | this handover; the extension header comment |
| Map off to `reasoning_effort: "none"`, the gateway's off token | direct probes: `thinking: {"type":"disabled"}` is ignored by the zen/go gateway for deepseek-family; `reasoning_effort: "none"` disables | this handover |
| Mark `space-bunny-free` off and minimal unsupported | the gateway has no off for it: both `reasoning_effort: "none"` and `thinking: {"type":"disabled"}` return invalid_request_error | this handover |
| Leave the `deepseek` and `openrouter` provider rows untouched | different transports and gateways; an over-broad change there is a separate concern | this handover |
| Emit explicit nulls for unadvertised levels in the overlay | pi treats a missing map key as supported and only an explicit null as unsupported; omission made "off" silently send nothing | this handover; the function comment |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The opencode zen/go gateway ignores `thinking: {"type":"disabled"}` on deepseek-family chat completions and honors `reasoning_effort: "none"` instead | bug (upstream gateway) | current iteration - the fix routes around it |
| pi's `getSupportedThinkingLevels` treats a missing `thinkingLevelMap` key as supported; only an explicit null means unsupported | contradiction | current iteration - the overlay now spells out unsupported levels |
| `space-bunny-free` cannot disable thinking server-side; any off signal hard-errors | bug (upstream gateway) | current iteration - honest fallback is a low minimum |
| The confusion between "off supported" and "off sent" came from three different map shapes (baked undefined, store null, overlay omission) agreeing on the outcome but disagreeing on the meaning | record | next iteration - check live refresh output before trusting the map shape |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/models.json` | off -> `reasoning_effort: "none"` plus generic `thinkingFormat` for the three opencode-go deepseek models; `space-bunny-free` off/minimal marked null; trailing comma removed |
| `src/reasoning/providers/pi/config/agent/extensions/opencode-go.ts` | `thinkingLevelMapFromEffort` spells out nulls for unadvertised levels; header comment corrected to describe the real off wiring |
| this handover | written after verification |

## Deferred items

| Item | Reason | Where it goes |
|---|---|---|
| Rebuild the pi image and confirm in a real `/model` session: off on `deepseek-v4-flash` shows no thinking traces, `space-bunny-free` offers no off level | requires a deployed container | operator after `make build` |
| Restart the interactive session after deploying config changes | the deployed files are live, but a running process keeps the model overrides it loaded at boot; the fix was verified live only in new processes | operator during the real-session confirm |
| Verify `deepseek-v4-pro` with `reasoning_effort: "none"` on the live gateway (only flash models were probed) | same family, low risk; session is the natural check | operator during the real-session confirm |

## What's Next

Return to the `feat/M_3-orchestration` line. No sub-milestone completed; no roadmap maintenance needed.

Watch-outs:

- Rebuild before judging the fix; the live config at `/home/agentuser/.pi/agent` is a deployment artifact.
- The stale `models-store.json` opencode-go entry (from the removed extension) persists until a rebuild deletes it; its space-bunny shape now agrees with the overlay output.

**Conclusions from this iteration:** the regression was two-layered. pi's baked "deepseek" transport sends `thinking: {"type":"disabled"}` at off, a signal the opencode gateway ignores; and the overlay's level maps omitted unadvertised levels, which pi reads as supported and sends as nothing. The gateway's real off token is `reasoning_effort: "none"`, which the generic transport emits when the map spells out an off value. `settings.json` was exonerated: the level sticks at the session level; the wire never said "off" in a form the gateway honors.
