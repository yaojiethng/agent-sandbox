# CLI to Workflow Interface

**Status:** draft - first write, not yet reviewed. Awaits the operator's decision.

**Scope:** the contract between the front door `scripts/agent-sandbox.sh` and the scripts it runs, one subcommand per invocation. On the workflow side: `scripts/workflows/{apply,draft,confirm,reject,interactive}.sh`, `scripts/{onboard,build,stop,prune}.sh`, `scripts/resume_agent.sh`, `scripts/start_agent.sh` (serving `start` and `dry-run`), and `src/libs/package_branch.sh` (serving `package-branch`). Outside this note: the parser's own flag surface and the Makefile template's translators, which [`command_flag_parsing.md`](../../docs/adr/command_flag_parsing.md) owns; what a workflow does after it starts; and the setting-declaration question, which the resolver contract note holds in [`20260924-design-draft-resolver_contract.md`](20260924-design-draft-resolver_contract.md).

## Context

The boundary is a router and a set of exec calls. `scripts/agent-sandbox.sh` parses its own four flags (`--env`, `--name`, `--project`, `--sandbox`), resolves the session identity, and replaces itself with the script that implements the subcommand through `exec bash <path> <flags> "${PASSTHROUGH[@]}"`. Nothing returns: the workflow's process becomes the operator's process, so the workflow's exit status is the command's exit status and the workflow's stdout and stderr are the command's streams.

The subcommand set appears in three literal lists in one file, and two of them already disagree: `print_subcommand_list` (l.89) names twelve; the usage line printed for a missing subcommand (l.133) names eleven and omits `package-branch`; the dispatch `case` (l.163 to l.270) implements twelve. The help router `route_help` (l.97) is a fourth copy, in case-arm form.

The name-to-implementation map is expressed twice, once for help and once for dispatch, and it uses four different path shapes. The lifecycle verbs live at `$SCRIPTS/<name>.sh`, `resume` at `$SCRIPTS/resume_agent.sh`, the four diff workflows at `$SCRIPTS/workflows/<name>.sh`, `start` and `dry-run` at `$SCRIPTS/start_agent.sh`, and `package-branch` at `$AGENT_SANDBOX_REPO/src/libs/package_branch.sh`. The last one is a library that also serves as a subcommand, which is why the mapping needs a fourth shape and why the library gates treat it as a library.

Identity is resolved at the interface and then passed as explicit flags, and the resolution differs per branch. `resolve_identity` wraps `env_resolve_identity`, and the branches call it with four different argument sets: `name dir sandbox` for `build`, `start`, `dry-run`, `stop` and `prune`; `sandbox` for `resume` and `package-branch`; `dir sandbox` for the four workflows; and `onboard` calls `require_base_args` instead. The forwarded flag set differs with it: the lifecycle verbs pass all three identity flags, the four workflows pass `--project` and `--sandbox`, `package-branch` passes `--sandbox` alone, and `onboard` forwards all three but resolves them by requirement rather than by resolution. `--env` is different: the interface consumes it for identity resolution, and forwards it to exactly the two leaves whose parse specs accept it - `start_agent.sh`, which serves both `start` and `dry-run`, and `resume_agent.sh`. No workflow and no lifecycle leaf accepts it (their specs carry no `--env`), and only `onboard.sh` uses `ENV_FILE` at all, so the variation follows the leaf's own contract rather than an omission. The workflow then re-parses what it received with `parse_args` and re-validates it with `check_base_flags`, and `stop.sh` and `prune.sh` canonicalise the sandbox path a second time. Row 48 records the arithmetic: three passes over four values.

Each workflow resolves its own helpers. A workflow derives the repository root from its own path depth (`AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-...}"` around a file-local `_<name>_self`), sources its own set of three to seven libraries, and states its dependencies as prose in its header. `scripts/workflows/apply.sh` is representative: `Depends on: AGENT_SANDBOX_REPO, src/libs/diff.sh, git, standard shell utilities`, followed by four source lines.

Because the handoff is `exec`, the boundary carries the workflow's verdict unchanged. The help surface shows what that means in practice, and it is inconsistent today: `agent-sandbox help` exits 0, `agent-sandbox help <sub>` and `agent-sandbox <sub> --help` exit 2, and `agent-sandbox --help` exits 1 with the message `Unknown subcommand: --help`. The parser's in-process help status is 2 by design, and each caller was meant to map it; the mapping lines are unreachable under `set -euo pipefail`, which is row 130. The top-level flag never reaches the help router, which is row 136.

### Consolidated issues

