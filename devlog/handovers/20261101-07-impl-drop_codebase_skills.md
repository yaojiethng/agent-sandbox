---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - drop the two deep-module skills

## Objective

Remove `improve-codebase-architecture` and `codebase-design` from the tree, with every carrier of their names, because nothing invokes either and the version on the fork is not worth keeping.

## Scope

Operator direction, 2026-11-01: "drop `improve-codebase-architecture`, and the new skill it adds. Don't think we use it, and don't think the version as exists on the fork would be useful."

`codebase-design` was vendored earlier this milestone (`20261101-06`) as the dependency that skill had been missing; `improve-codebase-architecture` was its only caller. Dropping the caller drops the dependency.

The measurement agrees with the direction: neither name appears in an invocation anywhere - no prompt, no skill, no workflow document - so the only references were the fork's internal links, its own record, and the source registry. The roadmap row that asked for one home for the vocabulary is deleted with its subject.

In scope: the two skill folders, both registry rows, the sibling records that name them, a fixture that borrowed the name, the scanner comment that cited one as its evidence, and the roadmap row whose subject they were.

Out of scope: the installed copies, which live in the operator's config home rather than in this tree and are theirs to keep or remove, and the upstream source record, which still names the two artifacts as present upstream.

## Acceptance criteria

| # | Criterion | This iteration |
|---|---|---|
| C1 | Both skill folders are gone and no file in the tree links either | accepted: the only remaining names are in closed records and ADR rationale, which state the past |
| C2 | The registry carries no artifact whose local path is absent | accepted: both rows removed; `check_skill_sources.sh` clean |
| C3 | Every generated or checked surface recounts the tree without them | accepted: 62 skills across 4 layers, 144 declared files, 71 skill names |
| C4 | The roadmap row whose subject they were is gone | accepted: the vocabulary row deleted |
| C5 | `dispatch`'s description states the trigger, spawning sub-agents | accepted: it keeps both prior claims and names the act |
| C6 | Lint clean and the suite green | accepted: 19 gates, 1435 tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Both skills leave together | one was the other's only caller, so keeping the dependency of a removed caller leaves a skill nothing reaches | this handover |
| The ADR rationale keeps naming both | `skill_source_catalog.md` argues from them as examples, and an ADR entry records what was decided against the tree it had; a record rewritten to match today's tree stops being a record | this handover |
| `dispatch`'s description keeps the wording the collapse produced | the trigger states the act - spawning sub-agents - rather than one situation, and it is right whether or not either skill exists | this handover |
| The registry row goes with the skill, and the source record stays | the registry certifies what the tree carries, and the source record names what upstream holds, so a skill dropped here is still an artifact upstream ships | this handover |

## Decisions pending

| Decision | Question | Why it is not mine |
|---|---|---|
| The installed copies | whether the config home's copies of either skill stay | they are the operator's state, reached through the mount rather than through this tree |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Neither skill was invoked by anything in the tree | measurement | the only references were internal links, one record, two registry rows and a fixture that borrowed the name | this handover, Completed |
| `test_skill_sources.sh` used `improve-codebase-architecture` as the name of a nested-skill fixture | defect | a fixture naming a real skill reads as a claim about that skill; it is now `nested-child` | this handover, Completed |
| `docs/adr/skill_source_catalog.md` argues from both skills as examples | record | left as written: the entry records the reasoning against the tree of its date | this handover, Decisions |

## Completed

| File | One-line change |
|---|---|
| `src/reasoning/agent/skills/improve-codebase-architecture/` | deleted: six files, the skill and its vocabulary copies |
| `src/reasoning/agent/skills/codebase-design/` | deleted: four files, the vendored skill and its record |
| `.agents/registry/sources/mattpocock-skills.json` | both artifact rows removed |
| `.markdownlint-cli2.mjs` | the wrap exemption for the deleted `LANGUAGE.md` removed |
| `src/reasoning/agent/skills/domain-modeling/MAINTENANCE.md` | its caller is recorded as dropped rather than live |
| `src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md` | the description states the trigger: use when spawning sub-agents |
| `scripts/lint/references.mjs` | the comment no longer cites a skill the tree lacks as its evidence |
| `tests/test_skill_sources.sh` | the nested-skill fixture is named `nested-child` |
| `devlog/roadmap.md` | the vocabulary row deleted with its subject |
| `devlog/handovers/20261101-07-impl-drop_codebase_skills.md` | this record |
