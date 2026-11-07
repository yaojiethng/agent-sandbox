---
date: 2026-10-17
milestone: M3.6.4 - The reasoning image refactor
type: Documentation
status: Closed
---

# Handover - The harness tier decision records

## Objective

Amend the tier ADR and the dispatch-backend ADR to the narrowed shape the run applies, so the decision records state the shared harness tier before the Dockerfiles do.

## Scope

The M3.6.4 row `The tier change lands`, its unit U4 of the run brief [`harness-tier-unification-run.md`](../../.agents/drafts/harness-tier-unification-run.md), which puts the decision record ahead of the implementation it describes. The run brief's other three units, and the rows `Pin every build input`, `The build-skip mechanism is removed` and `The host build probe is re-run against the new shape`, are out of scope for this unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The tier ADR's live entry names the shared `agent-harnesses` tier, the hermes exception and the install-mechanism rule that separates them | read `docs/adr/reasoning_layer_tiers.md`, the entry under `**Current:** 2026-10-17` | Agent [x] |
| The five-tier rows are superseded in the file's own form and not deleted | the `Reason superseded by 2026-10-17` line under the 2026-10-16 entry | Agent [x] |
| The dispatch CLI's home moves to the shared tier in the backend ADR | read `docs/adr/opencode_dispatch_backend.md`, the entry under `**Current:** 2026-10-17` | Agent [x] |
| No payload image is claimed, and the manifest with its layout gate is the declaration | both entries, and no `src/reasoning/payload.dockerfile` in the tree | Agent [x] |
| The lint umbrella passes over the tree | `bash scripts/lint.sh`, exit 0, 8 gates clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The tier list is four tiers: `agent-base`, `agent-harnesses`, `hermes-base` and `<provider>-agent-<project>` | the pi and opencode bases carried nothing but their harness install, so a shared tier holding both loses nothing and removes the `opencode-ai` double home | tier ADR, entry 2026-10-17 |
| The install's mechanism decides a harness's tier | a registry package is a tier-2 install; a source build with a compiler and its own language environment keeps a provider base | tier ADR, entry 2026-10-17 |
| No `agent-payload` image exists | the manifest declares every COPY pair and the layout gate holds the Dockerfiles equal to it, so an image would be a second carrier rather than a declaration | tier ADR, entry 2026-10-17 |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Should the COPY layout be derived at build time from `src/build/container-interface.json`, or stay declared in the Dockerfiles and held by `scripts/check_container_layout.sh`? | the M3.6.4 design step; it would replace the provider COPY lines this run writes | keep the declaration and the gate; a builder stage derives the tree from the manifest; defer to a later milestone |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The five-tier shape gave `opencode-ai` two homes, the shared dispatch row and the opencode provider base | design | one install declared twice, so a version bump was two edits that no gate compared | closed here, by the shared harness tier |
| The prior `agent-tools` name described a kind that does not exist: it installed harnesses, not tools | defect | a reader modelling the tiers from the name would place a provider's agent install in the shared tier | closed here, named `agent-harnesses` |
| The OpenCode dispatch route is unusable in this container: both free models hang with no output, `cat-jam-free` returns an upstream server error, and the paid models answer `Insufficient account funds` or `Model access is disabled` | environment | the free-tier dispatch the milestone is built around cannot run a worker here at all | `devlog/AGENT_FEEDBACK.md` candidate, not yet filed |

## Completed

| File | Change |
|---|---|
| `docs/adr/reasoning_layer_tiers.md` | added the 2026-10-17 entry for the four-tier shape, promoted R1, R2, R3, R5 and R6, and marked the 2026-10-16 five-tier entry superseded |
| `docs/adr/opencode_dispatch_backend.md` | added the 2026-10-17 entry moving the dispatch CLI to the shared harness tier and marked the 2026-10-15 entry superseded on that point |
