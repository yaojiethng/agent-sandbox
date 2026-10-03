# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Documentation
**Status:** Closed

## Objective

Produce a report against `@earendil-works/pi-coding-agent` 0.99.1 that a maintainer with no access to this repository can act on, and prove it by handing it to agents who have never seen the investigation.

## Scope

- `devlog/discussions/20260930-report-draft-opencode_go_provider_bug_report.md` - the report. Drafted 2026-09-30 and iterated through 2026-10-02; the date records when it was written, so the filename is unchanged.

Excluded: any change to pi, and any decision to send the report upstream.

## The defect

Pi ships a frozen catalog for the OpenCode Zen gateway and never refreshes it during normal use. For `opencode-go` the built-in catalog carries 29 ids against a gateway that advertises 43. When a user names one of the 14 ids the catalog lacks, pi answers confidently rather than saying the catalog is stale. `glm-5` resolves to `glm-5.3-flash` with no warning at all. The other 13 receive `kimi-k3` limits, price and reasoning map under the requested id.

Three findings, ordered root cause first: catalogs are never refreshed on a normal path; the built-in catalog is stale against the gateway; and an id the catalog lacks is answered with another model's metadata or with a different model and no warning. A fourth finding, on the extension composition path, is labelled extension-only because it cannot occur in vanilla pi.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The report reproduces the defect with commands a reader can run against a fresh install | four independent fresh installs, each reproduced | Met |
| 2 | A fresh implementer given only the report can produce a fix that passes the gate | four independent agents, three at 13 of 14 checks | Met |
| 3 | The report carries no reference to this repository, its process, or temporary paths | read of the shipped file | Met |
| 4 | Every claim in the report is measured against a stated build, and drift is labelled | the Version drift section | Met |
| 5 | The gate that scored the fixes fails on an unmodified pi | control at 7 of 14 | Met |

## What was measured, and how

The metric is a frozen static gate at `/tmp/gate/gate.mjs` with fourteen checks, run against a candidate tree and a pristine 0.99.1 control. It was proved sensitive before any result was read: the control fails seven of the fourteen.

| Tree | Score | Residual |
|---|---|---|
| control, unmodified 0.99.1 | 7/14 | the findings themselves |
| sample A, fresh agent, round 1 report | 13/14 | new module not reachable from the bundle entry |
| sample B, fresh agent, round 1 report | 13/14 | same |
| sample C, fresh agent, round 2 report | 13/14 | same |
| sample D, fresh agent, round 2 report | 11/14 | the same, plus a private field read and no changelog line |

Three of four independent agents landed on the same single residual. That consistency is the finding: the gap is in the report's placement, not in the agents' work, and the requirement moved from a checklist at the end into the fix itself as a four-row table.

The runtime checks were removed from the metric rather than reported as wins. A self-test showed Node's `fetch` ignores `HTTP_PROXY` and pi replaces `globalThis.fetch`, so every "no network observed" verdict was void. Finding 1 is verified statically, and the report says so.

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/discussions/20260930-report-draft-opencode_go_provider_bug_report.md` | the report, reframed to vanilla pi, then restructured so each resolution is a line-anchored diff | done |
| the resolution sections | prose replaced by exact patches against pinned 0.99.1, with the four module-wiring rows added | done |

## Findings

| # | Finding | Where it landed | Status |
|---|---|---|---|
| 1 | The report's first finding was the extension composition path, which cannot occur in vanilla pi | the report now leads with the core catalog-refresh defect | Fixed |
| 2 | Every headline count had drifted between builds | the Version drift section carries the corrected table | Fixed |
| 3 | `mergeModels` is not exported on 0.99.1, so the finding-4 patch did not apply as written | the report states the export is a prerequisite | Fixed |
| 4 | Finding 1 omitted the two session call sites that pass no flag at all | the corrected call-site list | Fixed |
| 5 | `pi update --models` cannot close the gap, because pi.dev serves the same 29 ids | corrected in the report | Fixed |
| 6 | pi-ai gates the network refresh phase on a resolvable credential, so wiring the flag fixes nothing for a keyless user | the credential gate, with verification that requires the credentials to be absent | Fixed |
| 7 | Deleting `thinkingLevelMap` from a substituted model inverts the reasoning levels pi sends | the map must be retained or explicitly narrowed | Fixed |
| 8 | Prose remedies produced trap proliferation, and a hand-patched bundle inverted a condition that `node --check` passed | resolutions became exact diffs, and the verification section requires the binary itself | Fixed |
| 9 | The report's stated remedy for finding 1 was a no-op | replaced with the anonymous endpoint read | Fixed |

## Findings summary

The report is 405 lines. Four independent implementers scored 11 to 13 of 14 against a 7 of 14 control. Every verdict in this handover is a gate result or a subagent's word; no finished patch was read and judged by hand.

## Mid-run adjustments

- The first three rounds had no harness, so each implementer invented its own scripts and the rounds were not comparable. Convergence was a judgment call until the gate existed.
- The gate produced three false positives on the best output: a regex that matched a nested spread, a field-name mismatch, and a case-sensitivity miss. A gate that fails correct work is as bad as one that passes broken work, so all three were fixed before any result was read as signal.
- The gate failed every correct tree on one check, because it punished the patch that chose not to widen a gate. Rewritten so the check fires only on the half-done state.

## Resolution methods

The report's prose was rewritten twice. The first rewrite replaced advice with the exact patches taken from the round-3 fix, which is what moved a fresh agent from 7 of 14 to 13 of 14. The second moved the module-wiring requirement out of the verification checklist and into the fix, after three of four agents made the same omission.

## Post-review learnings

An agent's claim about code should be re-measured before it displaces one already measured. In round 1 a reviewer asserted that `mergeModels` was exported on 0.99.1, contradicting a direct measurement from the tree in front of me, and the report was corrected to agree with the reviewer without re-checking. Round 2 caught it.

The same applies to ambient environment. The round-2 verification passed only because provider keys were present in the container. The next reviewer found the fix does nothing once they are stripped, which is a pass that was measuring the wrong thing.

## Final output artifacts

| Artifact | Home |
|---|---|
| the report | `devlog/discussions/20260930-report-draft-opencode_go_provider_bug_report.md` |
| the decision log for the gate | outside the repository, at the operator's request not to publish validation scaffolding |

## Resolution status

Closed as a record. The report's content is converged to within one known residual, which is stated in the report itself.

Open, and the operator's to decide:

1. Whether the report is sent upstream, edited first, or kept as a record.
2. Whether the one known residual, a new module not reachable from the bundle entry, is worth a fourth round. Four independent attempts produced it.

## Records this supersedes

None. The report is a new record.
