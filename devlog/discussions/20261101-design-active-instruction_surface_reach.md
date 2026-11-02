# The instruction surface declares its reach once

**Status:** active

## Context

The trigger was a review that could not end on a fact. A collision report was built, rewritten twice and deleted; a roadmap row asserted that a shipped payload is loaded twice and that turned out false; and every question about who owns which instruction had an answer that could be assembled by hand and no answer the system itself gave. The cost is not the defects. It is that each session re-derives the model, and two sessions disagree: one question in this line of enquiry produced forty-six rows, then thirty, then zero on the same tree.

The concept is small and already written down. `docs/reference/documentation_taxonomy.md` `## Reach` states it: reach is who reads a document, it belongs to the root that carries the document, and no document declares its own. Substitute a skill for a document and the same sentence is the payload rule. **Reach is one predicate with two carriers** - the context layer decides which reader a sentence reaches, the payload scope decides which sessions a skill is visible to - and a third carrier, the gate, decides what a file may reference.

What makes it expensive is not the concept but the number of places that re-express it. Eighteen files state it, depend on it or gate it - thirteen that state or depend on it and five that gate or scan it - and this survey found all eighteen only by reading the tree and the running container.

| Relation to the decision | Files |
|---|---|
| States it | [`container-interface.json`](../../src/build/container-interface.json) (its `image`, `provision`, `session` and `cells` sections), [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md) `## Reach`, [`agent_workflow.md`](../reference/agent_workflow.md), [`instruction-surface-conventions.md`](../development/instruction-surface-conventions.md), `provider.dockerfile`, `docker-compose.pi.yml`, `settings.json`, `preflight.sh`, `onboard.sh`, [`skill_layers.mjs`](../../scripts/skill_layers.mjs) `LAYERS`, [`.agents/registry/packages.json`](../../.agents/registry/packages.json) |
| Depends on it | [`container-interface.mjs`](../../src/build/container-interface.mjs), [`skill_graph.mjs`](../../scripts/skill_graph.mjs) |
| Gates it | [`check_container_layout.sh`](../../scripts/check_container_layout.sh), [`check_reach.sh`](../../scripts/check_reach.sh) with [`lint/reach.mjs`](../../scripts/lint/reach.mjs), [`check_instruction_surfaces.sh`](../../scripts/check_instruction_surfaces.sh), and [`lint/linking.mjs`](../../scripts/lint/linking.mjs), which already refuses a link landing outside the reach its cell declares |

Two multipliers make an edit expensive, and they compound. Vertically, each delivery mechanism speaks its own language - `COPY`, rsync, a mounts list, a settings package list, a JSON cell, a taxonomy route - so one decision has six dialects. Horizontally, each authority level restates it - ADR, reference document, development convention, code comment, roadmap row, handover - so one claim has six elevations. An edit costs the product, which is why "add one skill" feels heavy and why prose drifts: the prose is a cache of a lookup nobody runs.

The prose has already drifted, measurably. Forty-two non-devlog files name the layer-to-destination mapping and twenty-three state the seed lifecycle, and one of those statements is simply wrong: `agent_workflow.md` places the provider `AGENTS.md` at `src/reasoning/providers/<n>/config/AGENTS.md`, while the file is `config/agent/AGENTS.md`.

### Observations, each with the command that shows it

Measured 2026-11-01 in a running session. Three of these will be false after the next image build or the next seed, which is why the command travels with the number.

