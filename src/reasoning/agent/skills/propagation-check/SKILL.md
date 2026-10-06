---
name: propagation-check
description: The propagation discipline, and the audit that applies it. A change that lands across more than two files is not complete until every carrier is updated. Use when the task names more than two files, says "all", "every", "throughout" or "wherever X appears", or changes an output format, file layout or API surface; and before declaring such a task complete.
---

# Propagation discipline

A change that touches more than one file is one change, and every carrier of it is part of the task. The carriers are whatever the tree holds: this skill assumes no project layout.

## Before writing the first file

Produce the checklist in chat:

```text
Propagation checklist -- <change description>

| File | Change | Status |
|---|---|---|
| path/to/file.sh | rename FOO_VAR to BAR_VAR | pending |
| docs/reference.md | update the reference to BAR_VAR | pending |
```

Then:

- Mark a row `done` when that file is complete, before moving to the next one.
- When the scope expands, add rows for the new scope before producing any output for it.
- Before declaring the task complete, confirm every row. A row that cannot be completed in this iteration is flagged with a reason. Do not summarise coverage: show the table.

## When a checklist is required

- The task names more than two files as targets.
- The task uses "all", "every", "throughout", "wherever X appears", or "consistent with".
- The change alters an output format, a file layout, an API surface, or any contract another artefact consumes -- whatever the task's wording. Cover every consumer the project has: tests, documentation, downstream scripts, fixtures, and any knowledge tests it keeps.

## Renaming is one kind of propagation task

Search the tree for references to the old name (`grep -rn "<old name>" .`), update them all, use `git mv` for a tracked file or `mv` plus `git add` for an untracked one, and confirm that no stale reference remains before committing.

## The audit

Run this when coverage must be verified rather than asserted.

**Establish the change signature.** State in one line what the change looks like in code or text, specific enough for a grep to find it -- `OLD_NAME` -> `NEW_NAME`, or a label added to every definition of a thing.

**Find the candidates.** Grep for every file that holds the old form, references the changed symbol, or belongs to the affected component. Grep is the authority, not memory and not the task brief.

**Build the table.** For each candidate, open it and read the relevant section before judging it; never decide from the grep snippet alone. Record file, expected change, and status.

**Report the gaps.** For each row that is missed or partial, state exactly what is missing and whether it is fixed now or deferred. When every row is done, say "Propagation complete - no gaps found."

**Fix or defer.** Apply the fix-now gaps and mark their rows. Send a deferred gap to wherever the project keeps its open work -- a roadmap row when it has one, a note to the operator when it does not -- before the session closes.
