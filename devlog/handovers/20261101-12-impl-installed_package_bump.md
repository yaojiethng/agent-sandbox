---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
status: Closed
type: Implementation
---

# Handover - the installed package is the second carrier

## Objective

Give upstream text two named carriers, a procedure for each, and the pstack install moved onto the new one, so a bump is a directed act on a declared package rather than a folder diffed by hand.

## Scope

The terminology, the pattern pair and the install, in one slice, because each depends on the others: the vocabulary names the two carriers, the patterns are one each, and the install is what proves the second one works.

**Two carriers, one rule.** `vendored` is an in-tree artifact whose text came from an upstream, held by a store edge; `installed` is text a package brings, which the sandbox loads and the repository never carries. `in-tree` is the container both words sit under, so a home-grown skill is in-tree and not vendored. The rule that joins them: **one name, one route** - a name an installed package provides cannot also be vendored unless the package declares it excluded and the store holds its edge.

**The package bump is its own pattern, not a branch.** A vendored bump merges three inputs against a copy that exists; a package bump has no local copy and moves a checkout. One document, one act, so `patterns/vendor-bump.md` (renamed from `upstream-bump.md`) points at `patterns/package-bump.md` for the other carrier.

**The delegation, measured before the scope gate.** pi accepts a bare local directory as a package and discovers skills from its `skills/` folder; a package entry's filter disables one skill; and the filter path is relative to the package root. The three behaviours:

| Settings entry | skills found | enabled | the excluded name |
|---|---|---|---|
| no filter | 58 | 58 | enabled |
| `"skills": ["-skills/principle-guard-the-context-window"]` | 58 | 57 | disabled |
| `"skills": ["!principle-guard-the-context-window/*"]` | 58 | 58 | enabled, silently: the pattern is relative to the package root |
| `"skills": ["!skills/principle-guard-the-context-window/*"]` | 58 | 57 | disabled |

A bare-name filter is the trap: it looks right, matches nothing, and reports nothing. The pattern states it.

**A missing clone loads nothing, silently.** Measured: a settings entry pointing at an absent path resolves zero skills, and `skill_packages.mjs` compares source strings rather than resolved paths, so nothing reported it. This iteration adds the presence check, which is also the guard a fresh sandbox needs, because the clone is derivable but its absence is not visible.

**Persistence costs four declarations**, because only `agent/{prompts,sessions,skills}` and `model-recommendations.md` are mounted today: the manifest `mounts` row, the compose bind row, `onboard.sh`'s `mkdir`, and the layout table in `execution_model.md`. The clone lives at `$AGENT_HOME/agent/packages/pstack` and is the pin: git holds the revision, and nothing in the repository records it, because a machine path is not project intent.

**The install.** `cursor/plugins` checked out at `ae5650fe` (2026-10-31, pstack `0.15.36`), declared with one exclusion, which brings eleven skills the home does not have: `benchmark-checklist`, `correct`, `create-formal-verification-skill`, `in-your-own-words`, `ketchup`, `ketchup-video`, `maintain-formal-verification-skill`, `poteto-help`, `principle-explain-the-number`, `sharpen`, `statechart`.

