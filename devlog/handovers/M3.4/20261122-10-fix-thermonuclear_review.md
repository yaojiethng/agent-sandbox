---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the review round on the branch, and what each finding cost

## Objective

Every finding the one-pass thermonuclear review raised against the branch is either applied in this iteration or filed where its work belongs, and the branch reviews clean at the same gates.

## Scope

The review ran over `ca2d31af..8f09b312` with one seat on `opencode-go/deepseek-v4.1-flash` at `max`, read-only, one pass, no prior-round seed. Its report is the brief's answer; this handover is the triage. F4 was already filed at T11 and stays filed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The record read has a declared type contract | `bash tests/test_session_env.sh` covers phase 2 entered alone and an unopened view | Agent [x] |
| The catalog's projection is stated once | `grep -c 'case "$field"' scripts/agent-sandbox.sh` prints 1, and one `catalog_row` serves both the help route and the dispatch | Agent [x] |
| A value with a space, a hash and an ampersand round-trips into the record | `bash tests/test_trace_compose_gen.sh` case `test_paths_with_yaml_and_sed_metacharacters_roundtrip` | Agent [x] |
| A bare help request succeeds | `bash scripts/agent-sandbox.sh --help` exits 0 and prints the index; `bash tests/test_agent_cli_dispatch.sh` | Agent [x] |
| No record states what another commit disproved | `grep -c 'carries no jq' docs/adr/cli_surface.md` prints 0 | Agent [x] |
| `make test` and `scripts/lint.sh` pass | `bash scripts/run_tests.sh` (1680 tests), `bash scripts/lint.sh` (29 gates) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The review range is the merge-base, not `init_sha`. | `ca2d31af` is not an ancestor of the branch, so the two-dot diff over it presents another commit's file as the branch's work. `/package-branch` already takes the merge-base; the review now does too. | This table; `state.md` in the review's scratch directory |
| The record view is declared at source and opened by its reader. | An undeclared array answers element 0 for every key, and an indexed one does the same, so the primitive's contract was the array's accident rather than its statement. | This table; `src/libs/env.sh` |
| The compose generator takes one value table, and the scalars are quoted. | `${VAR}` was safe by construction because Compose interpolates after parsing; `{{VAR}}` is written before parsing, so every value became a candidate YAML token and a sed replacement at once. | This table; `src/build/compose.sh` |
| The three readers of a generated label unquote it. | A quoted scalar is the fix for the writer, and the readers that grep the record must agree or they read the quotes. One `yaml_unquote` now serves all three. | This table; `src/libs/common.sh` |

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | The reviewed range was not the branch's change set. | Applied as a decision; no tree change, because the tree never carried the extra commit |
| F2 | `record_get` had an unchecked array contract, and phase 2 read a view it did not open. | Applied: declared at source, opened in the reader, pass-through deleted |
| F3 | The catalog's projection was written four times. | Applied: one field-to-flag-and-mode case, one `catalog_row`, one `json_array`, plus a six-field row check |
| F4 | The record read path is five functions for two concepts. | Stays filed at T11, which now carries only that half |
| F5 | Values reached YAML unescaped and unquoted, and the branch widened that surface. | Applied: one value table, sed escaping, quoted scalars, unquoting readers, a round-trip test |
| F6 | The decision record claimed the host carries no `jq`, which the same commit disproves. | Applied: the clause is gone; the argument stands without it |
| F7 | `agent-sandbox --help` exited 1 as an unknown subcommand. | Applied: a help request routes to the index, with a test |
| F8 | One CLI case asserted the resolver's failure rather than the flag's rejection. | Applied: deleted; the leaf sweep carries the claim |
| F9 | Notes: a census comment contradicting its own pin, a handover naming a symbol that never shipped, trailing whitespace, and the `jq` host question. | Applied for the first three; the host question stays the decision pending handover `20261122-08` records |

## Decisions pending

- `jq` is required by the CLI test and by no install path. Reversing word: "make jq a host requirement", with one `command -v` in `install.sh` and a matrix row.
- The interactive pickers convert an epoch to a stamp so the stamp formatter can convert it back. Reversing word: "give `relative_time` an epoch entry point".

## Records

| File | Change |
|---|---|
| [`src/libs/env.sh`](../../../src/libs/env.sh) | The record view is declared associative at source, so the read is always the shape it documents. |
| [`src/libs/session_env.sh`](../../../src/libs/session_env.sh) | Phase 2 opens the view it reads, and the pass-through over it is deleted. |
| [`src/libs/common.sh`](../../../src/libs/common.sh) | `sed_replacement`, `yaml_quote` and `yaml_unquote`, the three escape rules the writer and its readers share. |
| [`src/build/compose.sh`](../../../src/build/compose.sh) | The 28-rule sed wall becomes one value table with escaping. |
| [`src/build/docker-compose.yml`](../../../src/build/docker-compose.yml), [`src/build/docker-compose.copy.yml`](../../../src/build/docker-compose.copy.yml), [`src/build/docker-compose.mount.yml`](../../../src/build/docker-compose.mount.yml), [`src/reasoning/agent-runtime/pi/docker-compose.pi.yml`](../../../src/reasoning/agent-runtime/pi/docker-compose.pi.yml) | The placeholders whose lookup is exact are single-quoted scalars. |
| [`src/libs/session_inventory.sh`](../../../src/libs/session_inventory.sh), [`src/libs/dry_run_record.sh`](../../../src/libs/dry_run_record.sh) | `record_label` and the dry-run digest check unquote through the one helper. |
| [`src/build/container-interface.mjs`](../../../src/build/container-interface.mjs) | The mount scan reads a quoted or unquoted scalar. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | One field case, one `catalog_row`, one `json_array`, and a bare help request reaches the index. |
| [`tests/test_agent_cli_dispatch.sh`](../../tests/test_agent_cli_dispatch.sh) | Two cases added, one vacuous case removed. |
| [`tests/test_session_env.sh`](../../tests/test_session_env.sh) | Two cases: phase 2 alone, and an unopened view. |
| [`tests/test_trace_compose_gen.sh`](../../tests/test_trace_compose_gen.sh) | The metacharacter round-trip case. |
| [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | The `jq` clause is gone. |
| [`devlog/roadmap.md`](../../roadmap.md) | T11 carries the record read path alone. |
| [`devlog/handovers/M3.4/20261122-05-impl-record_read_not_exported.md`](20261122-05-impl-record_read_not_exported.md) | Its rows name what shipped, not a symbol that never existed. |

## Completed

| File | Change |
|---|---|
| The reviewed findings | Four blockers applied, four mechanical findings applied, one note deleted with its case. |
| The tests | 1680 across 127 files, up from 1677. |
| The gates | 29 clean, and the container-layout scan reads quoted scalars. |
