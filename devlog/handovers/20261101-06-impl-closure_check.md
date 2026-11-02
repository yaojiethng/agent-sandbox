---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Active
---

# Handover - every reference a declared file makes resolves where its reader is

## Objective

Give the tree one reference scanner, and use it to answer two questions the declaration cannot answer alone: does a file that ships name a skill its reader will not have, and does a declared reach row correspond to a reference any file actually makes?

## Scope

**Position:** E2 of three, at the scope gate. E1 landed in `20261101-04`. E3, the kind consolidation, stays the gate-upkeep handoff.

Continues the roadmap row **Every reference a shipped file makes lands inside the zone its cell grants**, under the design record. The row's end: a skill invocation naming a skill the tree lacks and a path mention naming a root the manifest does not declare both fail. The row it started from asked a third question, whether a declared zone is vacant, and that question is answered by retiring the zones: see the decision below.

The measurement that sets the scope, run 2026-11-01 over the files the manifest declares:

| Measure | Value |
|---|---|
| Files inside a declared cell | 193 (a directory walk, not `git ls-files`: an untracked skill would otherwise be absent from the corpus) |
| Skill references in the form "`name` skill" or "skill `name`" | 38 |
| Of those, naming a skill no `SKILL.md` in the tree provides | 0, after the two fixes below |
| Path-like mentions (a backticked token starting at a known root) | 179, across 62 files |
| Declared reach rows | 10, of which 7 are referenced by no link at all. Retired in this iteration, with the operator's ruling |

**What this iteration checks.** Two rules, each decidable from the tree with no judgement:

1. **Invocation.** A token in the invocation form - a backticked name adjacent to the word "skill", either side - must name a skill the tree provides. The corpus is every `*/SKILL.md` directory name, read from a directory walk of the four layers rather than from `git ls-files`, because a skill added in the same commit must count. The form stays broad: a sentence that names an absent skill is a statement that something is broken, whether it reads as an invocation or as a remark, so it fails closed.
2. **Reach of an absolute mention.** A backticked token starting `/opt/`, `/usr/local/` or `$AGENT_HOME/` must land inside a root the manifest declares: an `image` destination, the provisioning template or home, a mount target, an `env` value, or a `session` path. This replaces the per-cell form, which the third rule retired.

**The third rule, and why it is gone.** Non-vacuity asked that every declared `reachable` row be referenced from its own cell. The measurement found only 3 of 10 rows referenced and, in the other direction, that every cell's files name folders the cell does not grant: `docs/`, `scripts/`, `tests/`, `devlog/` and `.agents/` across the eight cells. A complete grant set per cell would be eight near-identical lists, and the link gate had already made the rows nearly inert by building the permitted image set from every cell's runtime path and every session row. The operator ruled them deleted, and the ADR entry records it. What replaces the rule is the guard that the key stays deleted: a cell carrying any key but its four fails the gate.

**Ruled out, with the reason each fails this iteration.**

- **Repository-relative mentions** (`devlog/roadmap.md`, `docs/adr/`). They are not broken when read: a session's working directory is the project root, so the token resolves. Flagging them would need a claim about which readers lack the tree, which is the seeded-corpus question the linking rule already answers for links.
- **Prose that names a path without backticks, or a path built from variables** (`$D/scripts/fake.sh`, `src/build/<file>`). Both are undecidable without guessing, and a guess here reports a false defect in a record.
- **Renaming the link rule into the scanner.** The link rule's behaviour is pinned by 27 tests and a whole-tree gate; this iteration extracts the resolution half it needs and leaves the rule's arms intact.

**The scanner is extracted, not written twice.** `scripts/lint/linking.mjs` already resolves a shipped file's link in image space, maps an image path back to the repository source that populates it, and compares the target with a cell's reach. That logic moves to one module which both the rule and the new check import, because two copies of "what does this cell reach" is the defect this milestone exists to remove.

**The five invocations named a skill the tree lacks, and two different fixes followed.** `poteto-mode` and `poteto` were in `.agents/prompts/auto.md` and its maintenance record: that prompt is the operator's state, kept in the host's `.pi/agent/prompts/`, and it left the repository in `0286677b`. `codebase-design` was different in kind: it is an upstream skill our adapted `improve-codebase-architecture` depends on, so its absence was a live defect in a shipped skill, and it is now vendored from the pinned upstream revision with `disable-model-invocation: true`. The seven unreferenced rows stay open for adjudication at the close.

## Acceptance criteria

