# Bash Coding Conventions

Rules for writing bash scripts in this project. Supersedes the former `bash-scripting-traps.skill.md` and `bash-dependency-audit.skill.md`. For automated audit, see `.agents/audits/bash-audit.skill.md`.

**Authoritative style guide:** [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) (google/shellguide). Where this document and the Google guide conflict, this document wins on project-specific conventions (e.g. `set -euo pipefail`, library `return`/`exit` discipline, the `|| true` / `|| rc=$?` failure-tolerant idioms in rule 4); the Google guide is authoritative for general bash style (naming, quoting, `local`/`readonly`, function and command-substitution form, flags, output to stderr). The Google guide is silent on the `set -e`/`pipefail` failure-tolerant-check idioms we rely on  --  those are governed here.

**Linting:** `shellcheck` is installed and run on scripts (see `scripts/run_tests.sh` and the bash-audit skill). Shellcheck warnings beyond documented `# shellcheck disable` disables are treated as defects. Shellcheck does not flag the `grep`-no-match / `|| true` class of `set -e` landmines  --  those are covered by rule 4 below and are caught by review, not the linter.

## 1. Language Rules

### 1.1 Makefile content: `printf`, not heredocs

`p-19` in [the file content patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/file-content.md).

### 1.2 Terminate flag parsing with `--` before filenames

`p-20` in [the arguments patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/arguments.md).

### 1.3 Prefer `while read` over `xargs` for file processing

`p-21` in [the filenames patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/filenames.md).

### 1.4 Quote all variable expansions containing filenames

`p-7` in [the quoting patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/quoting.md).

### 1.5 Check for symlinks before `cp --parents`

`p-22` in [the filenames patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/filenames.md).

### 1.6 `BASH_SOURCE[0]` resolves to the symlink path

`p-1` in [the path resolution patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/path-resolution.md).

### 1.7 Derive `REPO_ROOT` from a named anchor, never count `../..`

`p-23` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 1.8 Use EXIT traps for partial-state rollback

`p-30` in [the operator facing text patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/operator-facing-text.md).

### 1.9 Operator prompts in orchestrators only

`p-28` in [the path resolution patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/path-resolution.md).

### 1.10 Absolute symlinks for cross-repository links

`p-15` in [the script boundaries patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/script-boundaries.md).

### 1.11 Dual-use scripts: guard with `BASH_SOURCE[0] == "$0"`

`p-5` in [the declaration patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/declaration.md).

### 1.12 Default to `local`; pass behaviour as CLI flags, not exports

`p-16` in [the script boundaries patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/script-boundaries.md).

### 1.13 Mode/config selection: parse the default once at ingestion, pass it as an argument

`p-17` in [the script boundaries patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/script-boundaries.md).

### 1.14 `exec` over sourcing for subcommand dispatch

`p-9` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 1.15 Self-derive repo root for dual-use scripts

`p-18` in [the shell options patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/shell-options.md).

### 1.16 No `local` at script top level

`p-24` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 1.17 Scope `|| true` to the command that needs it

`p-11` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

## 2. Dependency Management

### 2.1 Control flow graph

`p-26` in [the sourcing patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/sourcing.md).

### 2.2 Path resolution conventions

`p-25` in [the path resolution patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/path-resolution.md).

### 2.3 No circular sourcing

`p-27` in [the sourcing patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/sourcing.md).

## 3. Library Discipline

### 3.1 Library functions `return`, never `exit`

`p-13` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 3.2 Exit codes carry a verdict, never a magnitude

`p-14` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 3.3 Dual-use scripts: library functions + standalone guard

`p-15` in [the script boundaries patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/script-boundaries.md).

### 3.4 No speculative flags: boolean parameters need a production caller

`p-18` in [the shell options patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/shell-options.md).

### 3.5 Checks fail closed, name their failure key, and never presume a predecessor succeeded

`p-29` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

## 4. Common Pitfalls

### 4.1 `local FOO=$(cmd)` swallows exit codes

`p-4` in [the declaration patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/declaration.md).

### 4.2 `${VAR:-default}` on empty strings

`p-6` in [the declaration patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/declaration.md).

### 4.3 `grep -c` returns exit 1 on zero matches

`p-12` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 4.4 Sourced-lib reads must not redirect from unguaranteed paths

`p-31` in [the filenames patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/filenames.md).

### 4.5 Absolutize `git rev-parse --git-path` output before filesystem use

`p-32` in [the path resolution patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/path-resolution.md).

### 4.6 A prose comment must not start the token `shellcheck`

`p-33` in [the shellcheck patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/shellcheck.md).

## 5. Cross-References

| Source | Relationship |
|---|---|
| `interface-conventions.md` | CLI/TUI/API rules (this doc covers bash, not interface) |
| `.agents/skills/testing/SKILL.md` | Test judgements and patterns |
| `test_harness_mechanism.md` | The suite's runner, contract and gates |
| `.agents/audits/bash-audit.skill.md` | Automated audit skill |
| `devlog/AGENT_FEEDBACK.md` Gotchas section `[O]` | Original `exit` vs `return` finding |
| `devlog/AGENT_FEEDBACK.md` Bash section | Historical bash friction records |
