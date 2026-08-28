# Bash Coding Conventions

Rules for writing bash scripts in this project. Supersedes the former
`bash-scripting-traps.skill.md` and `bash-dependency-audit.skill.md`. For
automated audit, see `src/reasoning/agent/drafts/bash-audit.skill.md`.

**Authoritative style guide:** [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) (google/shellguide). Where this document and the Google guide conflict, this document wins on project-specific conventions (e.g. `set -euo pipefail`, library `return`/`exit` discipline, the `|| true` / `|| rc=$?` failure-tolerant idioms in rule 4); the Google guide is authoritative for general bash style (naming, quoting, `local`/`readonly`, function and command-substitution form, flags, output to stderr). The Google guide is silent on the `set -e`/`pipefail` failure-tolerant-check idioms we rely on  --  those are governed here.

**Linting:** `shellcheck` is installed and run on scripts (see `scripts/run_tests.sh` and the bash-audit skill). Shellcheck warnings beyond documented `# shellcheck disable` disables are treated as defects. Shellcheck does not flag the `grep`-no-match / `|| true` class of `set -e` landmines  --  those are covered by rule 4 below and are caught by review, not the linter.

---

## 1. Language Rules

### 1.1 Makefile content: `printf`, not heredocs

Heredocs produce spaces when indented; `make` requires tabs. Always use
`printf` with explicit `\t` for Makefile generation:

```bash
printf "\ntarget:\n\tcommand --flag=$(VAR)\n" >> Makefile
```

Verify with `cat -A`  --  tabs appear as `^I`.

### 1.2 Terminate flag parsing with `--` before filenames

Filenames beginning with `-` are interpreted as flags by `cp`, `rm`, `git`,
and most Unix tools.

```bash
cp --parents -- "$file" "$DEST/"
rm -- "$file"
```

### 1.3 Prefer `while read` over `xargs` for file processing

`xargs` batches arguments; a single bad filename fails the entire batch with
no per-file error. Use `while IFS= read -r -d ""` with null-delimited input:

```bash
while IFS= read -r -d "" file; do
  cp --parents -- "$file" "$DEST/" || echo "Error: failed: $file" >&2
done
```

### 1.4 Quote all variable expansions containing filenames

Unquoted expansion splits on whitespace. Quote at every point of use.

```bash
# Right
cp -- "$file" "$dest"

# Right  --  arrays
"${array[@]}"
```

**Never pass a string-as-list through word-splitting.** Storing multiple paths
in one scalar (`a b c`) and expanding it unquoted  --  `$VAR` (SC2086) or
`$(_list_fn)` in argument position (SC2046)  --  works only as long as every value
is whitespace-free, and silently breaks the moment one isn"t. Emit each item on
its own line and load into a real array, then expand with `"${arr[@]}"`:

```bash
# Right  --  emit per-line, load with mapfile, expand as array
list_files() { printf "%s\n" "src/libs" "docs/architecture" "docs/concepts"; }
mapfile -t SOURCES < <(list_files)
compute_hash "${SOURCES[@]}"

# Wrong  --  string-as-list, word-splitting a command substitution (SC2046)
echo_and_split() { echo "src/libs docs/architecture"; }
compute_hash $(echo_and_split)
```

Sourced command output in a herestring: `read -ra` reads only the first line;
use `mapfile -t ... < <(cmd)` or `mapfile -t ... <<< "$(cmd)"` to capture every
line.

### 1.5 Check for symlinks before `cp --parents`

`git ls-files --others` includes untracked symlinks. `cp --parents` cannot
copy symlinks. Check explicitly:

```bash
if [[ -L "$SOURCE_DIR/$file" ]]; then
  echo "Skipping symlink: $file" >&2
  continue
fi
```

### 1.6 `BASH_SOURCE[0]` resolves to the symlink path

When called through a symlink, `${BASH_SOURCE[0]}` returns the symlink path.
This is usually correct for intentional tooling symlinks. If the real file
location is needed, use `realpath`:

```bash
REAL_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
```

### 1.7 Derive `REPO_ROOT` from a named anchor, never count `../..`

