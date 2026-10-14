---
date: 2026-10-10
milestone: M3.4 - Configuration and Persisted Record Formats
type: Implementation
status: Closed
---

# Handover - Implementation: strip one layer of matching quotes in env_load

## Objective

Make the `.env` loader treat a matching pair of surrounding quotes as the quoting convention it is, so a quoted value loads as its contents, which is the first landing of the M3.4 environment-load row.

## Scope

One parser change in `src/libs/env.sh` and four new test units in `tests/test_env.sh`. After the existing key and value trims, the loader strips one layer of matching surrounding double or single quotes. Padding inside the quotes survives. An unbalanced quote, an embedded quote, and an empty quoted value behave literally: the first two are data, the third is the empty string.

Probed first, per the register's two resolved shapes: `export FOO=bar` still defines `FOO=bar` and a no-`=` line is still skipped with a warning. The live defect the probe found is the quoted-value shape in both syntaxes: `QUOTED="quoted value"` loaded as `"quoted value"` with the quotes in the value. The read-through row's two shapes were already fixed in 2026-09; the row text is now corrected in the roadmap by the pointer this milestone carries.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A double-quoted and a single-quoted value load as their contents, padding preserved | `bash tests/test_env.sh` (new units) | accepted: 14 passed, 0 failed |
| An unbalanced or embedded quote stays verbatim | the new unbalanced unit | accepted, after the 2026-10-10 correction below [CORRECTION -- 2026-10-10: the unit as first written could not fail on the interior-pairing shape; the fixture gained the `P` and `W` shapes and the guard was narrowed to a full enclosure] |
| The register's two shapes stay fixed | the existing export-prefix and no-equals units | accepted: both pass unchanged |
| Downstream loaders of the same file are unaffected | `bash tests/test_session_env.sh`, `bash scripts/run_tests.sh` | accepted: 17 passed, then 1054 passed 0 failed across 72 files |
| Gates clean | `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh`, `bash scripts/lint.sh` | accepted: 0 warnings, 0 findings, clean |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/env.sh`](../../src/libs/env.sh) | the shared `.env` loader; the quote rule lives with the other parsing rules |
| [`tests/test_env.sh`](../../tests/test_env.sh) | three new units pin the quote shapes against the existing twelve |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Strip exactly one layer, after the trims | a value quoted once is a convention; double-quoting (`K=""x""`) is data, and stripping after the trims keeps `K="  x  "` padding intact | this handover |
| Leave the prelude identity re-assert alone in this unit | the re-assert is the flag-wins precedence implementation, not redundant tax; removing it requires the load-then-resolve reorder, which is the next unit and carries its own risk surface | this handover, as a finding |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The reviewer dispatch (`pi -p`, pointed at `@src/reasoning/agent/skills/thermo-nuclear-code-quality-review/`) returned four findings on the first version of this unit. Three were verified by probe and all three are real: the ends-pairing guard stripped `K="a" and "b"` to `a" and "b"; the edit's anchor consumed the registration line of the happy-path unit, leaving the healthy-path unit unregistered; and the unbalanced unit passed under a mutation that deleted the whole quote block. [A] 2026-10-10 | bug | current iteration |
| The review also surfaced a pre-existing bug the first fix would have made worse: `export "$KEY=$VALUE"` targets the loader's function scope, so a local named like a .env key swallowed it -- a file with `VALUE=x` or `KEY=x` dropped the variable silently. The scratch names are now `_env_`-prefixed and a same-prefixed key is refused with a warning. [A] 2026-10-10 | bug | current iteration |
| The reorder that removes the identity re-assert (load `.env` before `env_resolve_identity`, so the resolver's exports land after the bulk load and the triple is asserted once) must first pin the missing-`.env` error path: today a flag-supplied identity with no `.env` still fails with the onboard hint, and `env_resolve_one` prints that hint only when no level supplies a value. [A] 2026-10-10 | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| [`src/libs/env.sh`](../../src/libs/env.sh) | one layer of matching surrounding quotes stripped from the value, with the header rule updated |
| [`tests/test_env.sh`](../../tests/test_env.sh) | three units: matching quotes with padding, unbalanced and embedded quotes, empty and export-prefixed quoted values |
