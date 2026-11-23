---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - a process reads a record once

## Objective

A process opens a record once, at its entry, reads every value it needs from that view, and hands a value on as an argument; no process parses a record twice and no record key reaches a child's environment.

## Scope

The T11 row **A process reads a record at most once, at its entry**. The file list is the scope proposal's, presented at the scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Three identity fields cost one parse | `bash tests/test_env_read_discipline.sh` -- `test_identity_resolve_opens_the_record_once` | Agent [x] |
| The opened view is the value, not the file | the same file -- `test_record_view_is_the_value_not_the_file` | Agent [x] |
| The generator reads no record | `grep -cE '(record_open\|record_get\|env_get)' src/build/compose.sh` prints `0`, and the census carries no `src/build/compose.sh` row | Agent [x] |
| No record key is exported | `grep -c 'export SERVE_PORT' scripts/run_agent.sh` prints `0`; `test_record_key_reaches_no_child` | Agent [x] |
| The record's optional worktree path reaches the run | `bash tests/test_session_env.sh` -- `test_names_worktree_reads_the_record`, which asserts the record value and the default when the key is absent | Agent [x] |
| A whole entry opens the record once | `bash tests/test_env_read_discipline.sh` -- `test_a_chain_step_opens_the_record_once`, which measures identity, init and names in one process | Agent [x] |
| An unknown placeholder fails the generator | the same suite, `test_trace_compose_gen.sh` -- `test_compose_generate_rejects_an_unknown_placeholder` | Agent [x] |
| `make test` and `scripts/lint.sh` pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the delivery diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A process opens a record once, at its entry, and reads from the view. | The chain parsed the record six times across three processes, and two of the three read a file the process above them had already resolved. Six views of one record can disagree; one view cannot. | This table; `docs/adr/resolution_model.md`, the `2026-11-22` entry |
| `record_open` is `env_parse`'s only caller, and `env_get` is deleted. | One parse per file per process becomes a property of the library rather than a discipline each reader remembers. The census holds that no new reader lands; the parse count is held behaviourally, because pinning the function that holds the call fails a correct refactor. | This table; `src/libs/env.sh`, `tests/test_env_read_discipline.sh` |
| An optional record key is read from the view, not required through the primitive. | A key with a stated default is not an error when absent, so it reads empty from the view and the reader applies the default; requiring it would turn every optional setting into a hard failure. | This table; `src/libs/session_env.sh` |
| The record's duplicate key rule is last-wins, stated once. | Two readers disagreed: the bulk loader exported line by line, so a later line won, while `env_get` returned the first match. One view means one rule, and a shell reading a script is the model. | This table; `src/libs/env.sh`, `tests/test_env.sh` |
| The process opens the record into a view every later stage reuses. | The resolver opens at the identity step and the initialiser runs later in the same process; without reuse the entry paid two opens for one file, which is the rule's own failure. | This table; `src/libs/env.sh`, `src/libs/session_env.sh`, `src/libs/env_resolve.sh` |
| An unresolved `{{...}}` in a staged template fails generation and names the placeholder. | Left in place it reaches `docker compose` as a literal and fails there, far from the cause; the check costs less than the debug it saves. A placeholder inside a comment is prose and is not checked. | This table; `src/build/compose.sh`, `tests/test_trace_compose_gen.sh` |
| `compose_generate` reads no record; the caller hands it the serve port and the autosave interval. | The generator becomes a function of its arguments, so a test drives it without a sandbox, and the record has one reader in that process instead of two. | This table; `src/build/compose.sh`, `scripts/run_agent.sh` |
| The values cross into the generator through the call-scoped assignment prefix the dry-run paths already use. | It is the idiom this file already carries for exactly this purpose, so no signature change and no new flag surface, which is what M3.4.2's router row is trying to shrink. | This table; `scripts/run_agent.sh` |
| The census grows a per-file call count for `record_open`/`record_get` and drops the `src/build/compose.sh` row. | The census is the check that a new reader cannot land quietly; the deletion of a row is the evidence the generator stopped reading. | This table; `tests/test_env_read_discipline.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| This does not rewrite M3.4.3's identity sub-row; it changes the API that row will use (`record_open`/`record_get` instead of per-key reads) and leaves the record's contents and home untouched. | scope | A lands against a reader that already opens once, so A adds no read discipline of its own. | M3.4.3's sub-row gains one clause: the read rule is per record, so a split into project and harness state means one open per record per process, not one open total. |
| `env_resolve_identity` can open two different files in one process: the CWD fallback to bootstrap `SANDBOX_DIR`, then the sandbox's own record. | code | The rule is one parse per file per process, not one per process, so the bootstrap is compliant; the second open clears the view so no key leaks across. | Deferred; named here. A shared first open would need `SANDBOX_DIR` before the path is known. |
| A review of this branch found the regression this iteration introduced: the commit removed the bulk `.env` load and did not replace the one record key that had no by-key reader, so `WORKTREE_DIR` in the record was silently ignored and mount delivery used `<sandbox>/.worktree`. | code | An operator who sets the key as the onboarding guide instructs gets a different checkout, with no error, and every resume regenerates it. | Fixed before this commit: `resolve_and_init` opens the record into the process view, `session_env_names` resolves the invocation value, then the record, then the default, and `test_names_worktree_reads_the_record` holds the record level. |
| Fixing the worktree read created a second open of the same file in one process: the resolver opened its own view and the initialiser opened another. | code | The entry contradicted the criterion the same commit states, and the defect was invisible to the parse-count test, which measured one stage. | Fixed before this commit: `env_record_view` is the one opener and a later stage reuses it; `test_a_chain_step_opens_the_record_once` measures the whole entry. |
| The generator left an unknown placeholder in the file silently. | code | The failure surfaced at `docker compose up` as a literal path or value, far from the template that named it. | Fixed before this commit: generation fails and names the placeholder; a comment is not checked. |
| The previous iteration's `test_compose_generate_preserves_runtime_var` used `${SERVE_PORT}` as its example, which the generator no longer leaves for runtime resolution; the test passed for the wrong reason. | test | A test that proves a property with a retired example stops proving it the day the property's scope narrows. | Fixed in this iteration: the fixture and the assertion now name a credential. |
| The last `${...}` in the generated file was a record key: `OPENCODE_SERVER_PASSWORD` is written into the sandbox `.env` at onboard and interpolated by Compose from `--project-directory`, so a record value reached the container outside the declaration. | code | The boundary rule read as unconditional while one record key travelled by a mechanism no test could see. | Resolved by removal on the operator's ruling: the serve overlay carries no credential, so no record key is interpolated at all and the only `${...}` left is an operator's provider key. |
| A static check pinned the parse call to `record_open` by line range: a pure refactor that wrapped the same single parse in a helper failed it, and a lazy view that re-read the file on every read passed it. | test | A check that fails a correct implementation and passes the defect it names is worse than no check: it teaches a reader to amend the gate. | Fixed in this iteration: the line-range check is deleted, and the property is held by `test_record_view_is_the_value_not_the_file`, which the lazy view fails. |
| Three comments still promised a resolution level this branch deleted: the dispatcher header and seam comment, and the Makefile template's identity note named `AGENT_SANDBOX_<KEY>` as a rung. | doc | A reader following the help text would set a variable that resolves nothing. | Fixed in handover `20261122-07`: the paragraphs are removed, not corrected -- a comment that went stale unnoticed was not load-bearing. The dispatcher's two subcommand lists had already converged. |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | T11 gains **A process reads a record at most once, at its entry**, landed with its note and this handover's link. |
| [`src/libs/env.sh`](../../../src/libs/env.sh) | `record_open` and `record_get` replace `env_get`; `env_parse` is documented as `record_open`'s only dependency. |
| [`src/libs/env.sh`](../../../src/libs/env.sh) | `env_record_view` is the one opener: it reuses the view already open for a file, so a later stage in the same process costs no parse. |
| [`src/build/compose.sh`](../../../src/build/compose.sh) | The header states the write-everything rule and the placeholder set; a staged template carrying an unknown placeholder fails generation by name. |
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | `env_resolve_identity` opens the process view once and reads up to three fields from it; `_record_field` is the one read-or-fail rule and `_env_value` is deleted. |
| [`scripts/run_agent.sh`](../../../scripts/run_agent.sh) | One `record_open` at the entry; `SERVE_PORT` from the view; `export SERVE_PORT` removed; both record values handed to the generator for the call. |
| [`src/build/compose.sh`](../../../src/build/compose.sh) | Takes the serve port and the autosave interval from its call scope; reads no record. |
| [`tests/test_env.sh`](../../../tests/test_env.sh) | Rewritten for `record_open`/`record_get`; the duplicate-key case now asserts last-wins. |
| [`tests/test_env_read_discipline.sh`](../../../tests/test_env_read_discipline.sh) | Two new checks: one parse for three fields, and a view that outlives its file; the census amended. |
| [`tests/test_trace_compose_gen.sh`](../../../tests/test_trace_compose_gen.sh) | The runtime-variable case uses a credential, which is the only value the generator leaves unresolved. |
| [`src/libs/session_env.sh`](../../../src/libs/session_env.sh) | `resolve_and_init` opens the record into one process view, `env_record_get` reads it, and the worktree path resolves as invocation value, then record, then the sibling default. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | The dispatch header and the seam comment state the ladder the resolver runs: explicit, then record, then the error naming `onboard`. |
| [`scripts/templates/Makefile.template`](../../../scripts/templates/Makefile.template) | The identity note names the record and the invocation directory, not a deleted environment rung. |
| [`tests/test_session_env.sh`](../../../tests/test_session_env.sh) | `test_names_worktree_reads_the_record`: the record's value reaches the run, and an absent key takes the default. |
| [`src/build/docker-compose.mount.yml`](../../../src/build/docker-compose.mount.yml) | The header states where the worktree path resolves, which is `session_env.sh` and not the old loader. |
| [`devlog/roadmap.md`](../../roadmap.md) | The closed M3.4.2 row names `record_get`, not the `env_get` this iteration deleted. |
| [`src/reasoning/agent-runtime/opencode/docker-compose.serve.yml`](../../../src/reasoning/agent-runtime/opencode/docker-compose.serve.yml) | The serve overlay carries no credential: the loopback binding is the whole of its exposure, and the last record key left to Compose interpolation is gone. |
| [`docs/reference/tool_interface.md`](../../../docs/reference/tool_interface.md) | The `.env` note states the strengthened invariant: nothing exported and nothing interpolated. |
| [`docs/adr/resolution_model.md`](../../../docs/adr/resolution_model.md) | The `2026-11-22` entry states the read rule, the one-caller property and the measured six-parse start chain. |
| [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md) | Compose generation states that the generator is handed its values and reads no record. |
