---
date: 2026-10-17
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - The manifest's shared rows

## Objective

Declare the payload each provider image shares once, so the manifest states the common rows a single time instead of repeating them per provider.

## Scope

The M3.6.4 row `The tier change lands`, its unit U3 of the run brief [`harness-tier-unification-run.md`](../../.agents/drafts/harness-tier-unification-run.md), which closes the row alongside unit U1 and unit U4. Unit U2, the seam's backend availability, is recorded below as having no subject once the shared tier landed. One stale comment in `src/libs/dispatch.sh` is corrected here as a carrier of U1's deletion.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A row naming a provider set yields one pair per provider | `bash tests/test_container_layout.sh`, case `test_providers_row_expands_to_one_pair_per_provider` | Agent [x] |
| A row carrying both keys, neither key, or an unknown provider is a finding that names the row | `bash tests/test_container_layout.sh`, the three negative cases | Agent [x] |
| The emitted pair set is unchanged by the collapse | `node src/build/container-interface.mjs pairs`, sorted before and after, one identical set | Agent [x] |
| The gate still compares in both directions | `bash scripts/check_container_layout.sh`, exit 0; `node src/build/container-interface.mjs check`, exit 0 | Agent [x] |
| Every consumer of the module still passes | `tests/test_instruction_surfaces.sh`, `tests/test_documented_defaults.sh`, `tests/test_opencode_config.sh`, `tests/test_lint_umbrella.sh`, all 0 | Agent [x] |
| The lint umbrella passes | `bash scripts/lint.sh`, exit 0, 8 gates clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A row names its providers with `provider` or `providers`, never both and never neither | the shared pairs are one declaration, and the singular key stays because most rows are one provider | `src/build/container-interface.json` `note`, `check_row_forms` |
| The array form is expanded at the reading boundary, so no consumer learns it | `pairs`, `copy_destinations`, `home_of`, `resolve_home` and the cell derivation keep their signatures and their output | `src/build/container-interface.mjs`, `manifest_rows` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Should the COPY layout be derived at build time from the manifest, or stay declared and gated? | the M3.6.4 design step | keep the declaration and the gate; a builder stage derives the tree; defer |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Unit U2 of the run brief, the seam's backend availability, has no subject after U1: both provider images now inherit a tier that installs both harnesses, so `dispatch_check` cannot refuse a backend that is absent and its selection logic is unchanged | design | a planned unit with nothing to change; dispatching it would have invented work | recorded here; the run brief's work-unit table is the record that needs the correction |
| `src/libs/dispatch.sh` said the pi image installs `opencode-ai`; the shared harness tier does, so both images carry it | defect | a reader tracing the dispatch binary's origin would look in a Dockerfile that no longer exists | closed here, comment only |
| The OpenCode dispatch route cannot run a worker in this container: both free models hang, `cat-jam-free` answers an upstream server error, and the paid models answer `Insufficient account funds` or `Model access is disabled` | environment | the free-tier route the milestone is built around is unusable here; this run's units ran through `pi -p` | `devlog/AGENT_FEEDBACK.md` candidate, not yet filed |

## Completed

| File | Change |
|---|---|
| `src/build/container-interface.json` | the four shared pairs collapse to one row each naming `pi`, `opencode` and `hermes`; the `note` states the two row forms |
| `src/build/container-interface.mjs` | `manifest_rows` expands the array form; `check_row_forms` refuses both keys, neither key, and an unknown provider, naming the row |
| `tests/test_container_layout.sh` | the expansion case and the three negative cases |
| `src/libs/dispatch.sh` | the comment naming the pi image as the `opencode-ai` install's home corrected |
