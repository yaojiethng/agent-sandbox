# Command Flag Ingestion

**Current:** 2026-09-18

> This ADR records the design as it stands and is expected to evolve. The
> per-command flag surface centralization landed in one pass across all leaf
> scripts; a later change supersedes the current entry by adding a dated
> entry, per the ADR policy. It is not a locked contract.

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

- `--flag=VAR` — value flag: sets `VAR` to the flag's value
- `--flag` — boolean flag: sets `UPPER_SNAKE(flag)` to `true`
- `--flag:VAR` — boolean flag writing to a named `VAR` (`--yes:YES_FLAG`)
- `<literal>` — accepted and ignored (compat toggles such as `--permissive`)

`parse_args` scans for `--help`/`-h` first (usage, exit 2), then matches each arg against the spec. Unknown args print usage and exit 1. Defaults: value vars and boolean vars default (to empty / `false`) only when unset, so a caller-predeclared default (`DELIVERY="copy"`) survives a spec whose flag never fires.

Clients keep all behavior not owned by flag routing:

- **Validation**: value validation (e.g. `--delivery` must be `copy` or `mount`) runs in the owning script after `parse_args`, with the exact historical error message.
- **Help and wording**: each script calls its own `usage()` (passed as `USAGE_FN`); the unknown-flag opening word is overridable via `_CLI_UNKNOWN_WORD` so scripts that historically said `Unknown flag` keep that exact output.
- **Leniency**: `_CLI_TOLERANT=1` restores a script's historical silent-ignore of unknown flags (prune), for surfaces where leniency was the contract.
- **Identity**: `--name`/`--project`/`--sandbox` resolve through the shared `parse_base_flags`/`check_base_flags` in `common.sh` (R3); `cli.sh` does not re-implement identity semantics, it forwards them through its spec.

The `agent-sandbox.sh` dispatcher is the one deliberate exception: its loop builds a `PASSTHROUGH` array (every non-identity arg forwarded to the leaf) rather than routing into variables. That is a collection loop, not a parse loop; converting it would force a collect-mode into the parser for no routing gain (R5).

**Rationale:** twelve `main()`/`usage()` pairs each hand-rolled a `for ARG` loop with the same skeleton (help scan, value/boolean case arms, unknown-arg error). The parse *shape* was duplicated even though the flag *names* were command-specific. One declarative parser removes the routing duplication while keeping the per-command surface literal in each script's spec line, which reads as a table of the command's real flags. `declare -g` var targets plus the unset-only default rule keep caller defaults (delivery default `copy`, prune's `AGE_DAYS` default) intact. The strict/tolerant and wording knobs exist because the historical output text is itself a pinned surface (tests match `Unknown flag: --rebuild-base` exactly).

**Rejected alternatives:**
- *Shared `parse_flags` helper with positional extraction* (a function per flag-class) — re-introduced per-script coordination and could not express explicit boolean var names or exact wording; the declarative spec covers it with less machinery.
- *Move flag validation into the parser* (e.g. a `--delivery` value-allowlist parameter) — couples the parser to per-command domain rules; validation stays with the owning script, which already owns the error text (R4).
- *Convert the dispatcher's PASSTHROUGH loop* — a collect-loop is semantic routing (build an arg array), not var ingestion; unifying it removes the dispatcher's one real job (R5).

**Edge cases / drivers:** The suite pins exact surfaces: start's `Unknown flag: --rebuild-base` text, apply's required-`--diff` error, run_agent's and start's `invalid --delivery` rejection, prune's silent tolerance. The `local` shadowing trap (a `main()`-local var hides a `declare -g` write) forced the rule that parsed vars are declared at the owning scope, not `local` in `main`. Interactive scripts (start wizard, resume picker) share `usage()` and parse as normal commands; the wizard state is separate (draws on `interactive.sh`), so it rides on top of, never inside, the parser.

Implementation: `src/libs/cli.sh`; consumers `scripts/workflows/{apply,confirm,draft,reject}.sh`, `scripts/{build,onboard,start_agent,resume_agent,run_agent,stop,prune}.sh`, `src/libs/package_branch.sh`. Surface documentation: [`tool_interface.md`](../architecture/tool_interface.md) (make-target flag tables). Identity precedence: [env_resolution.md](env_resolution.md).