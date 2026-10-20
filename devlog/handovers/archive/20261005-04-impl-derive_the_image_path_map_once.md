---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - Derive the Repository-to-Image Path Map Once

## Objective

Give the repository-to-image path map one implementation that every consumer reads, so a check states its mapping instead of carrying its own copy of the resolution.

## Scope

One roadmap row: **Derive the repository-to-image path map once, for every gate that needs it**. The row records two consumers that each hold their own copy -- `scripts/check_instruction_context.sh`, which parses the provider dockerfiles, and `scripts/lint/record-links.mjs`, which hand-lists the pairs -- and that a third consumer would hand-code a third.

Measured at scope time: the pairs a consumer needs come from two mechanisms, not one.

- The provider dockerfiles' `COPY` lines, which send a repository directory to an image directory. Three files glob as `src/reasoning/providers/*/provider.dockerfile`.
- The provisioning chain, which no `COPY` line states: `src/reasoning/providers/pi/config/` lands at `/opt/workflow/agent/config/` by `COPY`, and `src/reasoning/entrypoint.sh` copies that template into `$AGENT_HOME/` at every start, so the same source also has the destination `/home/agentuser/.pi/`. The `AGENTS.md` link check depends on this second destination, so a map derived from `COPY` lines alone is incomplete.

Out of scope: the bind-mounted subdirectories (`$AGENT_HOME/agent/{prompts,sessions,skills}`), which come from the host rather than from the image, and which no current consumer maps.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One implementation produces the map, and both consumers read it | read the two consumers; neither holds a pair list, a `COPY` parser, or a manifest reader | Agent [x] -- `scripts/lint/image-map.mjs` is the only reader; both consumers call or import it |
| The manifest declares the `image`, `provision` and `env` layers, and a check holds it equal to the `COPY` and `ENV` lines in both directions | the check's fixtures: a manifest row no line carries, and a line no row carries | Agent [x] -- `scripts/check_image_map.sh`, 8 fixture cases |
| The check fails closed: no manifest, no dockerfile, or an unparseable file is a finding | a fixture case | Agent [x] -- each is a named finding, and the gate exits 1 |
| The map carries the provisioning destination as well as the `COPY` destinations, so the provider config root still resolves for the link check | the link-check fixtures that cover the provider config root pass | Agent [x] -- the pair resolves through the manifest's `provision` row and the provider's `AGENT_HOME` |
| A `COPY` line added to a provider dockerfile changes what both consumers see, with no edit to either | add a line to a fixture dockerfile; the check names it, and both consumers pick it up from the manifest | Agent [x] -- with the manifest row added; a `COPY` line alone now fails the gate instead of being silently unseen |
| The gate's fixture seam still points both consumers at a fixture root | the existing gate fixtures pass | Agent [x] -- the module resolves from the repository, the manifest from the fixture root |
| `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | both commands | Agent [x] -- 8 gates clean; 1088 tests, 0 failed |
| The mechanism is accepted | operator acceptance at the scope gate | Operator [x] -- released: a JSON manifest, `image` + `provision` + `env`, read only by one module, no hand-rolled parsing |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/lint/image-map.json` | the manifest: the `image`, `provision` and `env` layers, declared once |
| `scripts/lint/image-map.mjs` | the one reader and deriver: it parses the manifest, derives the Dockerfile truth, and serves both consumers |
| `scripts/check_image_map.sh` | the drift gate: the manifest against the `COPY` and `ENV` lines, both directions |
| [`scripts/lint/record-links.mjs`](../../../scripts/lint/record-links.mjs) | holds the hand-written pair list, and a comment naming this row as open |
| [`scripts/check_instruction_context.sh`](../../scripts/check_instruction_context.sh) | parses the `COPY` lines in three places, and owns the fixture seam |
| [`tests/`](../../../tests/) | the manifest and gate cases, and the existing gate and rule fixtures |
| [`src/reasoning/entrypoint.sh`](../../../src/reasoning/entrypoint.sh) | holds the provisioning template path, one half of the map |
| [`devlog/roadmap.md`](../../../devlog/roadmap.md) | the row, and the write-back |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The map is a JSON manifest declaring the `image`, `provision` and `env` layers, and the Dockerfiles stay hand-written | the manifest declares and a check holds it equal to the `COPY` and `ENV` lines, so nothing is generated and no substitution runs; this is the pattern the loop inventory and the `CONTEXT.md` identity fields already use. Operator ruling. | the manifest, and the check |
| One module is the manifest's only reader | two consumers reading the file would each carry reading logic, and TSV or a hand-rolled field split would have to agree on column meaning forever; the module parses once and serves a machine output, so neither consumer reads the manifest. Operator ruling. | `scripts/lint/image-map.mjs` |
| The `mount` layer is out of this unit | it is declared host-side in two compose files, which the reasoning container cannot see, so the manifest could only declare it and nothing here could check it | this handover, Scope |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gate's truth source moved from the dockerfiles to the manifest, so three of its tests changed meaning rather than text: the provisioned-path case now removes a manifest row, the two-destination case adds a row, and the fail-closed case lost its dockerfile and gained a manifest. Each fixture writes its own manifest, since the manifest is part of the subject. Operator-relevant because a future COPY-line change now needs a manifest row in the same change. | scope change | current iteration | Triaged to: `tests/test_instruction_context.sh`, and the `provider.dockerfile` contract stated in `docs/architecture/tool_interface.md` |
| Two `ENV` facts only surfaced here: pi sets `WORKSPACE_DIR` and the other two providers do not, and pi repeats `AGENT_HOME` and `PROVIDER_NAME` across its two build stages, so the equality check dedupes by value rather than by line. The manifest records both, per provider. | steering | current iteration | Triaged to: `scripts/lint/image-map.json` |
| The operator asked whether the dockerfiles could read the manifest at build time. Not in the form asked: no `ARG` or `ENV` can take a command's output, and a Dockerfile has no loop, so N pairs are N generated instructions. The realizable form is a builder stage that reads the manifest and moves the assembled tree with one `COPY --from`, which makes drift impossible at four measured costs. Filed as an evaluation rather than acted on. | scope change | roadmap | Triaged to: `devlog/roadmap.md` T7, `Evaluation of stage construction` |
| The repository has no `.dockerignore`, which the `COPY . /ctx` variant of that evaluation needs, or `.git/` and the record layer enter the build context. | obstacle | next iteration | Triaged to: the T7 row, which records it |

