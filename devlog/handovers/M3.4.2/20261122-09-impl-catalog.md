---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - one catalog for the subcommand surface, and the gate that holds it

## Objective

The dispatcher declares its subcommand surface once, every surface it prints derives from that row set, and a test that invokes the CLI fails the moment two of them disagree.

## Scope

The M3.4.2 row **The router and its leaf handoff carry no contract**, scoped by the `/scope` brief of 2026-11-22 and designed in [`cli_surface.md`](../../../docs/adr/cli_surface.md) R7-R11. Three units in one slice: the catalog and its derived surfaces, one status map for the parse across 17 call sites, and the mutation subject map that named a test which never invoked the dispatcher. The Makefile alias table stays a second declaration by the operator's rule and is recorded, not derived.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A test invokes the dispatcher and fails on a divergence | `bash tests/test_agent_cli_dispatch.sh` runs 14 cases; mutation row D1 deletes a catalogue row and the set cases go red | Agent [x] |
| The four surfaces print one set | the test's two set cases, and `bash scripts/agent-sandbox.sh` with no argument now names `package-branch` | Agent [x] |
| `--help` and `-h` exit 0 for every subcommand, and an unknown flag never succeeds | the test's three table-driven cases, through the dispatcher and against each leaf | Agent [x] |
| `help --json` renders the catalog | `bash scripts/agent-sandbox.sh help --json \| jq -e .schema`; the test compares names, order, leaves, summaries and declared identity fields | Agent [x] |
| One status map, no leaf spelling it | `grep -rn 'rc -eq 2' scripts src` prints nothing; `parse_args_or_exit` is the only mapping | Agent [x] |
| The mutation rows bite | the dispatcher's catalogue section: 10 rows, 10 proven, 0 survived, 0 no-op | Agent [x] |
| No record states a check the leaves cannot satisfy | `cli_surface.md` and `interface-conventions.md` say the summary is the catalog's own line | Agent [x] |
| `make test` and `scripts/lint.sh` pass | `bash scripts/run_tests.sh` (1677 tests), `bash scripts/lint.sh` (29 gates) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The catalogue is a bash array of pipe-separated rows in the dispatcher, and four readers derive from it. | The CLI runs on the operator's host, where every manifest reader in the tree is absent; the row set is twelve lines, and `help --json` makes a rendering rather than a file, so nothing materializes to drift. | This table; `cli_surface.md` R7-R8 |
| `parse_args_or_exit` carries the lib gate's new one-line directive. | The function's whole contract is to exit, which pattern p-13 forbids in a sourced library; the alternative was the three-line block in 17 files that this row exists to remove. The directive names its reason and exempts one function. | This table; `scripts/check_lib_contract.sh` header; `src/libs/cli.sh` |
| `json_string` moves to `common.sh` and the three probe copies go. | `help --json` needed escaping, and a fourth copy would have carried the defect the probes already had: `stop_signal_matrix.sh` never escaped the carriage return. | This table; `src/libs/common.sh` |
| The catalogue's dispatcher section is replaced, not repaired. | After the rewrite, 24 of its 32 rows matched no text and 7 survived against the new test; a row that cannot bite is noise, so the section was re-authored as 10 rows covering the new structure. | This table; `tests/mutations/catalog.jsonl` |
| The dispatcher's `--env` and leading-argument forwards stay unpinned this iteration. | Observing them needs a sandbox fixture and a record at a non-default path. The mutation that dropped the leading argument survived, so the row was dropped rather than left pinning nothing. | [`devlog/roadmap.md`](../../devlog/roadmap.md) M3.4.2 |

## Decisions pending

- The Makefile aliases remain a second declaration of the surface. Reversing word: "derive the make aliases".
- `jq` is assumed on the developer's host for the test, and `install.sh` gains no check. Reversing word: "make jq a host requirement".

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | The dispatcher forwards `--env` to the resolver and a row's leading argument to the leaf, and no fixture-free test observes either; mutation row D9 survived and was dropped. | Filed as the M3.4.2 row **The dispatcher's two forwards are unpinned** |
| F2 | The catalogue's dispatcher section held 32 rows written against the pre-catalog dispatcher. | Resolved here: re-authored as 10 rows, all proven |
| F3 | `parse_help_flag` is live, but only `start_agent.sh` calls it; the conventions document had claimed it for every leaf. | Resolved in the plan session: the claim is gone and the function stays |
| F4 | Pattern p-13 had no exemption mechanism, so a function whose contract is to exit could not live in a sourced library. | Resolved here: the gate honours a reasoned directive, with two fixture cases |

## Records

| File | Change |
|---|---|
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | The catalogue and its four readers -- list, help index, no-argument message, dispatch -- plus `print_json`. |
| [`src/libs/cli.sh`](../../src/libs/cli.sh) | `parse_args_or_exit`, the one parse-status map, with the lib-gate directive. |
| [`src/libs/common.sh`](../../src/libs/common.sh) | `json_string`, the one JSON string literal escaper. |
| [`scripts/build_probe.sh`](../../scripts/build_probe.sh), [`scripts/stop_probe.sh`](../../scripts/stop_probe.sh), [`scripts/stop_signal_matrix.sh`](../../scripts/stop_signal_matrix.sh) | Their three `json_string` copies removed; the matrix script gains the carriage-return escape it lacked. |
| [`tests/test_agent_cli_dispatch.sh`](../../tests/test_agent_cli_dispatch.sh) | New: 14 cases, the only test that invokes the CLI as a process. |
| [`tests/test_cli_lib.sh`](../../tests/test_cli_lib.sh) | Four cases for `parse_args_or_exit`. |
| [`tests/test_lib_contract.sh`](../../tests/test_lib_contract.sh) | Two cases for the directive: its scope and its required reason. |
| [`scripts/check_lib_contract.sh`](../../scripts/check_lib_contract.sh) | Honours the p-13 directive and documents it in the header. |
| [`scripts/mutations_run.sh`](../../scripts/mutations_run.sh) | The dispatcher's subject map points at the test that invokes it. |
| [`tests/mutations/catalog.jsonl`](../../tests/mutations/catalog.jsonl) | The dispatcher section re-authored: 32 stale rows out, 10 proven rows in. |
| [`scripts/resume_agent.sh`](../../scripts/resume_agent.sh) | Its page names `--name`, `--project`, `--sandbox` and `--env`, which it accepts and the dispatcher forwards. |
| [`docs/adr/cli_surface.md`](../../docs/adr/cli_surface.md) | The summary is the catalogue's own line; the gate reads a leaf's `--help` for its identity fields. |
| [`docs/development/interface-conventions.md`](../../docs/development/interface-conventions.md) | Section 4 says the same, and names `parse_args_or_exit` as the one status map. |
| [`docs/reference/tool_interface.md`](../../docs/reference/tool_interface.md) | Names `help` and `help --json` as the discoverable surface. |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | The router row closes; the forwards row is filed. |

## Completed

| File | Change |
|---|---|
| 17 leaves and libs | `parse_args_or_exit` replaces both spellings of the status map, and six of them stop depending on `set -e` to report a usage error. |
| The dispatcher | Help routing, the no-argument message and the dispatch read `CLI_CATALOG`; no printed surface names the set twice. |
| The mutation tier | 10 dispatcher rows, 10 proven, none surviving. |
| The tests | 1677 across 127 files, up from 1657 across 126. |
