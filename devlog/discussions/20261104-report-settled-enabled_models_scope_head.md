# The shipped `enabledModels` head and the saved default

**Status:** settled

Environment: `@earendil-works/pi-coding-agent` 1.3.0, Node 22.22.3, Linux x64. Measurements taken 2026-11-04 in `/home/agentuser/sandbox`.

## Context

The T12 row says the shipped `enabledModels` head is `failover/*` while the configured default is `deepseek/deepseek-flash`, so `findInitialModel` starts on the scope head and the saved default is discarded. The operator reports the opposite kind of failure in practice: a new project with the bundled `settings.json` and no DeepSeek key has started on `claude-haiku-5-5`, an expensive model the operator does not want to use or test against.

The investigation answers four questions.

1. What model does pi 1.3.0 select, and under which conditions?
2. Where does `settings.json` come from at each lifecycle step?
3. Which records state the wrong mechanism?
4. Do the knowledge tests cover the failure?

## Method

The selection probe starts a real `pi --mode rpc --no-session` process with `PI_CODING_AGENT_DIR` pointing at a fixture directory. The fixture holds a copy of the shipped `settings.json` and a copy of the current auth map. A scenario that needs the DeepSeek key absent deletes the `deepseek` entry from the auth map and removes `DEEPSEEK_API_KEY` from the child environment. The probe reads `get_state`, `get_available_models`, and repeated `cycle_model` responses, then terminates the process. It sends no prompt, so pi makes no model call and the expensive model is never contacted. The selected model is read from session state, which is the same value the session header records.

The lifecycle probes run `scripts/onboard.sh` in fresh and `--refresh` modes against `/tmp` directories, and run `src/reasoning/entrypoint.sh` with a temporary `AGENT_HOME` and a sentinel `settings.json`. The scripts are read for the exclusion and copy rules.

The records are read at the cited lines. The knowledge tests are read and run.

## The lifecycle of `settings.json`

| Step | What it does to the provider directory | Does it write `settings.json`? | Evidence |
|---|---|---|---|
| `agent-sandbox onboard` (first run) | Seeds the host provider directory from `src/reasoning/providers/<n>/config/`, excluding `agent/settings.json`, `agent/auth.json`, `agent/models.json`, and `agent/AGENTS.md`; renames `env.stub` to `.env`; the provider hook creates the mount directories | No | `scripts/onboard.sh:269-310`, measured in `/tmp/probe-sandbox`: no `settings.json`, prompts present |
| `agent-sandbox onboard --refresh` (`make refresh`) | Rewrites the sandbox `Makefile` and `.env` only; does not call `_provision_providers` | No | `scripts/onboard.sh:162-220`, `scripts/templates/Makefile.template:399`; measured prompt mtime unchanged |
| `make build` or `make start REFRESH=1` | Rebuilds the provider image from the installed agent-sandbox tree; the Dockerfile copies `src/reasoning/providers/pi/config/` to `/opt/workflow/agent/config/` | Bakes the template into the image | `src/reasoning/providers/pi/provider.dockerfile:19`, `src/build/container-interface.json` provision row |
| Container start | `provider-entrypoint.sh` copies `/opt/workflow/agent/config/agent/` over `$AGENT_HOME/agent/` with `cp -RT --no-preserve=all`, overwriting | Yes, every start | `src/reasoning/entrypoint.sh` `_provision_agent_home`; measured: a sentinel `settings.json` at `$AGENT_HOME` was replaced by the image copy |
| Session edit | The file is container-local, not mounted | It survives until the container stops | `docs/reference/provider_lifecycle.md:21,59` |

The consequence for the row is that changing `src/reasoning/providers/pi/config/agent/settings.json` reaches a project only after the provider image is rebuilt from that tree. `make refresh` does not carry it, and `agent-sandbox onboard` never writes it. The host copy under `$SANDBOX_DIR/.pi/agent/` is not the source; the seeded copy inside the container is not mounted back.

## The selection matrix

All rows use the shipped settings unless the row names a variant. "DeepSeek auth" means the auth map has a `deepseek` entry and `DEEPSEEK_API_KEY` is set in the child environment. "No DeepSeek auth" removes both.

