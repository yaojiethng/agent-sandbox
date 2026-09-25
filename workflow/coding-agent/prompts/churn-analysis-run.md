# Churn Analysis - Run (Main-Agent Template)

## Purpose

Find refactor and rewrite targets by change frequency. A churn number alone never justifies a rewrite. The signal is the join: a file that changes often and carries read-through findings in its sector is the priority; a file that changes often with no findings is stable-but-evolving and needs no action.

This brief is the companion to [`read-through-run.md`](read-through-run.md). The read-through produces the findings register and measures whether the tests pin behaviour; this pass produces the change-frequency ranking and measures where the tree moves. Join the two before you propose any rewrite. The register this pass joins against lives in [`20260924-design-active-test_suite_readthrough.md`](../../../devlog/discussions/20260924-design-active-test_suite_readthrough.md); reach for the register version that is current at run time, because row numbers are stable and the file grows.

## The pinned measurement

Write the exact command and the window beside every churn table you produce. A count without them cannot be reproduced or compared. This rule is the whole point of the pass: the survey that prompted this brief stated a per-file count of 75 for `scripts/start_agent.sh` and 31 for `scripts/templates/Makefile.template`, and a later review could not re-derive either number because the record did not state the command. With rename following, the review measured the same two files at 88 and 54. The difference is the unpinned method, probably rename following and merge handling. Report a churn number only when its command and its window are written next to it.

The pinned command is:

```bash
git ls-files -z | while IFS= read -r -d '' f; do
  n=$(git log --follow --format=%H HEAD -- "$f" | wc -l)
  printf '%d\t%s\n' "$n" "$f"
done | sort -rn
```

The pinned window is the full history reachable from `HEAD` on the current branch at run time: no date bound, no merge exclusion, and no path filter beyond the file under measurement. The command above prints `count<TAB>path`, ranked descending. Re-run it at the start of each pass; the window moves with `HEAD`, so the counts are valid only inside the run that produced them.

`--follow` is required. Without it, git attributes the commits that predate a rename to the old path, so a renamed file's history resets at the rename and the old path ranks as a separate entry. That understates exactly the files that were reorganised, which are the files a rewrite survey is looking for. `--follow` accepts one path, so the loop runs the measurement once per tracked file. Confirm the flag is present before you trust a count that disagrees with an earlier run.

## The two sweeps

Separate mechanical churn from functional churn, and report both counts per file. Mechanical churn is a commit that only renames, moves, reformats, or mass-rewrites without changing behaviour. Functional churn is a commit that changes behaviour. A single blended count cannot tell an actively designed file from one that a repo-wide sweep passed through.

Classify each commit for the file under measurement from the commit subject and the diff. A commit is mechanical when one of these holds:

1. **Rename or move.** `git log --follow --name-status` shows the file with status `R` or `C` for that commit, or `git diff --numstat <commit>^ <commit> -- <path>` reports 0 added and 0 deleted lines. The path is the name the file carries in that commit, which `--name-status` supplies for a rename.
2. **Reformat or reflow.** The commit changes lines, but the whitespace-insensitive diff is empty: `git diff -w --numstat <commit>^ <commit> -- <path>` reports 0 added and 0 deleted. A re-indent, a line-wrap, or a tab-to-space change is mechanical.
3. **Mass rewrite.** The subject names a repo-wide textual operation for one convention (an ASCII migration, a punctuation sweep, a markdownlint sweep, a field-schema rename, an identifier rename, a line-wrap sweep), and the file's diff in that commit changes only the token the operation targets. Read the diff and confirm the change touches the token, not a value, a condition, or a control-flow line.

Otherwise the commit is functional. Default to functional on doubt: classifying a real behaviour change as mechanical hides a rewrite target, which is the failure the pass exists to prevent. State the number of commits the default caught in the run report.

## Output shape

Produce a ranked table with one row per file and these columns: the total commit count, the mechanical count, the functional count, and a cross-reference column that names the register rows or the sector the file appears in. Keep the total equal to the sum of the two counts, and state the command and the window above the table.

Rank all tracked files. The action list is the intersection of the ranking and the register: a file is actionable only when at least one register row names it. A documentation file qualifies only through a documentation-drift row, and its remedy is a documentation edit rather than a code rewrite. When no register row names a file, write `none` in the cross-reference column.

Below the table, list the files that are both high-churn and finding-bearing. That short list is the deliverable a reader acts on. A file on the list has a change frequency above the run's threshold and at least one register row; a file with a high count and no row is stable-but-evolving and stays off the list.

## Close

Record the ranked result in the register or in the roadmap write-back. A rewrite candidate becomes a roadmap task with its two numbers attached: the functional commit count and the register rows that name it. Never start a rewrite from the churn table alone. The table ranks attention; the register supplies the defect that a rewrite would fix, and the roadmap task carries both.

