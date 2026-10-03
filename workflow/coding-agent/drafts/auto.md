---
description: Reserved - the generalized dispatch keyword. The smart /auto dispatcher (Option A) is reserved here and M4-flagged; it resolves a roadmap task list's execution order, picks the dispatch shape per the work structure, and orchestrates. Until M4 lands, this stub fails closed and routes a single well-ordered unit list to sequential-work.
argument-hint: "[roadmap task list, possibly out of order - optional]"
---

> $@

# Auto - Generalized Dispatch (Reserved Stub)

**Status:** reserved stub for M4. The `/auto` keyword is reserved for the generalized smart dispatcher. Full semantics are recorded in the design record and the ADR section that M4 owns. This stub stands in place of the feature so no future M3.2.3 work claims the keyword.

## Semantics (reserved)

`/auto` is the smart dispatcher, distinct from the curated dispatch shapes. Given a roadmap task list (possibly supplied out of order, subtasks each carrying an execution rank), `/auto`:

1. resolves the execution order from the dependency structure;
2. decomposes the work into units and assigns each an execution rank;
3. picks the dispatch shape per the work structure -- sequential, parallel, or operator-gated -- from the curated dispatch-command surface;
4. orchestrates and queues the units, running everything it can and parking any unit that genuinely requires operator input.

`/auto` is Option A. The curated dispatch shapes it chooses among (`sequential-work`, `parallel-work`, `task-queue`, `fanout`) are the building blocks. Option B, loose-goal decomposition, is `/goal`, owned from M4. The current `/auto` semantics (sequential dispatch), formerly here, now live under `/sequential-work`.

## This stub fails closed

Until M4 implements the dispatcher, `/auto` does not guess a shape. It accepts a single well-ordered unit list that needs nothing but sequential dispatch and routes that list to [`sequential-work.md`](sequential-work.md). Anything else -- an out-of-order list, a list with subtasks of differing ranks, a unit that needs a decision -- is refused here and presented to the operator rather than guessed at. This keeps the reserved keyword fail-safe until its M4 implementation lands.

## Reference

- Semantics record: `devlog/discussions/archive/20261001-design-settled-auto_smart_dispatch.md`
- Predecessor check: [`backlog-triage.md`](../prompts/backlog-triage.md) answers the per-row form of the classification this dispatcher performs across a whole plan -- which open roadmap rows run unattended and which carry a question. It is available now and needs no dispatcher.
- ADR section: [`coding_agent_loop_workflow.md`](../../../docs/adr/coding_agent_loop_workflow.md) -- the `/auto` smart-dispatcher and `/goal` rows that M3.2.3 records and M4 implements.
