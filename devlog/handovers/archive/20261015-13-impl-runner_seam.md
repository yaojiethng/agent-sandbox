---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The runner seam

## Objective

One command builder with two backends, so a brief names a role and not a runtime, and a model only the OpenCode CLI reaches dispatches through it. This is the row that ships OpenCode as a usable dispatch subagent.

## Scope

The new lib and its CLI, the test, the one proven launch site, and the roadmap row.

Out of scope: the launch-site sweep, deferred to M3.6.3; the per-request measurement, which is M3.6.2; the provider decision, the next row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A role resolves to a `(provider, model)` pair and a level | `bash tests/test_dispatch.sh`, 14 cases with literal expectations | Accepted |
| An OpenCode-only provider selects the CLI backend | the same suite, the backend and override cases | Accepted |
| The two flag mappings are correct | the same suite, the command cases: pi `--provider/--model/--thinking`, opencode `-m/--variant --auto --dir` | Accepted |
| A missing role refuses rather than guesses | the same suite, the refusal cases, rc 1 | Accepted |
| The seam dispatches on the OpenCode backend end to end | `dispatch_command` built `opencode run --auto --dir ... -m opencode/cat-jam-free --variant high`; `bash -c` returned rc 0 in 4 seconds and the log carries `seam-ok` | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The backend is chosen by provider, over a declared opencode-only set | the measured boundary is a provider property: pi answers `403 FreeTierError` because the free tier is served only from the OpenCode app | the lib header; `DISPATCH_OPENCODE_PROVIDERS` |
| The thinking level maps to `--variant` on the OpenCode backend | `opencode run --help` names `--variant` as the reasoning-effort flag and has no `--thinking` value flag | the lib; the test |
| The builder prints a command carrying the brief's path, and the caller reads it at run time | the brief text stays out of the command string and the log | the lib; the test |
| The seam stays one lib, and one launch site is migrated now | the sweep touches 20 files that carry a `pi` invocation, most of them runbooks and prose; migrating one proves the shape and the sweep is M3.6.3 | this record; the roadmap row |

## Propagation

The measured launch-site count is 20 files in the live tree carrying a `pi` subagent invocation, by `grep -rlE "pi (-p|--provider|--model)"` over `.agents/`, `docs/`, `src/`, `workflow/` and `devlog/` minus handovers, tests and the seam. The runbooks among them are the executable sites.

| File | Change planned | Status |
|---|---|---|
| [`.agents/drafts/parallel-work.md`](../../../.agents/drafts/parallel-work.md) | the dispatch block calls `scripts/dispatch.sh` | Done |
| the remaining 19 files | migrate or record why they keep their own form | Deferred to M3.6.3 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `pi --provider opencode --model cat-jam-free` answers `403 FreeTierError`. The free tier is served only from inside the OpenCode app, so the CLI is the sanctioned route and no spoofing is needed. | measurement, confirms the seam premise | M3.6.2, M3.6.3 |
| `opencode run --format json` emits one JSON object per line: `step_start`, `text`, `step_finish`. `step_finish` carries `tokens` (input, output, reasoning, cache read and write) and `cost`. | measurement | the M3.6.2 OpenCode ledger source is now a known shape |
| `opencode` is not on `PATH`; it resolves at `$AGENT_HOME/opencode/node_modules/.bin/opencode` (v1.19.1). The seam resolves the binary from `DISPATCH_OPENCODE_BIN` with that default. | environment | the seam handles it; the provider decision may put it on `PATH` |
| The role table's `_ADVISOR` names `openrouter/z-ai/glm-5.3-flash`, a pi-served provider, so the seam selects the pi backend for it. | observation | no action |

## Completed

| File | Change |
|---|---|
| [`src/libs/dispatch.sh`](../../../src/libs/dispatch.sh) | new: the role resolver, the backend rule, the command builder |
| [`scripts/dispatch.sh`](../../../scripts/dispatch.sh) | new: the CLI entry point over the lib |
| [`tests/test_dispatch.sh`](../../../tests/test_dispatch.sh) | new: 14 cases over the builder |
| [`.agents/drafts/parallel-work.md`](../../../.agents/drafts/parallel-work.md) | the dispatch block uses the seam |
| [`devlog/roadmap.md`](../../roadmap.md) | the runner-seam row records the proof and the propagation decision |
