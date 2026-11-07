---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Implementation
status: Closed
---

# Handover - The build context narrowed to its declared inputs

## Objective

Make the build context the inputs the build declares, and prove it with a gate that reads `.dockerignore` against every declaration and prints the context's size.

## Scope

Continues the audit [`20261107-02`](20261107-02-audit-build_contract_gap.md); realizes the open row it filed.

In scope: [`The build context is narrowed to the declared inputs`](../../roadmap.md). The `.dockerignore` landed with the tier change, so the delta is the check, the narrowing, the tests and the recorded size. The context's declared inputs are the manifest's `image[].source` rows and every Dockerfile's `COPY` sources; the check holds the ignore file equal to that union in both directions, and prints the included file count and bytes. The page's static wiring layer and its catalog gain the context.

Out of scope: the pin implementation, which has its own row and needs the host to resolve digests and versions; the host probe run, which is the operator's because the container has no Docker; and the provider-directory rename, which has its own row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The context is the declared inputs: every `image[].source` and every Dockerfile `COPY` source survives `.dockerignore`, and every included path is one of those, a dockerfile, or the ignore file | `bash scripts/check_build_context.sh`; 0 findings, and the output names the file count and bytes | Agent [x] |
| The check's branches are tested: an excluded source, an included non-source, a Dockerfile exemption, a missing ignore file, and an unsupported pattern | `bash tests/test_build_context_gate.sh`; the existing `tests/test_build_context.sh` still passes | Agent [x] |
| The gate runs in the lint umbrella | `bash scripts/lint.sh` includes `check_build_context.sh`; clean across the gates | Agent [x] |
| The page names the context check and its invariant | read the static layer table, the context section and the catalog row in `docs/development/build_operational_model.md` | Agent [x] |
| The roadmap row states the ignore file as landed and the check and size as the delta, and the study keeps a live carrier | `git diff 26eaf730 -- devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files | read the `## Decisions` table against the check, the test, the page and the roadmap | Agent [x] |
| The roadmap is checked against the prior handover and no maintenance edit is needed | read the roadmap M3.6.4 section and the prior handover | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The context's declared inputs are the manifest's `image[].source` rows and every Dockerfile's `COPY` sources, and the check is exact: every included path is under one of them or is a dockerfile, and every one is included | the row's outcome is "narrowed to the declared inputs"; a containment-only check leaves the 408 KB of unused context and cannot hold the ignore file's own claim | this record; the page |
| The check reads the manifest through `load_manifest` from `container-interface.mjs` | the manifest has one reader; a second parser would be a second declaration of its shape | this record |
| The ignore matcher supports the ordered prefix form and the `!` exception; any glob is a finding | the file's patterns are path prefixes today; failing closed on a pattern the gate cannot evaluate is honest, where a silent skip would misreport the context | this record; the test |
| The check is a lint gate, not only a unit test | the context is static wiring, caught without a build, like the layout gate; the test covers the branches the real tree cannot | this record |
| The size is the check's included bytes; the page states the invariant and points at the check, and this record carries the iteration's measurement | the page does not own a value the tree derives; a hardcoded byte count goes stale silently | this record; the page |
| The dockerfiles and the ignore file count as context even when a pattern matches them | Docker sends the dockerfile and `.dockerignore` to the builder regardless, so the check's size and its exemption follow the real transfer | this record |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| The `.dockerignore` landed with the tier change, but the roadmap row and the audit's G5 were written before it; the row still says none exists | this record's Scope; the roadmap row now states the ignore file as landed and names the check and the size as the delta |
| The concluded audit study's only live carrier was the context row; closing it would leave the study with no open row | the open `Pin every build input` row, which now carries the study link |
| The sources set was the manifest's `image[].source` rows alone, so `.dockerignore` excluded `src/capability/` -- still an input to the capability image, whose five `COPY` lines the manifest does not carry. The gate read the same set, so it reported the context clean | the set is now the manifest's rows plus every Dockerfile's `COPY` sources, read from the tree; the gate test covers a Dockerfile no row mentions, and the finding names the Dockerfile that reads the excluded path |
| The gate's test first overwrote the existing `tests/test_build_context.sh`, the COPY-contract test, because the convention's name was already taken | the original is restored and the gate's test is `tests/test_build_context_gate.sh`; this record's Completed table names it |

## Completed

| File | Change |
|---|---|
| `src/build/build-context.mjs` | the declared-sources set, the Dockerfile `COPY` reader, the ignore matcher and the check |
| `scripts/check_build_context.sh` | the gate wrapper |
| `tests/test_build_context_gate.sh` | the check's branches, beside the existing COPY-contract test |
| `.dockerignore` | the non-source paths no Dockerfile copies |
| `scripts/lint.sh` | the context gate in the umbrella and its header |
| `docs/development/build_operational_model.md` | the context invariant, the gate and the catalog row |
| `devlog/roadmap.md` | the row's reconciliation and the study link on the pin row |
