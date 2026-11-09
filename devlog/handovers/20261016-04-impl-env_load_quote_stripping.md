---
date: 2026-10-16
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - strip one layer of matching quotes in env_load

## Objective

Make the `.env` loader treat a matching pair of surrounding quotes as the quoting convention it is, so a quoted value loads as its contents, which is the first landing of the environment-load row under M3.4.2.

## Scope

Ported from the parked draft branch, commit `3bed76f0`. In: one parser change in `src/libs/env.sh` and the quoted-value test units in `tests/test_env.sh`. After the existing key and value trims, the loader strips one layer of matching surrounding double or single quotes. Padding inside the quotes survives. An unbalanced quote, an embedded quote, and an empty quoted value behave literally: the first two are data, the third is the empty string. Probed first, per the register's two resolved shapes: `export FOO=bar` still defines `FOO=bar` and a no-`=` line is still skipped with a warning. The live defect the probe found is the quoted-value shape in both syntaxes: `QUOTED="quoted value"` loaded as `"quoted value"` with the quotes in the value. Out: the branch's milestone retitling and its roadmap pointers, which the current tree supersedes; the read-through row and the identity re-assert item stay on their own rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A double-quoted and a single-quoted value load as their contents, padding preserved | `bash tests/test_env.sh` (new units) | 17 passed, 0 failed |
| An unbalanced or embedded quote stays verbatim | the new unbalanced unit | 17 passed, 0 failed |
| The register's two shapes stay fixed | the existing export-prefix and no-equals units | 17 passed, 0 failed |
| Downstream loaders of the same file are unaffected | `bash tests/test_session_env.sh` | 17 passed, 0 failed |
| Gates clean | `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh`, `bash scripts/lint.sh` | 0 warnings across 175 files; 0 findings across 24 files; clean across 9 gates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Strip exactly one layer, after the trims | a value quoted once is a convention; double-quoting (`K=""x""`) is data, and stripping after the trims keeps `K="  x  "` padding intact | this handover |
| Leave the prelude identity re-assert alone in this unit | the re-assert is the flag-wins precedence implementation, not redundant tax; removing it requires the load-then-resolve reorder, which is the next unit and carries its own risk surface | this handover, as a finding |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The reviewer dispatch (`pi -p`, pointed at the thermo-nuclear code quality review skill) returned four findings on the first version of this unit. Three were verified by probe and all three are real: the ends-pairing guard stripped `K="a" and "b"` to `a" and "b`; the edit's anchor consumed the registration line of the happy-path unit, leaving the healthy-path unit unregistered; and the unbalanced unit passed under a mutation that deleted the whole quote block. [A] 2026-10-10 | bug | current iteration | fixed in this unit |
| The review also surfaced a pre-existing bug the first fix would have made worse: `export "$KEY=$VALUE"` targets the loader's function scope, so a local named like a .env key swallowed it, and a file with `VALUE=x` or `KEY=x` dropped the variable silently. The scratch names are now `_env_`-prefixed and a same-prefixed key is refused with a warning. [A] 2026-10-10 | bug | current iteration | fixed in this unit |
| The reorder that removes the identity re-assert (load `.env` before `env_resolve_identity`, so the resolver's exports land after the bulk load and the triple is asserted once) must first pin the missing-`.env` error path: today a flag-supplied identity with no `.env` still fails with the onboard hint, and `env_resolve_one` prints that hint only when no level supplies a value. [A] 2026-10-10 | scope change | next iteration | the next unit |

## Completed

| File | Change |
|---|---|
| [`src/libs/env.sh`](../../src/libs/env.sh) | one layer of matching surrounding quotes stripped from the value, with the header rule updated |
| [`tests/test_env.sh`](../../tests/test_env.sh) | quoted-value units: matching quotes with padding, unbalanced and embedded quotes, empty and export-prefixed quoted values |
