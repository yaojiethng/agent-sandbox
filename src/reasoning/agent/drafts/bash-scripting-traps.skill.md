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
TEMPLATE_DIR="${REPO_ROOT}/libs/_templates"
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

---

## 11. Guard Pattern for Dual-Use Scripts

A script that can be either executed directly or sourced by another
script must distinguish the two cases. The standard guard is:

```bash
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

This passes when the file is the top-level script and rejects when it is
sourced. The check is safe even if the parent script was itself sourced.

Use `"$0"`, not `${0}`. Both expand identically but `"$0"` is the
conventional form. Do not use array-length variations:

```bash
# Broken — || makes this pass when parent sourced the file
if [[ "${BASH_SOURCE[0]}" == "$0" || \
      ( "${#BASH_SOURCE[@]}" -gt 1 && \
        "${BASH_SOURCE[0]}" != "${BASH_SOURCE[1]}" ) ]]; then
  # This should NOT run when sourced, but the || ensures it does
```

## 12. Do not export state unnecessarily

**Rule:** default to `local`. Pass behaviour-affecting values as CLI flags,
not exported vars. An exported boolean like `REFRESH` set in one invocation
leaks into every child process, including teardown that should not inherit it.

```bash
# Wrong — REFRESH leaks into downstream teardown
export REFRESH=true
exec "$SCRIPT_DIR/run.sh" --name="$PROJECT"

# Right — passed as CLI flag, stays local
local REFRESH_FLAG=""
[[ "${REFRESH:-false}" == "true" ]] && REFRESH_FLAG="--refresh"
exec "$SCRIPT_DIR/run.sh" --name="$PROJECT" $REFRESH_FLAG
```

**Exceptions:** configuration (`.env` vars for `docker compose`) and identity
values (`SESSION_TS`, `SANDBOX_ID`, `HOST_HEAD_SHA`) are safe to export —
they describe context, they do not change behaviour.

## 13. `exec` Over Sourcing for Subcommand Dispatch

When a CLI entry point dispatches to subcommands, `exec` the subcommand
script rather than sourcing it. Each subcommand gets a clean process
boundary: its own `set -euo pipefail`, its own variables, its own
dependency loading.

```bash
# dispatch layer: minimal, no subcommand state
build)
  parse_flags "$@"
  exec bash "$SCRIPTS/build.sh" --target="$TARGET"
  ;;

apply)
  exec bash "$SCRIPTS/workflows/apply.sh" "$@"
  ;;
```

```bash
# Avoid — dispatch layer accumulates subcommand concerns
apply)
  source "apply.sh"
  if [[ "$INTERACTIVE" == true ]]; then
    source "interactive.sh"
    # picker logic, path construction, state management...
    # all in the dispatch layer
  fi
  ;;
```

The visual indicator: every `case` branch in a dispatch-only file should
be either `exec` or a short validation → `exec`. If a branch has more
than 5 lines of logic, the logic likely belongs in the subcommand script.

## 14. Self-Deriving the Repo Root for Dual-Use Scripts

A script that can be `exec`'d (no `AGENT_SANDBOX_REPO` set) or sourced
(`AGENT_SANDBOX_REPO` already set by parent) needs to handle both cases
at the top of the file:

```bash
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_self/../.." && pwd)}"
```

The `../..` assumes a specific project layout. If the layout changes, all
self-derivation paths must be updated together. Audit all files when the
project root or directory structure shifts.

## 15. Never use `local` at script top level

**Rule:** `local` is only valid inside a function. At top-level scope it is
a runtime error — `local: can only be used in a function` — that aborts the
script at that line. `bash -n` does not catch it (it is not a syntax
error), so it surfaces only when the code path executes.

```bash
# Wrong — runtime error, script aborts before exec
local REFRESH_FLAG=""
[[ "${REFRESH:-false}" == "true" ]] && REFRESH_FLAG="--refresh"
exec "$SCRIPT_DIR/run.sh" $REFRESH_FLAG

# Right — plain assignment at top level
REFRESH_FLAG=""
[[ "${REFRESH:-false}" == "true" ]] && REFRESH_FLAG="--refresh"
exec "$SCRIPT_DIR/run.sh" $REFRESH_FLAG
```

Trap 12's examples assume function scope. When applying them at script top
level, drop `local` and use a plain assignment.

## 16. `|| true` on a pipeline swallows all errors under pipefail

`set -o pipefail` makes a pipeline's exit code the first non-zero in the chain.
Appending `|| true` to the entire pipeline swallows every command's failure —
not just the last one.

```bash
# Broken — docker failure is swallowed silently
docker compose up -d 2>&1 | grep -v '^Container ' || true

# Right — scope || true to grep only via subshell
docker compose up -d 2>&1 | (grep -v '^Container ' || true)
```

The subshell is the boundary: `grep`'s failure is absorbed, but the first
command's failure still propagates through `pipefail` to `set -e`.