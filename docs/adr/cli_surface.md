# The CLI Surface

**Current:** 2026-11-22

The CLI surface is the `agent-sandbox` front door, the leaf command behind each subcommand, and the contract the two share: which subcommands exist and where they live, how a leaf reads its flags, what a leaf takes from the identity, and what a call exits with.

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Single parse path | Every command parses its flags through one declarative parser, not per-script `for ARG` loops |
| R2 | Exact surface preserved | Each leaf keeps its historical flag names, defaults, help text, and unknown-flag wording; the suite pins them |
| R3 | Identity stays shared | `--name`/`--project`/`--sandbox` parse through the shared base-flag helper, never re-implemented per script |
| R4 | Validation stays explicit | Flag-specific validation (e.g. `--delivery` allowed values) runs after parse, at the owning script, not inside the parser |
| R5 | Forwarding is explicit | The dispatcher collects passthrough args and forwards them to the leaf; no env-var smuggling of command input |
| R6 | A flag's shape matches its spec | A value flag with no `=` and a boolean flag with one are not matches; the mode's unknown-argument policy decides their fate (2026-09-25) |
| R7 | One declaration | A subcommand's name, leaf path, identity fields, leading arguments and one-line summary appear once, in the catalog; the list, the help index, the no-argument message and the dispatch derive from it (2026-11-22) |
| R8 | JSON is a rendering | `agent-sandbox help --json` prints the catalog as JSON; no manifest file and no generated artifact exists, so nothing drifts (2026-11-22) |
| R9 | One status map | The parse's status (0 parsed, 1 usage error, 2 help) maps to the process status in one function: help is success, a usage error is 1 (2026-11-22) |
| R10 | Help is the leaf's | `--help` routes to the child's own page and exits before its flags are required; the dispatcher duplicates no help text, and `help` is itself a subcommand (2026-11-22) |
| R11 | The exit code is a verdict | `0` success, `1` user error, `2+` system error; a magnitude never rides in the code (2026-11-22) |
| R12 | The record path is absolute | `default_env_file` normalizes every branch and the resolver exports `ENV_FILE` as an absolute path, so the resolver and the process it hands the path to name the same file (2026-11-23) |
| R13 | The dispatcher hands over resolved argv | The leaf receives the row's leading argument first, the resolved identity by value, the normalized absolute `--env`, and the passthrough arguments; an explicit empty env ref is empty rather than a fallback (2026-11-23) |

## The resolution and dispatch contract

The contract is stated once here; the gate names the carrier that enforces each row.

| # | Invariant | Owner | Gate |
|---|---|---|---|
| C1 | A row that declares `env` uses the identity resolver, so `ENV_FILE` exists. | catalogue | `tests/test_resolution_contract.sh` |
| C2 | A leaf named by an `env` row accepts `--env`. | leaf parse spec | `tests/test_resolution_contract.sh` |
| C3 | The dispatcher forwards `--env=$ENV_FILE`, never `--env=$ENV_REL`. | dispatch | `tests/test_agent_cli_dispatch.sh` |
| C4 | `default_env_file` returns an absolute path for every branch. | resolver | `tests/test_env_resolve.sh` |
| C5 | An explicit empty env ref is empty; only an omitted one falls back to `ENV_REL`. | resolver | `tests/test_env_resolve.sh` |
| C6 | The leaf receives the row's leading argument first, the resolved identity by value, and the passthrough arguments after the declared ones. | dispatch | `tests/test_agent_cli_dispatch.sh` |
| C7 | A relative `--env` with no explicit sandbox bootstraps `SANDBOX_DIR` from the CWD record, then opens the record the ref names. | resolver | `tests/test_env_resolve.sh` |

## 2026-11-23 -- The dispatcher hands over resolved argv

**Decision:** `dispatch` resolves the row's identity before it builds the forwarded flags, then `exec`s the leaf with the row's leading argument, the resolved `--name`/`--project`/`--sandbox`, the normalized absolute `--env`, and the operator's passthrough arguments. `env_resolve_identity` treats an explicit fourth argument as authoritative even when it is empty; only an omitted argument falls back to the caller's `ENV_REL`.

