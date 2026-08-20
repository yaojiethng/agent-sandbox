# Skill — Refactor: Move or Rename a Single File

**Atomic unit of file refactoring.** Repeating this process for every file in a directory constitutes a folder refactor. Repeating for every directory in a tree constitutes a structural cleanup.

## When to Use

- Renaming a file (e.g. `foo-bar.sh` → `foo_bar.sh`)
- Moving a file to a new directory (e.g. `libs/foo.sh` → `src/libs/foo.sh`)
- Splitting a file into multiple files (e.g. `big.sh` → `part_a.sh` + `part_b.sh`)
- Merging files into one

---

## Preflight — Freeze the Convention

Before touching any file, verify the naming convention against every filename in scope:

```bash
# List all files that will be touched
find libs/ scripts/ src/ -name '*.sh' | sort

# Check for convention violations (e.g. dashes where underscores are expected)
find . -name '*.sh' -name '*-*' -not -path './.git/*' | grep -v agent-sandbox
```

Decision on naming convention (dashes vs underscores, directories, extensions) must be made before implementation begins. Changing convention mid-iteration guarantees missed references.

---

## Step 1 — Catalogue Every Reference

Before the move or rename, find every reference to the file across the entire tree:

```bash
grep -rn 'target_file.sh' . --include="*.sh" --include="*.yml" --include="*.md" --include="Dockerfile"
```

Categorise each hit:

| Category | Must change? | Examples |
|---|---|---|
| **Source path** | ✅ Must change | `source "$DIR/target_file.sh"` |
| **Exec path** | ✅ Must change | `bash "$DIR/target_file.sh"` |
| **COPY source** | ✅ Must change | `COPY target_file.sh /opt/...` |
| **COPY target** | ✅ May change | `COPY src /opt/lib/target_file.sh` (keep target stable if backward compat matters) |
| **Test fixture** | ✅ Must change | Mock repo that creates files at old path |
| **Build context** | ✅ Must change | `_build_context_copy "$repo_root/libs/target_file.sh"` |
| **Documentation** | ⚠️ Should change | Docs referencing the old path |
| **Comments** | 🟡 Optional | `# see libs/target_file.sh` |

Produce a **propagation table**:

```markdown
| File | Line | Old reference | New reference |
|---|---|---|---|
| `scripts/foo.sh` | 42 | `source "libs/target.sh"` | `source "src/libs/target.sh"` |
| `src/capability/Dockerfile` | 28 | `COPY target.sh /opt/lib/target.sh` | `COPY src/libs/target.sh /opt/lib/target.sh` |
```

---

## Step 2 — Create the New File

```bash
# For a simple rename/move:
cp old/path/target.sh new/path/target.sh

# For a split: create each new file with the extracted content
# For a merge: create the merged file
```

Update internal source paths within the new file. If the file uses self-resolution (`_self_dir`), the relative source paths stay correct. If it uses absolute or repo-relative paths, update them:

```bash
# Check internal source paths
grep -n 'source' new/path/target.sh
```

**Do not delete the old file yet.**

---

## Step 3 — Update All References

Process every hit from Step 1's propagation table. Use bulk sed for simple path substitutions:

```bash
perl -i -pe 's|old/path/target\.sh|new/path/target.sh|g' scripts/*.sh src/*/*.sh
```

Verify with:

```bash
grep -rn 'old/path/target\.sh' . --include="*.sh" --include="*.yml" --include="*.md" --include="Dockerfile" | grep -v '.bak'
# Expected: zero matches (or only intentional comment references)
```

---

## Step 4 — Run Tests

```bash
make test
```

All tests must pass. Both the old and new files exist — old paths still resolve, so tests should not break at this stage.

---

## Step 5 — Remove the Old File

```bash
git rm old/path/target.sh
```

Run tests again:

```bash
make test
```

If tests fail, the old file had remaining references. Restore the old file (`git checkout old/path/target.sh`), return to Step 1, and fix the missed references.

---

## Step 6 — Commit

```bash
git add -A
git commit -m "refactor: move/rename target_file.sh → new/path/target_file.sh"
```

---

## Composition: Folder Refactor

To move/rename an entire directory, apply the single-file workflow to every file in the directory:

1. Preflight — freeze naming convention for all files in scope
2. For each file in the directory:
   - Catalogue references (across the whole tree, not just within the directory)
   - Create new file at target location
   - Update all references
   - Verify each file individually
3. After all files are moved: batch-remove old files, run full test suite, commit

For a folder refactor, the catalogue phase can be done once for all files in scope, but the copy-update-verify-remove cycle per file prevents cascading errors.

---

## Composition: Structural Cleanup

A structural cleanup (moving multiple directories) is a tree of folder refactors, each composed of single-file refactors. The same process scales: pre-flight, catalogue, execute each file, verify, remove, commit.
