---
description: Audit propagation coverage for a cross-file change. Use when a naming rule, structural convention, interface rename, variable, label, or any other change should have been applied across multiple files — and you want to verify nothing was missed. Invoke before declaring a task complete, after a context compaction, or whenever the operator asks "did you get all of them?" Consistent with the propagation discipline in AGENTS.md.
argument-hint: "<change description>"
---

Propagation audit for: $@

Per the propagation discipline in [AGENTS.md](AGENTS.md).

**Establish the change signature.** State in one line what the change looks like in code or text — specific enough that a grep can find it (e.g. `OLD_NAME` → `NEW_NAME`, label `agent-sandbox.session-name` added to every container definition).

**Find all candidate files.** Run targeted greps to find every file that contains the old form, references the changed symbol, or belongs to the affected component. Do not rely on memory or the task brief — grep is the authoritative source.

**Build the propagation table.** For each candidate file, open and read the relevant section — do not guess from the grep snippet — then record:

| File | Expected change | Actual state | Status |
|---|---|---|---|
| `path/to/file` | `<what should change>` | `<what is there>` | ✅ done / ❌ missed / ⚠️ partial |

**Report gaps.** For each row with status ❌ or ⚠️, state exactly what is missing and whether it should be fixed now or deferred. If all rows are ✅, state: "Propagation complete — no gaps found."

**Fix or defer.** Apply fix-now gaps and update the row to ✅. Record deferred gaps in the active handover's Deferred items section before closing the session.