| Scenario | Selected model | Scope diagnostics | Cost per 1M input/output |
|---|---|---|---|
| Shipped settings, DeepSeek auth | `deepseek/deepseek-flash` | `failover/*` no-match | direct DeepSeek price |
| Shipped settings, no DeepSeek auth | `opencode-go/claude-haiku-5-5` | `failover/*` no-match | 0.10 / 0.50 |
| Literal default head, `failover/*` removed, no DeepSeek auth | `openrouter/~deepseek/deepseek-flash-latest` | none | 0.00576 / 0.72 |
| Cheap fallback head `opencode-go/deepseek-v4.1-flash`, DeepSeek auth | `deepseek/deepseek-flash` | none | direct DeepSeek price |
| Cheap fallback head, no DeepSeek auth | `opencode-go/deepseek-v4.1-flash` | none | 0.15 / 0.60 |
| Empty `enabledModels`, no DeepSeek auth | `openrouter/moonshotai/kimi-k2.6` | none | measured from the returned model |
| Default authenticated but outside the scope (`opencode-go/*` only) | `opencode-go/claude-haiku-5-5` | none | 0.10 / 0.50 |
| Absent unique head `deepseek/zzz-absent`, no DeepSeek auth | `opencode-go/claude-haiku-5-5` | `deepseek/zzz-absent` no-match | 0.10 / 0.50 |

The cycle order follows the resolved scope. In the shipped no-key scenario, the cycle after `claude-haiku-5-5` is `opencode-go/minimax-m3`. In the cheap-fallback scenario it starts at `opencode-go/deepseek-v4.1-flash`.

### The approved fallback chain

The operator approved this order. The first entry that resolves to an authenticated model wins.

| Order | Pattern | Meaning |
|---|---|---|
| 1 | `opencode-go/deepseek-v4.1-flash` | the named cheap fallback |
| 2 | `openrouter/~deepseek/deepseek-flash-latest` | the OpenRouter equivalent |
| 3 | `openrouter/deepseek/deepseek-v4-flash` | a second OpenRouter DeepSeek id |
| 4 | `opencode-go/*` | the rest of the OpenCode Go catalog |
| 5 | `deepseek/*` | the direct DeepSeek catalog |
| 6 | `openrouter/z-ai/*` | the existing OpenRouter families |
| 7 | `openrouter/qwen/*` | the existing OpenRouter families |

Measured with the chain:

| Auth configured | Selected |
|---|---|
| DeepSeek, OpenCode, OpenRouter | `deepseek/deepseek-flash` |
| OpenCode, OpenRouter | `opencode-go/deepseek-v4.1-flash` |
| DeepSeek, OpenRouter | `deepseek/deepseek-flash` |
| OpenRouter only | `openrouter/~deepseek/deepseek-flash-latest` |
| none | `unknown/unknown` placeholder |

The chain answers the "what if opencode is also absent" question. A third literal covers OpenRouter, and the normal scoped-model wildcards follow it. The operator rejected zero-cost literals, so the chain stops at the paid OpenRouter entry. The chain is not a hard guarantee. A later literal can be skipped when an earlier unavailable literal fuzzy-matches a lookalike on another provider. A provider outside the chain can still win when the scope resolves empty. A completely unconfigured environment selects the `unknown/unknown` placeholder instead of refusing to start.

## The mechanisms, in order

The CLI does not call `findInitialModel` with the scope. `buildSessionOptions` in `dist/main.js:390-401` resolves the scope first, and when the saved default is a member of the resolved scope it selects that default before `findInitialModel` runs. This is why the shipped head `failover/*` does not change the starting model when the DeepSeek key is present. The `findInitialModel` scope-first rule is real, but the CLI passes a model, and the SDK path that calls `findInitialModel` passes `scopedModels: []` (`dist/core/sdk.js:104-116`).

When the DeepSeek key is absent, the saved default is not in the resolved scope. The scope is resolved against `modelRuntime.getAvailable()`, which filters by configured auth, so `deepseek/*` contributes nothing. The first pattern that matches decides. With `failover/*` first and matching nothing, `opencode-go/*` is next, and the first `opencode-go` model in catalog order is `claude-haiku-5-5`. That is the operator's symptom, reproduced without contacting the model.

A non-glob pattern that does not resolve is matched fuzzily against available models (`resolveModelReference` with `fuzzy: true`, `dist/core/model-resolver.js:272`). A literal head `deepseek/deepseek-flash` therefore resolves to `openrouter/~deepseek/deepseek-flash-latest` when DeepSeek is unauthenticated. The literal head is not a pin. It becomes a request for any model whose id resembles the pin, and the chosen provider is whichever authenticated catalog carries it.

An empty scope is not a fail-closed state. `buildSessionOptions` leaves the model unset, and the SDK's `findInitialModel` runs with `scopedModels: []`. The saved default fails the auth test, so step 3 walks `defaultModelPerProvider` and selected `openrouter/moonshotai/kimi-k2.6`. Removing the expensive provider patterns does not make the missing key loud; it changes which silent fallback wins.

