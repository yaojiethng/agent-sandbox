---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Active
---

# Handover - every reference a declared file makes lands inside its zone

## Objective

Give the tree one reference scanner, and use it to answer two questions the declaration cannot answer alone: does a file that ships name a skill its reader will not have, and does a declared reach row correspond to a reference any file actually makes?

## Scope

**Position:** E2 of three, at the scope gate. E1 landed in `20261101-04`. E3, the kind consolidation, stays the gate-upkeep handoff.

Continues the roadmap row **Every reference a shipped file makes lands inside the zone its cell grants**, under the design record. The row's end has two halves: a skill invocation and a path mention outside a zone both fail, and a zone no file references fails as vacuous.

The measurement that sets the scope, run 2026-11-01 over the files the manifest declares:

| Measure | Value |
|---|---|
| Files inside a declared cell | 193 (a directory walk, not `git ls-files`: an untracked skill would otherwise be absent from the corpus) |
| Skill references in the form "`name` skill" or "skill `name`" | 38 |
| Of those, naming a skill no `SKILL.md` in the tree provides | 0, after the two fixes below |
| Path-like mentions (a backticked token starting at a known root) | 179, across 62 files |
| Declared reach rows | 10, of which 7 are referenced by no link at all |

**What this iteration checks.** Three rules, each decidable from the tree with no judgement:

1. **Invocation.** A token in the invocation form - a backticked name adjacent to the word "skill", either side - must name a skill the tree provides. The corpus is every `*/SKILL.md` directory name, read from a directory walk of the four layers rather than from `git ls-files`, because a skill added in the same commit must count. The form stays broad: a sentence that names an absent skill is a statement that something is broken, whether it reads as an invocation or as a remark, so it fails closed.
2. **Reach of an absolute mention.** A backticked token starting `/opt/` or `$AGENT_HOME/` must land inside its cell's reach, read from the same declaration `scripts/lint/linking.mjs` already uses. This is the "path mention outside a zone" half, in the only form the container makes decidable.
3. **Non-vacuity.** Every declared `reachable` row must be the target of at least one reference from a file in its own cell, counting Markdown links and the two mention forms above.

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
| B2 | An absolute mention landing outside its cell's reach fails | pending |
| B3 | A declared reach row with no reference in its own cell fails | pending |
| B4 | The link rule's behaviour is unchanged: its 27 cases pass with the scanner extracted | pending |
| B5 | Each of the three checks has a fixture the checker rejects and a case it names as outside its reach | pending |
| B6 | Each of the three checks has a mutation row that returns `PROVEN` | pending |
| B7 | The five invocation findings and the seven vacuum rows are either fixed or recorded as a decision with its reason | pending |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The scan is a gate script over declared files, not a fourth markdownlint rule | non-vacuity is a property of the declaration rather than of a file, and a per-file rule cannot see the corpus | here |
| The skill corpus is read from the tree's own `SKILL.md` paths | a handwritten list is the drift this milestone removes, and the tree already holds the truth | here |
| The invocation form stays broad, and a missing skill fails closed | a sentence naming an absent skill is a defect whether it reads as an instruction or as a remark; the narrow imperative form was tried first and would have passed the live defect | here |

## Decisions pending

| Decision | Question | Why it is not mine |
|---|---|---|
| The seven unreferenced rows | does a row nobody references get deleted, or does it stay because a reader outside the tree uses it? | the rows are the operator's scope judgements; the check can only report them |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Five invocations named a skill the tree did not provide: `poteto-mode` and `poteto` in a prompt that left the repository, and `codebase-design`, which a shipped skill depended on | defect | the first two went with the prompt; the third was a live break in `improve-codebase-architecture` and is fixed by vendoring the upstream skill | this handover, Completed |
| The rule that found them was first narrowed to the imperative form on the evidence of a false positive; the false positive was the defect | judgement | a sentence that says the skill is absent is a report of a break, and the fix is to provide the skill, not to stop the rule from reading it | this handover, Decisions |
| Seven of the ten declared reach rows are referenced by no link | defect | a row no file uses is either dead or a claim about a reader outside the tree, and nothing currently tells the two apart | operator, raised here |

## Completed

| File | One-line change |
|---|---|
| `devlog/handovers/20261101-06-impl-closure_check.md` | opened, with the measurement and the narrowed rule set |
| `.agents/prompts/auto.md`, `.agents/prompts/auto/MAINTENANCE.md` | deleted: the prompt is operator state in the host's `.pi`, and it named a skill no image stages |
| `src/reasoning/agent/skills/codebase-design/` | new: the upstream skill vendored from the pinned revision, ASCII-swept, model invocation disabled, with its maintenance record |
| `.agents/registry/sources/mattpocock-skills.json` | the new artifact's `upstream_path`, `origin` and `base` |
| `src/reasoning/agent/skills/improve-codebase-architecture/MAINTENANCE.md` | the sentence that said the repository holds no `codebase-design` now states where it lives, and why the adapted copies stay |
| `src/reasoning/agent/skills/write-locations/SKILL.md` | `$AGENT_HOME` is the operator's to own and the agent's to manage: the agent writes it, and the host mounts it so the write outlives a container |
| `devlog/roadmap.md` | the duplicated-vocabulary row, and the closed prompt row's ownership wording |
