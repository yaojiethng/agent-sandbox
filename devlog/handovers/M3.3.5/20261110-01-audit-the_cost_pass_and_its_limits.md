---
date: 2026-11-10
milestone: M3.3.5 - The eval pipeline
type: Audit
status: Closed
---

# Handover - The cost pass leaves the prompt unchanged, and the limits are measured

## Objective

Run the S3 hypothesis against the landed prompt: the `/gm` survey reads only the current milestone's section of `devlog/roadmap.md` instead of the whole file, and the run records whether the read surface, token cost and wall clock fall without losing the structural score or the milestone alignment.

## Scope

The M3.3.5 row **The `/gm` survey's read cost falls in tokens per effective report**, following the accepted S2 rule (`20261109-10`). The control is the landed prompt at `6e95ccb2`; the hypothesis is the same file with the Survey roadmap bullet replaced by: "Read only the current milestone's `In progress` row, its section and its open items; grep for the section heading and read that range, not the whole file." The fixture base stays at `d76319d`, and the baseline overlay carries the landed prompt, so the only variable between the arms is the S3 bullet. The bullet is not landed; the operator resolves it after the reading. The calibration model `opencode-go/crouton-alpha-free` is deprecated (HTTP 410), so the run uses the declared survivor `opencode-go/iceman-contributor-free`; the baseline arm at eight runs is the control on that model.

