# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Make the `pi-bump` skill sound, and prove it by running it against the current state. The operator scoped the unit to the skill: the version pin is not moved here, and the follow-on units are scheduled after this one closes.

## Scope

The roadmap row "pi bump to 0.99.2, in three units", specifically the part of it that is the skill. The operator asked for a status report on 0.87.1 to 0.99.2 and for the skill to check compatibility with the home-spun extensions.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The probe derives its required surface from the extension sources rather than a hand-maintained list | `scripts/lint/pi-extension-compat.mjs`, `requiredSurface()` | accepted |
| 2 | The probe is clean against the installed pi | `node scripts/lint/pi-extension-compat.mjs`, 6 names, rc 0 | accepted |
| 3 | The probe is clean against the candidate | `--target 0.99.2`, 6 names, rc 0 | accepted |
| 4 | The probe is sensitive | an import of a name pi does not export turns it red, rc 1; the file restored and compared byte-identical | accepted |
| 5 | The skill reports before it edits | step 4, with the stop stated in the procedure | accepted |
| 6 | The changelog source the skill names actually exists | `npm pack` plus `tar`, executed | accepted |
| 7 | The stale-pin check can fail on the defect it was written for | `roadmap_future.md` still reads 0.86.0, which the old hardcoded range missed | accepted |
| 8 | The run reports a status for 0.87.1 to 0.99.2 and pins nothing | the run section below; the pin is still 0.87.1 | accepted |
| 9 | The suite is unaffected | `bash scripts/run_tests.sh`, 1012 of 1012 | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/agent/skills/pi-bump/SKILL.md`](../../src/reasoning/agent/skills/pi-bump/SKILL.md) | the procedure this unit makes sound |
| [`scripts/lint/pi-extension-compat.mjs`](../../scripts/lint/pi-extension-compat.mjs) | new, the probe the procedure runs |
| [`devlog/discussions/20261002-study-pi_bump_extension_compatibility.md`](../discussions/20261002-study-pi_bump_extension_compatibility.md) | the study behind the procedure |

## The run: 0.87.1 to 0.99.2

Steps 1 to 4 of the amended skill, executed, stopping where the skill says to stop. The version is reported, not applied.

**Step 1.** `curl -sS https://pi.dev/api/latest-version` reports `0.99.2`.

**Step 2.** The changelog ships in the package, not in `npm view`. Sections 0.99.0 through 0.99.2 read in full. Entries touching something this repository owns:

