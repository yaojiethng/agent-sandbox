---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Implementation
status: Closed
---

# Handover - The unresolved-rule warning in the Markdown gate

## Objective

Warn when a rule is enabled in `.markdownlint-cli2.mjs` but no `customRules` entry exports it, so an enabled rule cannot sit unregistered and silent.

## Scope

`scripts/check_markdown.sh` and its coverage line. Out of scope: blocking on the warning, which is the owner's call, and an assertion that every registered rule is enabled, which is the inverse failure and not observed.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | An enabled, unregistered rule name produces a warning naming it | a fixture rule name added to the config; the gate prints `Markdown gate: warning: rule "..." is enabled in the config but no customRules entry exports it; it is not running.` | pass |
| 2 | A clean config produces no warning | `bash scripts/check_markdown.sh` output carries no warning line | pass |
| 3 | The warning does not block | the gate exits 0 with the warning present | pass |
| 4 | Suite and lint green | `bash scripts/run_tests.sh`: 1028 of 1028; lint clean across 5 gates | pass |

## Hot files

| File | Change |
|---|---|
| `scripts/check_markdown.sh` | `warn_unresolved_rules` resolves every enabled non-`MD*` rule name against the `customRules` modules and warns on stderr; the coverage line now says it counts files, not link health |

## Decisions

1. **The check warns; it does not block.** The gate that owns an unresolved rule decides whether it matters, and a warning that blocks every commit over a naming slip trains the habit of skipping it.
2. **Only non-`MD*` names are resolved.** Built-in rules resolve by name inside markdownlint; a custom name is the only kind that can be enabled without being registered.
3. **The coverage line says what it counts.** `record-links coverage: 3 exempt tree(s), 652 Markdown file(s) exempt (file count, not link health)`. The exempt set's size is intentional and accepted; the line had been readable as a health statement over the 1,195 dead links it holds, and that reading is now closed in the label rather than in a second number.

## Decisions pending

- None. Whether the warning should block is recorded as an operator call the first time it fires on a real registration gap.

## Findings

- The failure this warns about cost a session: `doc-wrap` was enabled and unregistered, so every measurement of its behaviour was taken against a config that no longer ran it, and the cause took several turns to find. The warning would have named it on the first run.

## Completed

The warning, its label, and the coverage line's wording.

---
[AMENDMENT -- 2026-10-03: `type` read `Impl`, which is not a member of the type enum. It is set to `Implementation`. No other content changed: the iteration changed a gate script, which the Implementation type names.]
