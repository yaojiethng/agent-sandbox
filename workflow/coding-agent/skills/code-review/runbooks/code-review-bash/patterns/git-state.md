# Git-state patterns

Open this when a script reads or compares the state of a git tree.

## p-59 Compare two trees on a fixed porcelain format, never on the default

```bash
git -C "$src" status --porcelain=v1 -uall -z | sort -z > "$s1"
git -C "$dest" status --porcelain=v1 -uall -z | sort -z > "$s2"
cmp -s "$s1" "$s2" || printf 'seed differs from source\n' >&2
```

Plain `status --porcelain` is a display format that varies with configuration and with the shape of the tree: an untracked directory collapses to one entry unless `-uall` is given, and a path holding a space or a newline is quoted with C escapes unless `-z` is given. Two byte-identical trees therefore compare unequal, and a parse of the quoted form reads an escaped name as a filename. Ask for the versioned format, ask for every untracked file, read NUL-delimited, and sort, because status order follows the index rather than the tree.

Replaces: two `status --porcelain` outputs compared directly, and `status --porcelain | while read -r` over a name that can hold a newline.

## p-60 Pin the revision a diff is taken against

```bash
git -C "$repo" diff --stat HEAD
```

A diff with no revision compares the index to the working tree, so everything staged is invisible to it. A check or an export built on the bare form reports a clean tree while the change sits in the index, which is the state a script leaves behind whenever it stages before it packages. Name the revision instead: `HEAD` for the whole uncommitted set, `--cached` for the index alone, a base sha for a branch's work.

Replaces: a bare `git diff` as the source of a change list, a status report or an export.