| Entry | Bearing |
|---|---|
| Extension tool APIs gained `exposure`, `namespace`, `annotations`, `outputSchema`, `isError`, `prepareLoadout()` and `ctx.executeTool()` | additive; `task-queue` registers nine `taskq_*` tools and reads none of the new fields |
| `mcp`, `codemode`, `tool-search` and `llama.cpp` are now built-in extensions, with a warning when an extension replaces a built-in one | no collision. Our registrations are nine `taskq_*` tools, the `opencode-go` provider, and one `session_start` subscription |
| `--no-extensions` now also disables the built-in extensions | changes what the flag means for anyone using it to isolate an extension |
| `ModelRuntime` gained image generation, `getModelsOfType()` and `getModelOfType()`; when an extension supplies a model list it replaces the provider catalog across every operation, while `getModels()`, `getAvailableSnapshot()` and the model picker are unchanged | load-bearing and favourable. That last clause is the exact contract `model-refresh` is built on |
| pi.dev catalog requests now send `types=chat,image,classifier` | `model-refresh` consumes the models.dev blob per provider and filters nothing by type, so a new entry type could arrive unexamined. Not verified here |
| `defaultModelPerProvider["opencode-go"]` moved from `kimi-k2.6` to `kimi-k3`, with Fireworks and Together | measured in both builds. Moves `model-refresh` assumption A2 and the fallback base |
| Fixed new sessions ignoring the saved default model when it belongs to an extension-registered native provider with a stored credential (#9962) | does not cover the reported defect; see below |

**Step 3.** The probe reports clean against 0.99.2 over six imported names. `RefreshModelsContext` is identical in shape. pi removed no runtime export between the two versions and added four.

**The reported default-model defect is not fixed in 0.99.2.** The changelog line reads as though it covers the defect reported in [`20261002-report-draft-default_model_resolution_bug.md`](../discussions/20261002-report-draft-default_model_resolution_bug.md). It does not. `findInitialModel` in the 0.99.2 bundle is byte-identical to 0.87.1's, and driving both with the same four settings cases gives the same four results: a non-empty scope still selects `scopedModels[0]`, and the saved default is still never read. The upstream fix is scoped to an extension-registered native provider with a stored credential, which is a different case from a glob scope.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Report before editing, and stop for a release before steps 5 to 7 | the skill moved a pin, a settings record and a roadmap note before a reader could see whether the bump was safe. A reader who wants to know should not have to undo it first | `SKILL.md` step 4 |
| Derive the probe's required surface from the extension sources | a hand-maintained list is a list that rots, and an extension that starts importing something new would be uncovered until someone remembered to edit the list | `requiredSurface()` in the probe |
| Read the changelog out of the package with `npm pack` and `tar` | `npm view` returns version metadata, timestamps and dependency lists, and no notes. The old step named a source that does not exist | `SKILL.md` step 2 |
| Compare every version literal to `<NEW>` rather than grep a hardcoded range | the old check was `grep "0\.8[0-3]\."`, which would not have caught the 0.86.0 sitting in `roadmap_future.md` today. A grep with a hardcoded range is a check that passes on the defect it was written for | `SKILL.md` step 6 |
| Keep the probe out of `make lint` for now | it needs network and npm, which the other four gates do not, and in the skill it runs once per bump where the version API call already needs the network | roadmap row, with the reasoning and the cost stated |
| Walk the assumption table in the same step as the probe | a clean probe reads as a clearance it is not. The proof that the limit is real is in this repository: `mergeModels` became reachable with no import changing | `SKILL.md` step 3 |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Should the probe join `make lint`? | nothing today. The cost of leaving it out is that a breaking import reaches `main` with no gate until the next bump notices | make it offline-capable and gate every change, which costs a checked-in manifest of the surface; or leave it in the skill, and accept the gap between bumps |
| Is `model-refresh` deleted, narrowed, or kept, if upstream fixed the catalog defect it works around? | follow-on unit three | delete it and take the upstream fix, which loses the union guarantee it was written to provide; or keep it guarding a condition that no longer reproduces |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `npm view` carries no changelog, so the skill's step 2 named a source that does not exist | bug | a reader following the step gets nothing and has to find the changelog themselves | `SKILL.md` step 2, `npm pack` plus `tar` |
| The stale-pin grep covered 0.80 to 0.83 and would have passed the 0.86.0 actually present in `roadmap_future.md` | bug | the check that exists to catch a stale pin passes on one | `SKILL.md` step 6, and the 0.86.0 itself is named on the roadmap bump row |
| The skill edited three files before anything was reported | contradiction | a reader wanting to know whether a bump is safe had to undo it first | `SKILL.md` step 4 |
| The upstream #9962 fix does not cover the reported default-model defect, and its changelog line reads as though it does | contradiction | a reader would close an open report on the strength of one line | `devlog/roadmap.md`, a row recording that the report is not closed by 0.99.2, with the byte-identical measurement |
| `defaultModelPerProvider["opencode-go"]` moved to `kimi-k3` | contradiction | moves the fallback base `model-refresh` relies on and assumption A2 | `devlog/roadmap.md`, follow-on unit one, named as the first row to walk |
| pi.dev catalogs now carry image and classifier entries, which `model-refresh` does not filter by type | contradiction | unexamined entries can enter the served catalog | same row, same unit |
| `roadmap_future.md` still carries 0.86.0 | contradiction | three of the skill's three files disagree about the pinned version | follow-on unit two, which now cannot miss it |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent/skills/pi-bump/SKILL.md` | rewritten into seven steps: read the changelog, probe the extensions, report, stop, then edit, verify and commit on a release. The two defective checks replaced |
| `scripts/lint/pi-extension-compat.mjs` | new, the probe |
| `devlog/discussions/20261002-study-pi_bump_extension_compatibility.md` | new, the study behind the procedure, with a recommendation |
| `devlog/roadmap.md` | the three-unit row, the row recording that 0.99.2 does not close the default-model report, and the checker-placement row |

## Propagation replay

| File | Change planned | Status |
|---|---|---|
| `SKILL.md` step 1 | source the version from the API | completed, unchanged and correct |
| `SKILL.md` step 2 | changelog source corrected, and four kinds of entry named to watch for | completed |
| `SKILL.md` step 3 | the probe, plus the assumption-table walk in the same step | completed |
| `SKILL.md` step 4 | report and stop | completed, new |
| `SKILL.md` step 5 | edit the three files | completed, moved and now gated on a release |
| `SKILL.md` step 6 | verify, with the stale-pin check replaced | completed |
| `SKILL.md` step 7 | commit | completed, unchanged |
| `SKILL.md` the "Files to edit" table | unchanged, still the three files | completed, no change needed |
| `scripts/lint/pi-extension-compat.mjs` | new | completed |
| `devlog/discussions/20261002-study-pi_bump_extension_compatibility.md` | new | completed |
| `devlog/roadmap.md` | three rows | completed |
| the twelve unverified assumption rows | walk them against 0.99.2 | not started, follow-on unit one |
| `src/reasoning/providers/pi/base.dockerfile` and the other two files | move the pin to 0.99.2 | not started, follow-on unit two |
| `scripts/lint.sh` | add the probe as a fifth gate | not started, decisions-pending row |

## Deferred items

All three follow-on units: the assumption-table walk, the bump itself including the 0.86.0 in `roadmap_future.md`, and the extension's fate. All three are named in the roadmap row above, so none is re-listed here.

## What's Next

M3.2.1 - Loops as Workflows, and it stays in progress. The three follow-on units are scheduled, at the operator's direction, after this unit closes.

**Conclusions from this iteration.** A compatibility check over names is the strongest mechanism available for the mechanical class of bump break, and it is blind to the class that has already occurred in this repository. Both facts were found by running the procedure rather than by reading it, and the two defects it exposed were in the procedure, not in the code. A skill that has never been executed is a document, not a procedure.

**Watch out.** A clean probe is not a clearance, and the skill says so in the step that runs it. `roadmap_future.md` still reads 0.86.0, so the three files the skill edits do not currently agree. The pi 0.99.2 changelog carries a line that reads as though it closes the open default-model report; it does not, and the measurement is on the roadmap row.
