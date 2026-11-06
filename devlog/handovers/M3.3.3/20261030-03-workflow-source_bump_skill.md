---
date: 2026-10-30
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - The source-bump skill and its merge workspace

## Objective

Land the source bump as a standalone project skill and give it the CLI workspace commands it calls, so a maintainer can re-base one forked artifact on a reviewed upstream revision without transcribing the tracking file.

## Scope

Continues the parent row **The source bump is a skill, and `pi-bump` keeps its name** in M3.3.3, from handover `20261030-02` for the live store and `20261030-01` for the tracking CLI.

In scope: the skill at `.agents/skills/source-bump/SKILL.md`; the `source-bump diff` and `source-bump prepare` commands, tests and reference entry; the design record and roadmap correction from pattern to skill; and the handover.

Out of scope: `skill-scaffolder` as the host, a separate runbook sibling, a rename of `pi-bump`, a source cache, and the full source graph.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The source-bump skill exists and pi's loader discovers it without a finding. | `test -f .agents/skills/source-bump/SKILL.md`; `node tests/skill_layer_loader.mjs .`; `node scripts/skill_map.mjs` | Agent [x] |
| The skill's procedure names `check`, `diff`, `prepare`, `record` and the three-way `git merge-file` step. | `rg -n 'source-bump check' .agents/skills/source-bump/SKILL.md`; `rg -n 'source-bump diff' .agents/skills/source-bump/SKILL.md`; `rg -n 'source-bump prepare' .agents/skills/source-bump/SKILL.md`; `rg -n 'source-bump record' .agents/skills/source-bump/SKILL.md`; `rg -n 'git merge-file' .agents/skills/source-bump/SKILL.md` | Agent [x] |
| `source-bump diff` prints the `base -> local` change from a local clone and leaves the store byte-identical. | `bash tests/test_source_bump.sh` | Agent [x] |
| `source-bump prepare` creates `base`, `ours` and `theirs` from a local clone and leaves the store byte-identical. | `bash tests/test_source_bump.sh` | Agent [x] |
| The design record, reference and roadmap name the skill and no longer name `skill-scaffolder/patterns/source-bump.md`. | `rg -n 'source-bump' devlog/discussions/20261029-design-draft-skill_source_update.md docs/development/source_tracking.md devlog/roadmap.md`; `rg -n 'source bump' devlog/discussions/20261029-design-draft-skill_source_update.md docs/development/source_tracking.md devlog/roadmap.md`; negative check for the pattern path. | Agent [x] |
| The parent roadmap row is `[x]` and names handover `20261030-03`. | `rg -n 'The source bump is a skill' -A3 devlog/roadmap.md` | Agent [x] |
| `source-bump check` is clean across the live store after the commands land. | `node scripts/source_bump.mjs check` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The source bump is a standalone project skill at `.agents/skills/source-bump/SKILL.md`, not a `skill-scaffolder` pattern. The procedure is inline in the skill. | The operator approved the standalone path; a bump is an operator-directed action with its own trigger, and `pi-bump` is the precedent. The scaffolder's body is skill creation, not maintenance. | Design record; roadmap |
| `diff` and `prepare` implement the merge workspace the design record already planned. `prepare` takes a local upstream clone and never fetches. | The skill's procedure needs the commands; a local clone keeps the CLI deterministic and leaves the source-cache question open. | Design record; reference |
| `diff` prints a difference and exits 0. A difference is output, not a finding. | The exit code vocabulary reserves 1 for findings and refused writes; a diff is the command's result. | Reference |
| The CLI remains the only writer of the tracking file; the skill writes the local artifact and the design doc. | The store is deterministic state, and the merge is discretionary judgement. | Design record |
| The source facts stay immutable during a bump. A changed URL, license or copyright is a separate operator decision. | The CLI refuses a changed source fact; the skill stops rather than editing the store. | Design record; reference |
| The `prepare` workspace is temporary and uncommitted. The local artifact remains the only editable copy. | The workspace is a review and merge input; a committed copy would be a second source of truth. | Reference |
| The clone argument is `--clone`; `--upstream` stays the upstream artifact path in `add`. | A CLI flag with two meanings is a copying hazard; one name carries one value. | Reference; skill |
| The skill is project-only and does not ship. | It operates on `.agents/registry/sources`, which is repository-only; the image carries the artifacts and the `NOTICE`, not the maintenance procedure. | Reference |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The design record and roadmap still call the source bump a pattern at `skill-scaffolder/patterns/source-bump.md`; the operator approved the standalone skill. | Contradiction | Corrected in this unit. | This handover, Completed |
| `docs/development/source_tracking.md` says `diff` and `prepare` are not commands, so the procedure the skill needs has no mechanism. | Gap | The two commands land in this unit. | This handover, Completed |
| The design record's table says the CLI prepares the merge inputs, but the CLI has no `prepare`; the skill cannot be followed against the tree. | Gap | Implemented in this unit. | This handover, Completed |
| The skill map has no `source-bump` entry because the skill does not exist yet. | Carrier | The new `SKILL.md` is discovered by the existing map; no map code change is expected. | This handover, Completed |
| The source cache remains an open design question; the commands take a local clone supplied by the operator. | Open question | Recorded in the design record; no cache is introduced. | Design record, open question |
| The thermo-nuclear review found `--upstream` carried two meanings: the upstream artifact path in `add` and the clone directory in `diff` and `prepare`. | Contract | The new commands use `--clone`; `add` keeps `--upstream` for the artifact path. | This handover, fixed |
| `prepareWorkspace` carried a one-off mode flag and received a revision its diff path ignored. | Structure | Split into `buildBaseAndOurs` and `buildTheirs`; the revision always means the new revision. | This handover, fixed |
| `commandDiff`'s `finally` did not run when `error()` called `process.exit`, so a failed diff leaked its workspace. | Defect | The diff path records the failure, cleans in `finally`, then exits. | This handover, fixed |
| The design record said a git URL is cloned first, but the CLI rejects anything that is not a local directory. | Contradiction | The operator clones a URL first; the CLI takes the local clone. | This handover, fixed |
| The skill's step 2 assumed a `MAINTENANCE.md` for a prompt artifact, which has no record. | Gap | Step 2 names the record only for a skill or runbook; a prompt uses the design record. | This handover, fixed |
| The skill re-ran the commit and path checks that `prepare` already owns. | Redundancy | Removed the separate check; step 4 says `prepare` verifies both. | This handover, fixed |
| `prepare` leaves its workspace in `tmpdir`, so repeated bumps accumulate directories. | Risk | The skill says to remove the workspace after the merge; the CLI keeps it for the agent to use. | This handover, fixed |
| Thermo-nuclear review verdict: `ACCEPT`, no blockers. | Review | All non-blocking findings are fixed; the source cache and the external `tar` dependency remain residual risks. | This handover, fixed |
| Round 2 review: the skill's prompt merge destination used `<local>/<path>`, but a prompt's local path is the file, so the command targeted `<local>/<path>` as a directory. | Blocker | Fixed step 5: a prompt writes to `<local>`; a skill or runbook writes to `<local>/<path>`. The local-deletion presence case is stated. | This handover, fixed |
| Round 2 review: path verification checked existence, not whether a prompt was a blob and a skill or runbook a tree. | Contract | `verifyUpstreamPath` checks `git cat-file -t`; a misshapen edge has a test. | This handover, fixed |
| Round 2 review: `diff` and `prepare` duplicated the base safety preamble; `materialize` and `copyLocal` repeated the kind branch; the diff inherited user git config; the prepare tests leaked their workspaces. | Structure | Extracted `resolveBase`, added `isFileArtifact`, pinned `--no-ext-diff` and prefixes, and the tests remove their workspaces. | This handover, fixed |
| Round 2 review: no test covered an absent upstream path, and `git archive` honors `export-ignore`/`export-subst` while `tar` is an external dependency. | Risk | Added the absent-path test; the archive/attribute and `tar` risks are recorded in the design record. | This handover, fixed; design record, residual risk |
| Round 2 review verdict: `BLOCK`, one blocker and five non-blocking findings. | Review | All findings are fixed; a third review confirms the current head. | This handover, fixed |
| Round 3 review: the merge procedure had no rule for a both-added file or a base-only path. | Gap | Added both cases to step 5: both-added is decided by intent and cannot use `git merge-file`; a base-only path is already absent. | This handover, fixed |
| Round 3 review: `source_tracking.md` still said the patch was generated from `origin` and `base`. | Contradiction | Changed it to the `base -> local` diff. | This handover, fixed |
| Round 3 review: a prompt has no `MAINTENANCE.md`, so the skill's intent and resolve steps were unsatisfiable for it. | Gap | Steps 2 and 6 now ask the operator for a prompt's intent. | This handover, fixed |
| Round 3 review: a failure in `buildBaseAndOurs`, `buildTheirs` or `copyLocal` could leak the temp workspace. | Defect | The builders clean on failure, `prepare` cleans the workspace, and the top-level handler reports the thrown error. | This handover, fixed |
| Round 3 review verdict: `ACCEPT`, with four non-blocking findings. | Review | All four are fixed; a fourth review confirms the current head. | This handover, fixed |
| Round 4 review: the module runs two error primitives, so cleanup is re-implemented in four places; an unexpected error loses its stack; the builder-failure path has no test; the skill names workspace removal without the command. | Quality | Accepted at the review's approval bar; left as residual, not fixed. | This handover, residual |
| Round 4 review verdict: `ACCEPT`. | Review | Convergence reached; no blockers. | This handover, closed |

## Completed

| File | Change |
|---|---|
| `.agents/skills/source-bump/SKILL.md` | Added the standalone source-bump skill and its merge procedure. |
| `scripts/source_bump.mjs` | Added `diff` and `prepare`; factored the edge lookup; split the workspace builders; renamed the clone flag; made the builders clean up on failure. |
| `tests/test_source_bump.sh` | Added seven tests for the diff, prepare, prompt, misshapen-edge, absent-path and help paths; updated the clone flag. |
| `docs/development/source_tracking.md` | Documented the two commands, the clone flag and the skill link. |
| `devlog/discussions/20261029-design-draft-skill_source_update.md` | Named the skill and the implemented commands; removed the pattern plan and corrected the clone clause. |
| `devlog/roadmap.md` | Marked the source-bump row complete as a skill. |
| `devlog/handovers/20261030-03-workflow-source_bump_skill.md` | Closed this handover. |
