# Skill — Bugfix Protocol

## Purpose

Structured process for diagnosing and correcting failures found during acceptance testing or dry-run validation. Use when a systemic bug pattern emerges that requires tracing through multiple links in a chain.

## Before Acting

Ensure the failure is not a known or transient infrastructure issue (Docker daemon down, disk full). The error output must be available and traceable to specific source lines.

---

## Entry Conditions

- An integration test, dry-run, or acceptance check fails with an unexpected error.
- The failure is not a known or transient infrastructure issue.
- The error output is available and can be traced to specific source lines.

---

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
3. Ask: is this a direct failure or a **cascading failure** (symptom of an earlier bug)?

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
   - A **regression guard** for the specific bug pattern
   - A **live simulation** of the failing operation
   - Summary with guidance text for each possible failure mode
2. Run the diagnostic in the same environment that produced the error.
3. Adjust the diagnostic until it correctly identifies the root cause(s).

### 4. Fix

Apply targeted edits to the minimum set of files that address the root causes:

1. Fix one root cause per edit where possible.
2. Do not fix cascading symptoms — fix the root; the cascade resolves.
3. Do not refactor — address only what is broken. Flag adjacent improvement opportunities as notes.
4. Verify each fix:
   - `bash -n <file>` passes syntax check
   - Grep for the bug pattern to confirm no remaining instances
   - Re-run the diagnostic to confirm the check now passes

### 5. Record

Document the bug and fix in two places:

**A. Handover `[CORRECTION]` block** (per `docs/operations/handover_policy.md`):
- What was wrong, root cause for each distinct bug, what was changed, which files were modified

**B. Diagnostic script** — serves as the permanent record of preconditions and the regression guard.

### 6. Close

- Confirm the original failing command now passes.
- If the diagnostic was created as part of this session, note it in the `[CORRECTION]` block.
- Do not alter the handover's `Status`, timestamps, or acceptance criteria markers.

---

## Common Bug Patterns

### Top-level `local` keyword

`local` is valid only inside bash functions. In an executed script, `local` at the top level produces `local: can only be used in a function`. The variable may or may not be assigned depending on bash version.

**Detection:** `grep -nE '^\s*local\s+' <script>` — manually verify each match is inside a function body.

**Fix:** Remove the `local` keyword. Variables in bash are created by their first assignment.

### Wrong-container mount assumptions

The capability layer mounts only `.snapshot/` and `workspace/session-diffs/`. The reasoning layer additionally mounts `workspace/input/` and `workspace/output/`. Sandbox scripts must not treat agent-only mounts as `critical`.

**Fix:** Use `warn_check` instead of `critical` for agent-only mounts in capability-layer scripts.

### Missing library source

A function defined in a library file not sourced by the script. The call produces `command not found`.

**Fix:** Add the missing `source` line. Check the library's own dependencies.
