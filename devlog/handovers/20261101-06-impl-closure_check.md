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
| Files inside a declared cell | 152 |
| Skill references in the form "`name` skill" or "skill `name`" | 35 |
| Of those, naming a skill no `SKILL.md` in the tree provides | 5, in 3 files |
| Path-like mentions (a backticked token starting at a known root) | 179, across 62 files |
| Declared reach rows | 10, of which 7 are referenced by no link at all |

**What this iteration checks.** Three rules, each decidable from the tree with no judgement:

1. **Invocation.** A token in the invocation form - a backticked name adjacent to the word "skill" - must name a skill the tree provides. The corpus is every `*/SKILL.md` directory name, read from disk, never a list in code.
2. **Reach of an absolute mention.** A backticked token starting `/opt/` or `$AGENT_HOME/` must land inside its cell's reach, read from the same declaration `scripts/lint/linking.mjs` already uses. This is the "path mention outside a zone" half, in the only form the container makes decidable.
3. **Non-vacuity.** Every declared `reachable` row must be the target of at least one reference from a file in its own cell, counting Markdown links and the two mention forms above.

**Ruled out, with the reason each fails this iteration.**

- **Repository-relative mentions** (`devlog/roadmap.md`, `docs/adr/`). They are not broken when read: a session's working directory is the project root, so the token resolves. Flagging them would need a claim about which readers lack the tree, which is the seeded-corpus question the linking rule already answers for links.
- **Prose that names a path without backticks, or a path built from variables** (`$D/scripts/fake.sh`, `src/build/<file>`). Both are undecidable without guessing, and a guess here reports a false defect in a record.
- **Renaming the link rule into the scanner.** The link rule's behaviour is pinned by 27 tests and a whole-tree gate; this iteration extracts the resolution half it needs and leaves the rule's arms intact.

**The scanner is extracted, not written twice.** `scripts/lint/linking.mjs` already resolves a shipped file's link in image space, maps an image path back to the repository source that populates it, and compares the target with a cell's reach. That logic moves to one module which both the rule and the new check import, because two copies of "what does this cell reach" is the defect this milestone exists to remove.

**Findings the measurement already exposes, to be adjudicated here:** the five invocations naming a skill the tree lacks (`poteto-mode`, `poteto`, `codebase-design`), and the seven declared rows no file references.

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

## Decisions pending

| Decision | Question | Why it is not mine |
|---|---|---|
| The seven unreferenced rows | does a row nobody references get deleted, or does it stay because a reader outside the tree uses it? | the rows are the operator's scope judgements; the check can only report them |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Five invocations name a skill the tree does not provide: `poteto-mode` twice in `.agents/prompts/auto.md` and once in its `MAINTENANCE.md`, `poteto` in the same `MAINTENANCE.md`, `codebase-design` in `improve-codebase-architecture/MAINTENANCE.md` | defect | each sends a reader to a name with no skill behind it; two of the three files are operator-facing prompts | this handover, Scope |
| Seven of the ten declared reach rows are referenced by no link | defect | a row no file uses is either dead or a claim about a reader outside the tree, and nothing currently tells the two apart | operator, raised here |

## Completed

| File | One-line change |
|---|---|
| `devlog/handovers/20261101-06-impl-closure_check.md` | opened, with the measurement and the narrowed rule set |