This note collects the read-through findings that belong to the boundary. Rows marked new were found while assembling this note; the rest are already in the findings table and keep their numbers.

| Issue | Where it shows | Row |
|---|---|---|
| Three passes over four identity values | dispatcher `parse_args_collect` plus `env_resolve_identity`, then the workflow's `parse_args` plus `check_base_flags`, then `sandbox_dir_canon` in `stop.sh` and `prune.sh` | 48a |
| The help verdict exits 2 | six callers' normalisers are dead under `set -e`; the parser-side statuses are recorded in `command_flag_parsing.md` | 130 |
| The dispatcher's `--help` is an unknown subcommand | the flag sits in the subcommand slot, which `shift` removes before the help scan | 136 |
| The subcommand set is declared three times, and two copies disagree | `print_subcommand_list` (twelve), the usage line (eleven, no `package-branch`), the dispatch case (twelve); the list's content is asserted nowhere, so a divergence is invisible to the suite | new, 200 |
| The name-to-implementation map uses four path shapes, one of them a library file | `route_help` and the dispatch case, each listing the shapes independently | new |
| The forwarded identity flag set varies per branch | the twelve dispatch arms; the variation follows each leaf's own parse spec, and `--env` reaches the two leaves that accept it; the arms' declared subsets are unobservable, in three directions at once, and a leaf can require a flag it never reads (`apply.sh` requires `--sandbox` and uses only `--project`) | new, 205, 206, 219 |
| Each workflow re-derives the repository root and sources its own helper set, declared as prose | the workflow headers' `Depends on:` lines and their source blocks; the interface's own root derivation is never exercised, because the harness presets the variable it computes | new, 208 |
| The help router duplicates the dispatch map | `route_help` for `--help`, `help <sub>`, and `help --help`; its `resume` arm is the one shape whose file name differs from the subcommand, it is absent from the help test table, and pointing it at a non-existent file fails no unit; the `-h` alias is unpinned, and the help scan is pinned only in its first-argument form | new, 199, 201, 204 |
| The router's own error outcomes are uneven and unasserted | the empty-subcommand guard's `exit 1` has no unit, while the unknown-subcommand arm's status is pinned by the removed-verb unit; the unknown-subcommand message goes to stdout while `route_help`'s goes to stderr, and no unit asserts which | 202, 203 |
| A shared interactive helper lives in a workflow file, sourced at the point of use | `interactive_confirm_or_abort` is defined in `scripts/workflows/interactive.sh` and sourced inside a branch by five callers, three of them outside the workflow bundle | 148 |

## Options Considered

### Option area 1 - resolving a subcommand name to its implementation

This is the interface side of helper resolution: given a name, where is the script, and who says so.

**Option A - the status quo.** Two case blocks hold the mapping, a third statement holds the name list, a fourth holds the usage line. The cost is visible already: the usage line omits `package-branch`, the help page can drift from the dispatch table independently, and a new subcommand must be added in four places. The drift is also unguarded: no unit asserts the list's content, so removing an entry fails nothing (row 200).

**Option B - one declared table.** One associative array maps each name to its script path, its aliases, and its one-line description; the usage line, the help page, and the dispatch lookup all read that table. `package-branch`'s entry names its `src/libs/` path like any other entry, and the fourth path shape stops being a special case in two case blocks. Cost: the table is data that a reader must trace, where a case statement reads as prose, and the alias words (`start` and `dry-run` sharing one script, `resume` mapping to `resume_agent.sh`) need a shape in the table.

**Option C - the table plus convention discovery.** The table holds the exceptions (the lifecycle verbs, `package-branch`, the aliased pair) and the default rule is a file named after the subcommand in `scripts/workflows/`. Cost: a missing file becomes an exec failure rather than a routing error unless the router checks existence first, and the rule is implicit for the next reader.

### Option area 2 - how the interface hands off to a workflow

**Option A - the status quo.** `exec bash <path> <some identity flags> "${PASSTHROUGH[@]}"`, with the subset varying per branch as the context describes. A leaf can also require a flag it does not read: `apply.sh` refuses a call without `--sandbox` and then never mentions the value (row 219), so the declared set is a claim about the caller rather than about the work.

**Option B - one handoff form.** The interface resolves the implementation and execs it with the full identity set in one fixed order, followed by the forwarded remainder. Every workflow then sees the same argument shape, and the difference between branches becomes data rather than code. Cost: a workflow that does not need a flag must tolerate it, which the parser already supports through the accept-and-ignore literal form.