When no provider is authenticated, the scope resolves empty and pi does not refuse to start. It selects a placeholder model with provider `unknown`, id `unknown`, empty `baseUrl`, and zero context. The first request fails. The harness does not add a startup guard: it passes the environment and starts pi, and pi resolves credentials and offers `/login`. The principle and its rejected alternatives are in [`provider_auth_resolution.md`](../../docs/adr/provider_auth_resolution.md).

The scope still bounds the session. When the saved default is authenticated but outside the scope, the scope wins and the session starts on the scope head. That is the legitimate case for a scope, and it is the case the old mitigation described. It is not the case that produced haiku.

## Where the records are wrong

| Record | Claim | Measured behavior | Correction |
|---|---|---|---|
| `devlog/roadmap.md:793` (T12 row) | `enabledModels[0]` being `failover/*` makes `findInitialModel` start on the scope head and discard the saved default | With the DeepSeek key present the session starts on `deepseek/deepseek-flash`. With the key absent the session starts on the first `opencode-go` model, not the `failover/*` head | The row's premise holds only when the saved default is outside the resolved scope. The haiku case is a missing-key fallback, not a head-order defect |
| `model-refresh/README.md:265` | A non-empty scope outranks the saved default; `findInitialModel` returns `scopedModels[0]` on any non-empty scope | The `findInitialModel` statement is true, but the CLI pre-selects an in-scope saved default before that function runs | Name the CLI preference and the unauthenticated/outside-scope cases separately. The mitigation rationale is stale |
| `model-refresh/README.md:263` | The first entry is the model a session starts on when the scope outranks the saved default, and the first model the cycle key moves to | The first clause holds only in the outside-scope case. The cycle-order clause holds in every case | Keep the cycle-order claim, qualify the start-model claim |
| `model-refresh/default-model.ts:4-6` | `findInitialModel` consults the scope before the saved pair, so a configured default is dropped with no message | True of `findInitialModel`. The CLI path does not use it that way when the default is in scope. An unauthenticated default is dropped silently, and the extension's guard stays silent by design | Scope the comment to the resolver, or state the CLI path |
| `tests/knowledge/knowledge_pi_config_cycle.sh:16-18,97-99` | The first `enabledModels` entry decides the model every session starts on | False when the saved default is in scope; false when the head is an unavailable literal that fuzzy-matches another provider; true only when the default is outside the scope | Replace the causal comment with a behavior matrix that asserts the selected model |
| `docs/adr/single_source_model_recommendations.md:79` | A `No models match pattern` message means pi fell back to the startup default | A no-match means one pattern did not match. The fallback can be the next scope pattern, the provider-default sweep, or the first available model. The literal-head scenario prints no warning and still falls back | State that the warning is not a fallback signal, and verify the model from the session header |
| `docs/reference/provider_lifecycle.md:65` | `agent-sandbox onboard` seeds the same tree into `$SANDBOX_DIR/.<provider>/` | The rsync excludes `settings.json`, `auth.json`, `models.json`, and `AGENTS.md` | Say the onboard seed covers the mount directories and `.env`, not the config files |
| `docs/reference/agent_workflow.md:84` | The provider layer's update mechanism is `onboard.sh --refresh`, or editing `$SANDBOX_DIR/.<provider>/` | `onboard.sh --refresh` rewrites the Makefile and `.env` only; it does not re-provision the provider directory. The prompts/skills are host-mounted and editable; the config files are image-owned | Name `make build` or `make start REFRESH=1` for the config template, and the host edit for prompts/skills |
| `docs/development/provider_onboarding_guide.md:93` | A project onboarded earlier needs `agent-sandbox onboard --refresh` to pick up a new provider's config | Refresh does not re-provision provider directories | Say the project needs a fresh onboard, or the provider directory copied, plus an image rebuild |

## What the knowledge tests cover

`tests/knowledge/knowledge_pi_config_cycle.sh` asserted two things: the `packages` roots are present, and `enabledModels[0]` equals `defaultProvider/defaultModel`. The second assertion compared two strings, never started pi, and could not fail for the haiku scenario. The implementation removes it and leaves the harness-roots case. `tests/knowledge/knowledge_pi_model_selection.sh` now drives pi's RPC `get_state` over four auth configurations and asserts the selected model, with no prompt and no model call.

The removed comments carried the causal claim the assertion did not test. In the operator's terms, the comments are the authority and the outcomes are not. A test shaped as predicate-to-conclusion would print and assert "if the DeepSeek key is absent and the head is `failover/*`, then the selected model is `opencode-go/claude-haiku-5-5`", and fail when pi's behavior changes. That is the shape the selection probe already uses.

