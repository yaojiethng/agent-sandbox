---
description: Package all changed files and a diff into the workspace output mount for migration
trigger: /package-diff
---
Package the current session's changes for export via the workspace output mount.

Steps:

1. Identify all changed files: `git diff --name-only HEAD`

2. Infer a descriptive name for the change:
   - Read the diff (`git diff HEAD`) and the list of changed files
   - Derive a short snake_case label (3–5 words) that describes the nature of the change — e.g. `fix_snapshot_path_resolution`, `add_autosave_interval_config`, `refactor_compose_generation`
   - Avoid generic labels like `update_files` or `misc_changes`

3. Create the output directory:
   ```
   TIMESTAMP=$(date +%Y%m%d%H%M%S)
   LABEL=<derived descriptive name>
   OUTDIR=~/workspace/output/${TIMESTAMP}-${LABEL}
   mkdir -p "$OUTDIR/changed-files"
   ```

4. Copy each changed file into `$OUTDIR/changed-files/` preserving repo-relative paths:
   ```
   for f in $(git diff --name-only HEAD); do
     mkdir -p "$OUTDIR/changed-files/$(dirname "$f")"
     cp -- "$f" "$OUTDIR/changed-files/$f"
   done
   ```

5. Generate the diff: `git diff HEAD > "$OUTDIR/changes.diff"`

6. Write `$OUTDIR/migration-guide.md` containing:
   - What changed and why (root cause)
   - Table of changed files with nature of change
   - Deleted code (if any)
   - How to apply (Option A: copy files, Option B: git apply)
   - API breaking changes
   - Verification command
   - The snapshot invariant

7. Print a summary: the output directory path, list of files written, and diff size in lines
