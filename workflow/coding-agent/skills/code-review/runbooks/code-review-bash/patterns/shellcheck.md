# ShellCheck patterns

Open this when a comment, a suppression or a `source=` line is written for ShellCheck, or when the gate reports a parse error that looks like a false positive.

## p-33 Word a prose comment so the tool does not read it as a directive

```bash
# Wrong: the first token after the hash is the word, so this parses as a directive
# shellcheck absent -- rc 1

# Right
# the shellcheck tool is absent here, so the gate reports rc 1
```

ShellCheck reads a comment whose first token after `#` is the word `shellcheck` as a directive, then fails on one it cannot parse, reporting SC1072 or SC1073 at a line that holds no directive at all. A real directive starts that way on purpose: `disable=`, `enable=`, `source=`, `shell=`. A sentence about the tool is prose and takes another word first.

Replaces: `# shellcheck absent -- rc 1`, and the search for a false positive that follows it.