**Option C - the interface stops resolving identity.** It forwards the operator's arguments untouched and every workflow resolves identity through the shared helper. This is the same choice as Option C of area 4 seen from the handoff side. Cost: the interface stays a pure router, but each workflow keeps identity knowledge, and `check_base_flags` stays duplicated at every leaf.

### Option area 3 - helper resolution on the workflow side

**Option A - the status quo.** Every workflow derives the repository root from its own path depth and sources its own set, with the dependency list as prose in the header. The cost is that the two spellings of the root (`AGENT_SANDBOX_REPO` from the interface's environment and the same name defaulted from the file's own path) have to agree by convention, the prose dependency list cannot be checked, and neither side is covered: the interface's own derivation is never exercised, because the test harness presets the variable it computes (row 208).

**Option B - one entry helper.** A workflow sources one file that resolves the repository root and the helper set it needs, so its dependency list is executable. Cost: one indirection at every entry point, and a workflow with an unusual dependency still names it separately.

**Option C - make the dependency list data that the gates read.** The header's `Depends on:` line becomes a machine-readable element that `check_lib_contract.sh` or `check_shell.sh` verifies against the source block. Cost: the gates gain a parser, and the drift is documented rather than removed.

### Option area 4 - who resolves identity, and how many times

**Option A - the status quo.** The interface resolves, the workflow re-parses and re-validates, and two workflows canonicalise again. The redundancy is deliberate in part: `check_base_flags` is what protects a workflow invoked directly by a test or by hand.

**Option B - resolved once at the interface.** The workflow validates nothing and treats the passed flags as truth. Cost: direct invocation loses validation, which is the case `check_base_flags` exists for.

**Option C - resolved once at the leaf.** The interface forwards the operator's flags untouched and every workflow resolves through the shared helper. This is the unification the resolver contract note also asks for, and it removes the second and third passes rather than moving them. Cost: the interface can no longer fail before it execs, so a usage error surfaces from the workflow's process instead of the router's.

### Option area 5 - the verdict across the boundary

**Option A - the status quo.** Because the handoff is `exec`, the workflow's status is the command's status. Nothing is wrong with that for a workflow's own verdict. It is wrong for the boundary's own outcomes: help is a success and exits 2, and the top-level flag exits 1.

**Option B - the interface owns the boundary verdict.** The parser keeps its in-process status, one helper maps it, and the process exits 0 for help, 1 for a usage error, and the workflow's verdict otherwise. Rule 3.2 of `bash-coding-conventions.md` names this preference directly: a caller that would otherwise switch on several codes is better served by one helper, and repeated `case` statements at call sites are the alternative to avoid. Cost: one place changes instead of six, and the six per-caller normalisers are deleted.

## Decision

Recommended, not yet taken.

1. **Option area 1: Option B.** One declared table is the only form in which the name set, the aliases, and the script paths cannot disagree, and the existing disagreement between the usage line and the list shows the cost of leaving them separate.
2. **Option area 2: Option B.** A single handoff form makes the boundary readable and testable, and it removes the per-branch identity subsets that no reader can hold in mind.
3. **Option area 3: Option B, as a smaller follow-up.** One entry helper is a real improvement, but it touches every workflow and nothing depends on it yet. Option C is worth revisiting if the prose lists drift.
4. **Option area 4: Option A now, with Option C as the target.** Keeping `check_base_flags` at the leaf preserves direct invocation, while the interface's identity subsets become uniform under decision 2. Option C waits for the resolver contract note.
5. **Option area 5: Option B.** The verdict belongs to the process that owns the boundary, and the parser's statuses are recorded in `command_flag_parsing.md` rather than in this note.

## Consequences

Enables: a single place to add a subcommand; a help page that cannot disagree with the dispatch table; one argument shape at every workflow entry; and a boundary whose outcomes have defined exit codes.

Does not do: it does not settle the parser's own flag spec or the Makefile translators, which stay with `command_flag_parsing.md`; it does not remove `check_base_flags` from the leaves under decision 4; and it does not change what any workflow does after it starts.

Cost: the declared table replaces two case blocks that read as prose, so the change trades local readability for one source of truth. The uniform handoff gives every workflow three identity flags it may not use.

Risk: the boundary is what every CLI invocation crosses, so the change must keep the existing surfaces byte-identical where the suite pins them - the help text, the unknown-flag wording, and the dispatch oracle in `test_dispatch.sh` are the pinned surfaces named in `command_flag_parsing.md` R2.

Record: the principles this note would settle are boundary principles, so their home is `docs/adr/command_flag_parsing.md` while they govern the parser's surface, and a new ADR only if the router's shape proves to govern more than one local choice. Implementation needs its own handover; this note is a design record only.