Counting parent traversals (`../../`) is fragile. Derive from a known anchor:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${WORKFLOW_DIR}/../.." && pwd)"
```

### 1.8 Use EXIT traps for partial-state rollback

`set -euo pipefail` stops on error but does not clean up state already
written. Use a flag + EXIT trap:

```bash
CREATED=0
trap "[[ "$CREATED" -eq 1 ]] && rm -rf "$DIR"" EXIT
mkdir "$DIR"; CREATED=1
# ... work ...
CREATED=0  # disarm on success
```

### 1.9 Operator prompts in orchestrators only

Library scripts (primitives) emit errors to stderr and exit non-zero. Only
the top-level operator-facing script prints next-steps guidance.

```bash
# Library  --  right
do_thing || { echo "ERROR: thing failed: $reason" >&2; return 1; }

# Orchestrator  --  right
echo "Done. Next: run make start"
```

### 1.10 Absolute symlinks for cross-repository links

Relative symlinks across repository boundaries encode host directory
structure and break on moves. Use absolute symlinks:

```bash
ln -s "/absolute/path/to/target" "$LINK_PATH"
```

### 1.11 Dual-use scripts: guard with `BASH_SOURCE[0] == "$0"`

```bash
main() { ... }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

Use `"$0"`, not `${0}`. Do not add `||` array-length variations.

### 1.12 Default to `local`; pass behaviour as CLI flags, not exports

An exported boolean set in one invocation leaks into every child process,
including teardown. Pass as CLI flags instead.

```bash
# Right
local REFRESH_FLAG=""
[[ "${REFRESH:-false}" == "true" ]] && REFRESH_FLAG="--refresh"
exec "$SCRIPT_DIR/run.sh" --name="$PROJECT" $REFRESH_FLAG
```

Exceptions: `.env` config vars and identity values (`SESSION_TS`, `SANDBOX_ID`,
`HOST_HEAD_SHA`) are safe to export.

### 1.13 `exec` over sourcing for subcommand dispatch

Each subcommand gets a clean process boundary. Dispatch branches should be
`exec` or short validation -> `exec`. Branches over 5 lines belong in the
subcommand script.

```bash
build)
  parse_flags "$@"
  exec bash "$SCRIPTS/build.sh" --target="$TARGET"
  ;;
```

### 1.14 Self-derive repo root for dual-use scripts

Scripts that can be `exec`"d or sourced need to handle both:

```bash
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_self/../.." && pwd)}"
```

### 1.15 No `local` at script top level

`local` is only valid inside a function. At top-level scope it is a runtime
error not caught by `bash -n`. Use plain assignment.

```bash
# Right  --  at top level
REFRESH_FLAG=""
```

### 1.16 Scope `|| true` to the command that needs it

Under `set -o pipefail`, `|| true` on the whole pipeline swallows every
command"s failure. Scope to the individual command with a subshell:

```bash
# Right  --  only grep"s failure is absorbed
docker compose up -d 2>&1 | (grep -v "^Container " || true)
```

### 1.17 Shell option flags by file class

Every shell file declares its failure regime according to its class. The
class is determined by how the file is consumed, not by where it lives.

