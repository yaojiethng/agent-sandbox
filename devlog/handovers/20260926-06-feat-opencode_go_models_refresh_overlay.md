# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3 (provider infrastructure, operator fast-tracked; context only, not an M3.1 row)
**Type:** Implementation
**Status:** Closed

## Objective

Restore correct thinking levels on opencode-go's `deepseek-v4-flash` / `deepseek-flash` and refresh opencode-go's model catalog live. Ported from the `feat/opencode-go-extension` branch as one squashed commit with one handover, per operator direction.

## Scope

One new file: `src/reasoning/providers/pi/config/agent/extensions/opencode-go.ts`. No roadmap row (off-roadmap operator work). The pi bump and the removal of the bugged `pi-opencode-provider` extension already landed on the current line (`@earendil-works/pi-coding-agent@0.87.1` in `base.dockerfile`, no extension line in `provider.dockerfile`), so the port is the overlay only.

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The overlay loads under pi's extension loader and registers a `refreshModels` on the built-in `opencode-go` provider | jiti load against pi 0.87.1's alias set (coding-agent, pi-ai, pi-ai/providers/all) | Primary [x] - the file imports and the factory exports a function |
| The overlay never sets `compat.supportsReasoningEffort: false` | reading the compat constants | Primary [x] - `CHAT_COMPAT`/`DEEPSEEK_COMPAT` omit the flag, inheriting pi's auto-detection |
| The offline/cache phase does not fetch: `allowNetwork` false returns the baked catalog | `buildOpenCodeGoModels` | Primary [x] - the guard branches before the first fetch |
| The file is byte-identical to the branch tip (all six branch commits included) | `cmp` against `feat/opencode-go-extension` | Primary [x] |
| Top-level `set -e` for onboard remains unchanged | the port touches no shell file | Primary [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Port as a single squashed commit with one handover | operator fast-track; the six branch commits (pi bump, two feats, docs, two fixes) collapse into one record since the bump already landed on HEAD | this handover; operator direction |
| Thin refresh-overlay rather than a fork | pi composes a partial `registerProvider` into the built-in provider; the overlay inherits pi's correct transport/compat/thinking and only adds live membership | the branch records; this handover |
| `supportsReasoningEffort` is never set false on the overlay's compat | that explicit `false` is the root cause of the thinking regression on deepseek-family models | [`docs/models.md`](../../../docs/models.md); this handover |
| No roadmap row | provider infrastructure, not an M3.1 task | the branch records; this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The thinking regression was the removed extension's `supportsReasoningEffort: false`, not a pi bug; pi 0.87.1 ships a correct base catalog (30 opencode-go models) | record | validates the thin-overlay shape; the overlay must not disturb the baked config |
| The first import `@earendil-works/pi-ai/providers/opencode-go.models` does not resolve under pi's loader; the loader aliases only `pi-ai`, `/providers/all`, `/compat`, `/oauth` | fix (already in branch) | the overlay imports `getBuiltinModels` from `@earendil-works/pi-ai/providers/all`, the loader-aliased entry |
| The overlay must not fetch during the offline/cache refresh phase (`allowNetwork` false) or it aborts and surfaces "This operation was aborted" | fix (already in branch) | the guard returns the baked catalog before any fetch |
| The live environment's `models-store.json` still carries a stale 32-model `opencode-go` entry from the removed extension | record | container-transient; cleared on rebuild or by deleting the key; flagged in Deferred items |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/opencode-go.ts` | the refresh overlay: `refreshModels` returns the union of the baked catalog and the live-only models enriched from models.dev, with dead-correct compat/thinking (never `supportsReasoningEffort: false`), the `allowNetwork` offline guard, and provenance logging |
| this handover | written after verification |

## Deferred items

| Item | Reason | Where it goes |
|---|---|---|
| Rebuild the pi image and confirm the union is selectable in a real `/model` session | `pi --list-models` does not load extension providers, so it cannot prove the overlay | operator after `make build` |
| If the stale 32-model `models-store.json` opencode-go entry surfaces instead of the union, delete that store key | the overlay does not persist; the store entry shadows the union until removed | operator |

## What's Next

Operator rebuilds (`make build`), then in a real session confirms `deepseek-v4-flash` sends `thinking: {"type":"disabled"}` on off and `reasoning_effort` on low/medium/high/max, and the live-only models are selectable.

Read at iteration start: this handover, `docs/models.md`, and the extension file.

**Conclusions from this iteration:** the regression was the removed extension's compat flag, and pi 0.87.1's baked catalog is correct; the overlay restores live membership without reimplementing (and therefore without re-breaking) the provider config pi maintains. The port was a one-file replay because the bump and the extension removal were already folded into the current history by the earlier rewrite.
