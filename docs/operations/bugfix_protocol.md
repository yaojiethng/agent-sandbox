# Bugfix Protocol

Structured process for diagnosing and correcting failures found during acceptance testing or dry-run validation. Not a policy — use when a systemic bug pattern emerges that requires tracing through multiple links in a chain.

## Entry conditions

- A integration test, dry-run, or acceptance check fails with an unexpected error.
- The failure is not a known or transient infrastructure issue (e.g. Docker daemon down, disk full).
- The error output is available and can be traced to specific source lines.

## Procedure

### 1. Replicate

Run the failing command in the same context that produced the error. Capture the full output — do not filter or summarise it. Record:

- The exact command that was run
- The full stdout/stderr output, preserving line numbers and error location markers
- The container or host environment where the failure occurred

### 2. Trace

For each distinct error message in the output:

1. Identify the **source file and line number** that produced it.
2. Read the surrounding context (function definition, variable scope, control flow).
3. Ask: is this a direct failure (the check correctly identified a real problem) or a **cascading failure** (the error is a symptom of an earlier bug)?

Distinguish these cascading patterns:

| Cascade pattern | Example |
|---|---|
| Variable unset | `local` at top level causes assignment to fail → downstream uses empty string → "No such file or directory" |
| Missing dependency | `diff_export` called but `diff.sh` not sourced → command not found |
| Wrong-container assumption | Agent-only mount checked in sandbox → always fails |

### 3. Diagnose

For each unique root cause, write a diagnostic check that tests the precondition independently:

1. Create a **diagnostic script** in `tests/knowledge/diagnose_<area>.sh` following the existing pattern:
   - `set -uo pipefail` at top
   - `PASS`/`FAIL` counters with `pass()`/`fail()` helpers
   - Numbered sections (1..N) testing each link in the chain
   - A **regression guard** for the specific bug pattern (e.g. grep for top-level `local`)
   - A **live simulation** of the failing operation
   - Summary with guidance text for each possible failure mode
2. Run the diagnostic in the same environment that produced the error.
3. Adjust the diagnostic until it correctly identifies the root cause(s).

The diagnostic serves two purposes:
- **Confirms** the root cause before any fix is applied
- **Persists** as a regression test for future changes

### 4. Fix

Apply targeted edits to the minimum set of files that address the root causes:

1. Fix one root cause per edit where possible.
2. Do not fix cascading symptoms — fix the root; the cascade resolves.
3. Do not refactor — address only what is broken. Flag adjacent improvement opportunities as notes but do not act on them.
4. Verify each fix:
   - `bash -n <file>` passes syntax check
   - Grep for the bug pattern to confirm no remaining instances
   - Re-run the diagnostic to confirm the check now passes

### 5. Record

Document the bug and fix in two places:

**A. Handover `[CORRECTION]` block** (per `docs/operations/handover_policy.md` — Corrections to Closed Handovers):

```
---
[CORRECTION — YYYY-MM-DD]: <what was wrong, root cause for each distinct bug,
what was changed, which files were modified>
```

**B. Diagnostic script** — the diagnostic created in step 3 serves as the permanent record of preconditions and the regression guard for the bug pattern.

### 6. Close

- Confirm the original failing command now passes.
- If the diagnostic was created as part of this session, note it in the `[CORRECTION]` block so future readers know where to find it.
- Do not alter the handover's `Status`, timestamps, or acceptance criteria markers — the correction block is additive.

## Common bug patterns in this codebase

### Top-level `local` keyword

`local` is valid only inside bash functions. In an executed script (not sourced), `local` at the top level produces:

```
local: can only be used in a function
```

The variable may or may not be assigned depending on bash version. Subsequent uses of the variable see an empty string.

**Fix:** Remove the `local` keyword. Variables in bash are created by their first assignment — no declaration is needed at top level.

**Detection:** `grep -nE '^\s*local\s+' <script>` — then manually verify each match is inside a function body.

### Wrong-container mount assumptions

The capability layer (sandbox) mounts only `.snapshot/` and `workspace/session-diffs/`. The reasoning layer (agent) additionally mounts `workspace/input/` and `workspace/output/`. Check scripts that run in the sandbox must not treat INPUT_DIR or OUTPUT_DIR as `critical` — those directories are expected to be absent.

**Fix:** Use `warn_check` (informational) instead of `critical` for agent-only mounts in capability-layer scripts.

### Missing library source

A function may be defined in a library file that is not sourced by the script. The call produces a `command not found` error, which may be swallowed by `2>/dev/null` redirection.

**Fix:** Add the missing `source` line. Check the library's own dependencies — it may source additional files internally.

## Learnings from past applications

| Session | Bug pattern | Diagnostic created |
|---|---|---|
| 20260513-04 | Top-level `local` in pre-flight stderr capture; set -e regression; wrong-container mount checks | `tests/knowledge/diagnose_preflight.sh` |
| 20260513-06 | Top-level `local` in both dry-run scripts; missing `diff.sh` source; agent-only mounts checked as critical in sandbox | `tests/knowledge/diagnose_dry_run_capability.sh`, `tests/knowledge/diagnose_dry_run.sh` |

## Relationship to other documents

| Document | Role |
|---|---|
| `docs/operations/recovery_protocol.md` | Recovers lost work after container/filesystem reset |
| `docs/operations/documentation_policy.md` | Post-close correction policy for `[CORRECTION]` blocks |
| `docs/operations/handover_policy.md` | Corrections to Closed Handovers — procedure and constraints |
| `docs/operations/iteration_policy.md` | Session workflow — open, active, close phases |
