---
date: 2026-11-24
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the catalogue's fields are one vocabulary with one mapping

## Objective

The resolver's field selector for the project path is `project`, the catalogue's identity column uses the resolver's field names, one field table maps each field to its resolver mode and forwarded leaf flag, and an unknown field fails before any help or dispatch surface derives from it.

## Scope

The second open M3.4.2 row, raised by the thermonuclear review in [`20261123-04`](20261123-04-impl-review_fixes.md). The iteration changes the catalogue's field vocabulary, the resolver's field selector from `dir` to `project`, the mapping from a field to its resolver mode and forwarded flag, the JSON rendering of that mapping, and the contract gate that rejects an unknown field. `project` is both the resolver field and the historical leaf flag, so no translation remains, and every leaf keeps its current surface. It changes no path normalization, no record format and no record-read API. Path normalization for `PROJECT_DIR`, `SANDBOX_DIR` and `ENV_FILE` is deferred to the new M3.4.2 row **The identity paths have one fixed form**. The timestamp row remains open, and the `env_resolve_identity` name/dir duplication stays a note.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `env_resolve_identity` resolves `project` as the project-path selector and no longer treats `dir` as one. | `bash tests/test_env_resolve.sh`, cases `test_resolve_project_is_the_selector` and `test_resolve_dir_is_not_a_selector` | Agent [x] |
| Every catalogue identity value is declared in `CLI_FIELDS`, and the catalogue has no second field list. | `bash tests/test_resolution_contract.sh`, case `test_catalog_fields_are_in_the_field_vocabulary` | Agent [x] |
| A row declaring a field outside the vocabulary fails before help or dispatch, and the error names the row and field. | `bash tests/test_resolution_contract.sh`, case `test_unknown_catalog_field_fails_the_contract_gate` | Agent [x] |
| `help --json` renders `identity` as `["name","project","sandbox","env"]` and `flags` as `["--name","--project","--sandbox","--env"]` for `start`. | `bash tests/test_agent_cli_dispatch.sh`, case `test_json_renders_the_identity_vocabulary_and_flags` | Agent [x] |
| The dispatcher mutation set is 15/15, including the updated D13 and new D14/D15. | `MUTATIONS_STRICT=1 MUTATIONS_REQUIRED_SUBJECTS='scripts/agent-sandbox.sh' bash scripts/mutations_run.sh` | Agent [x] |
| The ADR and interface documents state the field vocabulary, mapping table, JSON split and validation point as built. | `rg -n -e 'R14' -e 'C8' docs/adr/cli_surface.md`; the three documents read against the diff | Agent [x] |
| Every decision this iteration records is realized in the files. | the `## Decisions` table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The catalogue's identity column carries the resolver's field names: `name`, `project`, `sandbox`, plus `env` as a forward-only field. | `project` was a leaf flag while the resolver called the same field `dir`, so the dispatcher translated between them in a second list. One vocabulary removes the translation and makes an unknown field detectable. | This table; `docs/adr/cli_surface.md` entry 2026-11-24 |
| `CLI_FIELDS` is the one field table, one row per field: field, resolver mode, forwarded flag, value variable. | The resolver loop and the forwarding loop each held their own `case`; a field added to one and not the other silently forwarded nothing. One row is the only place a new field is declared. | This table; `scripts/agent-sandbox.sh` |
| `project` forwards `--project`; the leaf flag does not change. | The resolver field and the leaf flag now share one word, so the table maps the field to its variable without translating the name. | This table; `docs/adr/cli_surface.md` entry 2026-11-24 |
| `env` has no resolver mode. | The resolver always exports `ENV_FILE`; `env` only tells the dispatcher to forward it. An empty resolver cell states that. | This table; `scripts/agent-sandbox.sh` |
| `help --json` renders `identity` as the field vocabulary and `flags` as the forwarded leaf flags. | A consumer needs both the resolver field and the flag it becomes; rendering only one leaves the consumer to re-derive the mapping this table owns. | This table; `docs/adr/cli_surface.md` entry 2026-11-24 |
| `catalog_validate` runs in `main` before any surface, and the dispatch lookup fails safely when called directly. | An unknown field currently falls through both `case` statements and forwards nothing. Validation at entry turns a silent omission into a named failure. | This table; `docs/adr/cli_surface.md` entry 2026-11-24 |
| The contract tests and the mutation rows read the field table rather than keeping a second list. | A second list would drift from the table exactly as the two `case` loops did. | This table; `tests/test_resolution_contract.sh`, `tests/mutations/catalog.jsonl` |
| Path normalization for `PROJECT_DIR`, `SANDBOX_DIR` and `ENV_FILE` is a separate M3.4.2 row, not this iteration. | Normalization changes the resolver contract, the `SESSION_ID` inputs, compose and labels, and the existence semantics of a path that may not exist yet. Folding it into the vocabulary row would mix two designs with different blast radii. | This table; roadmap row **The identity paths have one fixed form** |
| The dispatcher mutation subject map names every suite that holds its contract. | A new contract suite that the map omits lets a mutation row survive while the gate is green; the map is the carrier that makes the new test count. | This table; `scripts/mutations_run.sh` |

## Decisions pending

None.

## Findings

| # | Finding | Impact | Triaged to |
|---|---|---|---|
| F1 | The mutation subject map for `scripts/agent-sandbox.sh` named only the dispatch suite, so D14 survived even though the contract suite covered the validator. | The new validator was not load-bearing under mutation. | Completed: `scripts/mutations_run.sh` and mutation rows; 15/15 proven. |

## Completed

| File | Change |
|---|---|
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | The project-path selector is `project`; the default field list and internal names follow, and `dir` is no longer a selector. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | `CLI_FIELDS` maps each field to its resolver mode, flag and variable; `catalog_validate` runs before help or dispatch; `dispatch` and `print_json` derive from the table. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | Pins `project` as the selector and `dir` as retired. |
| [`tests/test_resolution_contract.sh`](../../../tests/test_resolution_contract.sh) | The catalogue vocabulary and the unknown-field failure are contract cases. |
| [`tests/test_agent_cli_dispatch.sh`](../../../tests/test_agent_cli_dispatch.sh) | The JSON identity/flags rendering and every forwarded flag are pinned. |
| [`tests/mutations/catalog.jsonl`](../../../tests/mutations/catalog.jsonl) | D13 moves to the table; D14 proves validation and D15 the project mapping. |
| [`scripts/mutations_run.sh`](../../../scripts/mutations_run.sh) | The dispatcher subject map includes the contract suite, so D14 is load-bearing. |
| [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | R14, C8, the 2026-11-24 entry and the D13 correction record the field vocabulary. |
| [`docs/development/interface-conventions.md`](../../../docs/development/interface-conventions.md) | The dispatcher help contract names the forwarded flag and the JSON field/flags split. |
| [`docs/reference/tool_interface.md`](../../../docs/reference/tool_interface.md) | The JSON surface names resolver fields and forwarded flags. |
| [`devlog/roadmap.md`](../../roadmap.md) | The row closes, the decision is recorded, and the path-format row is filed. |
