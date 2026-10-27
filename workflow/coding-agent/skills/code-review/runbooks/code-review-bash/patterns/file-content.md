# File-content patterns

Open this when code writes bytes into a file format that assigns meaning to whitespace.

## p-19 Write a whitespace-sensitive format with explicit escapes

```bash
printf "\ntarget:\n\tcommand --flag=\$(VAR)\n" >> Makefile
```

A heredoc carries its own indentation into the file, and some formats assign meaning to it: `make` requires a tab where a heredoc gives spaces, and an indented JSON or YAML writer has the same problem. Write the bytes explicitly with `printf` and a stated escape, then verify with `cat -A`, where a tab reads as `^I` and a space as itself.

Replaces: `cat >> Makefile <<EOF` with an indented body.
