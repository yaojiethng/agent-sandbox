---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Plan
status: Closed
---

# Handover - one catalog for the subcommand surface

## Objective

Settle how the CLI declares its subcommand surface once -- leaf path, identity requirement, leading arguments and one-line summary per subcommand -- so the dispatcher, the help and every leaf read one catalog instead of restating it.

## Scope

The M3.4.2 row **The router and its leaf handoff carry no contract**, at the grain of one task that needs decisions before it can be worked. The row's premise, measured: the subcommand set is spelled four times in `scripts/agent-sandbox.sh` and already diverges (the no-argument message omits `package-branch`), the identity flag set is spelled per case twelve times, and 18 sites across 17 files spell the parse's help-status mapping in two forms. The operator's direction widens the target from a table inside the dispatcher to a catalog that the leaf scripts and their usage also read.

Roadmap-maintenance ran before this session and its false-fact findings are applied in the same commit (see Completed).

Out of scope: the host requirements matrix and the `jq` gap a comment claimed, and any code in the catalog, the status map or the mutation rows -- the plan settles them and the implementation owns them. The wider ADR consolidation is filed at M3.5.3.

## Deliverables

Proposed, for confirmation at the scope gate: one ADR entry stating the catalog and its reader; the roadmap rows the decomposition needs, filed by `/scope`; and this handover's decisions.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The CLI surface is one ADR with its requirements | `docs/adr/cli_surface.md` holds R1-R11, and `ls docs/adr/command_flag_parsing.md` fails | Agent [x] |
| The decomposition is on the roadmap, not in the handover | `grep -c 'cli_surface' devlog/roadmap.md` prints 2 -- the design pointer on the M3.4.2 row and the decision | Agent [x] |
| The wider sprawl is filed as a task | `grep -c 'ADR record set is consolidated by plane' devlog/roadmap.md` prints 1 | Agent [x] |
| Each decision this session made is in the Decisions table with where it was recorded | the table read against the ADR entry and the roadmap rows | Agent [x] |
| The legacy-debt gate is clean for the two files this session edited | `bash scripts/check_doc_wrap_legacy.sh docs/adr/cli_surface.md docs/development/interface-conventions.md` | Agent [x] |
| The roadmap-maintenance findings that name a false fact are corrected in place | `grep -c 'env_load'` over the M3.4.2 rows prints 0; both handovers print M3.4.2 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The catalog is a bash declaration, and JSON is a rendering of it (`agent-sandbox help --json`), not a manifest file. | The CLI path needs no external reader: bash already holds the facts, `scripts/build_probe.sh` renders JSON this way, and a rendering materializes nothing, so there is no generated file to drift. | This table; ADR pending |
| Each leaf's `parse_args` spec stays the flag source; the catalog declares no flags. | A catalogue copy would be the second source this row exists to remove, and ADR R2 already pins each leaf's flags, help text and unknown-flag wording. | This table; ADR pending |
| The parse's status maps to the process status in `parse_args_or_exit`, one function. | A help request is success and a usage error is 1; 18 sites in 17 files spelled that policy in two forms, so the rule had no home to be corrected in. | This table; `cli_surface.md` R9 |
| The CLI plane's decisions live in one ADR, `cli_surface.md`, and `command_flag_parsing.md` is absorbed. | The sprawl the operator raised is a record-set problem, and adding a forty-third record for the catalog would have deepened it; the CLI plane already had one record, so widening it costs no new file. | This table; `docs/adr/cli_surface.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Two closed handovers name `T11 - Persisted record formats` as their milestone, and T11 has no Milestone Summary row, so the field is unassigned under the task-list convention's identifier rule. | record | A later reader resolving the milestone finds no active row, and the handover chain disagrees with its siblings, which name M3.4.2. | Corrected in this iteration's commit (`20261122-06`, `20261122-07`). |
| The closed M3.4.2 row **Environment: one load path, no repaired damage** names `env_load`, which the record-primitive work replaced; the tree has no `env_load`. | record | A closed row asserting a mechanism the tree does not have fails the task-list rule that a row states no fact the tree can falsify. | Corrected in place this iteration. |
| The closed M3.4.2 row **The runtime `SANDBOX_DIR` derivation contradicts the resolution ladder** names `AGENT_SANDBOX_SANDBOX_DIR` as a rung the runtime argument beats; that level no longer exists. | record | The row reads as current fact about a level the resolver dropped, so a reader takes a deleted rung for a live one. | Corrected in place this iteration. |
| Several closed M3.4.2 rows carry implementation narrative rather than one line of what landed plus a handover link. | record | The detail belongs in the handover, and a suite count or symbol in a row goes stale at the next change. | Deferred to M3.4.2's close: sub-milestone compaction is `/milestone-close`'s, per roadmap-maintenance's owner table. |
| Two scripts justified their JSON escaper with "the host toolchain carries no jq (docs/development/host_requirements.md)", and that document states nothing about jq; jq is on the host and four gates plus `package_eval_snapshot.sh` require it. | doc | A comment cited a claim no document makes, so a reader could not check it; the requirement matrix omits a tool a shipped library fails closed on. | Claims cut from `build_probe.sh` and `stop_probe.sh` this session. The matrix gap is out of scope by this handover's Scope sentence: adding jq there obliges `install.sh` to enforce it, which is an operator decision. |
| The mutation tier maps `scripts/agent-sandbox.sh` to `test_dispatch.sh`, and that file covers `scripts/dispatch.sh`, the subagent dispatcher; nothing invokes the CLI dispatcher. | test | All six dispatcher mutation rows are survivors by construction, so the tier reports the dispatcher as covered while no case reaches it. | Deferred to the implementation: M3.4.2's router row now names the subject map and the test file, and /scope owns the iteration. |

## Completed

| File | Change |
|---|---|
| [`devlog/handovers/M3.4/20261122-06-impl-record_read_once.md`](20261122-06-impl-record_read_once.md) | The `milestone` field names M3.4.2, the row the iteration worked. |
| [`devlog/handovers/M3.4/20261122-07-fix-probe_stamps_and_last_carriers.md`](20261122-07-fix-probe_stamps_and_last_carriers.md) | The same correction. |
| [`docs/adr/cli_surface.md`](../../docs/adr/cli_surface.md) | The CLI surface's one record: R1-R6 kept, R7-R11 added, the four existing entries moved unchanged, and the `2026-11-22` entry for the catalog. |
| [`docs/adr/command_flag_parsing.md`](../../docs/adr/command_flag_parsing.md) | Deleted; absorbed into the record above. |
| [`docs/development/interface-conventions.md`](../../docs/development/interface-conventions.md) | Sections 4 and 5 state the practice and cite the ADR for the rule; the stale `parse_help_flag` mechanism and the parser-status/process-status confusion are gone; its legacy wrap debt is cleared. |
| [`.markdownlint-cli2.mjs`](../../.markdownlint-cli2.mjs) | The absorbed path leaves the legacy debt list. |
| [`tests/test_doc_wrap_legacy_gate.sh`](../../tests/test_doc_wrap_legacy_gate.sh) | The fixture moves to a file that still carries debt. |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | M3.4.2's router row names the design, its decisions gain the catalog, and M3.5.3 gains the ADR-sprawl row. |
| [`devlog/handovers/20261016-01-docs-resolution_model_and_census_defects.md`](../20261016-01-docs-resolution_model_and_census_defects.md) | Its reference follows the record to its new name. |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | The help-scan comment cites R10 instead of naming `parse_help_flag`, which most leaves never call. |
