# Recovery — 20260430 Design Step

**Purpose:** the consolidated design session that runs after pre-clean lands and before Change A reconstruction begins. Replaces the lost 03/04/08 design fragments with a single durable record.

**Position in recovery flow:**

1. Investigations (`recovery-investigations.md`) — answer code-verification questions
2. Pre-clean (`recovery-pre-clean.md`) — land audit drift fixes and the helper extraction (if Q-I-1 finding warrants)
3. **20260430 design step** — this file describes what happens here
4. Change A reconstruction (`recovery-change-a.md`)
5. Change B implementation (`recovery-change-b.md`)

---

## Why this step exists separately

The lost timeline tried to design A and B inside the same sessions that produced the design doc, the roadmap, and (immediately after) the implementation. That collapse was driven by context-window pressure, not by the work being one logical thing. With a fresh context, separating design from implementation is the natural shape — and consolidating three lost design fragments into one is honest about what we're doing.

The output of this step is a handover and an updated design doc. Both are persistent artifacts that subsequent A and B sessions consume. Without those artifacts, the design step's conclusions live only in chat context and get lost the same way the originals did.

---

## Inputs to this step

- `recovery-investigations.md` with all findings filled in
- The recovery branch tip after pre-clean has landed (tree green, audit drift resolved)
- The current `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` (post-P-2c, with `INIT_SHA` references already corrected)
- The recovery tracking files (this one, plus pre-clean, change-a, change-b)
- The closed handovers from the lost timeline (03, 05, 06, 07, 09) — for content reference, not for inheritance of session structure

---

## Step objectives

The session must accomplish all of the following before producing its handover:

### O-1 — Confirm post-pre-clean state

Walk through the investigation findings. For each:

- Confirm the finding still holds at the design step's start (i.e. pre-clean's effects match what was expected).
- Identify divergences (pre-clean did more or less than scoped).
- Update the recovery tracking files to reflect actual state.

This is bookkeeping but load-bearing — A reconstruction is scoped against the post-pre-clean tree, not against the pre-pre-clean tree the original handovers describe.

### O-2 — Resolve B's open questions

Walk through `recovery-change-b.md` § Open questions. For each Q-B-N, produce a decision:

- The decision itself (one of the candidates, or a new option that emerged).
- The rationale (one paragraph max).
- Where the decision is recorded in the design doc.

By the end, `recovery-change-b.md` § Open questions should have every Q-B-N marked with its disposition. New questions that emerge get added to that section before the design step closes — but with their answers.

### O-3 — Scope code unification work for A

This is the substantive design work. Inputs: Q-I-1 finding, Q-I-5 finding, the original handover narratives.

Decisions to make:

- **Helper extraction shape.** What's the unified primitive's signature? Parameters, return convention, error handling, untracked-file handling.
- **Where it lives.** `libs/diff.sh` is the obvious home; confirm.
- **Migration order within A.1.** Helper introduced first, then call sites migrate, or all at once?
- **What about `package_diff.sh`?** It's in `libs/` not `scripts/` — does it call the helper directly, or does it have its own thin wrapper?
- **Backward-compat concerns.** Are there any external callers (tests excepted) that would break?

