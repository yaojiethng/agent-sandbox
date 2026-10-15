# Does a thinking level reach the DeepSeek API?

**Status:** settled

## Direction and parent story

Operator-directed diagnosis, 2026-10-04. No parent story: the operator asked whether the `deepseek` provider's `deepseek-flash` served `low` as `low`, and the answer became a config fix, an offline check, and this record. The work lands in the T12 roadmap row for the shipped pi config.

## Required reading

- [`src/reasoning/providers/pi/config/agent/models.json`](../../src/reasoning/providers/pi/config/agent/models.json)
- [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) `## Thinking levels`
- [`tests/extensions/pi/model-refresh/knowledge/knowledge_opencode_gateway_matrix.sh`](../../tests/extensions/pi/model-refresh/knowledge/knowledge_opencode_gateway_matrix.sh)

## Summary

The shipped `models.json` overrides are keyed on model ids, and pi applies an override only when the key equals the model's id in the provider's baked catalog. Three keys named ids pi does not bake, so nothing applied them: `deepseek-v4-flash` under `deepseek`, where the baked id is `deepseek-flash`, and the two unprefixed ids under `openrouter`, where pi bakes `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. A stale key is silent. The baked map's `null` for `low` stood, and pi clamped a request for `low` up to `high`. The named pair, `deepseek/deepseek-flash`, was never affected: its baked map already names `low`, and pi sends `reasoning_effort: "low"`. It reasons heavily at `low` because the model does, not because the config failed.

## Findings

### The API surface, measured on 2026-10-04

`GET https://api.deepseek.com/models` returns, for both models, `effort.supported_levels: ["low","high","max"]` and `effort.default_level: "high"`.

The chat endpoint validates the field. `reasoning_effort: "bogus"` returns HTTP 422 with the accepted set: `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `ultra`, `max`. The chat endpoint therefore accepts more levels than the model metadata advertises.

Both off spellings suppress reasoning completely. `reasoning_effort: "none"` and `thinking: {type: "disabled"}` each returned `reasoning_content` of length 0 and no `reasoning_tokens`, while still answering in full (3481 to 5066 characters across three samples).

### The dead keys, and the clamp they caused

The effective wire payload per pair, before the fix and after:

| Pair | `low` sends before | `low` sends after |
|---|---|---|
| `deepseek/deepseek-flash` | `thinking:{type:"enabled"}, reasoning_effort:"low"` | unchanged |
| `deepseek/deepseek-v4-pro` | `... reasoning_effort:"low"` | unchanged |
| `openrouter/deepseek/deepseek-v4-flash` | `reasoning:{effort:"high"}` | `reasoning:{effort:"low"}` |
| `openrouter/deepseek/deepseek-v4-pro` | `reasoning:{effort:"high"}` | `reasoning:{effort:"low"}` |

The `deepseek` provider's `deepseek-v4-flash` override was dropped rather than renamed: the baked `deepseek-flash` map already names every level the API advertises, and the override's extra `minimal` and `medium` sit below that advertised set.

### The measurement

The operator's symptom is a long thinking trace at `low`. Two measurements bound it.

The first is the session that raised it. It ran on `deepseek/deepseek-flash` at level `low` for 525 assistant turns, all at `low`:

| Measure, per turn | p50 | p90 | max |
|---|---|---|---|
| reasoning tokens | 235 | 1366 | 6353 |
| thinking-text characters | 905 | 5781 | 26646 |

The second is a live probe of the same model at `low` on a single hard prompt, six samples: 3587, 9951, 8864, 7724, 10420, 7790 reasoning tokens. `high` reached the 12000-token cap on four of six samples and `max` on all six. `off` returned 0 on all six. So `low` is the lowest working level, and it is still thousands of tokens on a hard task.

A paired run on the proof prompt, twelve samples per arm, separates `low` from `high` even with the `thinking` toggle present: mean 180 against 260 reasoning tokens, rank-sum U 23 against 121. `thinking` alone gave mean 236, and `reasoning_effort:"low"` without `thinking` gave mean 183. So the `thinking` toggle does not lift `low`.

### The probe prompts

Preserved verbatim, so a later reader reproduces the same measurement.

```text
How many positive integers n<1000 satisfy: n is divisible by 3, n+1 is divisible by 5, and n+2 is divisible by 7? Think step by step.
```

```text
A snail climbs 3 m a day and slips 2 m each night in a 10 m well. How many days to reach the top? Answer with the number only.
```

```text
Prove or disprove: for every positive integer n, n^2+n+41 is prime. Think carefully step by step, then give a one-line verdict.
```

```text
Design a lock-free MPMC bounded queue: give the algorithm, the memory-ordering argument, and the ABA problem handling. Be concise.
```

```text
Say ok
```

## Open Questions

- Whether `reasoning_effort: "minimal"` is lower than `low` on `deepseek-flash`. The parser accepts it; the model metadata does not advertise it. On the hard prompt both `low` and `minimal` saturated the 6000-token cap, so the probe did not separate them.
- Whether `openrouter/deepseek/*` honours `"low"` upstream. The fix makes pi send it; only a probe of OpenRouter confirms the answer.

## Constraints

Reasoning-token counts are noisy on any task hard enough to separate the levels. A single sample proves nothing; the paired run above needed twelve per arm to separate two levels.

## Next Steps

Replaced by Resolution at closure.

## Resolution

Adopt the config fix and the offline check. The three stale keys are resolved: the two `openrouter` keys take the `deepseek/` prefix, and the dead `deepseek` key is dropped. The check lives in `config.test.ts` and catches the class with no key and no network. The live effort probe stays unwritten, by operator direction, and remains an option: a knowledge script that names a provider and model, records the wire payload per level, sends N repeats per level, and reports the reasoning-token distribution and a rank-sum separation between adjacent levels. Its limit is the noise above, plus an API key and dozens of requests. The two open questions are the probes that would justify it.
