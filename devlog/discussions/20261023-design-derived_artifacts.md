---
status: settled
date: 2026-10-23
---

# Design - The derived artifacts this repository stores

## Context

A recurring error in this workshop: a derived intermediate is written to disk, and then maintained by hand for the rest of its life. Sometimes that is deliberate -- `workflow_statechart.md` is documentation, and the operator took it over as such. Usually it is not, and the artifact is a catalog, a registry, an index or a `.jsonl` that restates something the tree already holds.

The policy form is retired, so the answer is not a rule about catalogs. The answer is a measurement: which stored artifacts are derived, who regenerates each one, and what it costs when nobody does.

## Method

The census was a one-shot script run over the tracked tree, and nothing of it is kept except what it measured: the table in `## What the tree says`, and the detectors named below with what each one could and could not see. The script is not reproduced here. It was the wrong shape, for the reasons at `## Rejected` and in the reviewer section, and a reader who reran it would be rerunning the instrument this record argues against.

- **Detector A** -- a path some non-test code writes: `writeFileSync`, a redirect, `tee`. This finds a generator by its output.
- **Detectors B and C** -- a markdown table of eight rows or more whose first column mirrors names that exist in the tree, or is a slash command.
- **Detector E** -- a JSON or JSONL registry of eight entries or more that code reads.
- **The gardening metric** -- for each candidate, its commits, and how many of those changed only table rows or registry entries. A commit that touches only rows is upkeep, not substance.

The metric is a signal, not a verdict. It ranks `settings.json` first with 23 upkeep commits of 28, and `settings.json` is pi's settings record: the 23 are version bumps and surface declarations, all authored work. A file can churn without being derived, so the classification below is made by hand against the evidence.

## What the tree says

Detector A found **nothing**. No code in this repository writes a tracked file: every generator that exists writes to the host, to `.compose/`, to a run directory or to `$AGENT_HOME`, none of them into the tree. So the repository has no regenerable artifact at all. Every stored derived artifact here is hand-maintained, and "regenerate and diff" is not an option that is available today -- there is nothing to run.

That single result decides the shape of the answer below: a stored artifact can be checked against its source, but it cannot be rebuilt from it.

| Artifact | Size | Who regenerates it | Who reads it | Commits / upkeep | Classification |
|---|---|---|---|---|---|
| `tests/mutations/catalog.jsonl` | 244 rows | nobody; the `bite_*.sh` sources are deleted | one runner, which reports a drifted row as `stale` at use | 1 / 1 | Authored source; its one derived column is checked at use |
| chart `## Commands` | 17 rows | nobody | a human | 2 / 0 | Gated copy, and the gate is missing |
| `AGENTS.md` `### Loop prompts` | 9 rows | nobody | `check_instruction_surfaces.sh`, which holds it to the protocol's `scope` | 69 / 7 | Gated copy |
| ADR `coding_agent_loop_workflow.md` command table | 11 rows | nobody | a human | 22 / 3 | Authored source: a dated snapshot |
| `src/build/container-interface.json` | 45 rows | nobody | 8 files, plus the layout gate | 8 / 1 | Authored source: the declaration |
| `pi/config/agent/settings.json` | 16 keys | nobody | 5 files | 28 / 23 | Authored source; one field is a copy with no gate |
| chart `## States` | 40 rows | nobody | a human | 2 / 0 | Authored source; its id column repeats the diagram above it |
| `agent_workflow.md` ownership table | 12 rows | nobody | a human | 45 / 8 | Authored source; 3 of its 12 document cells are links |
| `documentation_taxonomy.md` `## Reach` | 4 rows | nobody | `check_reach.sh` | -- | Gated copy; one row unverified |

The four classifications are those of `principle-guard-derived-state`, which was written from this census and shipped one commit later. This record applies the principle; where the two disagree, the principle wins.

Two facts belong in the table's margin.

The mutation catalog carried a header of `count` and `last_updated` that its runner skips by pattern (`grep -v '"schema"'`): derived values stored in the artifact, read by nothing, and free to be wrong. Those were the only fields in this repository that were unambiguously the defect the census was looking for, and this iteration removed them, leaving schema, kind and origin -- all authored.

