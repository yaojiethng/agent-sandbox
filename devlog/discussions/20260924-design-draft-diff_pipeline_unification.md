# Diff Pipeline Unification

**Status:** draft -- first write, not yet reviewed. Awaits the operator's decision.

**Scope:** the export pipeline - the write path of `src/libs/diff.sh`, its caller `src/libs/package_branch.sh` (the per-commit writer `package_commits` and the `package_branch` dispatcher), and the stage boundaries of the orchestrator `src/libs/diff_export.sh`. Patch application (`_apply_patch_file`) and history mutation (`apply_and_commit`) are outside this note.

## Context

`diff.sh` converts sandbox repository state into patch artifacts. Three functions write those artifacts: `write_uncommitted_diff` and `write_all_changes_diff` for the two repository-wide diffs, and `package_branch`'s own loop for the per-commit patches under `patches/`. All four share one byte-level contract - drop index lines from text patches, keep them for binary patches, end the file with a newline - and only three of them are covered by its single implementation.

Two standing constraints shape the options.

The patch format is a decision, not an accident. [`sandbox_host_interface.md`](../../docs/concepts/sandbox_host_interface.md) states the interface carries plain patches: no `git am`, no `format-patch`, no git metadata headers, applied by hand on the host. A git transport format would carry authorship, commit messages, empty commits, and binary content natively, and would delete `strip_index_lines`, the apply retry ladder, and `apply_and_commit`'s empty-member branch with them. That option is excluded by the standing decision and this note does not re-open it. The note records the constraint so the next reader does not derive it again.

The sandbox index is contended. `wait_git_lockfile` in `diff_export.sh` polls `.git/index.lock` before an export because the agent runs in the same repository, and `capability/entrypoint.sh` calls it before the session export. The write path mutates exactly that index.

The pipeline has three stages. `diff_export` orchestrates and reports, `package_branch` sequences the packaging, and `diff.sh` writes the artifacts. They share two resources: the output directory and the repository index. The output directory is a third shared resource in the same sense: the orchestrator places a scratch capture file in it, the packager removes and recreates it, and the writers fill it. Neither resource has one owner. The findings split into two families that this note resolves together: the artifact contract is duplicated or absent (findings 63-66), and the stage boundaries leave shared state unowned (findings 68-70).

The evidence for this note is findings 57-71 of [`20260924-design-active-test_suite_readthrough.md`](20260924-design-active-test_suite_readthrough.md), extended by findings 82-85 from the `package_branch.sh` read-through. Each option below cites the mutation or probe that supports it.

The `package_branch.sh` pass adds three structural facts to the picture above. First, the dispatcher calls its four writers as bare statements with no status check, so any writer's failure degrades to an empty or partial artifact while `package_branch` returns the status of its last `echo` - the mechanism behind finding 68. Second, the dispatcher's `rm -rf` is the only cleaner of `changed-files/`: `write_changed_files` copies the current changed set and writes the manifest but never clears its target, so without that `rm` a file changed in an earlier run keeps a stale copy that the manifest no longer lists. The overwrite guarantee the module header documents rests on one line, and it is partial. Third, the guard that refuses an unreadable repository reads the index only: with a corrupt index it returns 128 and refuses, but with a truncated blob - an unreadable object store - the same check returns 0 while the per-commit `git diff` returns 128. The run proceeds and the bundle records SUCCESS.

## Options Considered

### Option area 1 - how untracked files enter the diff

Untracked files must appear in both repository-wide diffs. The current form brackets the write with `git add -N` and a restore, so the shared index carries the change for the duration of the write.

**Option A - keep the stage/restore bracket.** Two functions (`_diff_stage_untracked`, `_diff_restore_untracked`), one global array (`_DIFF_STAGED_UNTRACKED`), and a per-file `git add -N` loop. The restore is unpinned: dropping `--staged` leaves the suite green, and the mutation truncates the sandbox's untracked files to zero bytes, silently, at exit code 0, while the diff keeps the payload. The suite cannot see it because the units assert the diff bytes and then apply the patch to a fresh target repository; nothing reads the sandbox worktree after the call. The bracket also mutates the contended index, so a concurrent agent operation sees a different index while the export runs. Cost on 300 untracked files: 407 ms.

