---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - The routing skill takes the word it teaches

## Objective

Give the skill a name that carries its own leading word, so a reader meets `signpost` in the identifier rather than `routing`, which in this tree means dispatching.

## Scope

The roadmap row **Rename the routing skill to `principle-skill-signposting`**, which states its carrier list before it runs and splits that list three ways: the two copies of the skill, the live records that follow the name, and the closed records that keep it.

The live set came out as the row predicted. The two skill copies and their frontmatter `name`. `prompt-authoring-conventions.md`, which cited the identifier twice. Both ledger files, which carried the identifier as an observer and as a group prefix. The open row **Populate the leading words across the corpus**, which is the one open row that names the skill.

The closed set keeps the old identifier, following the precedent set when `principle-one-home-per-rule` became `principle-single-source-of-truth`: closed roadmap rows and closed handovers record what was true when written, and the rename itself is the one place that states both names.

One line beyond the identifier changed, and it is the same defect. The pointer line at `prompt-authoring-conventions.md` read "Skill names and descriptions route a skill", which uses `route` in the sense the row retires. It now reads "**A skill's name and description are its signpost.**", so the pointer and the identifier it cites agree on the word.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The identifier is the new one in both trees | `ls -d src/reasoning/providers/pi/config/agent/skills/principle-skill-signposting ~/.pi/agent/skills/principle-skill-signposting` names both directories and `ls` on the old path fails | Agent [x] |
| The two copies are identical and carry the new frontmatter name | `diff` over the pair prints nothing; `grep -c "name: principle-skill-signposting"` returns 1 on each | Agent [x] |
| No live surface still names the old identifier | `grep -rn principle-effective-skill-routing` over the live tree returns only closed roadmap rows and closed handovers | Agent [x] |
| The skill still passes its own shape, so the rename did not break the corpus gate | `bash scripts/check_skill_shape.sh` prints `skill shape: clean`, and the count it reports is unchanged at 25 | Agent [x] |
| The ledger resolves the renamed observer | `bash scripts/check_norm_ownership.sh --check` prints `clean across 139 row(s), 23 gated, 14 reviewed, 62 judgement, 40 description, 20 sourced` | Agent [x] |
| The umbrella and the suite are clean | `bash scripts/lint.sh` prints `Lint: clean`; `bash scripts/run_tests.sh` prints `1273 passed, 0 failed` | Agent [x] |

## Decisions

The closed records keep the old identifier rather than following the rename. A closed row states an outcome that was true under the name in force, and rewriting it would make the record claim a name that did not exist when the work landed. The precedent is `principle-one-home-per-rule`, renamed in `20261021-07` with its closed rows left as written.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `prompt-authoring-conventions.md` still calls a skill's advertised fields a route in two other places, outside the pointer line this unit corrected | gap | the word is the row's own premise, so leaving the other two instances means the corpus still carries the collision the rename retired from the identifier | `/milestone-close`, which reads the milestone's rows against the tree and files what the sections still hold |

## Completed

| File | Change |
|---|---|
| [`principle-skill-signposting/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/principle-skill-signposting/SKILL.md) | directory renamed with `git mv`, frontmatter `name` updated |
| the `$AGENT_HOME` copy | directory renamed, file copied, pair verified identical |
| [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | both citations repointed, and the pointer line's verb changed from `route` to `signpost` |
| [`communication-principle-maximize-conceptual-leverage/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-maximize-conceptual-leverage/SKILL.md) | its pointer to where a leading word is placed names the new identifier, in both copies |
| [`norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | regenerated, its two edited rows reclassified, and the observer repointed |
| [`norm-judgements.tsv`](../../scripts/lint/norm-judgements.tsv) | the group prefix and observer repointed, then regrouped |
| [`devlog/roadmap.md`](../roadmap.md) | the open row **Populate the leading words across the corpus** repointed, and this row closed as an outcome with its carrier split recorded |
