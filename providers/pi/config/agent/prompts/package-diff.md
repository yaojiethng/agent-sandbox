---
description: Package all changed files and a diff into the workspace output mount for migration
trigger: /package-diff
---
Package the current session's changes for export via the workspace output mount.

Steps:

1. Identify all changed files: `git diff --name-only HEAD`
2. Remove stale output:
   - `rm -rf ~/workspace/output/changed-files`
   - `rm -f ~/workspace/output/snapshot-pipeline-fix.diff`
   - `rm -f ~/workspace/output/migration-guide.md`
3. Copy each changed file into `~/workspace/output/changed-files/` preserving repo-relative paths:
   ```
   for f in $(git diff --name-only HEAD); do
     mkdir -p ~/workspace/output/changed-files/"$(dirname "$f")"
     cp -- "$f" ~/workspace/output/changed-files/"$f"
   done
   ```
4. Generate the diff: `git diff > ~/workspace/output/snapshot-pipeline-fix.diff`
5. Write a `~/workspace/output/migration-guide.md` containing:
   - What changed and why (root cause)
   - Table of changed files with nature of change
   - Deleted code (if any)
   - How to apply (Option A: copy files, Option B: git apply)
   - API breaking changes
   - Verification command
   - The snapshot invariant
6. Print a summary: list all output files and the diff size
