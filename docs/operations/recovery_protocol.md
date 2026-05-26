# Recovery Protocol

Ad-hoc workflow for recovering committed artifacts that violate policy or convention. Not a policy — use when needed, not on every session.

Covers two scenarios: recovering lost work after a container/filesystem reset (see **Recovery process**), and verifying that committed artifacts are correctly shaped after a recovery operation (see **Recovery verification audit**). The entry conditions for each section tell you which path to take.

## Recovery process

### Entry conditions

- Container or filesystem state was reset, losing committed work from one or more prior sessions.
- The lost work is known to exist from a session log (JSONL file) or from chat history.
- A handover documenting the lost sessions exists (either on disk or in session history).

### Procedure

**1. Assess what was lost**

Check the working tree and git history against the expected state:

```bash
git log --oneline <baseline>..HEAD
git status --short
ls devlog/handovers/
```

Identify which sessions' outputs are missing. The handovers tell you what was done; the git log tells you what survived. Any gap is a recovery target.

**2. Choose reconstruction method**

Two approaches, depending on available data:

- **Chat history replay** — if the session chat history is available and the changes are well-documented, replay the edits session by session. This is labor-intensive but reliable: each edit was already reviewed and confirmed during the original session.
- **JSONL session log replay** — if a session JSONL file survived the reset (written to an external mount), it may contain tool calls and outputs that can be parsed to reconstruct the work. This is faster but the JSONL schema is not standardised — what you get depends on the interface that wrote it.

**3. Replay in order**

If replaying from chat history:

- Reconstruct one session at a time, in chronological order.
- Run the full test suite after each session before committing.
- If a session had no code output (e.g. a planning session that only produced a handover), skip it — the handover can be recreated from the chat.
- If tests fail during replay, the issue may be a latent dependency the inlining work exposed (e.g. a build context function now copies a file that the test fixture doesn't create). Fix the fixture, not the production code.

```bash
# Per session:
# 1. Apply all edits for the session
# 2. Run tests
bash scripts/run_tests.sh
# 3. Commit
git add -A
git commit -m "<message>"
```

**4. Create handovers**

For each replayed session, create a handover file at `devlog/handovers/`:

- Date the handover to the current day (the replay date), not the original session date.
- Number it sequentially from the existing handovers in the repo.
- Set `Status: Closed` since the work was already completed.

**5. Verify completeness**

After all sessions are replayed:

```bash
# Run the full suite
bash scripts/run_tests.sh

# Check total test count matches expected (may increase if new tests were added)

# Verify all handovers exist with correct dating
ls devlog/handovers/
```

**6. Renumber and date-check**

If handovers were created with the wrong date despite Step 4's instruction (e.g. the original session date was used instead of today), this corrective step fixes them. Do not follow this step if Step 4 was done correctly — skip straight to Step 7.

```bash
# Rename files — replace placeholders with actual old/new date prefixes
mv devlog/handovers/20260511-*.md devlog/handovers/20260512-*.md

# Update date inside each file
for f in devlog/handovers/20260512-*.md; do
  sed -i 's/\*\*Session date:\*\* 2026-05-11/\*\*Session date:\*\* 2026-05-12/g' "$f"
done
```

After renaming, a rebase is needed to squash these rename commits into their originating commits — the verification audit section handles that step.

**7. Package for review**

Use `package-branch` with the correct output path:

```bash
bash libs/package_branch.sh --to=$HOME/workspace/output --session-summary=<snake_case_summary>
```

Read `agent/prompts/package-branch.md` for the correct invocation — do not guess the output path.

### Key learnings

- **Read prompt templates before acting.** Writing `package-branch` output to `/tmp/` instead of `$HOME/workspace/output/` was a pure guess — the prompt template specifies the path explicitly.
- **Handovers need immediate dating to today.** It is tempting to use the original session date, but that creates inconsistency when the recovery spans a different day. Date handovers to the replay date and close them immediately.
- **Rebase after replay, not during.** Replaying creates sequential commits that may include fixup commits for renumbering. The verification audit section (below) describes the rebase procedure as part of verifying and correcting the commit history — run it as a separate workflow session after replay is complete.
- **Test counts may shift.** Adding tests that verify old patterns are gone (e.g. "old flag no longer present") increases the total test count. Document expected counts in the handover.
- **Latent fixture bugs surface during inlining replay.** When production code is restructured (e.g. build_container.sh inlined into containers.sh), the restructured code may copy files the old test fixture never needed to provide. Fixture updates are legitimate replay work.

## Recovery verification audit

Procedure for verifying that a recovery operation produced a clean result.

### Entry conditions

- A previous agent session produced commits with known inconsistencies (wrong naming, working documents in git history, missing artifacts, fixup commits)
- An interactive rebase or other history-rewriting operation has been performed to fix them
- The recovery is complete and needs verification

### Procedure

**1. Check for banned artifacts in git history**

```bash
git log --all --diff-filter=A -- RECOVERY.md
git log --all -- RECOVERY.md
```

No matches for either command. If a match is found, the artifact was not fully expunged.

**2. Check for wrong-named files in any commit**

```bash
git log --all --diff-filter=A -- 'devlog/handovers/20260511*'
```

No matches. Any match indicates a stale file that should have been renamed or removed.

**3. Verify handover attribution per commit**

For each commit that should have created a handover:

```bash
git diff-tree --no-commit-id -r <sha> -- devlog/handovers/
```

Each commit should create exactly one handover file with the correct name and `add` mode (`:000000 100644 A ...`).

**4. Verify session date consistency across all handovers**

```bash
for f in devlog/handovers/YYYYMMDD-*.md; do
  grep "^\\*\\*Session date:" "$f"
done
```

All dates must match the date prefix in the filename. No `2026-05-11` dates in a `20260512-*` file (unless the session genuinely spanned two days).

**5. Verify file attribution consistency**

```bash
for sha in <commits that should have handovers>; do
  echo "--- $(git log --oneline -1 $sha) ---"
  git show $sha:devlog/handovers/ | head -4
done
```

Each commit's handover, when extracted, must have the correct session date and type.

**6. Verify working tree is clean**

```bash
git status --short
```

No output expected.

**7. Final history shape check**

```bash
git log --oneline <baseline>..HEAD
```

Confirm the commit sequence makes sense and no fixup or repair commits remain.

### Exit conditions

All checks pass. The history is clean — no working documents, no wrong prefix, no missing handovers, no fixup commits. The operator can proceed with normal session flow.

## Open questions

The recovery protocol has known gaps that have not yet been resolved. These are documented here for awareness and future improvement.

- **No expected test count baseline.** (Originated in handover audit, finding F1 from `20260512-07-workflow-recovery_verification_audit.md`.) The recovery procedure says "check total test count matches expected" (Step 5), but no canonical baseline is recorded anywhere. The operator or recovery agent has to rely on memory or infer from context. A test-count baseline should be committed alongside the test suite.
- **Chat history is the only complete change record.** (Originated in handover audit, finding F2 from `20260512-07-workflow-recovery_verification_audit.md`.) The session JSONL log format (`*.jsonl`) is interface-specific and not standardised. If the chat history is lost (container reset without persisted logs), there is no machine-parseable record of what changed. A structured session log format or explicit commit-hook-based change recording would eliminate this single point of failure.
