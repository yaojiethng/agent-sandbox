# Path-resolution patterns

Open this when code derives its own directory, its repository root, or a path from an argument, or when a module needs the name to call that path by.

## p-1 Self location

```bash
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

`BASH_SOURCE[0]` holds the path the script was invoked at, so a script reached through a symlink reports the link rather than the file it points to. Derive the directory from it, which works from any working directory and through any number of links.

- Names: the name `p-25` assigns to the context.
- Variant: the link path is usually the right answer, because it is where the operator installed the tool. Use `realpath` in place of `${BASH_SOURCE[0]}` only when the code needs the real file location, such as when it resolves a sibling by its physical path.
- Replaces: `dirname "$0"`, a hand-counted `..` chain, or `$(pwd)` read at import time.

## p-2 Traversal from a resolved name

```bash
REPO_ROOT="$(cd "${_self_dir}/../.." && pwd)"
```

Traversal starts from a name that is already resolved. `$PWD`, `$0` and a relative path are not anchors: each depends on the directory the caller happened to be in, and a count taken from one breaks when the script moves a level.

- Names: the anchor the line above resolved, and the name `p-25` assigns to what it resolves to.
- Count: the number of levels belongs on this line and nowhere else.
- Replaces: `cd ../../..` from `$PWD`, a path built from `$0` without resolving it, a literal absolute path.

## p-3 A root the caller may override

```bash
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "${_self_dir}/../.." && pwd)}"
```

A root the caller may override is read from the environment and defaulted to the resolved one, so the script runs from a plain checkout and a caller can still point it at another tree. Write both on the line that assigns it, so a reader sees the default and the override in one place rather than in a comment or a separate branch.

- Names: the environment variable the caller sets, defaulting to the resolved root.
- Replaces: an unconditional assignment that overrides the caller, and a bare reference that dies under `set -u` when nothing set it.

## p-25 Resolve each context's location under one name

| Context | Name | Resolves to |
|---|---|---|
| Container entry points | `_self_dir` | the hardcoded `/opt/sandbox/lib/`, no derivation |
| Cross-context shared libraries | `_self_dir` | self-resolution |
| Host installed CLI | `AGENT_SANDBOX_REPO` | the macro, defaulted as in `p-3` |
| Host repository scripts and test files | `REPO_ROOT` | derived from `_self_dir` |

Each context resolves its own location by the idiom in `p-1` and uses exactly this name, so a second name for the same thing is the fault: `SCRIPT_DIR`, `_self` and the per-file prefixes such as `_DIFF_SH_DIR` are spellings of `_self_dir` rather than names that may exist beside it.

Replaces: a name invented per file, and two names for one directory along a call chain.

## p-28 Cross a repository boundary with an absolute symlink

```bash
ln -s "/absolute/path/to/target" "$LINK_PATH"
```

A relative symlink across a repository boundary encodes the host's directory layout, so it breaks when either repository moves or when the checkout is at a different depth. Write the target as an absolute path, which is the one thing both sides agree on.

Replaces: `ln -s ../../other-repo/file "$LINK_PATH"`.

## p-32 Absolutize a resolved path before any filesystem use

```bash
p=$(git -C "$REPO" rev-parse --git-path info/exclude)
[[ $p == /* ]] || p="$REPO/$p"
mkdir -p "$(dirname "$p")"
printf '%s\n' "$entry" >> "$p"
```

`git rev-parse --git-path` prints a path relative to the repository root, not to the caller's working directory, so appending to its output byte for byte writes outside the repository. Resolve it against the root it came from before the first filesystem use.

Replaces: `git -C "$REPO" rev-parse --git-path info/exclude` used directly as a redirect target.

## p-39 Do the work inside the subshell that changes directory

```bash
# Wrong: the directory change dies with the command substitution
dir=$(cd "$TMP" && pwd)
printf 'hello\n' > file.txt

# Right: everything that depends on the new directory runs in that subshell
( cd "$TMP" && printf 'hello\n' > file.txt )
```

A command substitution runs in a subshell, so a `cd` inside it changes nothing the caller can see; only what it prints comes back. The lines after it then run in the directory the caller started in, and they succeed there, which is why nothing reports the mistake. A test helper that resolved a temporary directory this way committed the repository the caller was in. Change directory and do the work in the same subshell, or carry the resolved path out and use it.

Replaces: `dir=$(cd "$TMP" && pwd)` followed by work that assumes the caller moved.
