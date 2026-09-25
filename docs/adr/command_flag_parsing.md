# Command Flag Ingestion

**Current:** 2026-09-19

> This ADR records the design as it stands and is expected to evolve. The
> per-command flag surface centralization landed in one pass across all leaf
> scripts; a later change supersedes the current entry by adding a dated
> entry, per the ADR policy. It is not a locked contract.

## 2026-09-19 -- Collect mode: the dispatcher joins the canonical parser

**Decision:** `src/libs/cli.sh` exposes one implementation, `_cli_parse MODE USAGE_FN SINK_VAR spec... -- args...`, and two policy wrappers over it: `parse_args` (strict leaf parse, or tolerant per `_CLI_TOLERANT`) and `parse_args_collect` (forwarding parse for entry points). The `agent-sandbox.sh` dispatcher parses through the collect wrapper with a four-flag spec (`--env`, `--name`, `--project`, `--sandbox`) and forwards the collected remainder to the leaf; its hand-rolled PASSTHROUGH loop and its `parse_base_flags` call are retired. All parse state is local to the call: the spec registry is a local associative array inside `_cli_parse`, so a parse can never observe another parse's registry and no module-level registry survives. `--help`/`-h` is handled inside `_cli_parse` for the leaf modes and left to the caller in collect mode: the dispatcher owns help routing and scans its args itself before dispatch (unchanged).

**Why it supersedes the 2026-09-18 rejection:** the rejection stood on "no routing gain" and "the parser would grow machinery". A collect mode is now part of the parser because the shared implementation keeps it small, and the front door was the last entry point outside the canonical shape (R1). R5 still holds: forwarding is explicit, through the named sink array, and no env-var smuggling of command input occurs. The 2026-09-18 entry remains the record for the leaf surface.

**Rationale:** one parser semantics across all entry points; the dispatcher spec line reads as a table of the front door's own flags (identity + `--env`); future flag shapes added to the parser apply to the front door as well. Operator behavior is byte-identical (parity contract; the dispatch oracle suite pins it - unchanged `tests/test_dispatch.sh` cases remain green, plus a new order/passthrough case).

**Edge cases / drivers:** a bare value flag (`--env` without `=`) is consumed with an empty value, the same final leaf state as before. Unknown flags and positional tokens pass through in order. `SINK_VAR` must exist at call time (the dispatcher resets `PASSTHROUGH=()` before parsing). Identity validation is unchanged: `resolve_identity` and `check_base_flags` semantics untouched (R3) - parsing now happens in the spec, validation stays shared.

**Rejected alternatives:** keep the exception - rejected, the operator directed closure and the front door was the last non-canonical entry point. A tolerance knob on `parse_args` (`_CLI_TOLERANT` drops unknowns, it does not collect them) - rejected: dropping and collecting are different contracts; the collector needs the ordered remainder. Module-level parse state (a registry shared between entry points) - rejected: it forces `declare -g`, per-parse resets, and cross-parse contamination; a per-call local registry avoids all three.

Implementation: `src/libs/cli.sh` (`_cli_parse`, `parse_args`, `parse_args_collect`), `scripts/agent-sandbox.sh`, tests `tests/test_cli_lib.sh` and `tests/test_dispatch.sh`.

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Single parse path | Every command parses its flags through one declarative parser, not per-script `for ARG` loops |
| R2 | Exact surface preserved | Each leaf keeps its historical flag names, defaults, help text, and unknown-flag wording; the suite pins them |
| R3 | Identity stays shared | `--name`/`--project`/`--sandbox` parse through the shared base-flag helper, never re-implemented per script |
| R4 | Validation stays explicit | Flag-specific validation (e.g. `--delivery` allowed values) runs after parse, at the owning script, not inside the parser |
| R5 | Forwarding is explicit | The dispatcher collects passthrough args and forwards them to the leaf; no env-var smuggling of command input |

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
- **Leniency**: `_CLI_TOLERANT=1` restores a script's historical silent-ignore of unknown flags (prune), for surfaces where leniency was the contract.
- **Identity**: `--name`/`--project`/`--sandbox` resolve through the shared `check_base_flags` in `common.sh` (R3); `cli.sh` does not re-implement identity semantics, it forwards them through its spec.

The `agent-sandbox.sh` dispatcher is the one deliberate exception: its loop builds a `PASSTHROUGH` array (every non-identity arg forwarded to the leaf) rather than routing into variables. That is a collection loop, not a parse loop; converting it would force a collect-mode into the parser for no routing gain (R5).

**Rationale:** twelve `main()`/`usage()` pairs each hand-rolled a `for ARG` loop with the same skeleton (help scan, value/boolean case arms, unknown-arg error). The parse *shape* was duplicated even though the flag *names* were command-specific. One declarative parser removes the routing duplication while keeping the per-command surface literal in each script's spec line, which reads as a table of the command's real flags. `declare -g` var targets plus the unset-only default rule keep caller defaults (delivery default `copy`, prune's `AGE_DAYS` default) intact. The strict/tolerant and wording knobs exist because the historical output text is itself a pinned surface (tests match `Unknown flag: --rebuild-base` exactly).

**Rejected alternatives:**

- *Shared `parse_flags` helper with positional extraction* (a function per flag-class) -- re-introduced per-script coordination and could not express explicit boolean var names or exact wording; the declarative spec covers it with less machinery.
- *Move flag validation into the parser* (e.g. a `--delivery` value-allowlist parameter) -- couples the parser to per-command domain rules; validation stays with the owning script, which already owns the error text (R4).
- *Convert the dispatcher's PASSTHROUGH loop* -- a collect-loop is semantic routing (build an arg array), not var ingestion; unifying it removes the dispatcher's one real job (R5). *(Superseded 2026-09-19 by the collect-mode entry above: `parse_args_collect` makes the conversion small and the front door is the last non-canonical entry point.)*

**Edge cases / drivers:** The suite pins exact surfaces: start's `Unknown flag: --rebuild-base` text, apply's required-`--diff` error, run_agent's and start's `invalid --delivery` rejection, prune's silent tolerance. The `local` shadowing trap (a `main()`-local var hides a `declare -g` write) forced the rule that parsed vars are declared at the owning scope, not `local` in `main`. Interactive scripts (start wizard, resume picker) share `usage()` and parse as normal commands; the wizard state is separate (draws on `interactive.sh`), so it rides on top of, never inside, the parser.

Implementation: `src/libs/cli.sh`; consumers `scripts/workflows/{apply,confirm,draft,reject}.sh`, `scripts/{build,onboard,start_agent,resume_agent,run_agent,stop,prune}.sh`, `src/libs/package_branch.sh`. Surface documentation: [`tool_interface.md`](../architecture/tool_interface.md) (make-target flag tables). Identity precedence: [env_resolution.md](env_resolution.md).
