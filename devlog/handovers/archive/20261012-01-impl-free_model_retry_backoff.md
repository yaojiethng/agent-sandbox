---
date: 2026-10-12
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
---

# Handover - the free-model retry policy in the pi config

## Objective

Give the reasoning layer a retry policy that starts at 1s, doubles each attempt, and keeps retrying until the backoff passes 1h, and settle whether the models.dev metadata warning at startup is a defect.

## Scope

One operator-raised change, mapped to no roadmap task. The retry block lands in the pi config source and in the container's installed copy, because the source seeds the copy and the two must not diverge. Two adjacent items stay out of scope: the pre-existing uncommitted `models.json` delta from 2026-10-11, recorded under Findings and left untouched, and any per-model retry scoping, recorded under Decisions pending.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The retry block is present in the shipped config source | `jq '.retry'` shows enabled, maxRetries 13, baseDelayMs 1000, maxAgentDelayMs 3600000 | accepted |
| The installed copy matches the source | `diff` of the two files is empty, and `jq empty` passes on both | accepted |
| The backoff sequence passes 1h exactly at the last retry | retry 13's nominal delay is 1000ms times 2^12 = 4096s, past the 3600s ceiling; retries 1-12 run 1s to 2048s uncapped | accepted |
| The models.dev warning is benign | the warning names an aborted fetch, pi keeps its baked catalog, and the model list resolves | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/settings.json`](../../../src/reasoning/providers/pi/config/agent/settings.json) | carries the shipped retry policy for the reasoning layer |
| `~/.pi/agent/settings.json` | the live copy the agent runs against; it sits outside the tree, so the source is its record |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Apply the retry policy to every model, not to free models only | pi's `RetrySettings` exposes no model or provider scope, so a free-model-only policy cannot be expressed | this handover and the config source |
| Keep both config copies identical | the container copy is seeded from the repo source, and divergence leaves the shipped config describing a runtime it does not match | the two settings.json files |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Does riding out opencode-go free-tier caps warrant roadmap work? | nothing this iteration; it decides whether a future iteration pursues a scoped mechanism | leave as-is, because transient errors are covered and caps still fail fast; add a roadmap row for per-model retry scoping; switch models when `FreeUsageLimitError` arrives |

## Findings

| Finding | Type | Impact |
|---|---|---|
| pi runs one retry policy for every model, and opencode-go free-tier limit errors (`FreeUsageLimitError`, `GoUsageLimitError`, "Monthly usage limit reached", "available balance") are non-retryable by design | contradiction | current iteration |
| `models.json` holds an uncommitted `space-bunny-free` deletion made on 2026-10-11, before this iteration | scope change | current iteration |
| the models.dev metadata fetch aborts in this container, and pi falls back to its baked catalog | obstacle | current iteration |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/config/agent/settings.json`](../../../src/reasoning/providers/pi/config/agent/settings.json) | add the retry block: enabled, maxRetries 13, baseDelayMs 1000, maxAgentDelayMs 3600000 |
| [`devlog/handovers/archive/20261012-01-impl-free_model_retry_backoff.md`](20261012-01-impl-free_model_retry_backoff.md) | this handover |