`tests/extensions/pi/model-refresh/knowledge/knowledge_model_refresh_real_load.sh` exercises the extension's TUI branch but passes `--provider opencode-go --model space-bunny-free` explicitly, so it does not exercise scope resolution. The model-refresh unit tests assert the `discardedDefault` notice, including silence when the saved default is unauthenticated. That silence is a design choice, and it is why the haiku start produced no notice.

## Candidate changes and measured effects

These are measured options, not decisions.

| Option | With DeepSeek key | Without DeepSeek key | Trade-off |
|---|---|---|---|
| A. Literal default head, `failover/*` removed (the row's original fix) | `deepseek/deepseek-flash` | `openrouter/~deepseek/deepseek-flash-latest` | Avoids haiku, but the head is not a pin. The fuzzy match chooses another provider and prints no warning. The head-equals-default guard passes while the behavior is still not the default |
| B. Cheap fallback chain (approved) | `deepseek/deepseek-flash` | `opencode-go/deepseek-v4.1-flash`, then `openrouter/~deepseek/deepseek-flash-latest`, then the broad families | Predictable fallback for the three configured providers. The head no longer equals the default, so the current guard must be replaced by a behavior test. If no provider is authenticated, the `unknown/unknown` placeholder wins |
| C. Make the unauthenticated default visible | `deepseek/deepseek-flash` | The selection is unchanged; a startup notice names the configured default and the selected model | Changes no selection. The `discardedDefault` guard currently ignores unauthenticated defaults, so this is a rule change with its own tests |
| D. Upstream pi change | unchanged | A saved default that is absent or unauthenticated is reported, and startup either stops or asks for a model instead of selecting a fallback | Fixes the class, not this repository. The existing report's Finding 1 is already implemented in the 1.3.0 CLI for the in-scope case; the unauthenticated case and the fuzzy literal match remain |
| E. Write a project-level default during onboarding | depends on the project's auth | the written default | Requires a new mechanism. The image owns `settings.json`, onboard writes no config file, and a project-level file does not exist today |

Option B is the approved settings-only change. It keeps the saved default when it is available and walks a named chain when it is not. The operator declined zero-cost literals and directed the chain to fall through to the normal scoped-model wildcards. Option C is the complement if the operator wants the substitution to be visible rather than silent. Option D is the only option that makes a totally unconfigured environment fail closed, and it belongs upstream.

The head-equals-default assertion should not survive any of A, B, or C in its current form. Under A it passes while the selected model can still differ from the default. Under B it must fail by design. The assertion measures the wrong thing. A behavior test that drives pi's RPC surface measures the thing the operator cares about.

## Outcome

The operator approved option B and released the unit on 2026-11-04. The chain is in `src/reasoning/providers/pi/config/agent/settings.json`, and `failover/*` is gone. The head-equals-default assertion is retired for `tests/knowledge/knowledge_pi_model_selection.sh`, a comment-free RPC test over the four auth configurations. The `model-refresh` README and `default-model.ts` state the measured CLI preference. The no-auth row is withdrawn: the harness does not guard it, and the principle is [`provider_auth_resolution.md`](../../docs/adr/provider_auth_resolution.md). The upstream report stays with the T12 `pi upstream` row. The durable-settings question is at M3.2.3. Implementation handover `20261104-02`.

The settings change reaches a project only after `make build` or `make start REFRESH=1`; `make refresh` does not rebuild the provider image.

## Appendix: the probe

The session-local probe is `.scratchpad/probe-model-selection.mjs`. The essential sequence is below. `settingsPath` is copied to `$PI_CODING_AGENT_DIR/settings.json`; `auth.json` is copied with the `deepseek` entry removed for the no-key scenario.

```js
const child = spawn("pi", ["--mode", "rpc", "--no-session"], {
  cwd: "/tmp/probe-model-selection/project",
  env: { ...process.env, PI_CODING_AGENT_DIR: agentDir },
  stdio: ["pipe", "pipe", "pipe"],
});
child.stdin.write(JSON.stringify({ type: "get_state", id: "state" }) + "\n");
// read the JSONL response, then:
// { type: "response", id: "state", command: "get_state",
//   data: { model: { provider, id, cost, ... } } }
child.stdin.write(JSON.stringify({ type: "cycle_model", id: "cycle" }) + "\n");
// repeat cycle_model until the model repeats to read the scope order
child.kill("SIGTERM");
```

The full probe also sends `get_available_models` and prints the first entries, which is how the `opencode` and `opencode-go` catalogs were distinguished. No prompt is sent, so the probe cannot incur a model charge. That property is worth preserving if the probe is promoted into a test.
