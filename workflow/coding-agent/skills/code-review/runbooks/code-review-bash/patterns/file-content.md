# File-content patterns

Open this when code writes bytes into a file format that assigns meaning to whitespace.

## p-19 Write a whitespace-sensitive format with explicit escapes

```bash
printf "\ntarget:\n\tcommand --flag=\$(VAR)\n" >> Makefile
```

A heredoc carries its own indentation into the file, and some formats assign meaning to it: `make` requires a tab where a heredoc gives spaces, and an indented JSON or YAML writer has the same problem. Write the bytes explicitly with `printf` and a stated escape, then verify with `cat -A`, where a tab reads as `^I` and a space as itself.

Replaces: `cat >> Makefile <<EOF` with an indented body.

## p-58 An edit by shell command checks that its anchor matched

```bash
sed -i "s|{anchor}|{replacement}|" "$file"
grep -qF -- "{replacement}" "$file" || { printf 'edit did not land: %s\n' "$file" >&2; exit 1; }
```

A substitution whose pattern never matches exits 0 and changes nothing, so a script running several edits reports success while the file still holds the old text, and a missing file operand is the same failure one step earlier. An editor that reports a miss on a non-matching anchor is the reason to prefer one; where the edit runs in a shell, the anchor's absence is caught in the same statement that made it.

Replaces: a bare `sed -i` whose exit status is read as the edit's outcome.