**Option B - a scratch index.** Point `GIT_INDEX_FILE` at a file under a temporary directory, run `git add -A` against it, and diff the scratch index against the baseline with `git diff --cached`. The shared index is never opened. One command replaces the enumeration, the per-file loop, and the restore. `add -A` honours `.gitignore` natively, which also retires the `--exclude-standard` listing. Evidence from a fixture carrying a deletion, a modification, an untracked file, a CRLF file, trailing-whitespace content, and a gitignored file:

| Check | Result |
|---|---|
| Patch bytes against the current implementation | identical, 415 bytes both forms |
| Ignored file excluded | yes, without the `--exclude-standard` listing |
| Untracked payload present | yes |
| Deleted file present as a deletion | yes |
| Real index after the call | unchanged, no staged entry |
| `.git/index.lock` created | no |
| Cost on 300 untracked files | 64 ms against 407 ms |

Trade-offs. The scratch index costs one index write per export, against one index write per untracked file today, so the cost falls as the untracked count rises. `add -A` applies clean filters, so a repository carrying `.gitattributes` text conversion could produce different bytes than a worktree read; this repository has no `.gitattributes`, and a target project repository could have one. The function loses the ability to leave a partially staged index behind, which no caller wants.

### Option area 2 - how many implementations of the verbatim-diff contract

**Option A - two implementations.** `_write_git_diff` implements the contract for the two repository-wide diffs, and `package_branch.sh` reimplements it inline for the per-commit patches: the same `strip_index_lines` call, a different trailing-newline mechanism (`awk '{print} END{print ""}'` against `sed -e '$a\'`), and no empty fast path. The two mechanisms also disagree on empty input, where `awk` prints a newline and `sed` prints nothing, so an empty commit's patch is a one-byte file while the writers' empty case is a zero-byte file. `diff_is_empty` accepts both, so the divergence is invisible today and becomes a defect the moment a consumer reads the artifacts by size.

**Option B - one parameterised writer.** `_write_git_diff` gains an options parameter and every producer calls it. The contract has one implementation, the trailing-newline rule has one form, and the empty case has one shape. The capability difference then becomes an explicit argument at the call site rather than an accident of which function wrote the file.

### Option area 3 - the binary capability of the artifact writers

`--binary` appears only in `package_branch`'s `GIT_DIFF_OPTS`. The two repository-wide diffs do not pass it, so a binary change is carried by `patches/` and silently omitted from `all-changes.diff`, which the interface document describes as the net delta since the baseline.

**Option A - keep `--binary` out of the artifact writers.** The artifacts stay small and text-only. An operator who applies `all-changes.diff` receives every textual change and no binary change, with no signal that something was dropped. The behaviour is frozen by a unit that builds its own diffs with `git diff` and asserts the default one cannot apply, so it is recorded as expected rather than decided.

**Option B - `--binary` on all writers.** The artifact set becomes capability-uniform: anything `patches/` can carry, `all-changes.diff` can carry. The binary arm of `strip_index_lines` then serves every writer, and that arm is already pinned by 13 units. Cost: larger artifacts when a binary file changes, and the existing unit needs rewording because its subject is the default `git diff`, not a writer.

### Option area 4 - the scope of the change

**Option A - the write path only.** Smallest reviewable change, and it leaves the module's dependencies untouched.

**Option B - the write path plus the two dead dependencies.** `diff.sh` sources `routing.sh` and references nothing from it. It sources `session_state.sh` for one call: `write_all_changes_diff`'s `init_sha` default when the third argument is omitted, which no production caller uses, because `package_branch.sh` resolves the baseline once and passes it to all four writers. Both dependencies are removed by edits to the same functions the write path change already touches, so the two changes cost little more than one. The module becomes a patch library over git and coreutils alone.

### Option area 5 - the stage boundaries of the pipeline

