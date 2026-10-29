---
status: Active
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# The bash tail and the consolidation's stale clauses

## Objective

Land the two bash rules the consolidation row says no document owns, and correct the row's two claims the tree has outgrown, so the row names one residue instead of five.

## Scope

- `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/git-state.md`: two new entries, `p-59` and `p-60`.
- `devlog/roadmap.md`: the M3.2.2 row `The consolidation, run once over the whole set` edited in place.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The two bash rules are entries in the pattern set, each with a fence, a statement and `Replaces:` | `grep -c '^## p-' patterns/git-state.md` is 2 | Agent [x] Agent run: 2 |
| Ids are one past the highest ever used | every `^## p-` id in `patterns/` is unique and `p-60` is the maximum | Agent [x] Agent run: `p-60` is the maximum; the only repeated id is the README's illustrative tombstone `p-12` |
| No index lists the new file | `grep -rn 'git-state' --include=*.md .` returns nothing outside the entry's own path | Agent [x] Agent run: only the handover and the roadmap row name it |
| The row names the prose part as landed, citing the runbooks that discharge it | the row's prose clause names `reference-staleness`, `instruction-cleanup`, `test-review` and `doc-maintenance` | Agent [x] Agent run: the row names all four |
| The row's false claim about `conventions.md` is corrected | the row names the six categories and the vendored runbook as the nearest carrier | Agent [x] Agent run: the row names both |
| The row names one residue | the row's remaining work is the general code-quality plane | Agent [x] Agent run: the row states it is the remaining plane, and a contradicting sentence was deleted |
| The row's state the intent and delegate the method | the row's opening sentence names no cluster, no method and no history, and every landed cluster is a sub-row with its own outcome and handover | Agent [x] Agent run: the parent carries one intent sentence; the seven clusters are sub-rows, six `[x]` and one `[ ]` |
| Suite and lint clean | `bash scripts/run_tests.sh`, `bash scripts/lint.sh` | Agent [x] Agent run: lint clean across 15 gates; 1349 passed, 0 failed across 98 files |

## Decisions

- **`git-state.md` is a new file, not entries inside `file-content.md` or `processes.md`.** The subject is reading the state of a repository, and neither file's opener admits it: one opens on writing bytes into a whitespace-sensitive format, the other on spawning a child.
- **The prose part closes on evidence, not on work.** Four runbooks answer the ground the clause said was unowned, and one of them, `doc-maintenance`, answers the records half by nesting under `project-documentation`. Nothing is left to build.
- **The general plane stays the row's one residue.** It is the milestone's real slice and wants a scope of its own, so the row is corrected rather than closed.
- **A cluster that lands in its own iteration is a sub-row.** The row had grown into one paragraph carrying six outcomes, a method for each, and its own history, so no row could be ticked and the parent could not close. It is now one intent sentence and seven clusters beneath it, each with the outcome it delivered and the handover that landed it, which is the shape the milestone's earlier multi-iteration rows already take. The parent stays `[ ]` because one child is open.

## Decisions pending

- The owner for general code-quality rules: a `patterns/` list beside a general runbook, as recommended at the scope gate, a section in `docs/development/`, or the vendored runbook. The third is refused by its own provenance line; the first two are open.

## Findings

- `scripts/dispatch.sh:364`, `scripts/guards.sh:50`, `scripts/stop_probe.sh:224`, `scripts/build_probe.sh:356,423`, `src/capability/seed_volume.sh:102` and `src/libs/session_save_policy.sh:36` all test dirtiness on the default porcelain form. As a non-empty test that is correct and `p-59` does not fault it; the frozen format is what a *comparison* needs, and `seed_volume.sh:81` already takes it. The set has no rule for the difference, which is why `p-59` is written around comparison rather than around parsing.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/git-state.md` | Added: `p-59` fixed porcelain format for comparing trees, `p-60` pin the revision a diff is taken against |
| `devlog/roadmap.md` | The M3.2.2 consolidation row split into an intent sentence and seven cluster sub-rows: six landed and ticked, the general plane open; the `conventions.md` claim corrected and the false sentence about waiting on runbooks deleted |
