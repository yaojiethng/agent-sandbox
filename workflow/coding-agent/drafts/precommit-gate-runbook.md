---
description: "Braindump for a runbook that adds, amends and retires a lint gate. Draft; refinement happens in M3.1.2."
---

**Status:** draft. This is a dump, not a runbook. Refinement happens in M3.1.2, under the task "formalize the procedure for adding, amending or removing a pre-commit gate".

# Pre-commit and lint gate maintenance - braindump

Sources: the three reflection reviewers of 2026-10-02 (`judgment`, `tooling`, `divergent`, run over that session's digest), the decisions they proposed, and what this repository's gates look like today. Where a proposal is still a proposal it says so. Nothing here is a rule; the rules live in [`docs/development/bash-coding-conventions.md`](../../../docs/development/bash-coding-conventions.md), [`docs/adr/git_hooks.md`](../../../docs/adr/git_hooks.md) and [`.markdownlint-cli2.mjs`](../../../.markdownlint-cli2.mjs), and M3.1.2 decides what moves where.

## 1. What exists today

| Surface | Where | What it does |
|---|---|---|
| Copy-delivery hook | `src/capability/git-hooks/pre-commit.sh` | Markdown and ShellCheck over the staged set; blocks the commit. Mount delivery installs no hook, because its `.git` is a host directory ([`git_hooks.md`](../../../docs/adr/git_hooks.md)) |
| Host hook install | `scripts/manual/install_host_git_hooks.sh` | gives the host checkout the same gate |
| Lint umbrella | `scripts/lint.sh` | five gates run concurrently: shell, lib-contract, markdown, prompt frontmatter, legacy wrap |
| Markdown gate | `scripts/check_markdown.sh` | markdownlint-cli2 over the tree; owns the record-links rule, the doc-wrap rule and the unresolved-rule warning |
| Custom rules | `scripts/lint/*.mjs` | `doc-ascii`, `doc-wrap`, `record-links` |
| Exclusions | `.markdownlint-cli2.mjs` | one `recordTrees` list, read by two rules; a per-rule `legacyFiles` list that expires on the next edit |

## 2. The proposals

### 2.1 A gate is a rule inside the tool that owns the config

*Proposal (`judgment`).* "Express a repository gate as a rule inside the tool that already owns the config, not as a script that shells out to that tool. A wrapper inherits config discovery, path resolution, and ignore semantics it does not control, so single-file and tree runs diverge and the divergence is not debuggable from inside the wrapper."

This session paid for it: the first link gate was a bash wrapper around markdownlint-cli2, and its results disagreed between a single-file invocation and a tree run because the tool merges `--config` with whatever it discovers from the working directory. The wrapper was deleted. The markdownlint rule that replaced it has no such surface.

*Open for M3.1.2:* the bash gates (`check_shell.sh`, `check_lib_contract.sh`, `check_prompt_frontmatter.sh`) still shell out. Is a rule the right form for them too, or is the line between a gate that owns a tool and a gate that drives one worth stating?

### 2.2 Legacy state in a gate is declared data with an expiry

*Proposal (`judgment`).* "Name the exempt set in the gate's own config, print its size on every run, and expire an exemption when its file is next edited, so 'grandfathered' is a shrinking visible list rather than a permanent hole."

Shipped in two forms, and the difference matters. `legacyFiles` expires: `doc-wrap` reads `DOC_WRAP_ENFORCE`, and `check_doc_wrap_legacy.sh` passes the changed set, so the commit that touches a file clears it. `recordTrees` does not expire: three closed-record trees, 652 files, exempted outright.

*Open for M3.1.2:* the tree list has no owner and no end, and it holds 1,195 dead links the count does not measure. Either it earns an end, or the runbook says plainly that a tree is permanent and the debt inside it is accepted.

### 2.3 One setting, one key

*Proposal (`judgment`).* "A rule reads its scope from the config; it never keeps a private copy of the list, because two copies always diverge and the divergence is invisible until a run silently exempts the wrong tree."

Shipped, after shipping the opposite: `grandfatherTrees` and `ignoredRoots` held the same list and had already drifted. One `recordTrees`, declared once, referenced by every rule that exempts, and exported so the gate's coverage line reads the same declaration.

### 2.4 A bulk restore voids what you concluded from that file

*Proposal (`judgment`).* "Every conclusion already drawn against that file is void, not only future ones - re-derive before the next measurement."

The cost this session: `git checkout .markdownlint-cli2.mjs`, run to recover a fixture, silently dropped `doc-wrap.mjs` from `customRules`. Every measurement taken afterwards was of a gate that no longer ran the rule, and several turns went into explaining the discrepancy. This is a recurrence of `[A] 2026-08-10` in [`devlog/AGENT_FEEDBACK.md`](../../../devlog/AGENT_FEEDBACK.md), whose prescription is temp copies.

## 3. The mechanics, as measured

*Proposal (`tooling`), each verified against markdownlint-cli2 0.23.2 / markdownlint 0.41.1 in a scratch config:*

- Config `globs` are **added to** the command-line globs, never replaced. `markdownlint-cli2 'sub/b.md'` lints `sub/b.md` **and** everything the config globs match. `--no-globs` suppresses the config's.
- `--config <file>` does not replace the configs the tool discovers by walking up from the working directory; both are merged. Paths inside a config (`customRules`, `globs`, `ignores`) resolve against **that config file's** directory, not the cwd.
- Under `default: false`, a rule named in `config` but absent from `customRules` never runs and reports nothing. `doc-wrap` sat in that state for the life of the config. `check_markdown.sh` now warns; the assertion is a warning, not a block.
- Built-in `MD051` validates same-file fragments only, and no built-in rule tests that a relative target exists. A custom rule is genuinely required for link checking, and the only correct fragment algorithm is the forge's: lowercase, drop everything that is not a letter, digit, space, hyphen or underscore, one hyphen per space.
- A custom rule receives `params.name` as relative or absolute depending on the invocation, and `params.config` is only that rule's own entry. Normalise with `relative(process.cwd(), resolve(String(params.name)))`, and give directory exclusions a trailing slash because the test is `startsWith`.
- There are no per-rule CLI options, so the only seam for per-run behaviour is `process.env` inside the rule. `DOC_WRAP_ENFORCE` is that seam.
- The tool's own `Linting: N file(s)` line is the only trustworthy "the gate ran" signal; exit 0 with `Linting: 0` means nothing was checked.
- This repository's convention: one setting, one home. A shared list is declared once as a named export in `.markdownlint-cli2.mjs`, referenced from each rule's entry, and read back from bash with `node --input-type=module -e 'import settings ...'`.

## 4. The procedure this runbook would carry

*Proposal (`judgment` and `divergent`), stated as steps and not yet ratified:*

1. **Decide where the check belongs.** A rule inside the tool that owns the config, or a gate that drives a tool. One line in the conventions doc settles it.
2. **Write the rule or the script.** Fail closed when a dependency is missing; never report "clean" over an empty set.
3. **Register it**, in the tool's own registration list, not only in the config.
4. **Assert the registration.** A rule that is enabled and unregistered is a silent no-op; the Markdown gate warns, and the runbook says what to do when it fires.
5. **Scope it explicitly.** One key, declared once. An exemption that names a tree is a claim about that tree; write the claim down with a reason and, if it is temporary, an end.
6. **Give every exemption an expiry** or say in writing that it has none.
7. **Test it with fixtures**, not against the real tree: a passing case, the failure it catches, and the closed- and fail-closed paths.
8. **Measure it**, on the set it will actually run over -- staged files for the hook, the tree for a lint gate -- and write the number where the next agent will read it.
9. **Update the records that name it**: the conventions table, the ADR, and the roadmap row.

## 5. What this session cost without the runbook

- `doc-wrap` enabled and unregistered, silent, for the life of the config.
- Two exclusion keys for one setting, drifted before anyone read the other.
- A wrapper gate whose results depended on the working directory, deleted after hours.
- Eleven days of tests that mutated the repository's own gate config, because the config was simultaneously the source of truth and the fixture.
- A `check_markdown.sh` count that matched only `MD`-prefixed findings, so 1,902 errors printed as `markdownlint: 0 finding(s)`.

## 6. Open for M3.1.2

- One script with five gates, or one script per gate? The umbrella's concurrency is the argument for one; the per-gate test seams are the argument for five.
- Where does the timing budget live? The 2026-09 study measured about 30 seconds for `lint.sh`, dominated by one `shellcheck` pass over every tracked file; the parallel-shellcheck change landed the same day. Today the umbrella is about 5 seconds in this container. Nothing states what it should be, so nothing says when it has regressed.
- Should the hook and the lint gates share one procedure, or are they different enough to need two? The hook runs on staged files and can be bypassed; a lint gate runs on the tree and cannot.
- The unresolved-rule warning: warn or block? It warns today, on the argument that a warning which blocks every commit over a naming slip teaches people to skip it.
