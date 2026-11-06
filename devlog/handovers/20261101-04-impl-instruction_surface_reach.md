---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the instruction surface declares its reach once

## Objective

Make the interface manifest the one place a delivery destination, a reach grant and a bind mount are declared, and give the tree one command that prints the resulting surface.

## Scope

**Position:** E1 of three, all five steps. Steps: the criteria, the two cells that declare no reach, the four mount rows, the report command, one mutation row.

Continues the roadmap row **The instruction surface declares its reach once** under M3.3.3, from design record [`20261101-design-active-instruction_surface_reach.md`](../discussions/20261101-design-active-instruction_surface_reach.md). The row's own end sentence spans two rows and is amended here: this iteration delivers the declaration and the report, and the count of files that may state a destination is the next row's end.

The closure half is smaller than the design record says. [`scripts/lint/linking.mjs`](../../scripts/lint/linking.mjs) already refuses a link whose target lands outside the reach its cell declares, and `tests/test_linking.sh` pins it, so the check exists for Markdown links and this iteration extends rather than builds it. What is missing is narrower: two cells declare no reach at all, four bind mounts are declared in no machine-readable place, and no command prints what the manifest means.

This iteration is **E1, the declaration**. E2, the closure check, follows because it needs one shared reference scanner; E3, the kind consolidation, is the gate-upkeep handoff. The executable map is in the design record.

Ruled out of scope: counting how many files reference a declared reach row. It needs one shared link scanner that both the Markdown rule and this check consume, and the closure rule already reports the undeclared direction.

## Acceptance criteria

The four the design record states, with this iteration's half marked.

| # | Criterion | This iteration |
|---|---|---|
| A1 | Every recorded failure is a fixture the checker rejects, or a case it names as outside its reach | deferred to the fixtures row, which needs E2's checker to reject anything |
| A2 | Every constraint kind has a mutation row that returns `PROVEN` | E1's two kinds, partition and resolution, get a row; closure and non-vacuity wait on E2 |
| A3 | The model finds no counterexample at its declared bound, and the bound is small enough to enumerate | the bound is declared here; enumeration waits on E2 |
| A4 | A later session on this subject finds no new expresser | checked at close |

**Narrowing, recorded against A2.** Non-vacuity here is presence plus resolution, and resolution is decided per class rather than by one rule: a row conditioned on the repository tree must name a repository path that exists, a row naming an `/opt/` path must name one an `image` row populates, and a row naming the installed runtime is left to its condition, because the repository does not build that tree and no check here can decide it. The use-count, which is what makes a vacuous zone a finding, needs the shared reference scanner that E2 owns, so it is deferred rather than redefined.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The manifest gains a `mounts` section that agrees with the provider overlay, rather than generating it | docker compose merges the overlay itself; generating the block would change the build path, and this iteration adds a declaration and a check | here |
| A cell must declare `reachable`, and an empty list means it grants nothing | presence makes silence a finding; an empty list is a decision the operator can read, and `undefined` currently passes every check | here |
| Non-vacuity in this iteration is presence plus resolution: every declared row names a path that exists | the use-count needs the shared scanner ruled out above, and a row naming a moved tree is a finding on its own | here |
| The report is a `report` command on `container-interface.mjs`, not a new script | it is already the manifest's only deriver, and the tree is one script away from the regrowth this row exists to stop | here |
| The mutation tier's syntax gate follows the subject's language | it ran `bash -n` on every mutant, so a module subject could only ever be a no-op and the tier could not witness a module's lines at all | here, Findings |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A sidequest opens on the row-writing procedure (`20261101-05-design-task_row_mechanism.md`), because this work's rows cannot be re-cut under the current entry rule | scope | the rows stay as they are until the sidequest closes; this iteration keeps E1 step 2 | this handover, Findings |
| The sidequest `20261101-05` closed: the convention names the mechanism class and its evidence, the handover gate refuses completed work with no criterion, and this work's rows carry one class and one end each | scope | the rows are re-cut as the sidequest delivered them; the closure check is now its own roadmap row | this handover, Scope |
| The two cells that declared no `reachable` were not skipping the reach check: it ran on them, and what their silence hid was whether the cell grants nothing or nobody decided | defect | corrected in the roadmap row; the manifest now requires the key, so a third cell cannot read the same way | this handover, Decisions |
| The mutation tier rejected every module subject: its syntax gate ran `bash -n` on the mutant, so a `.mjs` mutation was recorded as a no-op rather than a survivor | defect | the gate now picks `node --check` by extension; two module rows in the fixture pin both the proven and the unparseable verdicts | this handover, Decisions |
| Three handovers carry `status: Active` from 2026-10-29 and 2026-10-31 alongside this one | defect | the interrupted iteration was identified by recency and content; the stale three are their own iterations' closes | operator, raised in chat |

## Completed

| File | One-line change |
|---|---|
| `devlog/roadmap.md` | amended the two rows' end sentences so each names what it delivers |
| `devlog/discussions/20261101-design-active-instruction_surface_reach.md` | the count corrected to eighteen, the probe command made reproducible, and the executable map added |
| `src/build/container-interface.json` | the two cells that declared no reach now declare an empty list, and the note states what an empty list means |
| `src/build/container-interface.mjs` | `check_reachable` reports an absent key instead of returning, so silence is a finding |
| `tests/test_container_layout.sh` | the fixture cells declare their reach, and a case pins the absent-key finding |
| `devlog/roadmap.md` | the closure row corrected: the check ran on those cells, and the silence was about a decision, not about coverage |
| `src/build/container-interface.mjs` | `report` prints the declared surface, one line per fact, and `check_reachable` resolves each row by class |
| `tests/test_container_layout.sh` | four cases: a missing repository path, an absent image path, the installed-runtime boundary, and the report printing twice identically |
| `scripts/mutations_run.sh` | the syntax gate follows the subject's language, so a module can be a mutation subject |
| `tests/test_mutations_runner.sh` | the fixture gains a module subject, a module mutation that bites, and one that does not parse |
| `tests/mutations/catalog.jsonl` | two rows: the required `reachable` key and the resolving reachable row, both `PROVEN` |
| `devlog/discussions/20261101-design-active-instruction_surface_reach.md` | E1's state records what landed |
| `src/build/container-interface.json` | the four bind mounts the pi overlay declares are rows, with the tree each one puts behind the surface |
| `src/build/container-interface.mjs` | `parse_mounts` reads the overlay and `check` holds the rows equal to it, both directions |
| `scripts/check_container_layout.sh` | the gate names the overlays among the artefacts it holds the manifest to |
| `docs/adr/instruction_surface_declaration.md` | a new entry declares the mount layer, with the earlier exclusion retired |
