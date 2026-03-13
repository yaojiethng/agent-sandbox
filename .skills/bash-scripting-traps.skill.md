# Skill — Bash Scripting Traps

Traps encountered in bash scripts working with git, make, file paths, and
process orchestration. Consult before writing any non-trivial bash script.

---

## 1. Makefile recipes require tabs, not spaces

Heredocs in bash scripts produce spaces when the file passes through an
editor or when the heredoc body is indented. `make` will fail with
`missing separator` if recipe lines use spaces.

**Never use heredocs for Makefile content.** Use `printf` with explicit `\t`:

```bash
printf '\ntarget:\n\tcommand --flag=$(VAR)\n' >> Makefile
```

Verify with `cat -A` — tabs appear as `^I`, spaces appear as plain spaces.

---

## 2. Filenames with leading dashes are interpreted as flags

Any command that takes filenames as arguments will misinterpret a filename
beginning with `-` as a flag. This includes `cp`, `rm`, `git`, and most
Unix tools.

**Always use `--` to terminate flag parsing before filenames:**

```bash
cp --parents -- "$file" "$DEST/"
rm -- "$file"
```

---

## 3. xargs batching breaks per-file error visibility and flag ordering

`xargs` batches arguments into as few invocations as possible. This means:
- A single bad filename causes the entire batch to fail with no indication of which file
- Flags like `-t` and `--parents` may interact incorrectly when filenames are injected mid-invocation

**Prefer a `while read` loop for file processing where error identity matters:**

```bash
while IFS= read -r -d '' file; do
  cp --parents -- "$file" "$DEST/" || echo "Error: failed: $file" >&2
done
```

Use `-d ''` with `IFS=` and `read -r` to handle null-delimited input correctly.
Null-delimited output from `git ls-files -z` or `find -print0` is safe for
filenames containing spaces, newlines, or special characters.

---

## 4. Spaces in filenames break unquoted variable expansion

Any filename stored in a variable must be quoted at every point of use.
Unquoted expansion splits on whitespace.

```bash
# Wrong
cp $file $dest

# Right
cp -- "$file" "$dest"
```

This applies to arrays too — use `"${array[@]}"` not `${array[*]}`.

---

## 5. Symlinks enumerated by git ls-files cannot be copied with cp --parents

`git ls-files --others` includes untracked symlinks. `cp --parents` cannot
copy a symlink — it will fail or follow the link unexpectedly.

**Check for symlinks explicitly and skip or handle them separately:**

```bash
if [[ -L "$SOURCE_DIR/$file" ]]; then
  echo "Skipping symlink: $file" >&2
  continue
fi
```

---

## 6. BASH_SOURCE[0] resolves to the symlink path, not the real file

When a script is called through a symlink, `${BASH_SOURCE[0]}` returns the
symlink path. `SCRIPT_DIR` derived from it will point into the symlink's
directory, not the real file's directory.

This is usually correct when the symlink is intentional tooling (e.g.
`.vault → workflow/knowledge-vault`), because relative paths from `SCRIPT_DIR`
then resolve through the symlink transparently.

However, if you need the real file's location, use `realpath`:

```bash
REAL_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
```

---

## 7. Derive REPO_ROOT explicitly — never count `../..` from a script

Counting parent directory traversals (`../../`) from a script's location is
fragile and unreadable. If the script moves, every derived path breaks.

**Always resolve REPO_ROOT as a named variable from a known anchor:**

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${WORKFLOW_DIR}/../.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/lib/_templates"
```

Each variable is derived from the one above. A layout change requires
updating one line, not hunting for all `../..` occurrences.

---

## 8. Rollback on partial initialisation requires a trap, not just set -e

`set -euo pipefail` stops execution on error but does not clean up state
already written. If a script creates a directory or file as part of an
initialisation sequence that later fails, the partial state persists.

**Use a trap on EXIT to roll back state created by the current run:**

```bash
CREATED_BY_THIS_RUN=0

rollback() {
  if [[ "$CREATED_BY_THIS_RUN" -eq 1 ]]; then
    rm -rf "$CREATED_DIR"
    echo "Rolled back: $CREATED_DIR removed." >&2
  fi
}

trap rollback EXIT

mkdir "$CREATED_DIR"
CREATED_BY_THIS_RUN=1

# ... rest of init ...

# Disarm on success
CREATED_BY_THIS_RUN=0
```

The flag is set after creation and disarmed at the end. Any exit before
disarming — including signals and `set -e` failures — triggers the rollback.

---

## 9. Operator prompts belong in orchestrating scripts, not in primitives

Scripts called by other scripts (primitives) should fail loudly and exit.
They should not print "next steps" or operator guidance — that output is
noise when the caller handles the result programmatically.

**Rule:** only the top-level operator-facing script emits next-steps guidance.
Primitives emit errors to stderr and exit non-zero.

```bash
# Primitive — wrong
do_thing || { echo "Failed. Next steps: ..."; exit 1; }

# Primitive — right
do_thing || { echo "ERROR: thing failed: $reason" >&2; exit 1; }

# Orchestrator — right
bash primitive.sh || {
  echo "Step failed. To diagnose: run diagnostic.sh" >&2
  exit 1
}
echo "Done. Next: run make start"
```

---

## 10. Relative symlinks to paths outside the project are fragile and confusing

A relative symlink from inside a project to a path outside it (e.g. to a
sibling repo) encodes the relative directory structure of the host machine.
It breaks if either directory moves and produces confusing `../../..` paths.

**Use absolute symlinks for links that cross repository boundaries:**

```bash
ln -s "/absolute/path/to/target" "$LINK_PATH"
```

Relative symlinks are appropriate within a single repository where the
relative path is stable by definition.
