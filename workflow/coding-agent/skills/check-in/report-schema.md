# The record-report schema

One JSON object per line, one line per finding. The schema has one owner, this skill; an auditor writes to it and never restates it. The invocation template in [`auditor-invocation.md`](auditor-invocation.md) passes it to each auditor.

## Fields

| Field | Required | Meaning |
|---|---|---|
| `skill` | yes | the auditor that produced the line: `roadmap-maintenance` or `handover-maintenance` |
| `file` | yes | the record, as a repository-root-relative path |
| `section` | yes on a finding | the heading, row or other locus. Never a line number: a number in a record is true once and goes stale with the next edit above it. |
| `check` | yes on a finding | the numbered check that produced it, as the auditor numbers it |
| `rule` | yes on a finding | the policy the check applies, as `path#anchor` |
| `finding` | yes on a finding | one line: what the record asserts, and what the tree or the policy shows instead |
| `recommendation` | yes on a finding | `fix-now`, `defer` or `escalate` |
| `deferTo` | yes on a `defer` | the existing roadmap unit of work that owns the broader task |
| `evidence` | yes on a finding | the read, grep or count that produced the finding |
| `result` | yes on a skip | `skip` |
| `reason` | yes on a skip | why the check produced no finding: it did not apply, it could not be judged, or an exception clause protects what it found. Name the clause. |

## The three recommendations

| Value | Condition | What the dispatcher does |
|---|---|---|
| `fix-now` | the correct form is determined by the tree or the policy, and the edit is bounded to a record | applies it in the single `chore:` commit |
| `defer` | the correct form is determined, and an existing roadmap unit of work already names the broader task | nothing. The named unit owns it; clearing it ahead of that pass is premature. The dispatcher rejects a `defer` that names no existing unit, so a `defer` never creates a row. |
| `escalate` | two sources disagree, or a value cannot be re-derived | a point below the inventory table |

A recommendation names no commit, no message and no fold. The auditor recommends whether a fix is available now; the dispatcher decides how the fix lands.

## A line is a finding or a skip

There is no third kind. A finding the auditor's own exception clauses protect is a skip whose `reason` names the clause. An auditor does not get to say a defect should be ignored: that would be overriding the rule it was given.

## A record finding carries no severity

Severity belongs to a work item, where [`SKILL.md`](SKILL.md) grades the inventory's Impact axis. A record finding is not work and carries no grade: its disposition is the recommendation. A severe finding is an `escalate`, which is the whole expression of severity this schema has.

## The report is never committed

The file lives at the run-scoped path the invocation template sets, outside the repository tree. It is a working artefact, so no commit-time gate sees it and no validator script exists. The enforcement is the template, which hands the auditor this schema, and the dispatcher's aggregation step, which rejects a line that does not conform.

## Example

```json
{"skill":"roadmap-maintenance","file":"devlog/roadmap.md","section":"M2.7 summary row","check":"3.18","rule":"roadmap_policy.md#corrections-to-closed-roadmap-and-changelog-entries","finding":"row reads Complete while the changelog entry records a supersession; no marker","recommendation":"fix-now","evidence":"grep -n SUPERSEDED devlog/changelog.md"}
{"skill":"roadmap-maintenance","file":"devlog/roadmap.md","section":"closed rows across the milestone","check":"3.6","rule":"roadmap_policy.md#compaction-cascading","finding":"twenty-plus closed rows carry landed narrative and counts that go stale","recommendation":"defer","deferTo":"the T12 pi-bump and extension pass","evidence":"grep -c Handover devlog/roadmap.md"}
{"skill":"roadmap-maintenance","file":"devlog/roadmap.md","section":"M3.2 sub-milestone","check":"3.10","rule":"roadmap_policy.md#fractal-milestone-numbering","finding":"a M3.2.1 node with no M3.2 parent, and no summary row","recommendation":"escalate","evidence":"no M3.2 heading exists in the tree or in git history"}
{"skill":"handover-maintenance","check":"3","result":"skip","reason":"no acceptance criterion names a validation tool that misses its failure mode"}
```