## The caution

Churn is a prioritisation input, not a defect. A high count can mean a large surface, an active area, or merely a file that predates a refactor and has since been swept mechanically. Read the count with the finding density: a file with 88 commits and 12 findings is a different proposition from a file with 88 commits and none. State this limitation in the run report, and do not let the ranking read as a defect list.

## Worked example

The pinned command run against this repository on the 679 commits reachable from `HEAD` on the current branch at run time (2026-09-25) returns:

```text
293	devlog/roadmap.md
134	devlog/handovers/20260701-03-impl-m2_6_2_persistence.md
88	scripts/start_agent.sh
66	scripts/agent-sandbox.sh
62	docs/architecture/tool_interface.md
62	docs/architecture/sandbox_lifecycle.md
59	devlog/AGENT_FEEDBACK.md
54	scripts/templates/Makefile.template
52	docs/architecture/execution_model.md
50	src/capability/entrypoint.sh
48	devlog/roadmap_future.md
46	src/build/compose.sh
44	docs/operations/handover_policy.md
43	scripts/run_agent.sh
43	docs/operations/iteration_policy.md
```

Applying the two-sweep rule above gives the ranked table for the top fifteen files. The cross-reference column holds the register rows that name the file, with the sectors those rows are triaged into.

| File | Total | Mechanical | Functional | Register rows (sectors) |
|---|---|---|---|---|
| `devlog/roadmap.md` | 293 | 8 | 285 | none |
| `devlog/handovers/20260701-03-impl-m2_6_2_persistence.md` | 134 | 7 | 127 | none |
| `scripts/start_agent.sh` | 88 | 4 | 84 | 43, 120, 165-171, 173, 265, 266 (A, C, F, H, I, J) |
| `scripts/agent-sandbox.sh` | 66 | 2 | 64 | 7, 48, 136, 199-201, 203-207, 266, 283 (A, C, G, H, I, J) |
| `docs/architecture/tool_interface.md` | 62 | 2 | 60 | 91, 299 (C, F) |
| `docs/architecture/sandbox_lifecycle.md` | 62 | 5 | 57 | none |
| `devlog/AGENT_FEEDBACK.md` | 59 | 4 | 55 | none |
| `scripts/templates/Makefile.template` | 54 | 3 | 51 | 37, 44, 45, 48, 155, 267-274 (A, F, H, I, J) |
| `docs/architecture/execution_model.md` | 52 | 4 | 48 | none |
| `src/capability/entrypoint.sh` | 50 | 6 | 44 | 10, 22, 70, 105-112, 302 (A, B, C, D, F) |
| `devlog/roadmap_future.md` | 48 | 3 | 45 | none |
| `src/build/compose.sh` | 46 | 3 | 43 | 19, 92, 94-96, 98-100, 116, 294, 297 (C, F, J) |
| `docs/operations/handover_policy.md` | 44 | 2 | 42 | none |
| `scripts/run_agent.sh` | 43 | 2 | 41 | 36, 166, 174-180, 182-186 (A, C, F, H, I, J) |
| `docs/operations/iteration_policy.md` | 43 | 3 | 40 | none |

The files that are both high-churn and finding-bearing, in rank order, are the deliverable of this run:

| File | Functional commits | Register rows |
|---|---|---|
| `scripts/start_agent.sh` | 84 | 43, 120, 165-171, 173, 265, 266 |
| `scripts/agent-sandbox.sh` | 64 | 7, 48, 136, 199-201, 203-207, 266, 283 |
| `docs/architecture/tool_interface.md` | 60 | 91, 299 |
| `scripts/templates/Makefile.template` | 51 | 37, 44, 45, 48, 155, 267-274 |
| `src/capability/entrypoint.sh` | 44 | 10, 22, 70, 105-112, 302 |
| `src/build/compose.sh` | 43 | 19, 92, 94-96, 98-100, 116, 294, 297 |
| `scripts/run_agent.sh` | 41 | 36, 166, 174-180, 182-186 |

`docs/architecture/tool_interface.md` enters the list through its two documentation findings; its remedy is a documentation edit, not a code rewrite. The two highest-churn entries are records, not code: `devlog/roadmap.md` and a handover carry the most commits because every iteration edits them. They stay in the ranked table and stay off the action list. This is the caution in practice.

## Invariants

- Every churn table carries the command that produced it and the window it measured.
- Every count uses `--follow`; a count without it is not comparable to the pinned measurement.
- Every file row reports the mechanical and the functional count separately, and the total equals their sum.
- No commit is classified mechanical on doubt; the default is functional.
- No rewrite is proposed from the churn table alone; a candidate carries its register rows and becomes a roadmap task.
- The ranked result is recorded in the register or the roadmap write-back, not only in chat.
