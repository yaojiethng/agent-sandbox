# Handover 20260901-11 — docs manual-wrapping policy adjustment + violation sweep

**Milestone:** M2.6 - Session Persistence
**Type:** docs
**Status:** Closed
**Date:** 2026-09-01

## Objective

Operator report: the AF/GOTCHAS record contains an entry about newlines in
the middle of prose / manual line wrapping; the corresponding policy wording
does not work and there are live violations in the tree. Adjust the policy
wording, then sweep and fix violations.

Note: policy-text changes need per-section operator approval (recorded
gotcha) — propose wording in chat, wait for release before writing.

## Acceptance Criteria

- AC1: Entries and corresponding policy sections identified and presented.
- AC2: Replacement wording approved by operator per section.
- AC3: Violation sweep executed; findings and fixes recorded.
- AC4: Single `docs:` delivery commit; handover closed in it.
## Completed

| Task | Evidence |
|---|---|
| Entries + policy section identified | GOTCHAS `2026-09-01`, AF `2026-08-09` (resurfaced `20260901-03`); `documentation_policy.md` `### Line wrapping` |
| Policy wording reworked (operator-approved text) | rule now positive: never manually word wrap prose; no line break mid-paragraph, not at sentence boundaries, not at a column limit; fenced blocks and table rows exempt |
| Brief rule added to pi-layer AGENTS.md Write Discipline | `src/reasoning/providers/pi/config/agent/AGENTS.md` + deployed `~/.pi/agent/AGENTS.md` synced (outside snapshot -- review by reading the file) |
| Violation sweep across governed docs | 20 files unwrapped (~530 net lines removed); detector residual: 0; sweep is provably structure-preserving (see Findings) |
| Records updated | AF `2026-08-09` and GOTCHAS `2026-09-01` escalated to probation with rework amendments; both name `scripts/manual/unwrap_prose.sh` as the current sweep solution for a probation resurfacing; GOTCHAS mitigation block itself unwrapped |
| Sweep tooling promoted (operator-directed) | `scripts/manual/unwrap_prose.sh`: `--check` detector mode + unwrap with built-in verification (fences byte-identical, structural lines identical, merge-only with indent preservation; restores on failure). Shellcheck-clean; tested: check/unwrap/idempotence on a pre-sweep copy |

## Findings

- The old wording's "a hard line break falls on a sentence or paragraph boundary" licensed the exact misreading it was meant to prevent; the reworked rule states the norm positively and reserves hard breaks for block boundaries.
- Both AGENTS.md layers contain no wrapped prose (remediated `20260810-01`) -- the operator's note that "the file itself also violates" was matched to `devlog/GOTCHAS.md`, whose mitigation block was verifiably wrapped; if a specific AGENTS.md spot was meant, it needs an operator pointer.
- **Sweep correctness (operator-flagged):** the first joiner pass corrupted markdown -- fences indented inside list items were collapsed into their content (`e2e-dry-run-container-startup-test.md`), and paragraph indents were stripped on flush. All 20 files were restored from backup and re-swept with a corrected joiner. Final state verified by three independent checks per file: (1) fenced regions (any indent, ` ``` `/`~~~`) byte-identical to pre-sweep; (2) structural lines (headings, nested lists, tables, blockquotes, hr, indented code) identical; (3) every output line is a merge of consecutive input lines with the first line's indent preserved. All 20 pass; whitespace-stripped content is byte-identical, so no characters were added or lost.
- Sweep verification tooling is now in-repo as `scripts/manual/unwrap_prose.sh` (promoted per operator directive), superseding the ad hoc `/tmp` scripts; the first-pass joiner bugs (indented-fence collapse, indent stripping) are guarded against by its built-in verification.

## What's Next

- None -- scope complete. Waiting on operator release for the delivery commit.