| Observation | Command |
|---|---|
| The home holds 81 skills, 30 of them byte-identical to the image's provider payload; the image copy is stamped at build time and the home copy at container start, so the entrypoint writes through the bind mount on every start | `node --input-type=module -e` against the installed loader: `SettingsManager.create(cwd, "<agent home>/agent")`, `new DefaultResourceLoader({cwd, agentDir, settingsManager})`, `.reload()`, then print `getSkills()`. Prints `110 diagnostics 0 roots 4` today; `stat -c '%y %n'` on a skill in each tree dates the copy |
| The loader reports 110 skills from four roots with zero collision diagnostics, so the payload is loaded once | `SettingsManager.create(cwd, "/home/agentuser/.pi/agent")` then `DefaultResourceLoader.reload()`, printing `getSkills()` |
| `agent/{skills,prompts,sessions}` are host-backed (device 2096) while `agent/{settings,AGENTS,models,auth}.json` and `agent/extensions/` are container-local (device 87) | `/proc/mounts`; `stat -c '%d'` |
| The image is behind the tree: `domain-model` against `domain-modeling`, three skills absent from the image, `principle-delegation-over-machinery` not shipped, and an orphaned `prose-review/runbooks/document-truth` still in the image | `diff -rq src/reasoning/agent/skills /opt/workflow/agent/skills` and the same for the provider and module trees |
| The default start does not rebuild, so `/opt` is fresh only as of the last build | `scripts/start_agent.sh:161` |

### Refutations

- **The payload is loaded once.** The earlier claim that it is loaded twice came from comparing a committed path with its image copy, which is a build input against a build output, and that pairing cannot race.
- **The home is not seeded once.** The onboard seed runs once; the entrypoint seed runs at every start. Three lifecycles exist, not two, and they are out of sync by construction.
- **`make refresh` does not re-seed the provider home.** It writes `Makefile` and `.env`; `start_agent.sh --refresh` rebuilds images instead. Two different commands share the name.
- **`/opt` files are fresh only relative to the image.** They are self-consistent and stale against the tree.
- **The stale `AGENTS.md` has a mechanism, not a habit.** The operator's editable copy sits at `$SANDBOX_DIR/.pi/agent/AGENTS.md` and is read by nothing; the live one is the image's, copied into the container each start.
- **Two of the sixteen are ours from this week.** `.agents/registry/packages.json` restates the package entries, and `preflight.sh` restates them again.

## Options Considered

**Documentation first.** Rewrite the layer and lifecycle tables so they are current, and keep prose as the carrier. Rejected on measurement: the tables were written twice already, the drift is 42 files deep, and the reader arrives rarely enough that a stale copy is indistinguishable from a current one.

**A gate per seam, as today.** Keep adding a check wherever two statements disagreed. Rejected: eighteen gates already exist, each written at the injury, and three of them now overlap. The gate list is a record of past failures, not a design.

**One declared object, one checker, generated documentation.** The manifest becomes the single declaration of scopes, sources, destinations, reach values and reference edges. The checker asserts partition, closure, resolution, agreement and non-vacuity over it. Every consumer either reads it or is gated against it, and documents cite the report rather than restating it. **Chosen.**

**A state machine as the placement model.** Encode placement as states and transitions, then verify that the rules always place an item correctly. Rejected in part. Placement is static: it has no events, and a transition system returns counterexample paths where a relational model returns the minimal violation - this file, this reference, this zone. **The temporal half is accepted**: a file's lifecycle, and the operations that move it between scopes, are a genuine state machine and get their own chart.

**One model over reach, lifecycle and provenance.** Rejected. It produces a richer object, and a richer object needs an engine to interpret it. This repository already paid for that: the skill graph carried a schema and a runtime validator, and the review that cut them ruled the graph a diagnostic whose shape is held by construction. Unification is a smaller object with more derivation, never a bigger object with more validation.

## Decision

**Reach is declared once, in the manifest, and everything else derives from it or is checked against it.** A cell declares its sources, its runtime path and its loader. What a file may reference is declared per root rather than per surface, because a reference resolves in the path space its reader holds: the image for a file that ships, the repository for one read in the working tree. The one command prints the surface: scopes, the loaded set with its roots, tree-versus-image drift, promotion candidates and unresolved references. This is the report a session reads instead of a document, and it is also what lets an agent see what it ships with.

**The concepts stay separate**, because they are orthogonal and merging them forces an engine: reach (who may see what), lifecycle (what survives what), provenance (where something came from). Each gets one object and one gate.