The runs and records merged here: `20261110-01-audit-targeted_roadmap_read`, `20261110-04-audit-intent_delegation`, `20261110-05-audit-read_back` and `20261110-06-audit-eval_instrument`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The baseline overlay equals the landed prompt, and the hypothesis overlay differs from it only by the Survey roadmap bullet. | `diff` of `fixture/configurations/baseline/workflow/coding-agent/prompts/gm.md` against `git show 6e95ccb2:workflow/coding-agent/prompts/gm.md` is empty; `diff` against the hypothesis overlay is one hunk | Agent [x] |
| `--check` accepts the case with the new configuration. | `run_case.sh --check=tests/eval/cases/gm-focus-milestone.json` prints `case ok` | Agent [x] |
| Both cells complete eight runs with no stop and no invalid run. | `benchmark.json`: `batch.stop: null`, both cells in `cells_run`, 16 valid | Agent [x] |
| The structural outcome is recorded per arm. | the benchmark's `rules`, `failed_assertions` and `analysis` | Agent [x] |
| The read surface per arm is recorded, so the mechanism is tested. | `turns_detail[].paths` aggregate for `devlog/roadmap.md`, opens and bytes | Agent [x] |
| The blind alignment reading is recorded per arm. | the label-free `grade/` and the joined `-grade.tsv` | Agent [x] |
| The case's decision rule is applied, and the result is stated without a significance claim. | the benchmark `analysis` and this record's Findings | Agent [x] |
| The S3 row carries the outcome, marked `[x]` when the hypothesis holds and left `[ ]` with the outcome when it does not. | `devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The control is the landed prompt at `6e95ccb2`, carried as the `baseline` overlay on the `d76319d` fixture | the fixture base stays fixed, so the only variable between the arms is the S3 bullet; the landed prompt is the one this edit would modify | this record |
| The run is eight runs per cell in both cell orders | the S2 run showed the cell order can carry a time effect, and eight runs is the calibration count | this record |
| The decision rule is applied as written: structural at or above, token cost and wall clock lower, blind alignment not worse | the hypothesis is a cost simplification, which is what the rule was written for | this record; `tests/eval/cases/gm-focus-milestone.json` |
| The run uses `opencode-go/iceman-contributor-free` | `crouton-alpha-free` returns HTTP 410 `ModelDeprecated`; iceman is the next survivor in the declared screen order, and the baseline arm is the control on the same model | this record |
| The targeted-read bullet is not landed | the median tokens and turns rose (1.04M against 987k tokens, 14 against 12 turns), the alignment was equal, and the mean edges are one long control run; the byte and open counts are a diagnostic, not the criterion; the row stays open for a read strategy that lowers tokens per effective report | this record; `devlog/roadmap.md` |
| The control is the landed prompt from `candidate-checkin-write-rule-20261110` | its text equals the current `gm.md`, and its eight valid runs are the same model and case | this record |
| The arms form a granularity ladder rather than one prompt | the question is whether method specificity changes the path, so the arms differ only in the Survey line's method content | this record |
| `rg` stays as the environment ships it | 13.0.0 is already installed; the intent-only arm is therefore the "available, unmentioned" scenario, and the control transcript already shows `rg` use | this record |
| Each arm ran alone at eight runs | a pool stop on one arm's timeout would hold the later arms; a single-cell batch isolates each arm | this record |
| No arm lands; the S3 row stays open | no arm is eligible on the case's rule: the script arm's alignment falls below the control, the intent-only arm loses structure, and the tool-family and named-tool arms cost more for equal alignment | this record; `devlog/roadmap.md` |
| The next branch is the artifact family, or a read strategy tested with an alignment mechanism | the extraction methods lower the raw read but lose the alignment; the read breadth appears to carry alignment, so the next test must protect that axis | this record; `devlog/roadmap.md` |
| Reuse the control and read-only cells | the operator directed it; the prompt texts are the same | this record |
| The naming sentence sits immediately before the current-milestone rule in `## Close` | it applies to both closing branches, and it names the requirement once | this record |
| The blind grade is repeated for all four cells with one prompt | the prior control and read-only verdicts came from a different prompt without the naming column; one grading pass keeps the 2x2 comparable | this record |
| No edit lands; the S3 row stays open | the naming edit does not recover the alignment, and the interaction is negative: script-naming is 0/8 against the script's 1/8 and the control's 2/8 | this record; `devlog/roadmap.md` |
| The next branch is the artifact family, or closing the row | the read method and the report requirement are both exhausted; only a smaller source that preserves the read context is left | this record; `devlog/roadmap.md` |
| Close the row | the operator chose close: the read and report branches are exhausted, and the control is the effective leader; the artifact branch is not tested | this record; `devlog/roadmap.md` |
| The audit is `record` only; no harness change | the next row writes the protocol, and a measurement change before the audit would invalidate the archive | this record |
| The A/A band is read only within one model | `crouton-alpha-free` was deprecated mid-session, so its batches are a different system from the iceman batches | this record |
| The alignment granularity is one report at eight runs | 1/8 is 12.5 percentage points, and every arm contrast observed was one or two reports | this record |
| The stale control is flagged, not fixed | it belongs to the case-record row, which owns the design fields | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `opencode-go/crouton-alpha-free` is deprecated. | model | the first S3 dispatch stopped on `exit-nonzero` at `baseline` run 1 with HTTP 410 `ModelDeprecated`; R7 named the class and the remaining cell | this record; the S3 run repeats on `iceman-contributor-free` |
| The targeted-read bullet does not reduce the roadmap read surface. | measurement | the single targeted run that read the roadmap opened it five times (1,079,855 B) against the control's one (215,971 B); the token median is 1.041M against 987k, and the wall mean is 284 s against 296 s; the mean token difference is one long control run | this record; the S3 row |
| The read-surface measure counts procedure, not cost. | harness | it records `read`-tool paths and bytes, not the tokens a read adds to the context; a batched read that opens more files but spends fewer tokens scores worse. 14 of the 16 runs show zero roadmap bytes because bash reads are invisible, but the decisive defect is the unit, not the coverage. The measure needed is tokens per effective read; per-turn tokens are already recorded. | `devlog/roadmap_future.md` deferred measurement infrastructure |
| The intent-only arm is not cheaper in effect. | measurement | token median 1.13M against the control's 1.20M (-6%), turns 12 against 13, but structural 0.9167 against 0.9643 and blind alignment 1/8 against 2/8; it used `cat` 45 times against the control's 13, reading more whole files | this record; the S3 row |
| `rg` is used without being named. | tooling | the control, whose prompt says "grep", uses `rg` 29 times; intent-only uses it 21 times; the named-`rg` arm raises it to 54 but does not lower the token cost (median 1.33M) | this record |
| The extraction suggestions lower the raw read, and the script arm lowers it most. | measurement | `intent-rg-command` median 0.97M (-19%); `intent-codemode` median 0.69M (-42%) with structural 1.0, the only arm with no failed assertion; it uses `grep` 56, `sed`/`awk` 110, a script 11 times, and the `read` tool 12 times against the control's 39 | this record; the S3 row |
| The raw saving costs the alignment that makes the report effective. | measurement | `intent-codemode` blind alignment 1/8 against the control's 2/8, so its effective cost is 5.65M against 4.97M per aligned report; `intent-rg-command` and `intent-rg` fall to 0/8 | this record; the S3 row |
| The tool-family and named-tool suggestions do not help. | measurement | `intent-tool` median 1.38M (+15%) with `cat` 84; `intent-rg` median 1.33M (+11%); equal structural at best | this record |
| One run in eight times out at 900 s on this route. | harness | four of the five arms had one `timeout`, at runs 5, 7, 7 and 2; the single-cell batches completed 7/8; `intent-rg` had none | this record; the eval's reliability note |
| The naming edit alone does not recover the alignment. | measurement | `naming-only` 1/8 aligned against the control's 2/8; token median 1.42M against 1.20M; structural 0.9 against 0.9643; two timeouts | this record; the S3 row |
| The script-plus-naming interaction is negative. | measurement | `script-naming` 0/8 aligned against the script's 1/8 and the control's 2/8; token median 0.92M against the script's 0.69M; structural 0.9643 against the script's 1.0; one timeout | this record; the S3 row |
| The naming instruction is followed without changing the recommendation. | measurement | the control names the milestone 8/8, the read-only 7/8, `naming-only` 6/8, `script-naming` 7/8; compliance is high, so the failure is not the instruction being ignored | this record |
| The read edit's raw saving does not translate to the effective measure. | measurement | the script arm's median 0.69M against the control's 1.20M, but 1/8 aligned against 2/8, so 5.65M against 4.97M per aligned report | this record; the S3 row |
| The route keeps timing out once or twice per eight runs at 900 s. | harness | `naming-only` two timeouts, `script-naming` one; the single-cell batches still completed 6-7 valid | this record; the eval's reliability note |
| The token A/A band is about 25 percent on the current model. | measurement | The identical `baseline` configuration produced per-run token medians of 987,057, 1,038,492 and 1,229,210 across three iceman batches, with 12 to 15 turns and correctness 0.96875 to 1.0. A single-batch median cannot resolve a 5 to 10 percent edit; the script arm's 42 percent cut is outside the band, and the targeted-read row's 5 percent rise is inside it. | the protocol row |
| The alignment granularity is one report. | measurement | At eight runs, 1/8 is 12.5 points. The current prompt aligned 2/8 on both blind passes, the `baseline` aligned 2/8 on three iceman batches, and the arm contrasts were 1/8 against 2/8 and 0/8 against 2/8. A one-report shift is the smallest effect the design can express, and it is also the size a re-grade could produce. | the protocol row |
| The grader agreed with itself on the one re-graded sample. | measurement | Two passes over the same eight control reports gave identical per-report verdicts, 2/8 aligned each time. Both passes used the same model and similar prompts; there is no independent second rater, so this is one sample, not a reliability estimate. | the protocol row; the deferred milestone's second rater |
| The mechanical assertions saturate. | measurement | `asks_direction` and `state_summary` are non-discriminating in all eleven batches that report them; `inventory_table` in six and `direction_form` in four. Correctness stayed between 0.875 and 1.0 and never decided a verdict. These assertions are a validity floor, not the outcome. | the protocol row |
| Attrition is about ten percent and clustered in timeouts. | harness | Nine invalid runs of 88 scheduled iceman runs across eight batches; the 900 s timeout accounts for eight of them, and one batch aborted on `exit-nonzero`. A cell that stops early still reports its valid n, so a per-run median over six or seven runs is not the intended eight. | the protocol row |
| The case's declared control is stale. | harness | `harness.decision.control` names `baseline`, the pre-repair prompt, while the current prompt is the `checkin-write-rule` overlay. The 2x2 correctly used the current prompt as its control, but the case's decision rule still points at a configuration the tree no longer runs. | the case-record row |
| The case's verdict rule ignores the band. | harness | `decision.min_effect` is 0 and `decision.runs` is the floor of 2, so any non-zero difference is eligible. The observed band makes that rule too permissive. | the case-record row |
| The run count spans 29 configurations over two cases, with arms added after the data was seen. | measurement | The 2x2 and the ladder were produced by reading earlier batches, so their counts are exploratory and were treated as confirmatory. No pre-registration exists. | the protocol row |
| The per-path read measure counts opens, not cost. | measurement | The attribution records `read` paths only, so bash reads leave no bytes and 14 of 16 runs show 0 roadmap bytes; the cost is the per-turn token total, and the files and bytes are diagnostics. | already recorded at `20261110-01` |

