# Bash Coding Conventions

Rules for writing bash scripts in this project. Supersedes the former `bash-scripting-traps.skill.md` and `bash-dependency-audit.skill.md`. For automated audit, see `.agents/audits/bash-audit.skill.md`.

**Authoritative style guide:** [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) (google/shellguide). Where this document and the Google guide conflict, this document wins on project-specific conventions (e.g. `set -euo pipefail`, library `return`/`exit` discipline, the `|| true` / `|| rc=$?` failure-tolerant idioms in rule 4); the Google guide is authoritative for general bash style (naming, quoting, `local`/`readonly`, function and command-substitution form, flags, output to stderr). The Google guide is silent on the `set -e`/`pipefail` failure-tolerant-check idioms we rely on  --  those are governed here.

**Linting:** `shellcheck` is installed and run on scripts (see `scripts/run_tests.sh` and the bash-audit skill). Shellcheck warnings beyond documented `# shellcheck disable` disables are treated as defects. Shellcheck does not flag the `grep`-no-match / `|| true` class of `set -e` landmines  --  those are covered by rule 4 below and are caught by review, not the linter.

## 1. Language Rules

### 1.1 Makefile content: `printf`, not heredocs

Heredocs produce spaces when indented; `make` requires tabs. Always use `printf` with explicit `\t` for Makefile generation:

```bash
printf "\ntarget:\n\tcommand --flag=$(VAR)\n" >> Makefile
```

Verify with `cat -A`  --  tabs appear as `^I`.

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

Scripts that can be `exec`"d or sourced need to handle both:

```bash
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$_self/../.." && pwd)}"
```

### 1.16 No `local` at script top level

`p-24` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 1.17 Scope `|| true` to the command that needs it

`p-11` in [the failure handling patterns](../../workflow/coding-agent/skills/code-review/code-review-bash/patterns/failure-handling.md).

### 1.18 Shell option flags by file class

Every shell file declares its failure regime according to its class. The class is determined by how the file is consumed, not by where it lives.

| Class | Rule | Why |
|---|---|---|
| Orchestrator entry points (exec"d, no source-consumers) | `set -euo pipefail` at top | fail-fast beats continuing with partial state |
| Dual-use (exec"d in production, sourced by tests) | flags inside `main()` or the rule 1.11 guard only | a top-level `set` mutates the sourcing consumer"s shell |
| Pure libraries (sourced only) | never set options | inherit the consumer"s regime; per-function correctness via rule 3.1 and the rule 4 idioms |
| Observe-and-report (test files, harness runners, diagnostic sweeps) | no `-e`  --  must run all checks and count failures; `set -uo pipefail` preferred | first-failure abort defeats reporting (`run_test`"s NO-ASSERTION detection relies on observing failures) |

In the last row, weaker than `-uo pipefail` is permitted only with an inline rationale comment (e.g. the dry-run diagnostics: "Intentionally no set -u: env vars are checked explicitly with guards").

Notes:

- Direct execution of subcommand scripts is the rule 1.13 dispatch architecture, not an accident to be designed away.
- `-u` in library code would fire on consumer-controlled environments; libraries validate their inputs explicitly instead.
- A class change (e.g. a lib growing an entry point) means re-declaring flags for the new class as part of that change.

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

Do not add boolean/string mode parameters to a function unless at least one production call site passes a value that changes behaviour. A flag "for later" is dead API surface: it widens every signature it threads through, invites untested branches, and its eventual removal touches every file in between (`STRICT` and `AUTO_SELECT` were both removed for exactly this  --  see the 2026-08-21 loc-reduction campaign). When a mode is genuinely needed, add the parameter and the call-site change in the same commit.

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

ShellCheck parses any comment line whose first token after `#` is the word `shellcheck` as a directive. A prose line such as `# shellcheck absent -- rc 1` becomes a directive the tool tries to parse, failing the gate with SC1072/SC1073 that looks like a false positive until the directive rule is known. Word the line so the tool name is not the first token (for example "the shellcheck tool absent"). Real directives (`# shellcheck disable=SCxxxx`, `enable=`, `source=`) are exempt. The gate's prose-comment pass (`scripts/check_shell.sh`) enforces this rule.

### 4.7 A process scan must not match the scanning shell

A scan for a process by name matches its own command line, because the pattern text is in the scanner's arguments: a loop that feeds the matching pids to `kill` signals itself, and the calling tool dies with 143. Match on the executable as well as the argument (`node\ *server.mjs`), and exclude the current pid. `pkill` is absent from the runtime image, so a cleanup that uses it removes nothing and reports no error; when the cleanup holds a port, verify the port is closed rather than read the kill as success.

## 5. Cross-References

| Source | Relationship |
|---|---|
| `interface-conventions.md` | CLI/TUI/API rules (this doc covers bash, not interface) |
| `.agents/skills/testing/SKILL.md` | Test judgements and patterns |
| `test_harness_mechanism.md` | The suite's runner, contract and gates |
| `.agents/audits/bash-audit.skill.md` | Automated audit skill |
| `devlog/AGENT_FEEDBACK.md` Gotchas section `[O]` | Original `exit` vs `return` finding |
| `devlog/AGENT_FEEDBACK.md` Bash section | Historical bash friction records |
