---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the package manifest and its drift report

## Objective

Give the operator of the sandbox a manifest that names the packages a project expects, and a check that reports the difference against what the session is configured with.

## Scope

The roadmap row `Track the skill packages a project adds, with a drift check`, whose draft handoff `.agents/drafts/installed-package-manifest-handoff.md` is consumed and deleted with this record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The manifest exists and is written in the operator's own pin form | `.agents/registry/packages.json` | accepted |
| A drift case is a finding and a clean case is not | `bash tests/test_skill_packages.sh`, the two drift tests and the match test | accepted |
| The gate runs at a stage where its evidence exists | `scripts/check_skill_packages.sh` in `scripts/lint.sh`, 18 gates | accepted |
| The manifest alone is the repo-time subject, and the installed state is a runtime report | the gate's header and `scripts/skill_packages.mjs` | accepted |
| The tree passes its gates | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | accepted, 18 gates clean and 1423 of 1423 tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate reads the manifest alone, and the drift is a runtime report | the installed state exists only in a container that has the image, so a gate reading it would fail a maintainer's checkout for a reason that is not a defect | `scripts/lint/skill_packages.mjs` header, this record |
| The manifest records every package the project expects, not only the ones it added | a manifest of additions alone cannot report a configured package nobody asked for, and the shipped stack arrives as packages too | `.agents/registry/packages.json` `note` |
| The pin is recorded as the operator wrote it, with `scope` and `why` | the handoff forbids a pin taxonomy here: the package manager owns pin semantics, and the manifest owns the intent | `.agents/registry/packages.json` |
| The configured package list is read once, by `configuredPackages` | the collision report and this check ask pi the same question, so one function answers it | `scripts/skill_packages.mjs` |
| The drift report fails nothing | a missing package is fixed by the operator running the provider's own command, not by the tree | `scripts/skill_packages.mjs` CLI |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does the session print the drift at start the way it prints a collision? | nothing today; the report is a command | print it beside the collision report, or leave it to the operator, who is the only party who can act on it |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| This container's configuration names two packages, `/opt/workflow/agent` and its coding-agent module, and both are image payloads rather than project additions | measurement | the manifest seeds with those two, so the check compares something real on the first run | this handover, Decisions |
| The gate grew `scripts/lint.sh` from 17 to 18 gates | measurement | the skill-layer and package gates now cover the same subject from two sides: names and pins | this handover |

## Completed

| File | Change |
|---|---|
| `.agents/registry/packages.json` | the manifest, seeded with the two payloads the image configures |
| `scripts/skill_packages.mjs` | the shared package reader, the manifest reader and the drift report |
| `scripts/lint/skill_packages.mjs` | the manifest gate: parse, non-empty, source, scope, reason, no repeat |
| `scripts/check_skill_packages.sh` | the gate wrapper, in the shape the other gates use |
| `scripts/lint.sh` | the gate registered, 18 in the set |
| `scripts/skill_collisions.mjs` | reads the configured packages through `configuredPackages` instead of constructing pi's package manager itself |
| `tests/test_skill_packages.sh` | seven cases: the gate's four and the drift's three |
| `.agents/drafts/installed-package-manifest-handoff.md` | deleted, its task landed |
| `devlog/roadmap.md` | the row closed, its handoff link replaced by this record |
