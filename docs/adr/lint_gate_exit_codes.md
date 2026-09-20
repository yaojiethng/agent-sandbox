# Lint Gate Exit Codes

**Current:** 2026-09-20

## 2026-09-20 -- The lint gates emit a verdict-only exit status, and each failure condition has its own diagnostic

**Decision:** The lint gates (`scripts/check_shell.sh`, `scripts/check_markdown.sh`) and their umbrella (`scripts/lint.sh`) emit a verdict-only exit status: `0` when the gate is clean, `1` when the gate found a defect or could not run. The finding count is printed to stdout, never encoded in the code. The table below lists every condition and the value it produces.

| Condition | stdout | exit code |
|---|---|---|
| Clean run, no findings | count + `Clean` | `0` |
| One or more findings | the findings and the count | `1` |
| Tool missing (`shellcheck`/`markdownlint-cli2`) | named error | `1` |
| Source directory missing | named error | `1` |
| Empty file set under the scan roots | named error | `1` |
| Tool aborted without emitting findings | the tool output | `1` |
| Umbrella: one gate failed | both gates still run; combined verdict | `1` |

Every failure condition names itself on stderr, so the operator distinguishes them from the exit code alone.

**Rationale:** An exit code answers one question: did the gate pass. A count, a severity, or a tool-missing condition is a magnitude, which is not what a process boundary reports to a caller that reads only zero versus non-zero. Rule 3.2 of [bash-coding-conventions.md](../../docs/development/bash-coding-conventions.md) states this: a missing tool is a finding, not a special code; print the finding and exit `1`. The earlier form collapsed these conditions into different values (the markdown gate exited `127` for a missing tool), which made a missing tool indistinguishable from 127 findings.

This is the exit-code contract the gate rewrite of handover `20260919-19` settles. It applies to the two gates and the umbrella that sequences them; a tool that fails without emitting findings fails the gate, because a clean verdict can never be derived from an aborted run.

**Edge cases / drivers:** The umbrella always runs both gates even when the first fails, so one failure never hides the other. A missing tool or an empty file set can never report "clean", because the gate cannot determine an answer; refusing to run is the fail-closed behaviour that keeps a broken gate from passing silently. The `test` harness exit (its failure count) remains the one standing exemption to the verdict rule, recorded in rule 3.2.