**Rationale:** the leaf is a new process, so the dispatcher's record view does not cross the boundary; the argv is the contract. Forwarding the raw path made the leaf resolve the path a second time, and a relative sandbox let that second resolution disagree. The `ENV_REL` fallback also shadowed the forward: replacing the argument with an empty string still read the global, so no test could tell whether the forward existed.

**Rejected alternatives:** override `exec` in a sourced shell -- rejected: it stops one step short of the process boundary the contract describes. Pass a snapshot of every record value by value -- rejected: the dispatcher would have to know every leaf's settings, and `run_agent` still reads keys the dispatcher does not own.

**Edge cases / drivers:** a row that declares `env` must use the identity resolver, because `ENV_FILE` is what resolution exports. A row that declares no `env` forwards no path. The fixture-root test runs the real dispatcher and a stub leaf, so the assertion is on the argv the leaf process receives. Mutation rows D11-D13 prove the leading argument, the resolver's env ref and the normalized path are each load-bearing.

Implementation: `scripts/agent-sandbox.sh` (`dispatch`), `src/libs/env_resolve.sh` (`env_resolve_identity`), `tests/test_agent_cli_dispatch.sh`, `tests/test_env_resolve.sh`, `tests/mutations/catalog.jsonl`.

## 2026-11-23 -- The record path is absolute

**Decision:** `default_env_file` returns an absolute path for every branch. An absolute `--env` is used as-is; a relative `--env` is a name under `SANDBOX_DIR`; an empty one falls back to `<sandbox>/.env`, then the invocation CWD's `.env`. The helper canonicalizes through `readlink -f` when the path resolves, and otherwise anchors a relative path at the invocation CWD. `env_resolve_identity` exports the result as `ENV_FILE`.

**Rationale:** the resolver selected a path, then handed callers a spelling that each consumer had to resolve again. A relative `SANDBOX_DIR` produced a relative `ENV_FILE`, so the leaf could re-resolve the path through its own CWD and read a different file. Path selection and path normalization belong at the one site that owns the selection.

**Rejected alternatives:** normalize only in the dispatcher -- rejected: every other caller of `env_resolve_identity` would keep the weaker guarantee, and the dispatcher would become a second path owner. Require every caller to pass an absolute `--sandbox` -- rejected: it narrows an accepted input to protect an internal invariant.

**Edge cases / drivers:** a path whose parent does not exist is still absolute, because a specified path's absence is reported by its reader rather than by path construction. The `test_env_resolve.sh` cases pin the relative-under-relative-sandbox case, the CWD fallback and the absolute input. `resolution_model.md` keeps the historical precedence entry and points here for the normalization rule.

Implementation: `src/libs/env_resolve.sh` (`_env_abs_path`, `default_env_file`), `tests/test_env_resolve.sh`.

## 2026-11-22 -- The subcommand surface is a catalog, and JSON is its rendering

**Decision:** The dispatcher holds one catalog row per subcommand: its name, leaf path, the identity fields the leaf accepts, any leading argument the dispatcher passes, and its one-line summary. The valid-subcommand list, the `help` index, the no-argument message, the help routing and the dispatch all derive from that table, so a subcommand is added in one place. `agent-sandbox help --json` renders the same rows as JSON, under a `schema` key, for a consumer that reads programmatically. The parse's status maps to the process status in `parse_args_or_exit`, one function in `src/libs/cli.sh`; a leaf calls it instead of spelling the mapping.

**Rationale:** The front door carried four descriptions of one set, and they had already diverged -- the no-argument message omitted `package-branch` while the help page and both dispatch arms carried it. The identity flag set was spelled once per case, twelve times, and the help-status policy was spelled eighteen times across seventeen files in two forms. A set that is described four times drifts four ways, and the drift is invisible because each description looks authoritative where it sits.

**JSON is a rendering, not a manifest.** The facts live in bash, where the CLI already runs, and JSON is printed on demand. A manifest file would need a reader on the operator's path, and a committed rendering would need a gate to catch its drift; the rendering has neither cost. `scripts/build_probe.sh` already writes JSON this way, escaping where it writes, so the rendering needs no reader and no new dependency.

