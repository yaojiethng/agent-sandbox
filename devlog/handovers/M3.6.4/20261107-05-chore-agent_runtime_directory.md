---
date: 2026-11-07
milestone: M3.6.4 - The reasoning image refactor
type: Housekeeping
status: Closed
---

# Handover - The provider directory moves to agent-runtime

## Objective

Move `src/reasoning/providers/` to `src/reasoning/agent-runtime/` and sweep every live reference, leaving the historical records as they were written.

## Scope

Continues the audit [`20261107-02`](20261107-02-audit-build_contract_gap.md); realizes its G10 row.

In scope: [`The provider directory is renamed to agent-runtime`](../../roadmap.md). The directory moves because it holds the agent-runtimes (pi, opencode, hermes), and `provider` is reserved for the model-id namespace. The provider ids, the image names and the tier shape do not move. The live references update: `src/`, `scripts/`, `tests/`, `.agents/`, `docs/reference/`, `docs/development/`, `AGENTS.md`, `.dockerignore`, the open roadmap rows, and the open lines of `roadmap_future.md`. The ADR `reasoning_layer_tiers.md` gains a dated entry. Historical records keep the old path in their prose: the handovers, the discussions, the changelog, the feedback record, the closed roadmap rows, and the prior ADR entries. Their link targets move, because a dead link is a navigation defect rather than a recorded fact.

Out of scope: the pin implementation and the host probe run, which have their own rows; and `src/reasoning/agent/` to `agent-context`, deferred by the 2026-10-22 decision.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The directory is `src/reasoning/agent-runtime/`, and `src/reasoning/providers/` no longer exists | `test -d src/reasoning/agent-runtime && ! test -e src/reasoning/providers`; the tree's provider ids, image names and tier shape unchanged | Agent [x] |
| Every live reference resolves, with no old path left in the live set | `grep -rn 'src/reasoning/providers' src scripts tests .agents docs/reference docs/development AGENTS.md .dockerignore` returns no match; the open roadmap rows carry the new path | Agent [x] |
| The historical records' prose keeps the old path, and their link targets resolve to the new one | `grep -rn 'src/reasoning/providers' devlog/handovers devlog/discussions` returns the recorded prose; `bash scripts/check_markdown.sh` is clean | Agent [x] |
| The layout, context and tier-contract gates agree with the move | `bash scripts/check_container_layout.sh`, `bash scripts/check_build_context.sh`, `bash tests/test_shared_base_contract.sh`, `bash tests/test_trace_build.sh`, `bash tests/test_image_names.sh`, `bash tests/test_build_probe.sh` all clean | Agent [x] |
| The live architecture documents and the ADR describe the directory as built | `grep -rn 'agent-runtime/' docs/reference docs/development docs/adr/reasoning_layer_tiers.md` finds the current path; the ADR carries the 2026-11-07 entry | Agent [x] |
| The suite and the lint pass | `bash scripts/run_tests.sh`; `bash scripts/lint.sh` | Agent [x] |
| Every decision this iteration recorded is realized in the files | read the `## Decisions` table against the tree, the ADR and the roadmap | Agent [x] |
| The roadmap is checked against the prior handover and no maintenance edit is needed | read the roadmap M3.6.4 section and the prior handover | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The move changes the directory only; the provider ids, the image names and the tier shape stay | the provider id names a model-id namespace and the image names are the runtime tier's, so neither is a directory path; the move is structural | this record; the ADR entry |
| The live set is `src`, `scripts`, `tests`, the two `docs/` subtrees that describe the current system, `AGENTS.md`, `.dockerignore`, the open roadmap rows and the open `roadmap_future` lines; the historical records keep the old path | the work-log convention says a record states what was true when it was written; the prior vocabulary rename set the same boundary | this record; the ADR entry |
| The ADR gains a new dated entry, and the prior entries keep their text | the ADR is the decision record; a new decision is an entry, and rewriting the prior entry would misstate the decision it recorded | this record; `docs/adr/reasoning_layer_tiers.md` |
| The sweep is a script over the live set, and the gates prove it | a 130-file hand edit is unverifiable; the script is the artifact a reviewer reruns, and the layout and context gates catch a path the script missed | this record |
| The `.dockerignore` entries and the manifest sources move with the directory, so the context gate re-proves the declared inputs | the context check reads the manifest; the manifest's sources are the moved paths, and the ignore file must stay their complement | this record; the context check |
| A historical record's prose keeps the old path, and its link targets update to the new one | the prose states what was true when written; a link target is a pointer, and a dead link is a navigation defect rather than a recorded fact | this record; the ADR entry |
| The moved provider docs' doc-wrap exemption ends with this move, so their paragraphs are reflowed and the three legacy entries leave the list | the exemption ends on the commit that next touches a file, and the move touches them; leaving the entries would keep a debt with no owner | this record; `.markdownlint-cli2.mjs` |

## Decisions pending

None.

## Findings

| Finding | Triaged to |
|---|---|
| The `.ts` extension tests under `tests/extensions/` import the moved path, but the shell suite does not run them; the sweep updates the imports and no gate here executes them | the open `The TypeScript and JavaScript sources have no linter` row, whose subject is the same missing gate over that tree |
| The move broke Markdown links in the `.agents` run briefs, three closed roadmap rows and the historical records; the link gate named them | fixed here: the link targets moved and the prose kept; the check is `bash scripts/check_markdown.sh` |
| The moved provider docs were in the doc-wrap legacy list, so the move ended their exemption and the gate demanded the reflow | fixed here: the three files are reflowed and the legacy entries removed from `.markdownlint-cli2.mjs` |
| The doc-wrap legacy list carried eleven stale entries: eight files already clean, two other live files, and one path that no longer exists | found by `bash scripts/check_doc_wrap_legacy.sh --stale`; dropped here with the three moved entries |

## Completed

| File | Change |
|---|---|
| `src/reasoning/agent-runtime/` | the moved provider tree |
| the live reference sweep | the paths under `src/`, `scripts/`, `tests/`, `.agents/`, `docs/reference/`, `docs/development/`, `AGENTS.md`, `.dockerignore` |
| the link-target sweep | 96 Markdown files: the historical prose keeps the old path, the link targets move |
| `src/reasoning/agent-runtime/{hermes,opencode}/quickstart.md`, `src/reasoning/agent-runtime/pi/onboard-readme.md` | the doc-wrap reflow; `.markdownlint-cli2.mjs` loses the three moved entries and eleven stale entries |
| `src/build/container-interface.json`, `src/build/container-interface.mjs` | the moved sources and the Dockerfile and compose paths |
| `tests/test_skill_map.sh` | the fixture link computed from the layer table |
| the docs code-snippet baseline | updated for the moved snippet sources |
| `docs/adr/reasoning_layer_tiers.md` | the 2026-11-07 entry |
| `devlog/roadmap.md` | the row's completed state and the open rows' paths |
