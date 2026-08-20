# Handover Audit Skill

**Status:** Draft — not yet formalised. Captures procedural content-quality rules that migrated out of `handover_policy.md` during the document split (session 20260522-03).

## Purpose

Validates that handover and spec content meets quality standards that go beyond format compliance. These rules are procedural (they check process, not field state) and don't fit the declarative framing of `handover_policy.md`.

## Audit Categories

### Spec-to-source integrity

**Rule:** Any code block in a spec that will be copy-pasted into implementation must be validated against live source within the same iteration.

The agent must have run a grep or read the relevant file during the iteration to confirm variable names, paths, and call signatures. Memory is not a substitute.

**Audit check:** For each code block in the spec, grep the handover's Hot files and Completed tables. The source file referenced in the code block must appear in one of them.

### Structured output format

**Rule:** If a spec requires a structured output (coverage map, propagation table, diff summary), the format must be defined in the spec before implementation begins. An open-ended analysis requirement without a specified output format will produce inconsistent results across iterations.

**Audit check:** grep the spec for "propagation", "coverage", "diff" — for each hit, verify a format template is present in the same spec section.

### Validation tool coverage

**Rule:** When a hygiene AC references a validation tool, verify the tool actually catches the failure mode it is meant to guard. `bash -n` does not catch runtime-only bash errors such as `local` outside a function, `set -u` violations in conditional branches, or arithmetic evaluation errors. For scripts, prefer a runtime check (capture stderr from an actual run) or a targeted grep for the specific anti-pattern.

**Audit check:** For each AC that references `bash -n`, verify the failure mode is a syntax error (not runtime). If uncertain, flag for operator review.

## Run Conditions

- **When:** At Gate 2 (before implementation) for spec-to-source integrity and structured output format. At Step 7 (pre-close) for validation tool coverage.
- **Who:** Agent self-check. Not operator-invoked.
- **Severity:** Warning — flags do not block gates but must be triaged before iteration close.

---

**Depends on:** [`handover_policy.md`](../../docs/operations/handover_policy.md), [`iteration_policy.md`](../../docs/operations/iteration_policy.md)