**The work runs in the order below**, because each stage makes the next cheap and because prose first is what has been tried for milestones.

| Stage | Move |
|---|---|
| 0 | State the stopping rule, so the work has a bound |
| 1 | One object: the manifest declares each root and its destination, and no other file states one |
| 2 | One checker: every reference resolves in the path space its reader holds, so a link from a shipped file to a repository-only target, a skill invocation naming a skill the tree lacks, and a path mention naming an undeclared root each fail |
| 3 | One statement: the taxonomy owns reach in prose, every other document cites it, and a lint rule refuses a destination outside a generated block |
| 4 | Stop the regrowth: a new consumer reads the object or arrives with its gate |

## The executables

Each check carries a stable name, so a row can name the one it advances. The ids are local to this table: a row in another document cites a check by its name and links this record, because an id assigned by position goes stale the moment a row is added, and nothing would report it.

| Id | Executable | Constraint kinds | Where it lands | State |
|---|---|---|---|---|
| **E1** | the declaration | partition, resolution | row one | landed in `20261101-04`. The manifest carries `image`, `provision`, `mounts`, `session` and `cells`; the gate holds the mount rows equal to the compose overlay in both directions; `report` prints the surface and two runs are byte-identical. The per-cell reach rows were retired in `20261101-06`: measured against their own cells, six of ten restated a declared root and no cell names a repository folder exclusively |
| **E2** | the closure check | closure | row one, then a row of its own | links carry the rule: `lint/linking.mjs` resolves a link in the path space its reader holds. A skill invocation naming a skill the tree lacks, and an absolute path mention naming an undeclared root, are unchecked, and the use-count needs one shared reference scanner |
| **E3** | the kind consolidation | agreement, liveness | the gate-upkeep handoff | one agreement instance (`check_container_layout.sh`) and the mutation tier, which already returns `PROVEN`, `SURVIVED` or `NO-OP` |
| - | the conformance checker | conformance | out of scope | six scripts, cheap and close to their subjects, recorded in the handoff with its reason |

**The gate properties are proposed separately.** The seven constraint kinds the eighteen gates express, their mapping and their consolidation are in [`gate-constraints-handoff.md`](../../.agents/drafts/gate-constraints-handoff.md), linked from the gate-upkeep procedure row, because retiring or replacing a gate is that milestone's act. The consolidation of the conformance gates is out of scope here.

**The stopping rule:** the work ends when a new delivery mechanism can be added without a new check, and when a maintainer can answer "who sees this, and what may it see" with one command.

**Acceptance criteria**, each decided by something other than the author's word:

- Every recorded failure is a fixture the checker rejects, or a case it names as outside its reach.
- Every constraint kind has a mutation row that returns `PROVEN`.
- The model finds no counterexample at its declared bound, and the bound is small enough to enumerate.
- A later session on this subject finds **no new expresser**. If it does, the object is incomplete and that is a precise bug.

## Consequences

**Enables.** One edit per fact instead of six; a session that can see its own composition; documentation that is either derived or a decision record, never a cache; and a gate set whose growth is bounded by kinds rather than by injuries.

**Forecloses.** A richer model with a runtime interpreter; any consolidation of the conformance gates; and any attempt to check placement judgement with a machine. Placement is decided by a person, bounded by the references: if a file's own references escape its zone, its placement is proven wrong, and if they do not, the judgement stands unsupported by any check.

**Corrects the record.** The roadmap row "A shipped payload is loaded twice" is removed, and this section is its replacement: the observation, the refutation and the command that shows both. It joins the earlier correction at commit `fe570686`, where a claim carried forward from a summary cost two rounds to unwind.

**Risks.** The model growing into an engine; a statechart used for a static property; a declaration asserted in JSON but exercised by nothing, which is why non-vacuity is a property rather than a nicety; and the recurring one, a fact recorded without its command, which is how the record acquired claims that were not true.