The orchestrator creates its stderr capture inside `OUTPUT_DIR` before calling the packager, and the packager then removes and recreates `OUTPUT_DIR`, so the capture is unlinked while its descriptor stays open and the failure-path dump comes back empty (finding 69, probed). The packager's step failures do not reach the orchestrator, because the call site tests its status with the `||` idiom, which suspends `set -e` for the whole function body; a truncated blob made a per-commit `git diff` fail with the artifact landing as 1 byte, `STATUS=SUCCESS` recorded, and no error log written (finding 68, probed). And the orchestrator's header lists the lockfile wait among its own reliability features while the wait is a caller obligation that one caller omits (finding 70).

**Option A - keep the ownership and fix each symptom.** The capture moves to the system temporary directory, close to the other scratch files the harness already creates. Each packaging step gains an explicit status check, which matches the module's existing style: its preflight already returns 1 explicitly. The header states the caller obligation for the lockfile wait. This is the smallest change, and the packager keeps the overwrite guarantee that its header documents and that `test_dispatcher_overwrites_output` pins.

**Option B - one owner per resource.** The caller creates and cleans `OUTPUT_DIR`, and the packager only writes files into it. This takes the destructive `rm -rf` out of a library function, but the overwrite guarantee moves to every caller: the autosave path wipes its staging directory anyway, while a direct `package_branch` invocation would leave the previous run's artifacts beside the new ones, which the overwrite unit exists to prevent. The gain over Option A is cleanliness of ownership, not a removed failure mode.

For the failure signal there is a second choice, independent of the directory: explicit per-step guards, or a status record the caller reads. Guards match the existing style and give a deterministic check. A call form that does not suppress `set -e` gives a backstop for a step nobody guards: `package_branch ...; rc=$?` instead of `package_branch ... || { ... }`. The two are complements, and the call-form change costs one line.

Two further stage-boundary items come from the `package_branch.sh` pass. The state guard at the dispatcher's entry reads the index only, so its comment promises more than its check delivers (finding 84, probed): the choice is between extending the guard and narrowing the claim.

**Option A - extend the guard.** Read the objects it is about to diff, in one `git cat-file --batch-check` pass over `rev-list --objects`, and refuse a repository whose objects are unreadable. This closes the class the comment names, at the cost of one extra git invocation per export on a healthy repository.

**Option B - narrow the claim.** Keep the check on the index, which is the failure that was demonstrated first, and state in the comment that object readability is the writers' own responsibility. This is free, and it leaves finding 68's failure mode (a partial artifact stamped SUCCESS) reachable through a different door.

For the overwrite guarantee the options are already stated above, and the `package_branch.sh` pass adds the reason Option A's guarantee is weaker than it looks: `write_changed_files` does not clear its target, so the guarantee for `changed-files/` depends entirely on the dispatcher's `rm -rf` (finding 83, bite-verified). Either the writer clears its own target, or the header states that the removal is the cleaner for every writer's directory.

**The lock surface, measured - the reason the wait is retired rather than tuned.** The lockfile wait guards a writer, not a reader. With `.git/index.lock` held, every read the pipeline uses returns 0 with the correct verdict (`status --porcelain`, `diff --stat`, `ls-files -m`, `ls-files --others --exclude-standard`, `rev-parse`, `rev-list`, `for-each-ref`, `merge-base`, `cat-file`, `log`, `show-ref`), while every writer fails with rc 128: `add -A`, `commit`, `checkout -b`, and `apply --index` each stop with "a git process may have crashed in this repository earlier: remove the file manually to continue". The only writer the pipeline owns is `diff.sh`'s `git add -N` staging loop, and the scratch index performs that same staging with rc 0 while the lock is held, leaving `.git/index.lock` untouched, with a byte-identical artifact (252 bytes both ways in this probe; 415 bytes in the wider fixture of finding 63). Two read-side measurements complete the picture: `git status --porcelain` writes the index when its stat cache is stale (the index mtime moves after a touch), and `GIT_OPTIONAL_LOCKS=0` leaves the index untouched with the verdict unchanged. The harness therefore has three lock classes rather than one: a false lock created by our own refresh during a read, a genuine lock held by a deliberate write, and a stale lock left by a killed writer. Only the third needs recovery, and recovery is an acknowledged refusal rather than the automatic pre-work delete in `draft_clear_stale_lock`. With the scratch index and optional-lock suppression, no harness process creates the file while reading or exporting, which is the condition that lets the wait, the probe, and the delete be removed rather than tuned. The boundary that makes this a rule rather than a local habit is drawn in [`20260925-design-draft-git_boundary.md`](20260925-design-draft-git_boundary.md).

