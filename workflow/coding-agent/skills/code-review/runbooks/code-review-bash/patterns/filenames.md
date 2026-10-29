# Filename patterns

Open this when code passes a filename, or a list of them, into a command.

## p-21 Read a null-delimited list, not `xargs`

```bash
git ls-files -z | while IFS= read -r -d "" file; do
  cp --parents -- "$file" "$DEST/" || echo "Error: failed: $file" >&2
done
```

`xargs` batches its arguments, so one bad filename fails the whole batch and no error names the file that caused it. Read null-delimited, which survives a newline in a filename, and act per file, so each failure is reported against its own name.

Replaces: `git ls-files | xargs cp --parents -t "$DEST/"`.

## p-22 Check for a symlink before `cp --parents`

```bash
if [[ -L "$SOURCE_DIR/$file" ]]; then
  echo "Skipping symlink: $file" >&2
  continue
fi
```

`git ls-files --others` includes untracked symlinks, and `cp --parents` cannot copy a symlink, so an unguarded walk fails partway with a message about the wrong file. Test each entry and skip or report it by name.

Replaces: a copy loop that reads its failure as a permissions problem.

## p-31 Check a path before a redirection consumes it

```bash
[[ -f $file ]] || return 0
while IFS='=' read -r k v; do
  ...
done < "$file"
```

A redirection from a path that is not there fails its command, and under `set -e` that failure ends the run of whoever called the function, so the operator sees the call site fail instead of this function returning a result. Test the path and return, which turns a missing file into an outcome the caller decides about. Guarding the call with `|| ...` is not a substitute: the shell's own expansion fails before any command runs, so an unset parameter under `set -u` escapes the guard and ends the shell.

Replaces: `while ... done < "$1"` in a sourced library, with the caller left to discover the abort.