The exclusion is load-bearing, not cosmetic. The vendored `principle-guard-the-context-window` is not a light adaptation of upstream's: it runs `context.sh`, quotes the provider's own reading, and requires the unit and count of a pass, where upstream's version is generic advice. Without the filter, upstream's copy would arrive beside the seeded one and pi's first-wins would decide which a session reads.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The two carriers are named once, where a reader first meets them, with the rule that joins them | read `.agents/skills/skill-fork/SKILL.md`; it states vendored, installed and the one-name-one-route rule | accepted: the carrier table, the `in-tree` note, and the routing table's four rows |
| The pattern pair is one act each, and each names the other | `ls .agents/skills/skill-fork/patterns`; `grep -l 'package-bump' .agents/skills/skill-fork/patterns/*.md` names the vendored pattern and the reverse | accepted: four patterns, and each bump names the other in its boundary |
| `drop-in` is retired from the live tree | `grep -rn 'drop-in' .agents docs devlog/roadmap.md` = `0` | accepted: `0`; the word never reached the live tree |
| The installed package persists across a sandbox start, with the manifest and the overlay agreeing | `node src/build/container-interface.mjs report` shows the packages root; `bash scripts/check_container_layout.sh` clean | accepted: the mount row, the compose bind and `onboard.sh`'s `mkdir` agree with the manifest |
| The package bump reads the revision it replaces and reports what it adds | `patterns/package-bump.md` carries the checkout, the filter trap and the report step | accepted: eight steps, and the filter table names the no-op form |
| An absent package is reported rather than silently loading nothing | `node scripts/skill_packages.mjs` names a configured package whose path does not exist; a test holds it | accepted: `test_a_configured_package_whose_path_is_absent_is_reported`, and the live report is clean |
| The filter behaviours are pinned by an offline test | `bash tests/test_installed_package.sh` - a bare directory is a package, an exact filter disables one skill, a bare-name filter no-ops, an absent path loads nothing | accepted: 5 pass, each pinning one behaviour against pi's own resolver |
| pstack is installed at the current revision and the eleven skills load | `node scripts/skill_packages.mjs` clean; the probe reports the enabled count; `pi list` shows the entry as filtered | accepted: 168 skills resolve, 167 enabled, 57 from the package, and all eleven new names are enabled |
| The vendored edge is not shadowed | the probe reports the excluded name as disabled, and `bash scripts/check_skill_map.sh` is clean | accepted: the seeded copy is enabled and the package's copy is the one disabled entry; the map is clean across 4 layers and 62 skills |
| The ADR records the second carrier and the filter trap | a dated entry in `docs/adr/skill_source_catalog.md` | accepted: `## 2026-11-01 -- The store covers vendored artifacts, and an installed package is the other carrier`, with four rejected alternatives |
| The suite and the lint gates are clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | accepted: clean across 19 gates; the suite is green |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `vendored` and `installed` name the two carriers, and `in-tree` is the container under both | each word then maps to a check: an edge, a packages entry, or `git ls-files` | `skill-fork/SKILL.md`, and the ADR entry |
| The package bump is its own pattern | one act per document; a merge and a checkout share no step | the pattern pair |
| The install's revision is not recorded in the repository | the clone is the pin and it lives in sandbox state; a committed revision would make one machine's history the project's claim | the pattern, and the ADR entry |
| The committed manifest does not name the install, and the report skips local sources | the manifest is project intent and a local path is machine state | `scripts/skill_packages.mjs` |
| A name the package provides is excluded before the same name can be vendored | one name, one route, and the filter is where the exclusion is written | the pattern pair, and the ADR entry |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A settings entry whose local path is absent loads zero skills and reports nothing | defect | a fresh sandbox silently loses every installed skill | fixed: the presence check in `skill_packages.mjs` |
| A filter whose path is not relative to the package root silently does nothing | defect | the excluded skill arrives beside the vendored copy, and pi's first-wins decides which a session reads | fixed: the pattern states it, and a test pins the no-op |
| The vendored `principle-guard-the-context-window` diverged far more than the edge's note implied | finding | the exclusion is load-bearing; without it the two copies compete | the ADR entry, and the pattern |
| The store's `upstream_path` names the harness copy of the skill, which is byte-identical to the canonical one | finding | two paths resolve at the pin, so the edge is not wrong but names the wrapper | the ADR entry: the canonical path is the plugin root, `pstack/skills/` |
| Nothing in the repository records which revision an install was taken from | finding | that is deliberate: the clone is the pin, and a committed revision would lie for the next sandbox | the ADR entry's rejected alternatives |

## Completed

| File | One-line change |
|---|---|
| `.agents/skills/skill-fork/SKILL.md` | the two carriers and the one-name-one-route rule, and a routing row per pattern |
| `.agents/skills/skill-fork/patterns/vendor-bump.md` | renamed from `upstream-bump.md`; its boundary names the other carrier |
| `.agents/skills/skill-fork/patterns/package-bump.md` | the declaration, the clone, the filter trap, eight steps and the failures |
| `.agents/skills/skill-fork/patterns/fork-and-strip.md` | the rule: exclude the package's name before vendoring it |
| `src/build/container-interface.json` | the packages mount row |
| `src/reasoning/providers/pi/docker-compose.pi.yml` | the bind row that makes it persist |
| `src/reasoning/providers/pi/onboard.sh` | the host directory it mounts |
| `docs/reference/execution_model.md` | the layout table names the packages root |
| `scripts/skill_packages.mjs` | a configured package that is absent is reported, and a local path is never unlisted |
| `tests/test_installed_package.sh` | pi's five filter behaviours, pinned offline |
| `tests/test_skill_packages.sh` | the unlisted case moves to a remote source; two cases added |
| `docs/adr/skill_source_catalog.md` | the second carrier, the boundary rule and the filter trap |
| `docs/development/source_tracking.md` | what the store does not hold includes an installed package |
| `devlog/roadmap.md` | the row closes as the second carrier |
| `devlog/handovers/20261101-12-impl-installed_package_bump.md` | this record |