If pre-clean already extracted the helper as a refactor commit (per Q-I-1's "three separate invocations" disposition), this step is choosing the *interface* for the helper that already exists. If pre-clean did not extract — because the helper was already unified — this step has nothing to do here; record that.

### O-4 — Re-scope A.1 / A.4 / A.2 / A.3 against the actual state

The original handovers' file lists for each A.x are stale by the time this step runs:

- Pre-clean has already landed parts of A.1's data-model work (`SESSION_STATE` write side, consumer migration).
- Pre-clean has already updated some docs that A.3 was going to update.
- If pre-clean extracted the helper, A.1's helper-introduction work is already done.
- Q-I-5's finding tells us how much routing extraction A.2 still needs to do.

Walk through `recovery-change-a.md` § A.1 / A.4 / A.2 / A.3 and update each section's "Files in scope" against actual remaining work. Items that pre-clean covered get removed. Items that emerged from investigations get added.

Output: each A.x section in `recovery-change-a.md` has a clean, current scope statement.

### O-5 — Produce the consolidated design doc update

The design doc (`docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`) currently has — per Q-I-7 and the audit — multiple Contract Amendments sections from the lost design fragments, plus stale references that pre-clean partly fixed.

Replace the multi-section structure with a single Contract Amendments section that describes:

- The unified output format (post-A.1 + A.4 state — what `session-diffs/` and `output/diffs/` look like)
- The `--channel` CLI contract (post-A.2)
- The diff-helper unified primitive (per O-3 decision)
- The channel boundary (apply consumes `output/diffs/`; draft consumes `session-diffs/` and `output/bundles/`)
- The Section B interactive contract (per O-2 decisions)
- Open items deliberately deferred (e.g. `package_diff` cross-write — record once, with rationale)

This is the design doc that the next person reading the project sees. It must be a single coherent record of the contract, not a layered archaeology of changes.

### O-6 — Produce the 20260430 design handover

Write `docs/devlog/handovers/20260430-NN-design-recovery_consolidated.md` per `handover_policy.md`. Standard handover shape, with these specifics:

- **Status:** Closed at session end
- **Carried forward:** the recovery context — reference RECOVERY.md and the four tracking files
- **Decisions made this session:** every O-2 and O-3 decision, with the rationale field pointing to where the rationale lives in the design doc
- **Hot files:** the design doc, the four recovery tracking files, the files in scope for the upcoming A.1 reconstruction
- **Next session:** the A.1 reconstruction implementation session
- **Conclusions from this session:** what the post-pre-clean state actually was, what changed in scope, and what's now ready for A reconstruction

This handover replaces 03/04/08. Acknowledge that explicitly in the body — "This handover consolidates design decisions originally made across three lost sessions (handovers 03, 04, 08); the final contract is recorded once here."

---

## What this step does NOT do

- **No code changes.** This is a design session. The only file modifications are to the design doc and the handover. The recovery tracking files get updated as part of bookkeeping, but those aren't repository state in the same sense.
- **No pre-clean re-litigation.** If pre-clean missed something, that's a finding — record it and decide whether to send back to pre-clean or fold into A. Don't redo pre-clean work here.
- **No B implementation.** Q-B-N decisions are scoping decisions. The implementation lands in Section B's session.
- **No ongoing investigation.** Investigations should be complete before this step starts. If a question can't be answered, that's an input to the design decisions, not a reason to keep digging.

---

## Exit criteria

Before this step closes:

1. All Q-I-N investigations have findings recorded in `recovery-investigations.md`.
2. All Q-B-N open questions in `recovery-change-b.md` have decisions, recorded both in that file and in the design doc.
3. `recovery-change-a.md` § A.1 / A.4 / A.2 / A.3 sections have current, accurate scope statements that reflect what pre-clean accomplished.
4. The design doc has one Contract Amendments section, not several.
5. The 20260430 design handover exists, is Closed, and references the four recovery tracking files.
6. `scripts/run_tests.sh` exits 0 (no regression — no code changed in this step, but doc changes shouldn't break anything either; sanity check).

---

## Risks specific to this step

**The temptation to keep designing.** This step has a clear scope (resolve open questions, re-scope A and B against current state, consolidate the design doc). Adding new design work — "while we're here, let's also reconsider X" — re-creates the conditions that made the original sessions blow context. If a new question emerges, write it down and defer it.

**The temptation to start implementing.** Especially around the helper extraction (O-3), it's tempting to "just write the helper while we're here." Don't. The design step decides the interface; A.1 reconstruction implements it. Mixing the two is what made A.x sessions originally have to fix bugs in their own scope.

**Doc-vs-code drift introduced here.** The design doc updated in O-5 must match the code that A reconstruction is about to land. If the design step makes a choice that the upcoming A code can't actually implement (e.g. an interface that doesn't fit the current call sites), the doc will drift again. Cross-check against actual code before finalising any interface decisions in O-3.