**Why the flags stay out.** A leaf's `parse_args` spec is its flag source, pinned by R2. A catalogue copy would be the second declaration this entry exists to remove, and the dispatcher does not need flags: it forwards them and the leaf rejects what it does not accept. The catalog names the leaf, so a consumer that needs flags runs that leaf's `--help`.

**Rejected alternatives:**

- *A manifest file with a reader, like `src/build/record-layout.json`* -- rejected: that pattern serves build and gate time, where node is present. The CLI runs on the operator's host, and every manifest reader in the tree is node. A manifest would put a new dependency on the one path that has never had one.
- *One table inside the dispatcher, with no JSON* -- rejected: the surface is the natural index for a consumer that is not bash, and the rendering is twelve lines over the same rows.
- *Deep help: the catalog carries every flag* -- rejected: about seventy flags across eleven leaves, duplicated from specs R2 already pins, held equal by a bidirectional gate, for a consumer that does not exist yet. The JSON shape is additive, so a `flags` key can be added when a consumer needs one.
- *A new ADR per subject, one for the catalog and one for the status map* -- rejected: it is the sprawl this consolidation exists to end. Both govern the same surface, so they are requirements on one record.

**Edge cases / drivers:** the no-argument message and the `help` page must print the same set, and the gate asserts it from the CLI rather than from the table. A declared identity field must appear in its leaf's own `--help` output, so the table cannot claim a field the leaf does not accept; the summary is the catalog's own index sentence, because a leaf's first usage line is its `Usage:` line and an index sentence is not a copy of anything. An unknown subcommand exits 1 and names itself; a leaf's exit status reaches the caller unchanged, because the dispatcher `exec`s it and never wraps it.

Implementation: `scripts/agent-sandbox.sh` (the catalog and its derived surfaces), `src/libs/cli.sh` (`parse_args_or_exit`), tests `tests/test_agent_cli_dispatch.sh` and `tests/test_cli_lib.sh`.

## 2026-09-25 -- A flag's shape must match its spec: a bare value flag is a rejected input

**Decision:** A spec entry's kind and the argument's shape must agree. `_cli_parse` treats a value flag written without `=` (`--env`) and a boolean flag written with one (`--yes=true`) as *not a match*: it clears the entry and lets the mode's unknown-argument policy decide the argument's fate. `parse_args` therefore rejects a bare value flag with `Unknown argument: --env` and rc 1, leaving the target variable unset; `parse_args_collect` forwards it to the sink unchanged for the leaf to reject; tolerant mode warns and drops it.

**Why it supersedes the 2026-09-19 edge case:** the 2026-09-19 entry recorded that a bare value flag "is consumed with an empty value, the same final leaf state as before". The implementation did neither: `${a#*=}` on an argument with no `=` returns the whole string, so `declare -g "$var=${a#*=}"` assigned the flag's own name as the value. The path is reachable and fail-open. `parse_args u --name=PROJECT_NAME -- --name` set `PROJECT_NAME=--name` and returned 0, and in `prune.sh` a missing `--age-days` value reached `date -d "--age-days days ago"`, failed, produced an empty cutoff, skipped the age filter, and selected every stale record instead of only those older than the default. Rejecting an unusable shape is both the smaller contract and the fail-closed one.

**Rationale:** a flag's shape is a contract, not a hint. Reading an absent value as the flag's name is a silent misconfiguration in every caller, and the thirteen `parse_args` callers cannot each defend against it. Deciding the fate of a mismatched shape in the mode's existing unknown-argument policy keeps one rule rather than three: the parser says "not a match", and strict, tolerant and collect each answer as they already do for an unknown word.

**Rejected alternatives:** assign an empty value, the recorded intent - rejected: a bare `--age-days` would still yield an empty cutoff and the same fail-open selection of every record, so it silences the misconfiguration instead of reporting it. Consume the following argument as the value, the GNU long-option convention - rejected: it steals the next positional token, which in collect mode is forwarded verbatim, and it makes a trailing bare flag undetectable. Validate in each caller - rejected: thirteen callers would re-implement a rule the parser already holds in the spec's kind.