### Option area 6 - the per-commit artifact set and its names

The per-commit writer emits two artifacts per commit: the `.diff` under `patches/` and a sibling `.msg` holding the full commit message. The `.msg` files are contract, not diagnostics: `src/reasoning/agent/prompts/package-branch.md` states that `make draft` consumes them to recreate commits with their original messages. No unit asserts that any `.msg` file exists, and dropping the write leaves all 37 units in the three package-branch suites green (finding 82, bite-verified). The file-name subject is sanitised through `sed 's/[^a-zA-Z0-9._-]/_/g'` and truncated to 60 characters; dropping the filter also leaves the suites green (finding 85), so a subject carrying a space or a slash never reaches a filename in a test.

**Option A - test only.** Add a unit asserting one `.msg` per patch and its message body, and one asserting a filename produced from a subject with a space and a slash. Smallest change, and it closes the gap without touching the writer.

**Option B - one naming rule.** Extract the `index + sha + subject` to filename mapping into one function, so the sanitisation and the length cap have one home and any consumer derives the same name. Cost: the writer and its unit both change, and the rule moves without a second consumer to justify it today.

**Option C - move the writer.** Relocate `package_commits` into `diff.sh` beside `_write_git_diff`, which is the logical conclusion of option areas 1 and 2: all patch writing then sits in the patch library, and `package_branch` becomes sequencing. Cost: a 70-line function and its call site move, and the module boundary question of finding 67 comes forward.

For the lockfile wait the choice is to keep it as a documented caller obligation, or to retire it once the writers stop touching the shared index. `_diff_stage_untracked` is the pipeline's only index writer; every other operation reads. Git writes the index atomically through `index.lock` and a rename, so a reader never observes a partial index, and what the wait really protects against is writer-against-writer contention - which the scratch index of option area 1 removes, because the scratch index is private to the export. A concurrent agent commit still moves `HEAD` during an export. The wait never addressed that, and it is the one race the pipeline accepts: the bundle is a snapshot, and `.export-status` records the `HEAD` read after packaging.

## Decision

Recommended, not yet taken.

1. **Option area 1: scratch index.** It removes a destructive failure mode, removes the shared-index mutation, retires two functions and a global, and is faster on any session with more than a few untracked files. The `.gitattributes` caveat is the one open point, and it needs a decision on whether to state it in the module header or guard against it.
2. **Option area 2: one parameterised writer.** Two implementations of one contract diverge, and the divergence already exists in the empty-input case.
3. **Option area 3: `--binary` on all writers.** A silent omission in the artifact the operator is told to apply as the complete delta is the worse failure, and the cost is disk space.
4. **Option area 4: include the dependency removal in the same pass.** The edits overlap, and the module gains a property worth having: no repository-library dependency at all.
5. **Option area 5, directory ownership: Option A.** Keep the overwrite in `package_branch`, and move the orchestrator's capture to the system temporary directory. The packager's overwrite is load-bearing for a rerun into the same directory, and the defect is the caller placing state in a directory it does not own.
6. **Option area 5, failure signal: guards plus a non-suppressing call form.** Per-step checks give a deterministic verdict; the `package_branch ...; rc=$?` form removes the trap that suppresses `set -e` for every step at once.
7. **Option area 5, lockfile wait: retire it with option area 1, and document the obligation until then.** The wait exists because the pipeline writes the shared index. Remove that write and the remaining contention is gone, while the `HEAD` race it never covered stays an accepted snapshot boundary.
8. **Option area 5, state guard: Option A.** The guard exists to stop a bundle that claims SUCCESS over degraded artifacts, and the object store is one of the two ways that happens. A check that covers the index only leaves the guard's own comment false and the failure reachable. The extra invocation is paid once per export and only on the exporting path.
9. **Option area 5, overwrite guarantee: make the writer clean its target, or state the removal as the cleaner.** Whichever is chosen, the header stops implying that every writer overwrites.
10. **Option area 6: Option A now, with Option B or C when the writer moves.** The `.msg` artifact is contract, so it needs a unit regardless of where the writer lives. The naming rule (Option B) and the relocation (Option C) both depend on the option areas 1 and 2 decision, which already rewrites the same loop, so they ride that pass rather than a separate one.

