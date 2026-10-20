---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Plan
status: Closed
---

# Handover - The layer install design

## Objective

Decide where the shared dispatch CLIs and each agent's extension payload install, express the cache model as data, and state the pin policy for every build input, so the `Pin every build input` row can apply the policy and the tier placement stops being ambiguous.

## Scope

The M3.6.1 row `The layer install design`. Its three inputs have landed: the install-step census (41 rows), the invalidation history (trigger counts 1, 22 and 448 per tier), and the host build probe's measured cost (1 second for a tier-3-only rebuild, 2 to 3 seconds for a base change, 77 seconds cold).

Out of scope: the rows `Pin every build input`, which applies the policy this session writes rather than writes one, and `A correction pass through the dispatch script needs its own commit`, which is unrelated to the build layer. No Dockerfile, build-script or compose change is made by this session unless the scope gate adds it; a design handover does not cover implementation.

Obstacle resolved this session: the row's phrase `both agents' extensions` presumed an OpenCode extension payload the tree does not carry. The operator ruled that pi's extensions are not ported, because they change pi's behaviour and OpenCode has its own. OpenCode reaches the common instruction base instead, through the generated config. The implementation the design names is not landed here, because a design handover does not cover implementation; it is filed as roadmap rows under M3.6.1 and in the new sub-milestone M3.6.5.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The design states the tier shape, the payload home, the cache model and the pin policy | [`20261016-design-settled-reasoning_layer_install.md`](../../discussions/20261016-design-settled-reasoning_layer_install.md) | Agent [x] |
| The durable decisions are ADRs | [`reasoning_layer_tiers.md`](../../../docs/adr/reasoning_layer_tiers.md) and [`build_input_pinning.md`](../../../docs/adr/build_input_pinning.md), plus a new section in [`instruction_surface_declaration.md`](../../../docs/adr/instruction_surface_declaration.md) | Agent [x] |
| The pin policy is specific enough to apply | one form per input class, every pin paired with a bump path, and the working-tree class excluded by name | Agent [x] |
| The OpenCode side is decided | the generator keeps its role, the provider filter and the prompt surface are settled, and the argument placeholder is unified | Agent [x] |
| The roadmap write-back lands | M3.6.1's design row closes, M3.6.5 is filed with its rows, and the hermes unification is deferred | Agent [x] |
| The evidence closes with the decision | both studies settle, carry a resolution, and are renamed to their settled names | Agent [x] |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| pi's extensions are not ported to OpenCode | the extensions change pi's behaviour, and OpenCode has its own behaviours, so a port serves nothing | operator ruling, this session |
| `.agents/prompts/` becomes a fourth instruction surface, and the row belongs to M3.6.5 | the onboarding guide is a prompt, and a prompt needs a prompt root | operator ruling, this session |
| OpenCode as a first-class provider is a new sub-milestone, M3.6.5, filed by this session's close | its outcome differs from M3.6.1's, and it carries its own work | operator ruling, this session |
| The tier shape is five images: the runtime, a shared tools tier, the provider base, a shared payload image and the provider agent | the duplicate dispatch-CLI install and the per-provider payload declaration both go, and docker's layer cache is the only reuse rule | [`reasoning_layer_tiers.md`](../../../docs/adr/reasoning_layer_tiers.md) |
| The shared payload ships once into `/opt/` and every provider pulls it with one `COPY --from` | the operator's ruling, and it settles the census's open question about the pi payload's tier | [`reasoning_layer_tiers.md`](../../../docs/adr/reasoning_layer_tiers.md) |
| `build_if_missing`, `_build_key` and the build-key label are removed | the skip saved about one second and its failure mode was a silently stale image | [`reasoning_layer_tiers.md`](../../../docs/adr/reasoning_layer_tiers.md) |
| A pin fixes the resolved artifact, one form per input class, and every pin gets a bump path | an exact version alone blocks the patch and lets a registry serve different bytes | [`build_input_pinning.md`](../../../docs/adr/build_input_pinning.md) |
| The OpenCode config stays generated | a hand-authored file restates the declaration with no gate between the two | [`instruction_surface_declaration.md`](../../../docs/adr/instruction_surface_declaration.md) |
| Prompt files are emitted as commands, and `references` carries the ambient directories | commands give invocability and references give discovery; `references` is the `@` alias, not the prompts' home | [`instruction_surface_declaration.md`](../../../docs/adr/instruction_surface_declaration.md) |
| The argument placeholder unifies on `$ARGUMENTS` | it is the only all-arguments form both runtimes accept | [`instruction_surface_declaration.md`](../../../docs/adr/instruction_surface_declaration.md) |
| `src/reasoning/agent/prompt-templates.md` is deleted | it restates pi's documentation and would have had to become the intersection of two formats | the design record |
| Hermes does not consolidate into the shared tiers | it would put the tree's only unpinned build on every provider's path | `Not in scope: M3.6` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The instruction transport has no caller. `OPENCODE_CONFIG` is set nowhere in the tree, and [`opencode-config.mjs`](../../../src/build/opencode-config.mjs) is invoked only by [`tests/test_opencode_config.sh`](../../../tests/test_opencode_config.sh). The W0 proof set the variable by hand. So the dispatch-invoked OpenCode worker does not receive the declared surfaces today, and `M3.6.5`'s first unit is wiring the generator rather than extending it. | defect | the transport row is a wiring defect, and the prompt extension rides on its fix | M3.6.5, the first row |
| The OpenCode skills transport is already live. [`src/build/opencode-config.mjs`](../../../src/build/opencode-config.mjs) puts every manifest cell whose `sources` end in `skills/` into the emitted config, plus `.agents/skills/`, which resolves to three skill roots. The **prompts** do not travel: the `instructions` array names two `AGENTS.md` files and no prompt root. | fact | the instruction-base work is a prompt-transport gap, not a whole-surface gap | M3.6.5, the prompt-surfaces row |
| The opencode provider image copies four paths only: `src/libs/`, the entrypoint, `docs/reference/` and `docs/policies/`. It carries no skill, prompt or config payload. | fact | the dispatch-invoked worker and the opencode session have different instruction reach, and both need stating | M3.6.5, the provider-image row |
| `.agents/` holds `audits/`, `drafts/` and `skills/`. There is no `prompts/` directory, and [`instruction-surface-conventions.md`](../../../docs/development/instruction-surface-conventions.md) describes `.agents/` as run briefs and audits. | constraint | a fourth surface is an instruction-surface decision that the M3.3.1 contract governs | M3.6.5, the fourth-surface row |
| There is no build context folder and no `.dockerignore`. [`scripts/build.sh`](../../../scripts/build.sh) passes the repository root as the context, so the whole tree including `.git/` and `devlog/` goes to the daemon on every call. The archived 2026-05-01 design's `build_context_agent` functions are gone. | fact | a curated context or a `.dockerignore` is available and unused | M3.6.1, the tier-change row |
| `_build_key` guards only the decision to invoke the daemon. Docker's own cache already invalidates a `COPY` layer on changed content, and a `RUN` layer on its command. The measured saving is about one second, and the failure mode is a silently stale image, which is the defect the build-skip fix closed. | fact | the cache model must state which of the three rules each tier uses, and whether the skip earns its risk | M3.6.1, the skip-removal row; decided in [`reasoning_layer_tiers.md`](../../../docs/adr/reasoning_layer_tiers.md) |
| Tier 3's 448-commit trigger count is not a cost. The measured tier-3 rebuild is 1 second wall and 0.1 second of steps, because an unchanged `COPY` is a layer-cache hit. | correction | the churn needs a transfer and layer-count fix, not a rebuild-suppression fix | the design record and the settled invalidation study |
| [`provider_onboarding_guide.md`](../../../docs/development/provider_onboarding_guide.md) states the three-tier build in two places, including its reference table. A fourth tier makes those sentences wrong. | propagation | the guide is the first document the design updates | M3.6.5, the guide-correction row |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/discussions/20261016-design-settled-reasoning_layer_install.md`](../../discussions/20261016-design-settled-reasoning_layer_install.md) | the design record: the tier shape, the payload home, the cache model, the pin policy and the OpenCode surface |
| [`docs/adr/reasoning_layer_tiers.md`](../../../docs/adr/reasoning_layer_tiers.md) | the five tiers, the shared payload declaration, and the removal of the skip mechanism |
| [`docs/adr/build_input_pinning.md`](../../../docs/adr/build_input_pinning.md) | the pin policy: one form per input class, a bump path for each, and the working-tree exclusion |
| [`docs/adr/instruction_surface_declaration.md`](../../../docs/adr/instruction_surface_declaration.md) | a new dated section: a runtime's surface is generated from the declaration, never restated by hand |
| [`devlog/roadmap.md`](../../roadmap.md) | the design row closes, two implementation rows and the sub-milestone M3.6.5 are filed, and the hermes unification is deferred |
| [`devlog/discussions/20261016-study-settled-install_step_census.md`](../../discussions/20261016-study-settled-install_step_census.md) | renamed on settle, its status set, and a resolution written |
| [`devlog/discussions/20261016-study-settled-invalidation_history.md`](../../discussions/20261016-study-settled-invalidation_history.md) | renamed on settle, its status set, and a resolution written |
| handovers [`20261016-10`](20261016-10-impl-the_install_step_census.md), [`20261016-11`](20261016-11-impl-the_invalidation_history.md) and [`20261016-13`](20261016-13-impl-the_host_build_probe.md) | their inbound links to the two studies updated for the settled names |
