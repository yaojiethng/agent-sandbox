---
date: 2026-11-22
milestone: T11 - Persisted record formats
type: Implementation
status: Closed
---

# Handover - one date format, and the last carriers of the deleted loader

## Objective

Every date the harness writes comes from `src/libs/time_format.sh`, including the three probe output names; and no comment still describes a mechanism this branch removed.

## Scope

The M3.4.2 row **The probe scripts' timestamps are a second form**, with the carrier sweep the operator's ruling opened: a comment that describes the deleted loader is part of that deletion. The router row is rewritten in the same change, as intent only.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No producer spells a date format | `grep -rn '%Y%m%dT%H%M%SZ' scripts/ src/` prints nothing; `grep -c 'ts_now' scripts/build_probe.sh scripts/stop_probe.sh scripts/stop_signal_matrix.sh` prints one each | Agent [x] |
| The probe tests carry the harness form | `bash tests/test_build_probe.sh`; `bash tests/test_stop_acceptance.sh` | Agent [x] |
| No comment names a resolution level the resolver dropped | `grep -rn 'AGENT_SANDBOX_' scripts/ src/ docs/` names only `AGENT_SANDBOX_REPO`, the install exception, and the rule statements that say it is not a level | Agent [x] |
| Every stated decision is realized in the files | the `## Decisions` table read against the delivery diff | Agent [x] |
| `make test` and `scripts/lint.sh` pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A probe's output name is harness time, not probe-local. | The harness already owns the date format and its two directions; a probe is one more producer, and a second spelling is a second definition nobody parses. | This table; `scripts/build_probe.sh`, `scripts/stop_probe.sh`, `scripts/stop_signal_matrix.sh` |
| A comment that restates a mechanism is removed, not corrected, once it has gone stale. | It went stale and nothing failed, so no reader depended on it; correcting it only schedules the next staleness. What remains is what only the file knows. | This table; `scripts/agent-sandbox.sh`, `scripts/templates/Makefile.template` |
| `AGENT_SANDBOX_INSTALL_DIR` is the one named exception to "a record key has no environment level". | `install` runs before a record is seeded, so there is no record to read; naming the exception keeps it one ruling rather than the precedent for the next key. | This table; `docs/adr/resolution_model.md` R4 and the `2026-11-22` entry |
| The router row states intent and delegates the method. | The row's measured details had already gone stale twice; the stable part is what the contract must guarantee, and the leaf is closest to how. | This table; `devlog/roadmap.md`, M3.4.2 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The dispatcher header repeated every leaf's flags, the identity ladder and a `--target` deprecation no longer in the code. | doc | Three copies of one truth, each free to drift; the flag list had already done so once, which is what the carrier sweep caught. The list now lives in `print_subcommand_list` and each leaf's `--help`. | Fixed here. |
| Nothing tested `stop_signal_matrix.sh`, so its stamp change is unverified by the suite. | test | The rows that do have a test now assert the harness form; this probe is operator-side and Docker-bound, so its exit is a live run rather than a unit test. | Recorded, not scheduled: the sample project's reproduction set is where a live probe run belongs (M3.4.5). |

| The doc-wrap gate declared a 45s budget and takes ~24s alone but more than 45s under the suite's 8-way load, so it timed out twice in this session and cost a full rerun each time. | test | A load-dependent deadline is a flake that reports itself as a failure; the suite's own rule is that a file whose honest runtime exceeds the default states its budget. | Fixed here: the file declares 120s and the reason. |

## Records

| Record | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | M3.4.2's probe-stamp row closes; the router row is rewritten as intent, with its stale measured details dropped. |
| [`docs/adr/resolution_model.md`](../../../docs/adr/resolution_model.md) | R4 and the `2026-11-22` entry state the install exception, and why it stays one. |
| [`tests/test_env_read_discipline.sh`](../../../tests/test_env_read_discipline.sh) | The environment-level check names the exception, so a future reader does not "fix" it. |

## Completed

| File | Change |
|---|---|
| [`scripts/build_probe.sh`](../../../scripts/build_probe.sh) | The output stamp comes from `ts_now`. |
| [`scripts/stop_probe.sh`](../../../scripts/stop_probe.sh) | The same, for the stop probe's run directory and report name. |
| [`scripts/stop_signal_matrix.sh`](../../../scripts/stop_signal_matrix.sh) | The same, for the matrix's run directory. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | The usage block, the identity ladder and the `--target` deprecation are removed; the header states what the dispatcher does and where the subcommand set lives. |
| [`scripts/templates/Makefile.template`](../../../scripts/templates/Makefile.template) | The identity note is removed; the `$(CURDIR)` explanation stays. |
| [`src/libs/session_env.sh`](../../../src/libs/session_env.sh) | The `.env loading` label names the record view. |
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh) | The responsibility line names identity resolution, not `.env loading`. |
| [`scripts/install.sh`](../../../scripts/install.sh) | The stale "one `.env` loader" note names the resolver, and the priority ladder names the exception. |
| [`tests/test_build_probe.sh`](../../../tests/test_build_probe.sh), [`tests/test_stop_acceptance.sh`](../../../tests/test_stop_acceptance.sh) | The fixtures that spelled the old `%Y%m%dT%H%M%SZ` form carry the harness form. |
| [`tests/test_doc_wrap_legacy_gate.sh`](../../../tests/test_doc_wrap_legacy_gate.sh) | The file declares the budget its honest parallel runtime needs. |
