---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - the cross-document duplication map

## Objective

Build the table that says, for every judgement line in the two prose documents, which judgement it states, how many documents state it, and whether it is scheduled to become a skill. The filing consumes that table as its work list.

## Scope

The M3.3.4 row **The cross-document duplication map**, cut from the settled re-plan page. The row's done-when has three parts: every judgement row carries a class, the scaffolder's duplicate sites are pointers, and the spec census retires with its surviving content carried.

In scope:

- the grouping data, and a derived class and document count per judgement;
- the scaffolder's alignment and its repo-owned copy;
- the class-2 candidates, flagged and not landed;
- two carried record corrections, named under `## Findings`.

Out of scope, with reason: every site edit beyond the scaffolder, the ledger's regeneration beyond what the grouping needs, and the filing itself. Those belong to **The communication-surface filing**, which this iteration only schedules.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every judgement row of the ledger carries a group | `bash scripts/check_norm_ownership.sh --groups` reports no ungrouped judgement | Agent [x] |
| Every group carries a derived class and document count | the generated columns are present for all groups and the count equals the distinct sources | Agent [x] |
| A class-1 group names the skill that will own it, or is listed as pending | the map's class-1 rows name an existing skill or a scheduled one | Agent [x] |
| Class-2 candidates are flagged and no class-2 judgement is landed | the map lists them; no convention edit lands one | Agent [x] |
| The scaffolder's duplicate sites are pointers, and a repo-owned copy exists | `grep -rn` over the scaffolder finds no restated rule; the repo path holds the file | Agent [x] |
| The spec census retires only with its surviving content carried | the map holds the twelve proposed names, or the census row stays open | Agent [x] |
| Both carried record corrections land | the re-plan page's sequence clause is tagged; `20261020-07`'s Completed row is tagged | Agent [x] |
| No census, no classifier call, and no unexercised line deleted | `git status --short` names only the scope's files | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The grouping is a hand table beside the generated ledger, keyed by line hash | `--generate` rewrites the ledger, so a hand column on it is wiped on the next regeneration; the hash is the stable join key | the report, `## What the map is` |
| The map covers judgements only | a gated or reviewed row already names the artifact that catches its breach, so the home rule leaves no question about it; a description asks nothing of the reader | the report, `## What the map is` |
| Every row of a group must carry the same note | one corrupted row was invisible while the check read a single representative note, so the class could be edited away without a failure | `check_norm_ownership.sh` `groups()`, and the negative test under `## Findings` |
| The class-1 group files no new skill | its seven sites state a rule whose home, `principle-one-home-per-rule`, already exists; a second skill would be a second home | the report, `## The result` |
| The filing is rescoped to the class-1 sites plus the scaffolder | the measured overlap is one judgement, not three surfaces of the same rules | the roadmap's filing row |
| The spec census is `rejected` now, not at the filing's close | the grouping and the names it held now live in `norm-judgements.tsv`, so its plan function and its map function both have successors | the census's status line and the re-plan page's correction |
| The scaffolder's repository copy sits in the pi-config skill tree | that tree is where the other installed pi skills sit, so it is the plausible seed | the report, `## The scaffolder` |

## Decisions pending

None. One inference is unconfirmed and carried: that `src/reasoning/providers/pi/config/agent/skills/` seeds `$AGENT_HOME/agent/skills/` is inferred from the installed set, not read from an install step in this repository. The filing confirms it against the image build.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The two documents state one judgement in common, not three surfaces of the same rules | result, decision-changing | the filing keeps its reason and loses most of its size: one repoint group, no new skill | the roadmap's filing row |
| `one-term-one-meaning` is falsified as a skill: its test bans a rotating synonym, while the recorded failures were one word with two meanings | result | it stays a candidate, recommended for rejection | the report, `## The twelve proposed names` |
| The first negative test passed while the map was corrupted | result | the check read one representative note per group; it now compares every row, and the rerun fails as it should | `check_norm_ownership.sh` `groups()` |
| `skill-scaffolder` existed only in the agent config home, in neither repository skill root | result | the repository never owned it, so its duplicate template survived the cleanup | the report, `## The scaffolder` |
| The scope's file table omitted `20261019-design-draft-prose_standards_specs.md`, whose status change is the exit the roadmap row named | scope reconciliation | declared here; the edit is the status transition and one correction blockquote | this record |
| `20261020-07`'s Completed row named a deleted file as restored | record defect, carried from the plan iteration | corrected with a tag in that closed record | `20261020-07` |
| The re-plan page named the filing, not the map, as the census's retirement point | record defect, carried from the plan iteration | corrected with a tag on the page | the page |

## Completed

| File | Change |
|---|---|
| `scripts/lint/norm-judgements.tsv` | new: 75 judgement rows grouped, each with a `skill:`, `candidate:` or local note |
| `scripts/check_norm_ownership.sh` | new `--groups` mode deriving the class and counts, failing on an ungrouped line, a stale grouping row, or a group whose rows disagree; `--check` calls it |
| `src/reasoning/providers/pi/config/agent/skills/skill-scaffolder/SKILL.md` | new repository copy: the body template and `paths:` frontmatter replaced by a labelled frontmatter copy and a pointer to the conventions |
| `~/.pi/agent/skills/skill-scaffolder/SKILL.md` | aligned, byte-identical to the repository copy; outside the repository, listed for that reason |
| `devlog/discussions/20261020-report-settled-duplication_map.md` | new: the map, the result, the rescoping, the twelve names' fate, the scaffolder |
| `devlog/discussions/20261019-design-draft-prose_standards_specs.md` | status `rejected`, with the reason and the successor |
| `devlog/discussions/20261020-design-settled-communication_domain_replan.md` | correction tag: the census's exit is the map's close, not the filing's |
| `devlog/handovers/20261020-07-chore-rewrite_the_series_without_the_census.md` | correction tag: the Completed row named a deleted file as restored |
| `devlog/roadmap.md` | the map row marked done with its landing note; the filing row rescoped to the class-1 sites and the scaffolder |
| `devlog/handovers/20261020-09-workflow-duplication_map.md` | this record |
