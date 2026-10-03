# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Documentation
**Status:** Closed

## Objective

Report the default-model resolution defect against pi in the form a maintainer with no access to this repository can act on, and land the settings change that makes the shipped configuration behave as the operator specified.

## Scope

The roadmap row "Default model resolution: the report, and the settings mitigation". The operator reported that their configured default model was not taking effect, rejected a settings-only fix in favour of the correct upstream semantics, and asked for a bug report in the format of the existing opencode-go provider report.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The report's central claim is measured against the shipped resolver, not a re-implementation of it | the four-row table, produced by driving `findInitialModel` and `resolveModelScopeFromModels` with an injected catalog and auth set | accepted |
| 2 | The report names the code a maintainer edits | line-anchored excerpts from `dist/core/model-resolver.js` on 0.87.1 | accepted |
| 3 | The report carries no reference to this repository, its process, or temporary paths | read of the shipped file | accepted |
| 4 | Version drift is labelled rather than implied | the report's `## Version drift` section | accepted |
| 5 | The verification section names the two guards on its own check | the auth-set guard and the `fallbackMessage`-content guard | accepted |
| 6 | The shipped settings select the configured default | `tests/knowledge/knowledge_pi_config_cycle.sh`, 6 of 6 | accepted |
| 7 | A reorder of the scope is caught rather than shipped | a deliberate rotation of `enabledModels` turned the new case red; the file restored and compared byte-identical | accepted |
| 8 | The whole suite is green | `bash scripts/run_tests.sh`, 1012 of 1012 | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/discussions/20261002-report-draft-default_model_resolution_bug.md`](../discussions/20261002-report-draft-default_model_resolution_bug.md) | the report |
| [`src/reasoning/providers/pi/config/agent/settings.json`](../../src/reasoning/providers/pi/config/agent/settings.json) | set a default and a scope head that contradicted it |
| [`tests/knowledge/knowledge_pi_config_cycle.sh`](../../tests/knowledge/knowledge_pi_config_cycle.sh) | the new case that holds the two settings together |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Report the defect rather than work around it in the resolver | the operator's semantics ("load the full list then pick the default from there") is a change to pi's code, which is the report's subject and not this repository's | the report, Finding 1 |
| Mitigate in the settings by putting the exact default at the head of the scope | the scope's first entry decides the model, so the head is where a default belongs until pi honours the default properly. It also makes the model-cycle key start where the user expects | `enabledModels` in the onboard settings |
| Pin the head-equals-default relation in a knowledge case rather than a unit test | the thing being held is a relation between two settings fields and a third list, which is a configuration fact rather than a function's behaviour, and the existing file already inspects the real settings | `test_scope_head_names_the_default` |
| Do not write outside the working tree | the operator asked for `~/.pi/agent/settings.json` to be updated. It is outside the sandbox boundary, so an edit there would not appear in the reviewed diff. The repository file carries the change | decisions-pending row below |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Should the harness boundary be extended so an agent can write `~/.pi/agent/settings.json`? | keeping the live user settings in step with the onboard template without the operator editing it by hand | extend the boundary, which widens what an agent may write; or leave it, and rely on the template reseeding on the next container start |
| Is the report sent upstream, edited first, or kept as a record? | nothing; the report is complete either way | send it, which needs the operator to own the disclosure; edit it first, which costs another round; keep it, which is what the prior report's own status has sat at |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The shipped settings set `defaultProvider`/`defaultModel` and an `enabledModels` head pointing at a different provider, and the head won | bug | every session opened on a model nobody configured, silently | `src/reasoning/providers/pi/config/agent/settings.json`, reordered to the operator's revision |
| The mitigation depends on the `model-refresh` extension, because `space-bunny-free` is absent from pi 0.87.1's baked `opencode-go` catalog and is supplied by the persisted store | blocker | without the extension the head pattern matches nothing and the scope falls through with only a resolver-level diagnostic | recorded on the roadmap row and as the second half of the report's Finding 3 |
| pi's `findInitialModel` docstring lists five priorities and the function implements four, the missing one being the session restore owned by a different function | contradiction | a reader diagnosing the defect believes the saved default is a low-priority tiebreak rather than the branch that returns first | the report's own section, since it changes how a maintainer reads Finding 1 |
| The container's `~/.pi/agent/settings.json` still carries the old six-pattern list, so the operator's host edit is not visible in this container | contradiction | the repository and the live file disagree until the next mount, and a reader comparing them would think the fix did not land | decisions-pending row above |
| 0.99.2's changelog carries a fix for "new sessions intermittently ignoring the saved default model" that reads as though it closes this report, and it does not | contradiction | a reader who sees that line would close the report on it | `devlog/roadmap.md`, the row recording that the report is not closed by 0.99.2, with the measurement that `findInitialModel` is byte-identical across the two versions |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261002-report-draft-default_model_resolution_bug.md` | new, the report, with three findings plus the docstring section, a version-drift section and a verification section |
| `src/reasoning/providers/pi/config/agent/settings.json` | `enabledModels` reordered to the operator's revision, with the exact default at the head |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | new `test_scope_head_names_the_default` case, run from the file's existing tail |
| `devlog/roadmap.md` | the row, with the extension dependency and the scope-ordering follow-on |

## Propagation replay

| File | Change planned | Status |
|---|---|---|
| the report document | new | completed |
| `settings.json` `enabledModels` | reorder, exact default at the head | completed |
| `settings.json` `defaultProvider` / `defaultModel` | read, unchanged, they were already correct | completed |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | add the head-equals-default case and run it | completed |
| `tests/extensions/pi/model-refresh/*` | no change; the report is a separate record from the extension's own README | completed, no change needed |
| `~/.pi/agent/settings.json` | mirror the enabledModels change | not started, outside the working tree; decisions-pending row |
| a local statement of the scope-ordering rule | state that the head of `enabledModels` is the selection | not started, roadmap follow-on on this row |
| `docs/development/prompt-authoring-conventions.md` | no; that document governs prompt authoring, not pi settings | completed, out of scope |

## Deferred items

The live user settings file, the scope-ordering rule stated locally, and the extension dependency. All three are named in the records above with a decisions-pending or roadmap home, so none is re-listed here.

## What's Next

M3.2.1 - Loops as Workflows, and it stays in progress.

**Conclusions from this iteration.** A preference that is consulted on one branch and not another is not a weak preference, it is a conditional one, and the condition was `scopedModels.length > 0`. The control that settles it is worth more than the mechanism: empty the scope, change nothing else, and the default is selected. That is a two-line experiment, and it converts a settings puzzle into an ordering bug.

**Watch out.** The mitigation is a head-entry, not a default, and the head resolves against pi's baked catalog plus whatever an extension adds. `space-bunny-free` is not in the baked set. Removing the `model-refresh` extension breaks it. The pi 0.99.2 changelog will tempt a reader into closing the report; it does not close it, and the roadmap row says so with the measurement.