| Class | Rule | Why |
|---|---|---|
| Orchestrator entry points (exec"d, no source-consumers) | `set -euo pipefail` at top | fail-fast beats continuing with partial state |
| Dual-use (exec"d in production, sourced by tests) | flags inside `main()` or the rule 1.11 guard only | a top-level `set` mutates the sourcing consumer"s shell |
| Pure libraries (sourced only) | never set options | inherit the consumer"s regime; per-function correctness via rule 3.1 and the rule 4 idioms |
| Observe-and-report (test files, harness runners, diagnostic sweeps) | no `-e`  --  must run all checks and count failures; `set -uo pipefail` preferred | first-failure abort defeats reporting (`run_test`"s NO-ASSERTION detection relies on observing failures) |

In the last row, weaker than `-uo pipefail` is permitted only with an inline
rationale comment (e.g. the dry-run diagnostics: "Intentionally no set -u:
env vars are checked explicitly with guards").

Notes:

- Direct execution of subcommand scripts is the rule 1.13 dispatch architecture,
  not an accident to be designed away.
- `-u` in library code would fire on consumer-controlled environments;
  libraries validate their inputs explicitly instead.
- A class change (e.g. a lib growing an entry point) means re-declaring flags
  for the new class as part of that change.

---

## 2. Dependency Management

### 2.1 Control flow graph

```
scripts/  ---> src/libs/, src/build/     host scripts source shared libs
scripts/  ---> scripts/                  may source other scripts if logically
                                          a library (e.g. checkpoint.sh)
src/libs/ ---> src/libs/ only            libs never source scripts
src/build/---> src/build/, src/libs/     build libs source shared libs only
tests/*   ---> anything                  tests can source everything
nothing   ---> tests/                    nothing sources tests
```

### 2.2 Path resolution conventions

| Context | Convention | Variable |
|---|---|---|
| Container entrypoints | Hardcoded `/opt/sandbox/lib/` | Absolute path |
| Cross-context shared libs | Self-resolution | `_self_dir` |
| Host installed CLI | Macro | `$AGENT_SANDBOX_REPO` |
| Host repo scripts | Repo root | `$REPO_ROOT` |
| Test files | Repo root | `$REPO_ROOT` |

### 2.3 No circular sourcing

Shared functions live in leaf libraries, never in orchestrators. If
`A.sh` sources `B.sh` and `B.sh` needs a function from `A.sh`, extract the
shared function to a third library `C.sh` sourced by both.

---

## 3. Library Discipline

### 3.1 Library functions `return`, never `exit`

Functions in sourced libraries (`src/libs/`, `src/build/`) must use
`return 1`, not `exit 1`. All entrypoint callers run under `set -euo pipefail`,
so a non-zero return triggers script exit identically. Bare `exit` in a
sourced function is a latent bug if called from a test harness, sub-shell, or
interactive context.

```bash
# Library  --  right
check_base_flags() {
  if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: --name is required" >&2
    return 1
  fi
}
```

Entrypoint scripts (`scripts/*.sh`) and standalone `main()` blocks may use
`exit` legitimately.

### 3.2 Dual-use scripts: library functions + standalone guard

Files in `src/libs/` may export functions (for sourcing) and also run
standalone. The `BASH_SOURCE[0] == "$0"` guard separates the two modes.

### 3.3 No speculative flags: boolean parameters need a production caller

Do not add boolean/string mode parameters to a function unless at least one
production call site passes a value that changes behaviour. A flag "for later"
is dead API surface: it widens every signature it threads through, invites
untested branches, and its eventual removal touches every file in between
(`STRICT` and `AUTO_SELECT` were both removed for exactly this  --  see the
2026-08-21 loc-reduction campaign). When a mode is genuinely needed, add the
parameter and the call-site change in the same commit.

---

## 4. Common Pitfalls

### 4.1 `local FOO=$(cmd)` swallows exit codes

`local` is a builtin that always returns 0. Under `set -e`, the exit code of
the command substitution is silently absorbed. Split the assignment:

```bash
local FOO; FOO=$(failing_cmd)
```

### 4.2 `${VAR:-default}` on empty strings

`${VAR:-default}` expands to `default` only when `VAR` is unset, not when it
is an empty string. Validate explicitly:

```bash
local BASE_COMMIT="$BRANCH_FROM_ARG"
[[ -n "$BASE_COMMIT" ]] || BASE_COMMIT="HEAD"
```

### 4.3 `grep -c` returns exit 1 on zero matches

Under `set -e`, `grep -c` aborts when zero matches is expected -- but note it
also prints its own count (`0`) on stdout. Copyable idiom:

```bash
COUNT=$(grep -c "pattern" file || true)
COUNT=${COUNT:-0}   # only needed for the error paths (missing file)
```

Do NOT write `|| echo 0`: since grep already printed `0`, the substitution
captures both lines and the variable becomes `0\n0` (two zeros). The plain
`|| true` absorbs only the exit code; `${COUNT:-0}` covers the cases where
grep produced no output at all.

---

## 5. Cross-References

| Source | Relationship |
|---|---|
| `interface-conventions.md` | CLI/TUI/API rules (this doc covers bash, not interface) |
| `testing-conventions.md` | Test patterns and anti-patterns |
| `testing_policy.md` | Testing policy and rules |
| `src/reasoning/agent/drafts/bash-audit.skill.md` | Automated audit skill |
| `devlog/GOTCHAS.md` [H] | Original `exit` vs `return` finding |
| `devlog/AGENT_FEEDBACK.md` Bash section | Historical bash friction records |
