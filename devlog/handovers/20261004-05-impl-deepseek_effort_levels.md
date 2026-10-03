---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
---

# Handover - Implementation: the shipped pi config's effort levels are checked

## Objective

Fix the three stale `models.json` override keys, add an offline check that resolves the effective model and prints the effort each thinking level puts on the wire, and record the DeepSeek effort diagnosis.

## Scope

Operator-directed intermission. It continues the `model-refresh improvements` parent row's audit thread but is not one of its three units: the subject is the shipped pi config (`src/reasoning/providers/pi/config/agent/models.json`), not the extension.

Targets the `models.json` override keys, a new offline check in the `model-refresh` suite, and the diagnosis record.

Out of scope: the live effort probe (item three of the diagnosis). The operator deferred it as a text record because it spends requests and returns a fuzzy verdict. The extension's `sources.json` is unchanged: it declares `opencode-go` alone, and its overrides are not dead.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | Every `models.json` provider override key matches a model id the provider's baked catalog carries, and the check fails when one does not | `node --test tests/extensions/pi/model-refresh/config.test.ts` passes; a temporary `deepseek-bogus` key turned it red with `names no model pi bakes; it is a stale key` | Agent [x] |
| 2 | The check prints the wire effort each thinking level produces for the shipped config's deepseek-family models | the check's stdout lists each provider/model/level, and node's test reporter prints it | Agent [x] |
| 3 | The two `openrouter` overrides apply: `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro` reach the effective model, and `low` no longer clamps to `high` | the check asserts the override landed and `wire(low) === "low"`; the payload is `reasoning:{effort:"low"}` | Agent [x] |
| 4 | The `deepseek` provider's dead `deepseek-v4-flash` key is resolved, with the reason recorded | the key is dropped; the record states the baked map already names every advertised level | Agent [x] |
| 5 | The check runs under `make test`, with the suite's registration guard covering it | the wrapper reports 10 node files, and the guard fails on an unregistered one | Agent [x] |
| 6 | The diagnosis is recorded: the probe prompts, the per-turn percentile table, the API surface facts, and the deferred live probe as an option | `devlog/discussions/20261004-study-deepseek_effort_levels.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/models.json`](../../src/reasoning/providers/pi/config/agent/models.json) | the three stale override keys; the `deepseek` key's resolution |
| [`tests/extensions/pi/model-refresh/config.test.ts`](../../tests/extensions/pi/model-refresh/config.test.ts) | new: the offline map and wire check, and its printed table |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | the registration guard gains the new file |
| [`devlog/discussions/20261004-study-deepseek_effort_levels.md`](../../devlog/discussions/20261004-study-deepseek_effort_levels.md) | new: the diagnosis record and the deferred live probe |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the T12 row for the fix and its check |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The dead-key check is the gate; the printed table is its diagnostic | the clamp is a symptom of a key that never matched, and only the key check catches that class; the table turns the clamp's effect into something a reader sees | this record; the check's header |
| The `deepseek` provider's `deepseek-v4-flash` override is dropped rather than renamed | the baked `deepseek-flash` map already names every level the API advertises (`low`, `high`, `max`), and the override's extra `minimal` and `medium` are below the API's own advertised set | this record; `models.json` |
| The live effort probe stays unwritten and is recorded as an option | operator, 2026-10-04: it spends dozens of requests and its rank-sum verdict is fuzzy on any task hard enough to separate the levels | the study document |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `git log -S'"deepseek-flash"'` on `models.json` returns nothing: the stale keys are not a code regression, they were written when pi's baked ids matched and stopped matching when pi renamed the native entry | measurement | this iteration, criteria 3 and 4 | Triaged to: this record; `20261004-study-deepseek_effort_levels.md` |
| `openrouter` may not honour `reasoning:{effort:"low"}` upstream. The fix makes pi send it; only an OpenRouter probe confirms the answer | assumption | next iteration if the probe is ever wanted | Triaged to: `20261004-study-deepseek_effort_levels.md` Open Questions |
| The check reads `models.json` beside the extension, so it skips in the mutation gate's mirror, which copies the extension alone. The gate still replays 44 rows and the suite stays green | method | recorded, no action | Triaged to: this record |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/config/agent/models.json`](../../src/reasoning/providers/pi/config/agent/models.json) | the two `openrouter` override keys take the `deepseek/` prefix; the dead `deepseek/deepseek-v4-flash` override is dropped |
| [`tests/extensions/pi/model-refresh/config.test.ts`](../../tests/extensions/pi/model-refresh/config.test.ts) | new: the offline config check, its dead-key gate, its wire assertion and its printed table |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | the registration guard gains `config.test.ts` |
| [`devlog/discussions/20261004-study-deepseek_effort_levels.md`](../../devlog/discussions/20261004-study-deepseek_effort_levels.md) | new: the API surface, the dead keys, the measurement, the probe prompts and the deferred live probe |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the T12 row for the fix and its check |
