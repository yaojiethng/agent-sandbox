# Skill — Bash Audit

Audit bash code against the rules in
[`bash-coding-conventions.md`](../../../../docs/development/bash-coding-conventions.md).
One-line findings, ranked by impact. Read-only, one-shot.

## Tags

| Tag | Rule violated | Replacement |
|---|---|---|
| `exit-in-lib:` | `exit` in sourced library function | `return 1` |
| `unquoted:` | unquoted variable expansion | `"$var"` |
| `heredoc-make:` | heredoc for Makefile content | `printf` with `\t` |
| `local-top:` | `local` at script top level | plain assignment |
| `export-leak:` | unnecessary `export` of behaviour flag | CLI flag |
| `source-cycle:` | circular sourcing between libs | extract to shared leaf lib |
| `subshell-pitfall:` | `|| true` on whole pipeline | subshell scope `(cmd \|\| true)` |
| `shrink:` | same logic, fewer lines | show shorter form |
| `stdlib:` | hand-rolled thing bash builtins cover | name the builtin |

## Hunt

Bare `exit` in `src/libs/` and `src/build/`, unquoted expansions, heredocs
generating Makefile content, `local` at top level, `export` of behaviour
flags, `|| true` on pipelines, circular source paths.

## Output

One line per finding, ranked by impact: `<tag> <what to cut>. <replacement>. [path:line]`.
End with `net: -<N> issues found.` Nothing to cut: `Clean. Ship.`

## Boundaries

Scope: bash coding-conventions violations only. Correctness bugs, security
holes, and performance are out of scope. Lists findings, applies nothing.
One-shot.
