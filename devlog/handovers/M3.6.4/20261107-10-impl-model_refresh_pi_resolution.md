---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - The model-refresh suite finds the pi installation

## Objective

Resolve the pi packages the model-refresh suite loads from the `pi` on PATH instead of one hard-coded npm prefix, so the suite runs wherever pi is installed rather than reporting `not-run`.

## Scope

Repairs an inherited defect, not an M3.6.4 row. The suite read `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent` and derived pi-ai and jiti from beneath it. That layout belongs to an npm global install; the agent image installs pi at `/opt/npm/pi`, and hoists pi-ai and jiti to its `node_modules`, so all three paths missed. The mutation gate's control row turns an unrunnable mirror into a failure, which is why a missing path surfaced as a red suite rather than a skip.

In scope: `tests/extensions/pi/model-refresh/`, where the resolver sits in `fixtures.ts` and the suites, the mutation runner and its load probe read it.

Out of scope: the task-queue and model-failover mutation runners, which pin their own copy of the same path; they run green today, and giving them the resolver is a separate change.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every hard-coded pi path in the suite is gone | `grep -rn PI_PACKAGE_GLOBAL tests/extensions/pi/model-refresh/` finds only the child-process environment name | Agent [x] |
| The suite reaches its mirror and passes | `bash tests/test_model_refresh.sh`; 2 passed, 0 failed | Agent [x] |
| The resolver names the right packages in this container | the roots print `/opt/npm/pi/node_modules/@earendil-works/pi-coding-agent`, `.../@earendil-works/pi-ai` and `/opt/npm/pi/node_modules/jiti/lib/jiti.cjs` | Agent [x] |
| A global install still resolves | `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent` remains the last candidate when no `pi` is on PATH | Agent [x] |
| The suite is green in the umbrella | `bash scripts/run_tests.sh`; 1471 passed, 0 failed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The package root is found from the `pi` on PATH, by walking up to the `package.json` that carries the package's name | the shell finds pi that way, and the name in the manifest identifies the directory however it was hoisted; a fixed npm prefix is an assumption about one install method | this record; `fixtures.ts` |
| pi-ai is found by directory, not by `require.resolve` | its exports map carries no `require` condition, so the resolver throws on it even where the package is present | this record; `fixtures.ts` |
| jiti is resolved through pi's own `createRequire` | the subpath is not exported; the bare specifier is, and it answers the CJS entry the suite imports dynamically | this record; `fixtures.ts` |
| The child-process environment keeps the name `PI_PACKAGE_GLOBAL` | the two sibling mutation runners pass the same variable to their probes; renaming it here would split one convention across three files for no gain | this record |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| The suite's absence guard turns into a failure rather than a skip, because the mutation control row cannot distinguish an absent install from a broken mirror | this record's Scope; the guard's message now says which install it looked for |
| A path pinned to one install method is invisible until the environment changes: this suite was green while pi lived at the prefix it named | the resolver, which reads the install the way the shell does |

## Completed

| File | Change |
|---|---|
| `tests/extensions/pi/model-refresh/fixtures.ts` | the resolver: the package root from PATH, pi-ai by directory, jiti through pi's own require |
| `tests/extensions/pi/model-refresh/composition.test.ts` | the composer entry from the resolver |
| `tests/extensions/pi/model-refresh/config.test.ts` | the baked catalog, composer and completions entries from the resolver |
| `tests/extensions/pi/model-refresh/invariants.test.ts` | the pi entries and the jiti import from the resolver |
| `tests/extensions/pi/model-refresh/load.test.ts` | the package entry, the pi-ai aliases and the jiti import from the resolver |
| `tests/extensions/pi/model-refresh/mutation/runner.ts` | the availability probe and the loader probe from the resolver |
| `devlog/handovers/M3.6.4/20261107-10-impl-model_refresh_pi_resolution.md` | this record |