| # | Criterion | This iteration |
|---|---|---|
| B1 | A file naming a skill the tree does not provide fails, and the finding names the file and the name | pending |
| B2 | An absolute mention landing outside every declared root fails | pending |
| B3 | A cell carrying a key the declaration does not carry fails | accepted: `test_cell_carrying_a_retired_key_flagged` |
| B4 | The link rule's behaviour is unchanged where it decides a reader's path space: its 26 cases pass | accepted |
| B5 | A repository-only link from a shipped file still fails, and a link between two declared destinations passes | accepted: two cases rewritten, both bite |
| B6 | Each of the two remaining checks has a fixture the checker rejects and a mutation row that returns `PROVEN` | pending |
| B7 | The five invocation findings and the ten reach rows are either fixed or recorded as a decision with its reason | accepted: the five are fixed, the rows are retired by ADR |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scan is a gate script over declared files, not a fourth markdownlint rule | non-vacuity is a property of the declaration rather than of a file, and a per-file rule cannot see the corpus | here |
| The skill corpus is read from the tree's own `SKILL.md` paths | a handwritten list is the drift this milestone removes, and the tree already holds the truth | here |
| The invocation form stays broad, and a missing skill fails closed | a sentence naming an absent skill is a defect whether it reads as an instruction or as a remark; the narrow imperative form was tried first and would have passed the live defect | here |
| A cell declares no reach | measured in both directions: six of ten rows restated a root the manifest already declares, no cell names a repository folder exclusively, and the link gate built its permitted set from the whole session anyway. The operator ruled the deletion; the ADR entry supersedes the clause that introduced the key | [`docs/adr/instruction_surface_declaration.md`](../../docs/adr/instruction_surface_declaration.md), 2026-11-01 |
| A retired key is a finding, not ignored data | a row nothing reads is a decision written where nothing enforces it, and the key is the second field this declaration has retired | here |

## Decisions pending

| Decision | Question | Why it is not mine |
|---|---|---|

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Five invocations named a skill the tree did not provide: `poteto-mode` and `poteto` in a prompt that left the repository, and `codebase-design`, which a shipped skill depended on | defect | the first two went with the prompt; the third was a live break in `improve-codebase-architecture` and is fixed by vendoring the upstream skill | this handover, Completed |
| The rule that found them was first narrowed to the imperative form on the evidence of a false positive; the false positive was the defect | judgement | a sentence that says the skill is absent is a report of a break, and the fix is to provide the skill, not to stop the rule from reading it | this handover, Decisions |
| Seven of the ten declared reach rows were referenced by no link | defect | measured in the other direction too, so the rows could not be completed: six restated a declared root and the eighth would have restated the repository. Retired, not filled in | this handover, Decisions |
| The link gate's per-cell arm could have been read as a boundary between surfaces, and it never was one | judgement | its permitted image set was every cell's runtime path plus every session row plus the cell's own rows, so only a path outside the whole session could have failed it, and that path fails the image-existence arm first | this handover, Completed |

## Completed

| File | One-line change |
|---|---|
| `devlog/handovers/20261101-06-impl-closure_check.md` | opened, with the measurement and the narrowed rule set |
| `.agents/prompts/auto.md`, `.agents/prompts/auto/MAINTENANCE.md` | deleted: the prompt is operator state in the host's `.pi`, and it named a skill no image stages |
| `src/reasoning/agent/skills/codebase-design/` | new: the upstream skill vendored from the pinned revision, ASCII-swept, model invocation disabled, with its maintenance record |
| `.agents/registry/sources/mattpocock-skills.json` | the new artifact's `upstream_path`, `origin` and `base` |
| `src/reasoning/agent/skills/improve-codebase-architecture/MAINTENANCE.md` | the sentence that said the repository holds no `codebase-design` now states where it lives, and why the adapted copies stay |
| `src/reasoning/agent/skills/write-locations/SKILL.md` | `$AGENT_HOME` is the operator's to own and the agent's to manage, and the mount follows from the persistence |
| `devlog/roadmap.md` | the duplicated-vocabulary row, the closed prompt row's ownership wording, and the closure row re-stated without a per-cell zone |
| `docs/adr/instruction_surface_declaration.md` | new 2026-11-01 entry superseding the clause that gave a cell its `reachable` rows |
| `src/build/container-interface.json` | the key removed from all eight cells; ten rows gone |
| `src/build/container-interface.mjs` | `instruction_reach` and `check_reachable` removed; `check_cell_keys` added, so a cell carrying a key the declaration does not carry is a finding; `report` no longer prints reach rows |
| `scripts/lint/linking.mjs` | the two per-cell arms and the import removed; the remaining rule resolves a link in the path space its reader holds |
| `docs/development/instruction-surface-conventions.md` | the field row, the cell shape, the condition table and the linking gate's description |
| `.agents/skills/linking/SKILL.md` | the manifest declares roots once; the skill names no destination |
| `tests/test_container_layout.sh` | the reach fixtures and four cases replaced by the retired-key case; 33 pass |
| `tests/test_linking.sh` | three reach cases replaced by two: a link between two declared destinations is clean, and a repository-only target from a shipped file is flagged; 26 pass |
| `tests/mutations/catalog.jsonl`, `scripts/mutations_run.sh` | rows 248 and 249 re-aimed at the retired-key guard and the image-existence arm, both `PROVEN`; the subject map gains `scripts/lint/linking.mjs` |
