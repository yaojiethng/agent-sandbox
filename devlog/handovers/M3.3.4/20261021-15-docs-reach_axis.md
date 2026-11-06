---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Documentation
status: Closed
---

# Handover - Reach is a root's property, and a citation must not outrun it

## Objective

Give the taxonomy a reach axis, and answer how a shipped skill cites a rule that lives in this repository, so a citation can be judged instead of styled.

## Scope

Two rows that are one decision. **The reach axis of the documentation taxonomy** states the axis. **Decide how a shipped skill cites a rule that lives in this repository** is what the axis answers, and it cannot land without the axis, because the legality test reads it.

The axis lands as two facts about a root rather than one fact about a document. Reach is who reads it, and delivery is how it arrives in front of that reader. The two do not move together, and separating them is what makes the axis true: an image-mounted root and a root the project's own setup fills reach the same reader by different routes, and every reading happens inside a provisioned project. A document inherits both from the root that carries it, so no document declares either.

Delivery has four routes: the image as a module payload, the image as a provider's config, `initialize` copying `assets/conventions/<name>/` into `.agents/skills/<name>/`, and nothing at all for the repository-only folders. Three consequences follow, and each one removes work the row expected.

The root list is not copied into the taxonomy. An `image` or `cells` row mounts a source at a runtime path, and a source no row mounts is project-scoped, so the manifest already holds the list and the taxonomy names the surface rather than restating it. That is also why the row's first option, a committed view rendered from the manifest, is filed as its own row instead of being built here: the axis needs the list, and the list already exists in a machine-readable place. What the rendered view adds is a `scope` value and a gate over the pair, which is a manifest key and a build change.

Enablement stays out of the axis. It is a property of a module, so a module is enabled by its own entry and `agent-sandbox` is enabled always.

The row's sequencing named M3.3.2's retirement as a prerequisite, on the grounds that the retirement decides whether `docs/policies/` survives. That premise belonged to the earlier design, where reach was a column over document kinds and folders. Under a root's reach, the retirement removes files inside a root and changes no root, so the dependency is gone.

`skill-scaffolder` is a carrier of the same fact. It offered a shipped skill and a global skill as the two targets, and one of them delivers nothing: the config home is seeded from the image at every start, so a file written there is lost on the next start and no gate reads it while it lives. Its three targets are now the three delivery routes that exist, and the warning is stated beside them.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The taxonomy separates reach from delivery, and states that a root carries both | `sed -n '/^## Reach/,/^## /p' docs/reference/documentation_taxonomy.md` states two reach values and four delivery routes, names the manifest as the surface holding the root list, and names `initialize`'s assets as the route that fills a project root | Agent [x] |
| No document restates the root list | `grep -rn "module-scoped" docs/ src/ workflow/` names no root-to-reach table outside `documentation_taxonomy.md` | Agent [x] |
| The citation rule covers a skill and states the legality test as a delivery match | `sed -n '/^## A reference resolves where the workflow document runs/,/^## /p' docs/development/prompt-authoring-conventions.md` opens on "A reference is legal when its target is delivered to the reader the citing document reaches", and names `$AGENT_HOME/agent/skills/<name>/` and `.agents/skills/<name>/` | Agent [x] |
| The two carriers cite the path their reader can open | `grep -rn "docs/reference/agent_workflow.md" src/reasoning/providers/pi/config/agent/skills/ .agents/skills/` returns nothing, and `grep -rc "/opt/sandbox/docs/reference/agent_workflow.md"` returns 1 for each of the two skills, in both copies | Agent [x] |
| The ledger classifies the two new lines | `bash scripts/check_norm_ownership.sh --check` prints `clean across 140 row(s), 23 gated, 14 reviewed, 62 judgement, 41 description, 20 sourced` | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints `1273 passed, 0 failed` | Agent [x] |

## Decisions

Reach and delivery are inherited from the root, and they are two facts. The one-axis version, where `module-scoped`, `provider-scoped` and `project-scoped` sat on a single wider-or-narrower scale, was wrong in the direction that matters: a provider-mounted skill and a project-seeded convention are read by the same agent in the same project, so neither is wider than the other, and a legality test reading width would have called a legal citation illegal.

The legality test is the citation rule, and it reads delivery. A reference is legal when its target is delivered to the reader the citing document reaches, and where nothing delivers the target the citing document states the rule. That single test replaces the three answers the row listed, because a restatement is what promotion looks like when the dependency is a rule.

The rendering is filed, not built. The row's own first option was a committed view held to the manifest by the gate, and building it needs a `scope` key on the manifest rows plus a renderer and a gate. The axis is now stated and readable without it, so the mechanism belongs in its own unit.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `documentation_taxonomy.md` still states the policy-set definition, "The policy set is every `docs/**/*_policy.md` file, in any folder", three lines above the reach axis | gap | it is the definition the milestone decided to drop, and it is the one sentence in the document that would survive the axis as a competing membership test | M3.3.2's policy-member row, which owns the definition and the test it removes |
| The linking gate enforces the legality test already, for the one case it can see: a shipped document may not link a repository path that no image row mounts | result | it caught this unit's own first draft, which linked `src/build/container-interface.json` from a shipping document. The rule is now stated in words where the gate was the only statement of it | recorded here; no row |

## Completed

| File | Change |
|---|---|
| [`documentation_taxonomy.md`](../docs/reference/documentation_taxonomy.md) | a `## Reach` section: three values, reach inherited from the root, the manifest named as the surface holding the root list, enablement excluded, and the two-value pointer rule |
| [`prompt-authoring-conventions.md`](../docs/development/prompt-authoring-conventions.md) | the section retitled to cover a workflow document, the legality test stated, and the root a skill runs from named beside the prompt's |
| [`principle-check-placement/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-check-placement/SKILL.md) | the norm-kinds citation names `/opt/sandbox/docs/reference/agent_workflow.md`, the path its mounted reader opens; both copies |
| [`principle-single-source-of-truth/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md) | the same citation, both copies |
| [`norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | regenerated, and the two new lines classified: the legality test as a rule with `lint:linking.mjs` as its observer, the run locations as a description |
| [`.agents/skills/skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | its three targets are the three delivery routes, and it states that writing in the config home loses the file |
| [`devlog/roadmap.md`](../roadmap.md) | both rows closed, and the rendered-view row filed with its end state |
