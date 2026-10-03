# Agent Handover

**Date:** 2026-09-25
**Milestone:** M3.1 - Backpressure
**Type:** Documentation
**Status:** Closed

## Objective

Correct the lint-gate ADR's gate set and record the flag-parsing contract change the bare-value fix introduced.

## Scope

Two ADR corrections, one unit of approval: the lint-gate drift recorded as register row 290, and the flag-parsing edge case invalidated by row 41's landed fix. Documents only; no code and no tests.

## Carried forward

| Item | From handover |
|---|---|
| The two ADR tasks from the check-in inventory | no handover; surfaced during the gm survey |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The lint-gate ADR names the gate set without a stale count | reading the ADR against `GATES` in `scripts/lint.sh` | Agent [x] (no "two gates" wording remains) |
| The flag-parsing ADR carries a new current entry, the prior entry demoted with a supersession line, and the edge case promoted | reading the ADR against the policy's editing procedure | Agent [x] |
| The promoted requirement is in the Requirements table | the table's R6 row | Agent [x] |
| Register row 290 reads resolved | the row's `status` field | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/adr/lint_gate_exit_codes.md`](../../docs/adr/lint_gate_exit_codes.md) | the gate set drifted from two to three |
| [`docs/adr/command_flag_parsing.md`](../../docs/adr/command_flag_parsing.md) | the bare-value edge case states a contract the parser never had |
| [`devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl`](../discussions/20260924-design-active-test_suite_readthrough.jsonl) | row 290's status |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Clarify the lint-gate ADR in place rather than add a dated entry | no decision changed: the exit-code contract is the same, and only the set of gates it governs grew. The prose now points at `GATES`, so a fourth gate cannot re-break it. | the ADR |
| Add a dated entry for the flag-parsing change and demote the prior one | the bare-value contract did change, so the policy's editing procedure applies: new `Current:` entry, prior entry demoted with a supersession line, edge case promoted to a standing requirement | the ADR |
| Annotate the demoted edge case rather than rewrite it | the policy keeps a demoted entry's decision and rationale; the annotation records what the implementation actually did | the ADR |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The flag-parsing ADR's 2026-09-19 edge case was not merely stale: it recorded a contract the implementation never had. It said a bare value flag is consumed with an empty value, while `${a#*=}` returned the whole argument and assigned the flag's own name as the value. | bug | current iteration |
| Register row 103, "the ADR's missing-tool behaviour is unasserted", is a test row in the same ADR family and remains open; it belongs to the test lane, not this one. | scope change | next iteration |
| The flag-parsing ADR's Requirements table sits after its 2026-09-19 entry rather than between the `Current:` line and the first entry, which the policy's structure places it. Pre-existing; not corrected here. | contradiction | next iteration |

## Completed

| File | Change |
|---|---|
| `docs/adr/lint_gate_exit_codes.md` | the decision, the condition table, the scope sentence and the edge-case paragraph now name the gate set generically and point at `GATES`; the tool-missing row notes that the lib-contract gate needs no external tool |
| `docs/adr/command_flag_parsing.md` | `Current:` moved to 2026-09-25; a new entry records that a flag's shape must match its spec; the 2026-09-19 entry is demoted with a supersession line; the edge case is annotated and promoted to R6 |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | row 290 flipped to resolved |

## Deferred items

None. Row 103 and the Requirements-table placement are recorded in Findings.

## What's Next

The refactor unit: register row 33, the git commit-distance and position primitives.

**Conclusions from this iteration:** an ADR can be wrong rather than merely stale, and the difference decides the treatment: drift is a clarification, a contract the code never had is a dated entry.