## Completed

| File | Change |
|---|---|
| `scripts/lint/image-map.json` | new: the container layout declared once, as `image` (26 rows), `provision` (1) and `env` (10) |
| `scripts/lint/image-map.mjs` | new: the manifest's only reader; derives the dockerfiles' `COPY` and `ENV` truth, serves `pairs` and `check`, and resolves the provisioning chain through `AGENT_HOME` |
| `scripts/check_image_map.sh` | new: the drift gate, registered in `scripts/lint.sh` |
| `tests/test_image_map.sh` | new: 8 cases, including a row with no line, a line with no row, the entrypoint-template mismatch, and the rendered `pairs` output |
| [`scripts/lint/record-links.mjs`](../../../scripts/lint/record-links.mjs) | the hand-written pair list and the shim comment are gone; the rule imports the module and fails loudly when the manifest declares nothing |
| [`scripts/check_instruction_context.sh`](../../scripts/check_instruction_context.sh) | parses the manifest through the module instead of the dockerfiles; fails closed on a missing module, manifest or pair; the runtime-path findings now name the manifest |
| `tests/test_instruction_context.sh` | each fixture writes a manifest; 3 cases rewritten for the new truth source, and 1 renamed |
| `scripts/lint.sh` | `check_image_map.sh` joins `GATES` |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | `## Provider Interface` states that a new `COPY` or `ENV` line needs a manifest row in the same change |
| [`docs/development/instruction-context-template.md`](../../docs/development/instruction-context-template.md) | the gate's description reads the manifest through the module |
| [`devlog/roadmap.md`](../../../devlog/roadmap.md) | the row resolved, and the stage-construction evaluation filed under T7 |
