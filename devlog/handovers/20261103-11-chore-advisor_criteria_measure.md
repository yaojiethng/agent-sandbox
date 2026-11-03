---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Housekeeping
status: Closed
---

# Handover - a criterion stays only where the step does not state its end

## Objective

Measure the advisor skills against the reporting an agent consumes, and drop the completion criteria those skills do not need, without losing a rule.

## Scope

In scope: the rule in `forms.md` that mandated a criterion on every step, and the three files that applied it the most, `chain.md`, `content.md` and `roadmap-maintenance`.

Out of scope: `doc-maintenance`, which carries the same pattern and is not an advisor skill; it keeps its criteria and its meta-line, and its case is recorded as a finding rather than fixed here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No advisor runbook states a criterion the step already states | `grep -rc 'Completion criterion'` over the three files returns 0 each | Agent [x] |
| No rule is lost with the criteria | `grep -n 'canonical marker' runbooks/chain.md` and `grep -n 'reported for escalation' runbooks/chain.md`; both clauses now sit in the step's body | Agent [x] |
| Each file is shorter than it was | `wc -l`: `chain.md` 94 to 82, `content.md` 36 to 30, `roadmap-maintenance` 149 to 145 | Agent [x] |
| `bash scripts/lint.sh` is clean | twenty gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The convention states a test, not a quota | `forms.md` said every step ends on a criterion, which is what produced a line restating the step above it; it now says the observable is stated as a criterion where the step's own sentences do not already say it | `forms.md` item 4 |
| A criterion that restates its step and its report rule goes | The report rule is one line per finding and one per skip, stated once in the reporting step; a per-step "or is reported" is that rule repeated, and it crowds the step it bounds | `chain.md`, `content.md`, `roadmap-maintenance` |
| Unique clauses move into the body rather than leaving with the criterion | Two criteria carried content their steps did not: an empty section's canonical marker, and the escalation on a dropped deferred item. Both are now sentences in the step | `chain.md` |

## Decisions pending

None.

## Findings

- `prose-review`, `code-review` and `close-read` carry no completion criterion at all, so the row's subject was three files rather than the whole advisor set.
- `doc-maintenance` still carries one per step under the same meta-line. It is a documentation skill, so this row's scope does not reach it, and the same test would apply to it.
- The line count moved in one direction only: 279 lines to 257 across the three, and no criterion was replaced by a longer sentence.

## Completed

| File | Change |
|---|---|
| `.agents/skills/instruction-authoring/references/forms.md` | item 4 states the test that decides a criterion |
| `workflow/coding-agent/skills/handover-maintenance/runbooks/chain.md` | seven criteria and the meta-line go, two clauses move into the body |
| `workflow/coding-agent/skills/handover-maintenance/runbooks/content.md` | two criteria and the meta-line go |
| `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md` | two criteria go, the escalation sentence stays |
| `.agents/skills/instruction-authoring/references/prompt-conventions.md` | the prompt sheet stops restating the rule and points at `forms.md` item 4 |
| `devlog/roadmap.md` | the row is closed |
