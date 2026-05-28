# CLI Interaction Standards

Principles for CLI tools (bash scripts, one-off functions, and entrypoints)
used within the agent-sandbox harness. Designed to make tools recoverable
by automated agents and predictable for human operators.

---

## 1. Required Arguments Must Produce Self-Recovery Errors

When a required argument is missing, the tool **must not** silently use a
default or crash with a bare message like "Error: missing --to". It must
emit a full error block that lets the caller immediately retry:

```
Error: --session-summary is required. Provide a concise snake_case label.

  Good: --session-summary=fix_provisioning_metadata_agnostic
  Good: --session-summary=add_format_patch_support
  Bad:  --session-summary=changes
  Bad:  --session-summary=snapshot

Usage: package_branch.sh --to=<dir> --session-summary=<text> [--baseline=<sha>]

  --to=<dir>           Required. Base output directory.
  --session-summary    Required. Snake_case label for the bundle directory.
  --baseline=<sha>     Optional. Override baseline SHA.
```

The error must include:
- What was missing (exact argument name)
- One or two good examples
- One or two bad examples (to train agents away from useless defaults like `snapshot`)
- The full usage line
- Description of each argument

## 2. Success Output Includes an Actionable Next Step

A tool that produces artefacts should not just print its output path — it
should tell the caller what to do next:

```
package_commits: generated 1 diff(s) in /path/to/bundles/TS-LABEL-TS/patches
package_branch: artefacts written to:
  /path/to/bundles/TS-LABEL-TS

To draft this bundle on host, run:
  make draft FROM=bundles SESSION=TS-LABEL-TS BRANCH_SUMMARY=<slug>
```

The next step should be:
- Concrete — a command the caller can copy-paste
- Contextual — parameterised with the exact artefact path/name just produced
- Optional — `<slug>` placeholders show the caller must fill in a value

## 3. Stdout vs Stderr Discipline

| Stream | What goes there |
|---|---|
| `stdout` | The primary result — the thing the caller asked for. Must be parseable. |
| `stderr` | Everything else — progress, warnings, the final summary, the next-step command. |

**Rationale:** If stdout is the artefact path, `make apply DIFF=$(tool ...)` works.
If stdout contains "generated 1 diff(s)", that pipeline breaks.

When stdout is not meaningful (pure side-effect tools like `package_branch`),
the tool may write only to stderr. The caller should capture stderr for
the completion summary.

## 4. `--help` Is Mandatory

Every CLI tool must implement `--help` and display:

- A one-line description of what the tool does
- Usage line with all arguments
- Description of each argument
- One or two examples

## 5. Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | User error — bad/missing argument, invalid input |
| `2+` | System error — missing directory, git failure, permission denied |

This lets callers distinguish "the caller messed up" from "the system is
broken" without parsing error messages.

## 6. Use `--flags`, Not Implicit Env Vars

Tools read environment variables only if they are:
- Documented in the tool's `--help` output
- Prefixed with the tool name or a well-known namespace

Uncontrolled env var reading leads to invisible state dependencies that
are hard to debug. An explicit `--flag` is always preferred.

## 7. Paths Are Absolute

All paths printed by a tool must be absolute. Relative paths are
ambiguous when the caller may be in a different working directory.

---

## 8. Makefile Variable Overrides Must Be Validated

Make silently ignores unknown variable overrides. If a user types
`make draft CHANNEL=bundles`, Make sets `CHANNEL` but no target reads
it — the command proceeds with incorrect defaults. The user gets no
error and the wrong behaviour.

To prevent this, every Makefile template that accepts user-facing
variable overrides **must** guard against the known misused names
with an explicit `ifdef`/`$(error)` block:

```makefile
ifdef CHANNEL
$(error CHANNEL is not a Make variable. Did you mean FROM? Example: make $(MAKECMDGOALS) FROM=$(CHANNEL))
endif
```

All accepted variables must be declared with `?=` at the top of the
Makefile so they are visible in one place. Any variable that a user
might reasonably try but that is not in the accepted set must have
a guard with an error message that points to the correct name.

## References

| Document | Relevance |
|---|---|
| [`tool_interface.md`](../architecture/tool_interface.md) | Harness-level CLI contracts |
| [`package_branch.sh`](../../libs/package_branch.sh) | Reference implementation — error recovery + actionable next step |
