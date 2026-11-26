---
date: 2026-11-24
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the record read is one cached primitive

## Objective

The sandbox record is read through one public primitive, `record_get FILE KEY`, which owns the parse and the cache; the array parameter, `record_open`, `env_record_view` and the public `ENV_RECORD` disappear from the tree.

## Scope

The first open M3.4.2 row, raised by the thermonuclear review in [`20261123-04`](20261123-04-impl-review_fixes.md). The iteration changes the record-read API and its six explicit view sites and three reads; it changes no resolution rule, no record format and no parser semantics. `env_parse` stays the public parser. `kv_record.sh` and the catalogue row are out of scope. The `env_resolve_identity` name/dir duplication stays a note, not this row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `record_get FILE KEY` is the only public record read; `record_open`, `env_record_view` and `ENV_RECORD` are neither defined nor called in `src/` or `scripts/`. | `rg -n -e '^\s*record_open\s*\(' -e '^\s*env_record_view\s*\(' src scripts` and `rg -n '\bENV_RECORD\b' src scripts` both print nothing; `rg -n '^record_get\(\)' src/libs/env.sh` prints the definition | Agent [x] |
| A second read of the same file parses it once, and the cached value survives the file's removal. | `bash tests/test_env.sh`, cases `test_record_get_parses_a_file_once` and `test_record_get_cache_survives_file_removal` | Agent [x] |
| The first read of a malformed record warns; a later read of the same file does not. | `bash tests/test_env.sh`, case `test_record_get_warns_once_for_a_malformed_line` | Agent [x] |
| Every reader calls `record_get FILE KEY`, and the read census names the new call sites. | `bash tests/test_env_read_discipline.sh`, case `test_env_resolution_call_census` | Agent [x] |
| The test files use the public primitive; `record_open` and the `ENV_RECORD` array are no longer read from a test. | `rg -n -e '^\s*record_open\s' -e 'record_get ENV_RECORD' -e 'env_record_view\s' tests/test_env.sh tests/test_session_env.sh` prints nothing | Agent [x] |
| The resolution ADR states the one-primitive cache, the `REPLY` return, the one-file slot and the lazy warning behaviour, carries the 2026-11-22 correction, and describes the record read as built. | `rg -n -e '2026-11-24' -e 'REPLY' -e 'one-file slot' -e 'first read' docs/adr/resolution_model.md`; the same ADR read against the diff | Agent [x] |
| Every decision this iteration records is realized in the files. | the `## Decisions` table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `record_get FILE KEY` sets `REPLY` and prints nothing. | Every current read captures the value with `$(...)`, and a command substitution's subshell discards a cache written inside it. A printing primitive cannot hold the one-parse property at these call sites; the two-argument signature survives by returning through `REPLY`. | This table; `docs/adr/resolution_model.md` entry 2026-11-24 |
| The cache holds one file, and reading a different file replaces it. | This is the retired `env_record_view` contract. No caller interleaves two records; a future caller that does pays one re-parse, not a stale merge. | This table; `docs/adr/resolution_model.md` entry 2026-11-24 |
| The parse is lazy: the first `record_get` for a file parses it, and a record no reader asks for emits no warning. | A read primitive cannot parse before it is read without a separate open call, which is the API this row removes. Production reads every record it opens; the observable change is confined to a malformed record nobody reads. | This table; `docs/adr/resolution_model.md` entry 2026-11-24 |
| `env_parse` stays public; `_record_open`, `_ENV_RECORD_CACHE` and `_ENV_RECORD_FILE` become private. | The parser has its own contract and tests; the open and the cache are implementation details of the read primitive. | This table; `src/libs/env.sh` |
| The private cache takes no `AGENT_SANDBOX_` prefix. | That namespace is channel B cross-process tool configuration. A private shell cache is not exported, not an input and not configuration, so the prefix would advertise a contract that does not exist. The leading underscore is the library-private convention. | This table; `docs/adr/resolution_model.md` entry 2026-11-24 |

## Decisions pending

None.

## Findings

| # | Finding | Impact | Triaged to |
|---|---|---|---|
| F1 | A printing `record_get FILE KEY` cannot hold a cache at the six current call sites: each captures the value in `$()`, whose subshell discards the cache. `_record_field` is also captured, so it must stop returning by stdout as well. | Changes the primitive's return channel to `REPLY`; the public signature stays two arguments. | Decisions table; ADR entry 2026-11-24 |

## Completed

| File | Change |
|---|---|
| [`src/libs/env.sh`](../../../src/libs/env.sh) | `record_get FILE KEY` sets `REPLY`, owns `_ENV_RECORD_CACHE` and `_ENV_RECORD_FILE`, and replaces the public array/open/view API. |
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | `_record_field` returns through `REPLY`; the three explicit view calls are gone. |
| [`src/libs/session_env.sh`](../../../src/libs/session_env.sh) | The two view calls are gone; `WORKTREE_DIR` reads through the primitive. |
| [`scripts/run_agent.sh`](../../../scripts/run_agent.sh) | The view call is gone; `AUTOSAVE_INTERVAL` reads through the primitive before `compose_generate`. |
| [`tests/test_env.sh`](../../../tests/test_env.sh) | The read helper uses the primitive; one-parse, cache-survives-removal and warn-once cases added. |
| [`tests/test_env_read_discipline.sh`](../../../tests/test_env_read_discipline.sh) | The cache case moved to the primitive's unit file; the census names the new call sites. |
| [`tests/test_session_env.sh`](../../../tests/test_session_env.sh) | The unopened-view case became a missing-file read. |
| [`docs/adr/resolution_model.md`](../../../docs/adr/resolution_model.md) | Entry 2026-11-24 records the primitive, private cache, `REPLY`, one-file slot and lazy warning; the 2026-11-22 entry carries the correction. |
| [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md) | `run_agent.sh` now reads the record rather than opening a view. |
| [`devlog/roadmap.md`](../../roadmap.md) | The M3.4.2 row is marked with its outcome, and the decision is recorded under the sub-milestone. |