The `/auto` name is carried by two artifacts: an ADR row reserving `/auto` for M4, and `.agents/prompts/auto.md`, this project's own routing target for a subagent style. One name, two things, and no gate would have said so, because both exist.

## The rule

The unit of derivation is the **column**, not the file, and the direction of the claim decides the classification.

- A column whose value the tree can supply -- a file exists, a directory lists it -- is derived. Store it only behind a gate that regenerates it and diffs, or print it and store nothing.
- A column whose value is a claim -- a description, an edge, a decision, a chosen subset -- is authored. A gate that regenerated it would replace a judgement with a generator.
- The test for the first case is one sentence: **does the table assert that it equals a set the tree already holds?** The chart's `## Commands` does, and is ungated. `AGENTS.md`'s loop table does not: it asserts the nine prompts the protocol governs, and the gate holds it to that declaration rather than to the directory. That is why one is a defect and the other is not, and no file-level rule can see the difference.

Three consequences follow, and they are the answer to the operator's question.

1. **Nothing in this repository is regenerable, so the first move is not to build generators.** A gate that checks a stored copy against its source is one tenth the code of a generator that rebuilds it, and this tree has no generator to build on.
2. **A registry that a program writes and reads is not a catalog.** `container-interface.json` and the task-queue journals are authored declarations and runtime state; neither is restated elsewhere and neither needs deriving.
3. **A facility whose corpus cannot be regenerated is a feature decision, not a check.** The mutation corpus's 244 rows, its one run record and its opt-in tier cost upkeep in a currency this repository is short of: hand-editing a data file when a subject script changes. That decision is the operator's, and it carries a number, below.

## Rejected

- **R1 -- A committed census script.** The census runs once per question; a committed script needs tests, a gate, and a reader who runs it. The query is kept instead, as text, and re-run by pasting it.
- **R2 -- A gate that rebuilds a catalog from the directory.** There is nothing to rebuild with: no generator exists, so the gate would have to embed the generator anyway, which is R1 with a worse name.
- **R3 -- Deriving `container-interface.json` from the dockerfiles.** It is the declaration the dockerfiles are checked against. Deriving it inverts the dependency the whole layout gate rests on.
- **R4 -- Treating the chart's `## States` as a catalog of the tree.** No file holds a state list, so there is nothing to derive it from. It does duplicate the chart's own Mermaid declarations, 40 ids against 40 declarations, which is a duplication inside one file rather than a copy of the tree, and it is a roadmap row rather than a project of this unit.

## Two reviewer seats, blind

Both seats classified the nine artifacts from the numbers alone, without the verdicts, and both perturbed a copy of the tree rather than arguing. They converged on every home this record now states, and they corrected three of my first readings:

- **The mutation catalog is authored, not stored-and-derived.** Its `name` and `new` columns are judgements about which line to break and to what; only `old` is a byte copy of the subject. A row cannot be regenerated, so the artifact is a curated corpus whose one derived column is checked at use.
- **The chart's tables are authored, and the derivation is one column wide.** With 17 rows against 17 files the row set is a directory listing, but the fires-from and leaves-in cells compress multi-hop routing that no file holds. The same shape explains `## States`: its id column restates the diagram in the same file, and its gloss column is design prose.
- **The churn metric measures the file, not the artifact.** It is shape-blind (its upkeep regex fires on any changed line beginning with a table pipe or a brace), rename-sensitive, and it ranks its own false positive first. It is reported as a ranking of where to look; the classification above is the evidence.

One seat also found that `settings.json` carries the image's version pin as a literal, so one version lives in two records with one hand-synced copy -- the census's own defect at the smallest scale it occurs here.

## Consequences

The census adds one row to the roadmap for the mutation corpus's classification, and amends the parked cited-command row, whose second subject the chart's `## Commands` table now is.

The rule it states belongs in the judgement corpus rather than in a convention, because it is a judgement. It was written on release as `principle-guard-derived-state`, which carries the three filters, the four classifications and the column test; this record keeps the census that produced it.
