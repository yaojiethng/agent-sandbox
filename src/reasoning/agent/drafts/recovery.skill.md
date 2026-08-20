# Skill — Recovery Protocol

## Purpose

Ad-hoc workflow for recovering committed artifacts that violate policy or convention. Not a policy — use when needed, not on every iteration.

Covers two scenarios: recovering lost work after a container/filesystem reset, and verifying that committed artifacts are correctly shaped after a recovery operation.

## Before Acting

Confirm which scenario applies:
- **Recovery process** — container or filesystem state was reset, losing committed work
- **Recovery verification audit** — recovery is complete and needs verification

---

## Recovery Process

### Entry Conditions

- Container or filesystem state was reset, losing committed work from one or more prior iterations.
- The lost work is known to exist from a session log (JSONL file) or from chat history.
- A handover documenting the lost iterations exists.

### Procedure

**1. Assess what was lost**

```bash
git log --oneline <baseline>..HEAD
git status --short
ls devlog/handovers/
```

Identify which iterations' outputs are missing. The handovers tell you what was done; the git log tells you what survived.

**2. Choose reconstruction method**

- **Chat history replay** — replay edits iteration by iteration. Labor-intensive but reliable.
- **JSONL session log replay** — if a session JSONL file survived the reset, it may contain tool calls and outputs. Faster but schema is not standardised.

**3. Replay in order**

Reconstruct one iteration at a time, in chronological order. Run the full test suite after each iteration before committing. If an iteration had no code output (e.g. a planning iteration), skip it.

```bash
# Per iteration:
# 1. Apply all edits for the iteration
# 2. Run tests
bash scripts/run_tests.sh
# 3. Commit
git add -A
git commit -m "<message>"
```

**4. Create handovers**

For each replayed iteration, create a handover file at `devlog/handovers/`:
- Date the handover to the current day (the replay date), not the original iteration date.
- Number it sequentially from the existing handovers in the repo.
- Set `Status: Closed` since the work was already completed.

**5. Verify completeness**

```bash
bash scripts/run_tests.sh
ls devlog/handovers/
```

**6. Renumber and date-check (if needed)**

If handovers were created with the wrong date, rename files and update dates inside them. Skip if Step 4 was done correctly.

```bash
mv devlog/handovers/<old-date>-*.md devlog/handovers/<new-date>-*.md
for f in devlog/handovers/<new-date>-*.md; do
  sed -i 's/<old-date>/<new-date>/g' "$f"
done
```

A rebase is needed after renaming to squash rename commits — the verification audit section handles that.

**7. Package for review**

```bash
bash libs/package_branch.sh --to=$HOME/workspace/output --bundle-summary=<snake_case_summary>
```

Read `agent/prompts/package-branch.md` for the correct invocation.

---

## Recovery Verification Audit

### Entry Conditions

- A previous agent iteration produced commits with known inconsistencies (wrong naming, missing artifacts, fixup commits).
- An interactive rebase or other history-rewriting operation has been performed to fix them.
- The recovery is complete and needs verification.

### Procedure

**1. Check for banned artifacts in git history**

```bash
git log --all --diff-filter=A -- RECOVERY.md
git log --all -- RECOVERY.md
```

No matches expected.

**2. Check for wrong-named files in any commit**

```bash
git log --all --diff-filter=A -- 'devlog/handovers/<wrong-pattern>*'
```

No matches expected.

**3. Verify handover attribution per commit**

```bash
git diff-tree --no-commit-id -r <sha> -- devlog/handovers/
```

Each commit should create exactly one handover file with correct name and `add` mode.

**4. Verify date consistency**

```bash
for f in devlog/handovers/YYYYMMDD-*.md; do
  grep -E "\*\*Session date:|\*\*Date:" "$f"
done
```

All dates must match the date prefix in the filename.

**5. Verify file attribution consistency**

```bash
for sha in <commits that should have handovers>; do
  git show $sha:devlog/handovers/ | head -4
done
```

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

### Exit Conditions

All checks pass. The history is clean — no working documents, no wrong prefix, no missing handovers, no fixup commits.

---

## Known Gaps

- **No expected test count baseline.** The recovery procedure says "check total test count matches expected" but no canonical baseline is recorded. A test-count baseline should be committed alongside the test suite.
- **Chat history is the only complete change record.** Session JSONL log format is interface-specific and not standardised. If chat history is lost, there is no machine-parseable record of what changed.
