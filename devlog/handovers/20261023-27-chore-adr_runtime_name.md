---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Housekeeping
status: Closed
---

# Handover - The ADR is named for its runtime

## Objective

Retire the word `backend` from the ADR's name and title and the word `pair` from the last six comments that used it for a provider and a model, so both tokens survive only where a reader is told they are retired.

## Scope

`docs/adr/opencode_dispatch_backend.md` and its three inbound links, the `model-failover` extension's comments, and one roadmap row.

The previous sweep renamed the live carriers and left two categories: the ADR's filename and title, which the closed row had put out of scope, and the failover extension's `physical pair`, which I had argued to keep because it names what pi reports. The operator overruled both on 2026-10-23: the file is named for its principle, which is that dispatch reaches OpenCode through its runtime, and the extension's comments name the two fields they actually hold.

Out of scope: the extension's behaviour and its survival, which the failover A/B row decides, and the vocabulary's deprecated-token lines, which are where a reader learns the words are retired.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR is named for the principle and its title matches | `ls docs/adr/opencode_runtime_dispatch.md`, first line reads `# OpenCode as a Dispatch Runtime` | Agent [x] |
| No inbound link points at the old name | `grep -rn opencode_dispatch_backend --include=*.md .` reaches only handovers and drafts, which are history | Agent [x] |
| The extension's six comments name the provider and the model | `grep -rn pair src/reasoning/providers/pi/config/agent/extensions/model-failover/` prints nothing | Agent [x] |
| The retirement declarations keep both tokens | `grep -n "Deprecated tokens" docs/reference/terminology.md` names `backend` under `runtime` and `pair` under `assignment` | Agent [x] |
| The gate and the extension's suite are clean | `bash scripts/lint.sh` across 12 gates, `node --test` over the extension's tests | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The ADR becomes `opencode_runtime_dispatch.md`, titled "OpenCode as a Dispatch Runtime" | the principle is that dispatch reaches OpenCode through its runtime; the install is that principle's rationale, and the old name was the token the vocabulary retired | the ADR, and the roadmap row |
| The extension's comments say the provider and the model rather than `assignment` | that object carries no runtime and no thinking level, so the reserved term would claim two fields it does not have; naming the two fields keeps one word for one thing | [`router.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/router.ts) and its siblings |
| The deprecated-token lines keep both words | a line that retires a word has to name it; deleting those lines would leave a reader with no statement that the words are out | [`terminology.md`](../../docs/reference/terminology.md) |
| The extension's behaviour is untouched | the A/B row decides whether the extension survives, and a comment rename must not pre-empt it | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The closed row **The word `backend` survives the rename** put the ADR's name out of scope, and the operator's ruling supersedes that | record | a reader of the closed row would take the filename for a settled decision | the new row above, which closes the retitle with the operator's direction named |

## Completed

| File | Change |
|---|---|
| [`docs/adr/opencode_runtime_dispatch.md`](../../docs/adr/opencode_runtime_dispatch.md) | renamed by `git mv` from `opencode_dispatch_backend.md`, title reads `# OpenCode as a Dispatch Runtime` |
| [`docs/adr/reasoning_layer_tiers.md`](../../docs/adr/reasoning_layer_tiers.md) | its link follows the rename |
| [`devlog/roadmap.md`](../roadmap.md) | two inbound links follow the rename, and the retitle closes as its own row |
| [`router.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/router.ts), [`index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/index.ts), [`types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts) | six comments name the provider and the model |