**Edge cases / drivers:** R2's exact-surface requirement still holds and the suite pins it: `tests/test_cli_lib.sh` covers a rejected bare value flag, a forwarded one in collect mode, and a boolean flag carrying a value. A leaf that accepted a bare value flag as empty now rejects it; no caller relies on the old form. The `prune.sh` half of the original finding, numeric validation of `AGE_DAYS`, is a separate fail-closed item and is not part of this entry.

Implementation: `src/libs/cli.sh` (`_cli_parse`), tests `tests/test_cli_lib.sh`.

## 2026-09-19 -- Collect mode: the dispatcher joins the canonical parser

**Decision:** `src/libs/cli.sh` exposes one implementation, `_cli_parse MODE USAGE_FN SINK_VAR spec... -- args...`, and two policy wrappers over it: `parse_args` (strict leaf parse) and `parse_args_collect` (forwarding parse for entry points). The `agent-sandbox.sh` dispatcher parses through the collect wrapper with a four-flag spec (`--env`, `--name`, `--project`, `--sandbox`) and forwards the collected remainder to the leaf; its hand-rolled PASSTHROUGH loop and its `parse_base_flags` call are retired. All parse state is local to the call: the spec registry is a local associative array inside `_cli_parse`, so a parse can never observe another parse's registry and no module-level registry survives. `--help`/`-h` is handled inside `_cli_parse` for the leaf modes and left to the caller in collect mode: the dispatcher owns help routing and scans its args itself before dispatch (unchanged).

**Why it supersedes the 2026-09-18 rejection:** the rejection stood on "no routing gain" and "the parser would grow machinery". A collect mode is now part of the parser because the shared implementation keeps it small, and the front door was the last entry point outside the canonical shape (R1). R5 still holds: forwarding is explicit, through the named sink array, and no env-var smuggling of command input occurs. The 2026-09-18 entry remains the record for the leaf surface.

**Rationale:** one parser semantics across all entry points; the dispatcher spec line reads as a table of the front door's own flags (identity + `--env`); future flag shapes added to the parser apply to the front door as well. Operator behavior is byte-identical (parity contract; the dispatch oracle suite pins it - unchanged `tests/test_dispatch.sh` cases remain green, plus a new order/passthrough case).

**Edge cases / drivers:** a bare value flag (`--env` without `=`) is consumed with an empty value, the same final leaf state as before. **Superseded 2026-09-25:** the parser assigned the flag's own name instead of an empty value, and a mismatched shape is now rejected rather than consumed. Unknown flags and positional tokens pass through in order. `SINK_VAR` must exist at call time (the dispatcher resets `PASSTHROUGH=()` before parsing). Identity validation is unchanged: `resolve_identity` and `check_base_flags` semantics untouched (R3) - parsing now happens in the spec, validation stays shared.

**Rejected alternatives:** keep the exception - rejected, the operator directed closure and the front door was the last non-canonical entry point. A tolerance knob on `parse_args` (`_CLI_TOLERANT` drops unknowns, it does not collect them) - rejected: dropping and collecting are different contracts; the collector needs the ordered remainder. The `_CLI_TOLERANT` leaf fallback was later removed entirely (2026-09-27), so every leaf parse is now strict. Module-level parse state (a registry shared between entry points) - rejected: it forces `declare -g`, per-parse resets, and cross-parse contamination; a per-call local registry avoids all three.

Implementation: `src/libs/cli.sh` (`_cli_parse`, `parse_args`, `parse_args_collect`), `scripts/agent-sandbox.sh`, tests `tests/test_cli_lib.sh` and `tests/test_dispatch.sh`.

## 2026-09-18 -- Shared declarative parser: one flag-routing path

**Decision:** `src/libs/cli.sh` exposes `parse_args USAGE_FN spec... -- args...` as the single flag-ingestion path for every leaf command. A spec entry is one of four shapes:

