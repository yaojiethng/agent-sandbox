---
date: 2026-11-08
milestone: M3.3.5 - The eval pipeline
type: Implementation
status: Closed
---

# Handover - The replayed eval harness reaches a gradeable run

## Objective

Replay `feat/M3_3_5-evals` onto the current `HEAD`, then run a declared eval from the replayed harness and make it produce the evidence the case grades.

## Scope

The branch replay and the harness defects a real run exposed: the role table the runner resolves, the committed delta the grade carries, and the per-run measure object the benchmark states. The subject is the M3.3.5 harness row and its tests.

Out of scope: the blind grade of the contrast reports and the case's verdict; the remaining M3.3.5 rows, including the stopped-run and assertion-record rows; and any change to the case fixture or its decision rule.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The branch is replayed onto `feat/M_3-orchestration` with its four units intact | `git log --oneline feat/M_3-orchestration..HEAD` prints four commits | Agent [x] |
| A declared run resolves the repository's role table when neither `EVAL_RECOMMENDATIONS_FILE` nor `PROJECT_DIR` is set | `bash tests/test_eval_harness.sh` (`test_run_case_uses_the_repository_role_table`) | Agent [x] |
| The grade carries a run's committed change, not only its working-tree remainder | `bash tests/test_eval_harness.sh` (`test_run_case_writes_a_sanitized_grade_dir`) | Agent [x] |
| The benchmark's `runs_detail` carries each run's measure object and model | `bash tests/test_eval_harness.sh` (`test_run_case_scores_a_stub_run`) | Agent [x] |
| The real inverted contrast writes a report into the blind grade dir | `grade/case-01.txt` carries a 9-line `report.jsonl`; `grade/case-02.txt` carries a 14-line one | Agent [x] |
| The contrast loses the sensitivity gate's two rules before the subject batch | neither report names `docs/development/host_requirements.md`; the one `scripts/install.sh` mention is an unrelated `INSTALL_DIR` claim, not evidence about the hints | Agent [x] |
| The harness suite and the lint umbrella are green | `bash tests/test_eval_harness.sh` (32 of 32); `bash scripts/lint.sh` (25 gates) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The dispatch seam owns the role-table default | The table is committed with the repository, and a second path in the eval sent a run to a per-user file the repository does not ship | `.agents/skills/evals/scripts/run_case.sh` |
| The grade carries the committed delta as well as the uncommitted remainder | A run that commits its report left the grade directory empty, so the case was ungradeable | `.agents/skills/evals/scripts/run_case.sh` |
| `runs_detail` carries the measure object beside the commit fields | The reference already states the measure object, and a report case's fields were invisible in the benchmark | `.agents/skills/evals/scripts/run_case.sh` |
| The blind grade and the verdict stay out of this unit | The sensitivity gate stopped before the subject batch, and the report content is the grader's evidence, not the harness's | this record |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Which defect the default review misses? | A doc-maintenance case that separates the skill from its absence | the existing options in handover `20261107-03`: a cross-document inconsistency, a claim whose source is an obscure manifest, or a weaker model |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first replayed invocation failed with `dispatch: role table not found: /home/agentuser/.pi/model-recommendations.md` | harness defect | a fresh checkout could not run an eval without an undocumented environment variable | fixed here |
| The fixed run produced an empty grade file because the agent committed `report.jsonl`; the grade cutter read only the working-tree remainder | harness defect | the case's evidence was lost with the worktree | fixed here |
| Both inverted runs reported other drifted documents and omitted R1; one named `scripts/install.sh` for an unrelated claim and neither tied it to the hints, so R2 also has no evidence | measurement | the configuration built to fail now fails, so the sensitivity gate passes and the subject batch may be read | this record; the case's `plan.json` |
| The benchmark's top-level `correctness` is null for a report case | design | expected: the case is graded blind, so the harness does not compute a mechanical pass rate for it | `references/harness.md`; the case's `measurement` |
| The replay conflicted in `scripts/lint.sh` and in one discussion record | record | HEAD had added the build-context and pin gates; the branch adds the eval-entrypoint gate, so the union is kept; HEAD had re-pathed a record the branch deletes, so the deletion stands | this record |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/scripts/run_case.sh` | The dispatch seam resolves the table; the grade carries the committed delta; `runs_detail` carries the measure |
| `tests/test_eval_harness.sh` | The repository-table fallback, the committed-change grade and the measure object are pinned |
| `devlog/handovers/M3.3.5/20261108-01-impl-eval_run_replay.md` | this record |

Merged from handovers `20261108-02-impl-gm_ablation_case` `20261108-03-fix-prompt_case_overlay` `20261108-05-test-gm_sentence_candidates` `20261109-03-impl-gm_case_reproduces`; their decisions and findings remain in the pre-rewrite history.
