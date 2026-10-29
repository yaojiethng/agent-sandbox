---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - Carrier retirement and report pruning

## Objective

Clear the surface the census left behind. Three things exist in the tree only to satisfy the shape the work had while it was in flight: a conventions document that is a five-line stub, a bash audit carrier whose every rule is now a pattern entry, and a set of records whose findings are answered. This iteration removes the first two, points what still refers to them at the entries, and prunes the records to the ones a later session can use.

## Scope

In scope, in this order:

1. delete `docs/development/bash-coding-conventions.md`, and repoint its three live referents: `AGENT_FEEDBACK.md`, and `roadmap.md` twice.
2. give `patterns/README.md` the sentence a section-number citation resolves against.
3. delete `.agents/audits/bash-audit.skill.md`, and repoint the surface-area report's row.
4. prune the records whose findings are answered, and correct the ones kept.
5. record the operator's rulings in place of the stub decision: a record citation is closed once committed, and the linking gate is the only thing that must resolve.

Out of scope: `kelsey-code-reviewer.skill.md`. Its container half states ten Dockerfile rules that no pattern file, conventions document or runbook owns, so deleting it would delete the only statement of them; it waits for the container runbook on the consolidation row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The conventions document does not exist | `git ls-files docs/development/bash-coding-conventions.md` prints nothing | Agent [x] -- deleted; `patterns/README.md` carries the route a section-number citation takes |
| Every live link to it resolves | `bash scripts/lint.sh`, linking gate | Agent [x] -- three links repointed; the fourth was inside the carrier, deleted in the same unit |
| A record's section-number citation has a stated route | the retirement note in `patterns/README.md`, naming the search that finds an entry | Agent [x] -- `## What retired into this set` |
| The bash audit carrier does not exist | `git ls-files .agents/audits/bash-audit.skill.md` prints nothing | Agent [x] -- deleted |
| Nothing in the tree claims the carrier is current | `grep -rn "bash-audit" .agents/ workflow/`, every hit describing a retirement | Agent [x] -- the surface-area row says deleted, and the code-review shell names it as absorbed |
| `kelsey` stays, and the record says why | the carrier-fates record, naming the ten container rules and their absent owner | Agent [x] -- the `kelsey` section states them and names the container runbook as the unit that takes them |
| The pruned records are named with what replaced them | this handover's Completed rows, one per record, each naming where its content now lives | Agent [x] -- two rows, one deletion and one reduction |
| The gate is clean and the suite passes | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] -- the gate is clean across 13; the suite passes 1321 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A record citation is closed once committed; only live links must resolve | the operator's ruling. A record states what was true when it was written, and rewriting it to keep a pointer working falsifies the record to satisfy a checker | this handover |
| The stub goes, once its three live referents are repointed | the stub existed to keep record citations resolving, which the ruling above removes as a reason. What remained were three live links, and three edits are cheaper than a file that exists to satisfy nobody | this handover |
| `kelsey` stays until a container runbook exists | its Dockerfile rules have no owner anywhere in the tree. Deletion is safe only when every rule a carrier states is an entry somewhere, which is true of `bash-audit` and false of `kelsey` | `20261026-report-settled-carrier_fates.md` |

## Decisions pending

| Code | Item | State | Ruling |
|---|---|---|---|
| E1 | Should `surface-area-report.md` be rewritten to describe the surface after the retirement, or left as the audit that described it before? | Ruled | Left as the audit, with the row marked `(deleted)` and its disposition changed to `Retired`. The report keeps the reading it had and gains the state that replaced it, which is the least a settled record may say |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The linking gate checks record links, so a record citation is not free to break | defect | the census close assumed records could keep a dead path; the gate decides otherwise, and the stub's deletion is a three-link edit rather than none | this iteration's scope, item 1 |
| `bash-audit` was safe to delete because every rule it named has an entry, and `kelsey` is not | finding | the deletion test is per rule, not per file: a carrier goes when its rules are owned, and stays while one rule has no home | `20261026-report-settled-carrier_fates.md`, the `kelsey` section |

## Completed

| File | Change |
|---|---|
| `docs/development/bash-coding-conventions.md` | deleted. It was a five-line stub whose job was to keep record citations resolving, and the operator's ruling removed that job; the three live links it held were repointed instead |
| `patterns/README.md` | `## What retired into this set`: where a record's section-number citation resolves, and the search that finds the entry by subject |
| `.agents/audits/bash-audit.skill.md` | deleted. Every rule it named is an entry, which is what the 15-site screen established; its two pointers were the surface-area report's row and the code-review shell, both repointed |
| `devlog/AGENT_FEEDBACK.md`, `devlog/roadmap.md` | the three live links to the retired document, now naming the pattern set |
| `20261026-report-active-bash_audit_sites.md` | deleted. All 15 of its rulings resolved to `moot`, `drop` or `answered`, and it had no referent once the carrier was gone |
| `20261026-report-draft-pattern_provenance.md` | reduced from 162 lines to 109: pass 1's 35-row table became its result, the operator-question list went because every row was ruled, and the failures table now names the entries it became |
| `20261026-report-settled-carrier_fates.md` | the `bash-audit` row and the `## The bridge` section now describe the deletion, and record why the stub's reasoning changed |
| `devlog/roadmap.md` | the consolidation row carries what this iteration completed: the bash carrier consolidated and deleted, `kelsey` waiting on the container runbook |