- `--flag=VAR` -- value flag: sets `VAR` to the flag's value
- `--flag` -- boolean flag: sets `UPPER_SNAKE(flag)` to `true`
- `--flag:VAR` -- boolean flag writing to a named `VAR` (`--yes:YES_FLAG`)
- `<literal>` -- accepted and ignored (compat toggles such as `--permissive`)

`parse_args` scans for `--help`/`-h` first (usage, exit 2), then matches each arg against the spec. Unknown args print usage and exit 1. Defaults: value vars and boolean vars default (to empty / `false`) only when unset, so a caller-predeclared default (`DELIVERY="copy"`) survives a spec whose flag never fires.

Clients keep all behavior not owned by flag routing:

- **Validation**: value validation (e.g. `--delivery` must be `copy` or `mount`) runs in the owning script after `parse_args`, with the exact historical error message.
- **Help and wording**: each script calls its own `usage()` (passed as `USAGE_FN`); the unknown-flag opening word is overridable via `_CLI_UNKNOWN_WORD` so scripts that historically said `Unknown flag` keep that exact output.
- **Strict leaf parse**: every leaf parse rejects unknown flags and prints usage with rc 1. No tolerant mode remains; a typo in a destructive command must not run the command silently.
- **Identity**: `--name`/`--project`/`--sandbox` resolve through the shared `check_base_flags` in `common.sh` (R3); `cli.sh` does not re-implement identity semantics, it forwards them through its spec.

The `agent-sandbox.sh` dispatcher is the one deliberate exception: its loop builds a `PASSTHROUGH` array (every non-identity arg forwarded to the leaf) rather than routing into variables. That is a collection loop, not a parse loop; converting it would force a collect-mode into the parser for no routing gain (R5).

**Rationale:** twelve `main()`/`usage()` pairs each hand-rolled a `for ARG` loop with the same skeleton (help scan, value/boolean case arms, unknown-arg error). The parse *shape* was duplicated even though the flag *names* were command-specific. One declarative parser removes the routing duplication while keeping the per-command surface literal in each script's spec line, which reads as a table of the command's real flags. `declare -g` var targets plus the unset-only default rule keep caller defaults (delivery default `copy`, prune's `AGE_DAYS` default) intact. The strict/tolerant and wording knobs exist because the historical output text is itself a pinned surface (tests match `Unknown flag: --rebuild-base` exactly).

**Rejected alternatives:**

- *Shared `parse_flags` helper with positional extraction* (a function per flag-class) -- re-introduced per-script coordination and could not express explicit boolean var names or exact wording; the declarative spec covers it with less machinery.
- *Move flag validation into the parser* (e.g. a `--delivery` value-allowlist parameter) -- couples the parser to per-command domain rules; validation stays with the owning script, which already owns the error text (R4).
- *Convert the dispatcher's PASSTHROUGH loop* -- a collect-loop is semantic routing (build an arg array), not var ingestion; unifying it removes the dispatcher's one real job (R5). *(Superseded 2026-09-19 by the collect-mode entry above: `parse_args_collect` makes the conversion small and the front door is the last non-canonical entry point.)*

**Edge cases / drivers:** The suite pins exact surfaces: start's `Unknown flag: --rebuild-base` text, apply's required-`--diff` error, run_agent's and start's `invalid --delivery` rejection, prune's silent tolerance. The `local` shadowing trap (a `main()`-local var hides a `declare -g` write) forced the rule that parsed vars are declared at the owning scope, not `local` in `main`. Interactive scripts (start wizard, resume picker) share `usage()` and parse as normal commands; the wizard state is separate (draws on `interactive.sh`), so it rides on top of, never inside, the parser.

Implementation: `src/libs/cli.sh`; consumers `scripts/workflows/{apply,confirm,draft,reject}.sh`, `scripts/{build,onboard,start_agent,resume_agent,run_agent,stop,prune}.sh`, `src/libs/package_branch.sh`. Surface documentation: [`tool_interface.md`](../reference/tool_interface.md) (make-target flag tables). Identity precedence: [resolution_model.md](resolution_model.md).