The module boundary moves stay out of scope. `write_changed_files` decides bundle content and belongs with `package_branch`, its only caller; `apply_and_commit` encodes the empty-member commit rule and belongs with the apply drivers. Each is recorded as its own finding.

## Consequences

Deletions, if the recommendation is taken: `_diff_stage_untracked`, `_diff_restore_untracked`, `_DIFF_STAGED_UNTRACKED`, the per-file add loop, the `routing.sh` source, the `init_sha` default, and its `init_sha not found` branch. The last two also delete a duplicate of the baseline check that `package_branch` already performs with a better diagnostic.

Changes: `_write_git_diff` takes an options parameter and writes through a scratch index; `package_branch`'s per-commit loop calls it instead of its inline pipeline; the three writers pass `--binary`; `package_branch` gains a status check per packaging step; the dispatcher's state guard covers the object store; the dispatcher's `rm -rf` and `write_changed_files` reach one owner for `changed-files/`; `diff_export`'s capture file moves out of `OUTPUT_DIR` and its call to `package_branch` stops using the `||` form; the orchestrator's header states the lockfile obligation, and if the wait retires, the entrypoint's `wait_git_lockfile ... || true` line goes with it, which also stops swallowing the timeout verdict.

Tests to update: the two units that exercise the two-argument `write_all_changes_diff` form and the `init_sha` default; the lockfile units, if the wait retires; and `test_dispatcher_overwrites_output` keeps its subject, because Option A keeps the overwrite with the packager, though it gains a second subject: a rerun with a smaller changed set, which is the case that shows the stale `changed-files/` copy today. Tests to add: the real index is untouched after a write; the artifact writers carry a binary change; an empty commit's patch has the same shape as an empty repository-wide diff; a mid-package `git` failure produces a FAIL status, a non-empty stderr in the error log, and a non-zero return; a post-wipe failure keeps its diagnostic; no capture file survives inside a bundle; one `.msg` per patch holds the full message; a subject with a space and a slash produces a loadable filename; and a repository with a truncated blob is refused rather than packaged. The existing binary unit keeps its meaning because it builds its diffs directly.

Residual risks. A target repository with `.gitattributes` text conversion may produce different bytes through `git add -A` than through a worktree read. The scratch index is written under the system temporary directory, so it needs the same cleanup guarantee the staging path already has, and it must not be created on a filesystem the container cannot write.

Follow-ups this note does not cover, and where they now live. The manifest contract (finding 59, a docstring correction and one unit) and the unpinned `--ignore-whitespace` policy (finding 58) stay in the read-through's findings table. The remaining minor unpinned items in `package_branch.sh` - the explicit-baseline validation, the preflight's call site, and the inner `rm -rf` in `package_commits` - are recorded as finding 85 and need no design decision. The module boundary moves (finding 67) remain deferred, with Option C of area 6 as the case that would force them.

Record. The principles that settle here - one writer per artifact contract, the artifact set carries every change class, and each pipeline stage owns its own scratch state while the caller owns the package directory - govern more than the change that introduces them, so they belong in an ADR when the operator decides. `docs/adr/diff_packaging.md` is the home: it already records the export baseline, the save decision, and the single-export-mechanism principle.

Implementation needs its own handover. This note is a design record only.