## Completed

| File | One-line change summary |
|---|---|
| File | One-line change summary |
| `tests/eval/cases/gm-focus-milestone.json` | Adds the `targeted-roadmap-read` configuration and the fixture notes. |
| `devlog/roadmap.md` | Records the S3 outcome and leaves the row open. |
| `devlog/roadmap_future.md` | Adds the command-level read-measurement gap to the deferred measurement milestone. |
| `devlog/handovers/M3.3.5/20261110-01-audit-targeted_roadmap_read.md` | This record. |
| File | One-line change summary |
| `tests/eval/cases/gm-focus-milestone.json` | Adds the five `intent-*` configurations. |
| `devlog/roadmap.md` | Records the ladder's outcome on the S3 row, left open. |
| `devlog/handovers/M3.3.5/20261110-04-audit-intent_delegation.md` | This record. |
| `$HOME/workspace/output/evals/gm-focus-milestone/` | The five arm batches and the blind grading sets. |
| File | One-line change summary |
| `tests/eval/cases/gm-focus-milestone.json` | Adds the `naming-only` and `script-naming` configurations. |
| `devlog/roadmap.md` | Closes the S3 row with the 2x2 outcome and the control as the effective leader. |
| `devlog/handovers/M3.3.5/20261110-05-audit-read_back.md` | This record. |
| `$HOME/workspace/output/evals/gm-focus-milestone/` | The two new cells and the four-cell blind set. |
| File | One-line change summary |
| `devlog/roadmap.md` | Files the four protocol rows under M3.3.5. |
| `devlog/handovers/M3.3.5/20261110-06-audit-eval_instrument.md` | This record. |
