---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Housekeeping
status: Closed
---

# Handover - The harness and agent-runtime vocabulary

## Objective

Reserve `harness` for the whole setup and name pi and opencode `agent-runtime`, renaming the shared image tier from `agent-harnesses` to `agent-runtimes`.

## Scope

The M3.6.4 naming change the operator deferred here on 2026-10-22. In scope: the reserved vocabulary, the shared image tier and its live carriers, and the roadmap row that names them.

Out of scope: the `src/reasoning/providers/` to `src/reasoning/agent-runtime/` directory rename, which is a 121-reference structural move filed this iteration as its own open M3.6.4 row; and `src/reasoning/agent/` to `agent-context`, deferred by the same 2026-10-22 decision. Historical records -- archived handovers and discussions, the closed handovers `20261017-02` to `20261017-06`, and the changelog -- are not retro-renamed; they state what was true when they were written. `tests/test_build_probe.sh` and `tests/test_container_layout.sh` were planned for fixture changes and needed none: neither carries a tier token, and both pass as regression checks.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The vocabulary defines `harness` as the whole setup and `agent-runtime` as pi/opencode | `grep -nE "^## (harness\|agent-runtime)$" docs/reference/terminology.md` returns both | Agent [x] |
| The old tier name is gone from live carriers | `grep -rnE "agent-harnesses\|harnesses\.dockerfile\|harnesses_base_image_name" src scripts tests .agents workflow` returns no match; the only `docs/` matches are the historical entries, the rejected-alternative row and the rename note | Agent [x] |
| The new tier name is present where the build, probe, tests and docs name it | `grep -rnE "agent-runtimes\|runtimes\.dockerfile\|runtimes_base_image_name" src scripts tests docs .agents workflow` returns 58 matches | Agent [x] |
| The tier's build and contract checks pass under the new name | `bash tests/test_shared_base_contract.sh` 8, `test_trace_build.sh` 17, `test_build_probe.sh` 14, `test_container_layout.sh` 37, `test_image_names.sh` 8; all pass | Agent [x] |
| The ADR records the rename and keeps the old name as history | `grep -nE "^## 2026-11-07\|^## 2026-10-17" docs/adr/reasoning_layer_tiers.md` names both entries | Agent [x] |
| The live architecture documents describe the tier as built | `tool_interface.md`, `provider_onboarding_guide.md` and `opencode_runtime_dispatch.md` carry 9 `agent-runtimes` mentions | Agent [x] |
| The roadmap names `agent-runtimes`, and the directory move is an open M3.6.4 row | `git diff 14ed4449 -- devlog/roadmap.md` shows both | Agent [x] |
| Every decision this iteration recorded is realized in the files | the naming decision is in the terminology and the ADR; the directory row is in the roadmap; the history rule is in the terminology Usage | Agent [x] |
| Historical records are unchanged | `git diff 14ed4449 -- devlog/handovers/20261017-*.md devlog/changelog.md docs/adr/archive devlog/discussions/archive` is empty | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `agent-runtimes` names the shared tier and image; `agent-runtime` is the reserved term, with `runtime` as the short form | the tier holds pi and opencode, so the plural names what it installs; the qualified term disambiguates the executable from the harness | `docs/reference/terminology.md`, `docs/adr/reasoning_layer_tiers.md` |
| The directory move is its own M3.6.4 row | the vocabulary change touches about twenty files; the directory rename touches 121 references and is a separate outcome | this record; the roadmap row written this iteration |
| Historical records are not retro-renamed | the work-log convention states it, and a record that renamed its own past would misstate what was built | `docs/reference/terminology.md` Usage |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `docs/adr/pi_subagent_dispatch.md` linked `#runtime` and said `runtime` where the reserved term is now `agent-runtime` | defect (record) | renaming the heading broke the link, so the record no longer reached the term it cited | fixed here, link and prose updated |
| `docs/reference/tool_interface.md` said base images are built once per provider | defect (record) | false for the shared tier, which is built once for all providers | fixed here in the same paragraph |
| `src/reasoning/runtimes.dockerfile` named `src/libs/dispatch.sh` for the runner seam | defect (record) | the seam moved to `scripts/dispatch.sh` and `src/libs/dispatch/`; the old path sends a reader to a missing file | fixed here |
| `src/reasoning/providers/opencode/provider.dockerfile` named `scripts/build_container.sh` | defect (record) | the build entrypoint is `scripts/build.sh`; the comment named a file the tree does not hold | fixed here |
| The host build probe's expected tier names move with this rename | process | the operator's open probe row must expect `agent-runtimes` where it expected `agent-harnesses` | the open row `The host build probe is re-run against the new shape` |

## Completed

| File | Change |
|---|---|
| `.agents/drafts/harness-tier-unification-run.md` | tier names updated to `agent-runtimes`; the prose says agent-runtime where it means the executable |
| `.agents/skills/pi-bump/SKILL.md` | bump path and tier name updated |
| `devlog/roadmap.md` | the M3.6.4 text names `agent-runtimes`; the directory-move row is filed open |
| `docs/adr/harness_versioning.md` | the layer list names `agent-runtime` and `harness payload` |
| `docs/adr/opencode_runtime_dispatch.md` | the current entry names `agent-runtimes`; a rename note is added |
| `docs/adr/pi_subagent_dispatch.md` | the `#runtime` link and prose updated to `agent-runtime` |
| `docs/adr/reasoning_layer_tiers.md` | requirements and a 2026-11-07 entry name `agent-runtimes`; the old entry stays historical |
| `docs/development/provider_onboarding_guide.md` | Step 2 and the tier bullets name the agent-runtime install; language runtime disambiguated |
| `docs/reference/terminology.md` | `harness` and `agent-runtime` entries; the provider entry points at the new term |
| `docs/reference/tool_interface.md` | naming table and tier paragraph; the stale `built once per provider` sentence corrected |
| `scripts/build.sh` | tier-2 image and Dockerfile names; comments follow |
| `scripts/build_probe.sh` | `runtimes_base_image_name` and `runtimes.dockerfile` |
| `src/build/image.sh` | `runtimes_base_image_name` returns `agent-runtimes` |
| `src/reasoning/providers/opencode/provider.dockerfile` | header, base image and stale build-script name |
| `src/reasoning/providers/pi/provider.dockerfile` | header and base image |
| `src/reasoning/harnesses.dockerfile` to `src/reasoning/runtimes.dockerfile` | renamed; header names the tier; stale dispatch path fixed |
| `tests/test_image_names.sh` | new `runtimes_base_image_name` unit |
| `tests/test_shared_base_contract.sh` | tier names, test name and comments |
| `tests/test_trace_build.sh` | build-order expectation and test name |
