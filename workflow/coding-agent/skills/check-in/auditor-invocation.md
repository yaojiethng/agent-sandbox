# The auditor invocation template

The template below is what the exhaustive check dispatches to each auditor. It is the one place the schema is handed over, so an auditor writes to a shape it was given rather than one it chose, and a third auditor added later needs no schema of its own.

Substitute two values and pass the result to a fresh subagent.

- `<auditor>` -- `roadmap-maintenance` or `handover-maintenance`.
- `<report-path>` -- the run-scoped path for that auditor's report, outside the repository tree. One file per auditor; more auditors mean more files. A path under `/tmp` is the default.

```text
Read the file `workflow/coding-agent/skills/<auditor>.md` from the repository root and follow its procedure.

You report only. Write no record, no file inside the repository tree, and no commit. Your single output is the JSONL report at the path below.

Report path: <report-path>

Write one JSON object per line, with exactly these fields:

- skill: "<auditor>"
- file: the record path, repository-root relative
- section: the heading, row or other locus; never a line number
- check: the numbered check that produced the finding
- rule: the policy the check applies, as path#anchor
- finding: one line, what the record asserts and what the tree or the policy shows instead
- recommendation: "fix-now", "defer" or "escalate"
- deferTo: required when recommendation is "defer"; the existing roadmap unit of work that owns the broader task
- evidence: the read, grep or count that produced the finding

"fix-now" means the correct form is determined by the tree or the policy and the edit is bounded to a record. "defer" means it is determined but an existing roadmap unit already names the broader task. "escalate" means two sources disagree or a value cannot be re-derived.

For a check that produced no finding, write one line with exactly these fields instead:

- skill: "<auditor>"
- check: the number
- result: "skip"
- reason: why, in one line; name the exception clause when one protects what the check found

The schema has one owner, `workflow/coding-agent/skills/check-in/report-schema.md`; do not restate it in your output and do not add fields to it.
```

## After the dispatch

The dispatcher reads both files, validates each line against [`report-schema.md`](report-schema.md), inspects each finding, and applies the `fix-now` set. The reports stay where they are and are never committed.

## Failure to report

An auditor that returned no file, an empty file, or a line that does not conform has failed its dispatch. Report the failure with the auditor named; do not treat a missing report as a clean run. An auditor that reported nothing at all has not said the record is clean, it has said it did not check.
