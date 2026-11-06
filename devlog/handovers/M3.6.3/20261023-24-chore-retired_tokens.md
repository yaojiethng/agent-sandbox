---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Housekeeping
status: Closed
---

# Handover - The retired tokens leave the live carriers

## Objective

Retire the two deprecated tokens, `backend` and `pair`, from every live carrier that used either where it meant a runtime or an assignment, so the vocabulary's source of truth stops being contradicted by the tree around it.

## Scope

The two open rows **The word `backend` survives the rename** and **The word `pair` survives the rename**, and the carriers each names.

A token retired in the vocabulary survives in the documents and the code beside it. The previous iteration met one carrier while writing an ADR, and filed the sweep rather than folding it in. This unit takes both rows together because they are one class, one reading habit, and one pass over the same files.

Out of scope, each with its reason. The two ADR filenames keep the token, because a stable name is what other documents link to and the rows put a historical title out of scope. A `pair` of two arbitrary things stays wherever it names two things and not an assignment: two reviewer seats, a skill and its script, a key and its value, a commit and its inverse. `src/reasoning/providers/pi/config/agent/extensions/model-failover/` keeps `physical pair`, because there it names a provider and a model as pi's own API reports them, and the extension quotes that API rather than using this vocabulary.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No live dispatch carrier uses `backend` for a runtime | `grep -rn backend` over `scripts/`, `src/libs/dispatch/`, the two `AGENTS.md` layers and `docs/reference/` returns only the deprecated-token line and the ADR filenames | Agent [x] |
| The ledger's field and its reader agree | `bash tests/test_cost_ledger.sh` passes, and its record carries `runtime` | Agent [x] |
| No live dispatch carrier uses `pair` for an assignment | the same grep over the same set returns the deprecated-token line and the deliberate `pair of two things` uses only | Agent [x] |
| The reviewer runner and its test agree on the new word | `bash tests/test_review_dispatch.sh` passes at 9 cases, including the usage line and the refusal message | Agent [x] |
| The pinned-assignment path still refuses a malformed pin | `bash tests/test_dispatch.sh` passes at 52 cases | Agent [x] |
| The installed pi layer states what the source states | `diff -q src/reasoning/providers/pi/config/agent/AGENTS.md ~/.pi/agent/AGENTS.md` prints nothing | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1311 across 95 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The ledger's field becomes `runtime` rather than being dropped | the field answers which executable ran the session, and `runtime` is the term the vocabulary defines for that; a reader of one record should not have to translate | [`cost_ledger.mjs`](../../scripts/cost_ledger.mjs) and its test |
| The reviewer runner's argument, variable and messages all take the new word | a half-renamed refusal message would teach the retired term at the moment a caller reads why the call failed | [`review-dispatch.sh`](../../src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh) |
| A `pair` of two arbitrary things is left alone | the token is deprecated where it means an assignment, and a pair of seats or of key and value is the word's ordinary sense; renaming those would trade one inaccuracy for another | this record |
| The `model-failover` extension keeps `physical pair` | it names what pi reports on the route, so the words are the API's and not this vocabulary's | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `pair` row filed last iteration named two skill-scaffolder pages as carriers, and both use the word for a pair of units rather than an assignment | record | the row would have sent the next reader to rename two correct sentences | corrected here: the row closes with the two pages named as deliberate uses |
| The `backend` row named `reasoning_layer_tiers.md` as a carrier, and its occurrence is inside a link to the ADR filename rather than the token | record | the count in the row pointed at a filename the same row puts out of scope | corrected here: the row closes with the filename named as the surviving carrier |
| `src/reasoning/providers/pi/config/agent/extensions/model-failover/` carries the word `pair` for a provider and a model in six places | mechanism | a reader of that extension meets the retired token, but it names pi's own route concept rather than a dispatch assignment | no change: the extension quotes an external API's terms, and the failover A/B row decides whether the extension survives at all |

## Completed

| File | Change |
|---|---|
| [`scripts/cost_ledger.mjs`](../../scripts/cost_ledger.mjs) | the record field `backend` becomes `runtime` |
| [`tests/test_cost_ledger.sh`](../../tests/test_cost_ledger.sh) | reads `.runtime` |
| [`src/libs/dispatch/table.ts`](../../src/libs/dispatch/table.ts) | the comment says the request fails at the provider, not at the backend |
| [`src/libs/dispatch/cli.ts`](../../src/libs/dispatch/cli.ts) | the local name for a pinned assignment is `pinned`, not `pair` |
| [`src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh`](../../src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh) | the comment, the usage line, the argument, the refusal message and the printed line say assignment |
| [`tests/test_review_dispatch.sh`](../../tests/test_review_dispatch.sh) | case names, labels and the usage and refusal assertions follow |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | one label says assignment |
| [`scripts/check_launch_sites.sh`](../../scripts/check_launch_sites.sh) | the allowlist comment says the reviewer's runner takes its assignment from its caller |
| [`AGENTS.md`](../../AGENTS.md) | the dispatch procedure resolves and records an assignment, four places |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the reviewer block and the dispatch procedure say assignment, seven places; the installed copy is byte-identical |
| [`src/reasoning/agent/prompts/advisor.md`](../../src/reasoning/agent/prompts/advisor.md) | the resolution line names an ordered assignment list |
| [`docs/adr/single_source_model_recommendations.md`](../../docs/adr/single_source_model_recommendations.md) | the current entry and its rationale say assignment where they meant one |
| [`docs/adr/opencode_dispatch_backend.md`](../../docs/adr/opencode_dispatch_backend.md) | the rationale says a dispatch runtime and a session runtime are different jobs |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | the `launch site` entry says a fixed run takes its assignment from its caller |
| [`devlog/roadmap.md`](../roadmap.md) | both token rows close here |
