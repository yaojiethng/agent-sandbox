---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the sandbox record is read, never exported

## Objective

A value the sandbox record holds reaches its reader by key and never as a child's environment, so the record is the source of truth for its own keys, and the compose file the generator writes declares every value it holds.

## Scope

The M3.4.2 row **The sandbox record is read, never exported**. The file list is the scope proposal's, presented at the scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No record key reaches a process that resolved it, or its children | `bash tests/test_env_read_discipline.sh` -- `test_record_key_reaches_no_child`; `test_common_init_exports_identity_and_paths` asserts `DELIVERABLE_MODE` is unset | Agent [x] |
| The parser prints and never exports | `grep -cE '^[[:space:]]*export ' src/libs/env.sh` prints `0`; `test_parser_exports_nothing` | Agent [x] |
| The host prelude carries no read site | `grep -vE '^\s*#' src/libs/session_env.sh \| grep -cE '(env_load\|env_parse\|env_get) '` prints `0`; `test_prelude_carries_no_read_site` | Agent [x] |
| A record key has no environment level | `grep -vE '^\s*#' src/libs/env_resolve.sh \| grep -c AGENT_SANDBOX_` prints `0`; the two env-level tests are inverted to assert the record wins; `test_no_environment_level_for_a_record_key` | Agent [x] |
| The generated compose carries no harness `${...}`, only an operator credential | `grep -rn '\${' src/build/*.yml src/reasoning/agent-runtime/*/docker-compose*.yml` lists only credential rows; `test_start_agent.sh::test_rendered_compose_fully_substituted_and_names_both_containers` | Agent [x] |
| The four channels and the ladder are stated once | `grep -n 'Four channels' docs/adr/resolution_model.md`; the `2026-11-22` entry; `docs/reference/execution_model.md` states the generator rule; `docs/reference/sandbox_identity.md` states the ladder | Agent [x] |
| `make test` and `scripts/lint.sh` pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |
| The roadmap row compacts to its landing note and handover link | `grep -n 'The sandbox record is read, never exported' devlog/roadmap.md` carries the landing note and the handover link | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the delivery diff -- eight decisions, each naming its file | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Configuration travels by four channels and no fifth: the OS-and-docker environment, the tool's own configuration, the sandbox record, the run record. Only the first two are ambient. | A record that is exported becomes the ambient environment of every child: it stops being the source of truth, two writers own one fact, and a leak is indistinguishable from a legitimate value. | This table; `docs/adr/resolution_model.md`, `2026-11-22` entry |
| A record key resolves as argument, then record, then a stated default or a hard error. | R2 stated "flag beats an environment variable and the `.env`"; with no environment level the requirement narrows to the record, and R4 is replaced by its inverse. | This table; `docs/adr/resolution_model.md` requirements table; `docs/reference/sandbox_identity.md` |
| `AGENT_SANDBOX_<KEY>` retires for every key the record holds, identity included. | The level was a second writer for a key the record already owns. `AGENT_SANDBOX_REPO` and `AGENT_SANDBOX_INSTALL_DIR` stay: they are the tool's configuration, a different channel. | This table; `src/libs/env_resolve.sh`; the ADR entry's edge cases |
| `env_load` is replaced by `env_parse` and `env_get`, and the host prelude loads nothing. | The parser's job is to print the record; the reader's job is to ask for a key. A loader that exports is the leak path itself. | This table; `src/libs/env.sh`, `src/libs/session_env.sh`, `src/libs/env_resolve.sh` |
| The compose generator writes every value it holds; `${VARIABLE}` survives only for an operator credential. | A generated file that depends on its invoker is a file nobody declared. The credential is the operator's, not the harness's to write. | This table; `docs/reference/execution_model.md`; `src/build/compose.sh` |
| The legacy `${SANDBOX_DIR}`, `${WORKTREE_DIR}` and directory sed rules are deleted in favour of `{{...}}` placeholders. | One placeholder form, so the substitution rule and the template agree and the container-interface manifest compares like with like. | This table; `src/build/compose.sh`, `src/build/container-interface.json` |
| `run_agent.sh` reads `SERVE_PORT` from the record by key, and `install_dir` keeps its own two environment names. | The port is a record key; the install directory is the tool's configuration, so its level is the caller's and the record is the fallback. | This table; `scripts/run_agent.sh`, `scripts/install.sh` |
| `tests/test_env_read_discipline.sh` holds the boundary twice: a runtime probe that a record key reaches no child, and a census that fails until a new read site is deliberately amended. | The runtime probe catches the behaviour; the census catches the next `env_load`-shaped shortcut before it lands. | This table; `tests/test_env_read_discipline.sh`, `docs/adr/resolution_model.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The boundary probe uses one key (`RECORD_BOUNDARY_PROBE`), and the identity triple is still exported as the harness's resolved value. | test | A future change that re-exports an identity key would pass the probe, because the probe does not name those three keys. | The T11 record-key row: pin the exported name set beside the record key set. |
| The `.env` still carries `MAKEFILE_VERSION` (no reader) and `INSTALL_DIR` (the tool's configuration, channel B, in the sandbox record). | code | The record holds two keys that are not its own, which is the class split's remaining tail. | T11's **The sandbox record carries only sandbox configuration**, written this iteration. |
| `env_parse` renders a value as `KEY=VALUE` on stdout, so a value containing a newline cannot round-trip. | code | No record value carries a newline today, and every reader takes one key. | Deferred; named here, not filed, because no task holds it yet. |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | M3.4.2's row restated as **The sandbox record is read, never exported**: four channels, argument/record/default for a record key, `AGENT_SANDBOX_<KEY>` retired, generator writes what it knows. |
| [`devlog/roadmap.md`](../../roadmap.md) | M3.4.3's identity sub-row given the key shrink (`init_sha` and the contract version stay, six keys leave), the one-writer rule, and the move out of `.git`. |
| [`devlog/roadmap.md`](../../roadmap.md) | M3.4.7's **container-harness contract** given the no-interpolation requirement, host uid and gid included. |
| [`devlog/roadmap.md`](../../roadmap.md) | M3.4.7's **session identity in the agent container** given its basis: declaration is ergonomics, the record is the source. |
| [`devlog/roadmap.md`](../../roadmap.md) | T11 gains **The sandbox record carries only sandbox configuration**. |
| [`devlog/roadmap.md`](../../roadmap.md) | The three rescoped rows lose their provenance clauses; the rows state what they require and nothing about the move. |
| [`src/libs/env.sh`](../../../src/libs/env.sh) | `env_load` replaced by `env_parse` (prints canonical entries) and `env_get` (reads one key); no `export` remains. |
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | The `AGENT_SANDBOX_<KEY>` level removed; `env_resolve_one` takes `KEY ENV_FILE [REMEDY]`; `_env_value` reads through `env_get`. |
| [`src/libs/session_env.sh`](../../../src/libs/session_env.sh) | The bulk load and the identity re-assert removed; the prelude resolves nothing and loads nothing. |
| [`scripts/run_agent.sh`](../../../scripts/run_agent.sh) | `SERVE_PORT` read from the record by key; `env.sh` sourced. |
| [`scripts/install.sh`](../../../scripts/install.sh) | `install_dir` keeps its two environment names as the caller's level and reads the record through `env_resolve_one`. |
| [`scripts/onboard.sh`](../../../scripts/onboard.sh) | The refresh-mode `PROJECT_DIR` read uses the new `env_resolve_one` arity. |
| [`src/build/compose.sh`](../../../src/build/compose.sh) | Writes `{{HOST_UID}}`, `{{HOST_GID}}`, `{{SERVE_PORT}}`, `{{AUTOSAVE_INTERVAL}}`, `{{RESET_VOLUME}}` and the `{{SANDBOX_DIR}}`/`{{WORKTREE_DIR}}`/directory paths; the legacy `${...}` sed rules are deleted; `SERVE_PORT` and `AUTOSAVE_INTERVAL` are read from the record. |
| [`src/build/docker-compose.yml`](../../../src/build/docker-compose.yml) | Every harness `${...}` converted to `{{...}}`; the header and path-mapping comments state the rule. |
| [`src/build/docker-compose.copy.yml`](../../../src/build/docker-compose.copy.yml) | Session identity and host uid/gid written by the generator. |
| [`src/build/docker-compose.mount.yml`](../../../src/build/docker-compose.mount.yml) | Worktree path written by the generator. |
| [`src/reasoning/agent-runtime/pi/docker-compose.pi.yml`](../../../src/reasoning/agent-runtime/pi/docker-compose.pi.yml) | Sandbox-dir mount sources moved to `{{SANDBOX_DIR}}`; credentials left as `${...}`. |
| [`src/reasoning/agent-runtime/opencode/docker-compose.serve.yml`](../../../src/reasoning/agent-runtime/opencode/docker-compose.serve.yml) | Serve port written by the generator; the password stays a `${...}`. |
| [`src/build/container-interface.json`](../../../src/build/container-interface.json) | The pi mount sources name `{{SANDBOX_DIR}}`, matching the overlay the layout gate compares against. |
| [`tests/test_env.sh`](../../../tests/test_env.sh) | Rewritten for `env_parse`/`env_get`; the child-export case inverted, the duplicate-key rule added. |
| [`tests/test_env_read_discipline.sh`](../../../tests/test_env_read_discipline.sh) | Holds the boundary: no export in the parser, no read in the prelude, no environment level, a runtime child probe, and the amended census. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | The two environment-level cases inverted; arity updated; the absent-default case now supplies explicit identity. |
| [`tests/test_session_env.sh`](../../../tests/test_session_env.sh) | The prelude's export contract asserts the record is *not* loaded; the env-var case inverted. |
| [`docs/adr/resolution_model.md`](../../../docs/adr/resolution_model.md) | `2026-11-22` entry: four channels, the ladder, one writer per fact; R2 and R4 rewritten, R7 added. |
| [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md) | Compose generation states the write-everything rule and the credential exception. |
| [`docs/reference/sandbox_identity.md`](../../../docs/reference/sandbox_identity.md) | The resolution-precedence paragraph loses the environment level. |
| [`docs/reference/tool_interface.md`](../../../docs/reference/tool_interface.md) | The `.env` variable table states that no value is exported, and the two generator-written values say who writes them. |
| [`workflow/coding-agent/skills/close-read/assets/exemplar.md`](../../../workflow/coding-agent/skills/close-read/assets/exemplar.md) | The quoted unit follows the parser's new name and behaviour. |
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh), [`tests/test_start_agent.sh`](../../../tests/test_start_agent.sh) | Two comments that still named the retired `AGENT_SANDBOX_SANDBOX_DIR` level. |
