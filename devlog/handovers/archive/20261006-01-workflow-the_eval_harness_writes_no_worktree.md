---
date: 2026-10-06
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - The Eval Harness Writes No Worktree

## Objective

Move the eval harness's per-run worktrees into a temp directory, and write back only a packaged bundle of each run's change.

## Scope

Continues the T1 row `Skill and prompt eval infrastructure`, from handover `20261005-10` (the skill) and `20261005-13` (the hillclimb playbook).

Two operator directives, both about what a graded run leaves on disk.

1. **The worktrees go to a temp directory.** A run clones the base bundle once per run, and that clone is the whole footprint: 20 MB against 172 KB of measures, logs and transcripts. The hillclimb's output directory holds 1.3 GB, and three earlier eval runs hold 96 MB.
2. **Only a bundle of the change is written back.** The graded artefact is the run's delivery commit, so the change travels as a bundle of the delta from the fixture's base commit. The worktree that produced it is scratch and does not outlive the run.
3. **The eval output already on disk is cleaned up too**, at the operator's direction. Each old run's change is packaged as a bundle from its worktree, the bundle is verified against its base, and only then does the worktree go. Nothing is deleted that the bundle or a patch does not carry.

In scope: the work root, the cleanup and the write-back in `run_case.sh`; the fixture and artefact paths in `SKILL.md`; the harness requirements in the hillclimb playbook; the harness case set; the existing eval output; the roadmap write-back.

Out of scope, each with its reason: `measure_commit.sh` takes one project path and is unaffected by where that path is; `src/libs/package_eval_snapshot.sh` packages a session transcript rather than a run's worktree; the per-configuration pi config copies stay where they are, at the operator's direction.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No run leaves a worktree under the output directory | a graded run's `--out` tree holds no `project/` directory | Agent [x] |
| Each run's change is written back as a bundle | a clone of the base bundle, then `git fetch run.bundle HEAD`, yields the run's commit | Agent [x] |
| A run that never committed still yields its change | a dirty run's `run.patch` applies to the fixture | Agent [x] |
| The temp root does not outlive the run | the path printed under `EVAL_KEEP_WORK=1` is absent after the default run that follows it | Agent [x] |
| The skill and the playbook state the new shape | `SKILL.md` step 2, its step 3, its step 6, and the playbook's harness requirements name the work root and the bundle | Agent [x] |
| The harness case set covers the new behaviour | `bash tests/test_eval_harness.sh`, 7 existing cases plus 5 new ones, 12 passed | Agent [x] |
| Every old eval run's change survives the cleanup | 54 bundles written and verified against their bases before removal; 0 worktrees left under `output/evals/` | Agent [x] |
| The cleanup frees the footprint without losing an artefact | `output/evals/` falls from 1.42 GB to 47 MB | Agent [x] |
| Lint and the suite are clean | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] -- 8 gates clean, 1113 tests across 76 files, liveness clean |
| The handover closes | this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/skills/eval/scripts/run_case.sh` | the work root, the cleanup, and the write-back |
| `workflow/coding-agent/skills/eval/SKILL.md` | step 2's fixture path and step 6's artefact rule |
| `workflow/coding-agent/skills/eval/playbooks/hillclimb.md` | the harness requirements paragraph |
| `tests/test_eval_harness.sh` | the stub-agent case, plus a case per new behaviour |
| `devlog/roadmap.md` | the T1 eval-infrastructure row's write-back |
| `devlog/handovers/archive/20261006-01-workflow-the_eval_harness_writes_no_worktree.md` | this handover |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The worktree moves to a temp root; the measures, logs and bundles stay at `--out` | per run the clone is 20 MB against 172 KB of artefacts, so the worktree is 99% of the footprint | this handover |
| The write-back is the delta from the fixture's base commit to the run's HEAD | the operator reviews the change rather than the tree, and the base commit already arrives as the input bundle | this handover |
| A run that left the tree dirty also writes a patch | the graded artefact is the commit, but a failed run often makes none, and the patch is the only evidence left once its worktree is gone | this handover |
| The temp root is removed at exit, and kept under `EVAL_KEEP_WORK=1` | a worktree under inspection is worth keeping when the operator asks for it, and a stray one is not worth keeping by default | this handover |
| The session transcript and the per-configuration config copy stay under the output slug | the operator's directive named worktrees; a transcript is the evidence a blind grader reads, and a config is an artefact of the run | this handover |
| The historical worktrees are bundled before they are deleted | the bundle is the only record of what those runs delivered once the worktree is gone, so the order is package, verify, remove | this handover |
| The historical bundles are thin deltas, not self-contained archives | a self-contained bundle would re-carry the 20 MB base once per run, which is the footprint this iteration removes | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The eval skill's documented fixture path (`$HOME/workspace/output/evals/<slug>/iteration-N/<case>/<configuration>/project`) and `run_case.sh`'s output layout (`<out>/case-<label>/run-<i>`) disagree, and the hillclimb produced a third shape again (`<out>/runs/case-<label>/run-<i>`). The doc and the script are corrected together here. | contradiction | current iteration |
| Three earlier eval runs hold 96 MB of worktrees and the hillclimb holds 1.3 GB, against 172 KB of artefacts per run. | evidence, measured | current iteration |
| `git bundle create <file> <rev> -q` fails with `unrecognized argument: -q`, because `bundle create` does not take options after its positional arguments, and the write-back's `[[ ]] && cmd` form swallowed the failure so no bundle appeared. The new case caught it. The call now puts the option first and fails loudly. | defect, caught by the test | current iteration |
| `dirbytes+=<bytes>` without `declare -i` concatenates strings, so a byte total became one 0-prefixed integer, an arithmetic expansion then failed as an invalid octal, and the cleanup script stopped after the first output directory while printing a plausible summary for it. The remaining directories were processed on the re-run. | defect, silent | current iteration |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/eval/scripts/run_case.sh` | the work root (`--work=`, `EVAL_KEEP_WORK=1`, a `mktemp -d` default and an exit trap), the recorded base commit, and the per-run write-back: a bundle of `base..HEAD` and a patch of any remainder; `--measure-only` now needs the work root |
| `workflow/coding-agent/skills/eval/SKILL.md` | steps 2, 3 and 6 and the invariants: the fixture lives in a work root, the config copy and the measures stay under the output slug, and the change comes back as a bundle |
| `workflow/coding-agent/skills/eval/playbooks/hillclimb.md` | the harness requirements name the work root and the bundle |
| `tests/test_eval_harness.sh` | the stub workspace and runner extracted; 5 new cases: no worktree under `--out`, the kept work root, the change bundle, the dirty run's patch, and `--measure-only` without a work root; 12 passed |
| `output/evals/` (outside the tree) | 72 worktrees packaged and removed: 54 bundles, 68 MB from the skill-eval runs and 1,080 MB from the hillclimb; the directory falls from 1.42 GB to 47 MB |
| `devlog/roadmap.md` | the T1 eval-infrastructure row's write-back |
