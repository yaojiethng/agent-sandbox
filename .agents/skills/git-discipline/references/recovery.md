# Recovery

## The model

A recovery is the repair when the record and the repository disagree about work the operator directed. The claim is what the handover or the roadmap says; the evidence is what the repository holds. The class is decided by the evidence, never by the claim; the claim only says where the repair returns.

| Class | The claim | The disagreement | Procedure |
|---|---|---|---|
| Partial | the iteration is `implementing` | the record holds the intent, and the disk holds part of it | [`partial.md`](../../../../workflow/coding-agent/skills/recovery/runbooks/partial.md) |
| Absent | the iteration is `committed` | no commit holds the work | [`absent.md`](../../../../workflow/coding-agent/skills/recovery/runbooks/absent.md) |

The entry is `/recovery`, which hands the operator's description to the [`recovery`](../../../../workflow/coding-agent/skills/recovery/SKILL.md) skill. The skill classifies the description and opens the runbook.

A child branch that will not rebase onto its parent is not a recovery: that is mergeability, and `prepare-rebase` owns it. A change the repository holds and the operator now disagrees with is a correction, and [`correction.md`](correction.md) owns it.
