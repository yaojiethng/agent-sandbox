# Story — Diff Pipeline Unification and Baseline Advancement

**Status:** Resolved

> **Resolved.** Design recorded in [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md).

---

## Context

Change 2 of M2.3 adds `diff_format_patch` and `diff_generate` as named functions in
`libs/diff.sh`, producing per-commit patches and a full session diff automatically on
container exit. The `package-diff` skill (a prompt template the agent runs manually)
produces a similar artefact — raw diff plus file copies — but against `HEAD` rather than
`BASELINE_SHA`. The two mechanisms solve adjacent problems using overlapping logic, and
their relationship to each other and to the baseline advancement problem is worth settling
before Change 3 begins.

The deeper motivation is a workflow the current harness cannot support: the operator
applies a mid-session diff, commits it to the host repo, and the agent continues working
in the same container without full teardown and reinitialisation. This would materially
speed up iterative development — particularly in the dogfooding scenario where the cost of
a full container restart (snapshot rebuild, image check, volume recreation) is paid on
every apply-and-continue cycle.

---

## Pain Points

**Duplicated diff/package logic.** `libs/diff.sh` (Change 2) and `package-diff` (skill)
both enumerate changes since a baseline, write a diff, and copy output to a workspace
location. The implementations are independent — a bug fix or behaviour change in one does
not propagate to the other.

**`package-diff` baseline is implicitly `HEAD`.** The skill captures only uncommitted
changes at the moment of invocation. Change 2 uses `BASELINE_SHA`, capturing all agent
commits since session start. These are the same only if the agent has made no commits. The
skill is useful as a mid-session checkpoint of uncommitted work; it is not a substitute for
Change 2's full session artefact.

**No mechanism to advance `BASELINE_SHA` in a running container.** After the operator
applies a draft and commits to the host repo, the container's `BASELINE_SHA` is stale. The
next diff pipeline run re-captures already-applied work alongside new work. To continue in
the same container without restart, the container needs a way to advance its own baseline.

---

## Constraints

- `package-diff` must remain functional during the M2.3 transition period.
- Any unification must not change Change 2's behaviour or output format.
- The advancement mechanism must not require the container to have network access or direct
  knowledge of the host repo state — the operator supplies the patches.
- Baseline advancement must be idempotent: applying the same patches twice must not corrupt
  `sandbox/` state.

---

## Investigation Findings

### Diff primitive contract

The two callers have distinct and complementary baseline semantics:

| Caller | Baseline | Trigger | Purpose |
|---|---|---|---|
| Change 2 EXIT trap | `BASELINE_SHA` (session start) | Automatic on container exit | Full session artefact |
| `package-diff` (skill) | `HEAD` (current commit) | Manual — agent invokes | Mid-session uncommitted checkpoint |

These are not redundant. The skill fills the gap the EXIT trap cannot — capturing
uncommitted work at an arbitrary point during the session.

A third direction emerges from the baseline advancement design: `package-diff` used
operator-side to push host amendments into a running container without restart. This is the
symmetric counterpart to `make sync`. See design doc — Diff Primitives section.

### `package-diff` as a wrapper

Once `diff_format_patch` exists in `libs/diff.sh`, `package-diff` is rewritten as a thin
wrapper over that function with `HEAD` as the baseline argument. The `migration-guide.md`
generation step stays in the skill layer — it requires agent reasoning. This unifies the
implementation without changing either caller's behaviour.

### Baseline advancement

Resolved in full. See [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md) — Baseline Advancement section.

---

## Resolution

**Decision:** Adopt the two-primitive model (`format-patch` for history-preserving apply
workflow; `package-diff` for content-addressed checkpointing in both directions) and the
`make confirm SYNC=1` / `make sync` advancement design.

**Where the work goes:**
- `package-diff` unification — chore session after Change 3 is validated. Rewrite skill
  as thin wrapper over `diff_package` in `libs/diff.sh`. Non-blocking.
- Baseline advancement — M2.3 Change 6. Depends on Change 5 (container naming + labels).
- Full design: [`design_apply_workflow_and_baseline_advancement.md`](design_apply_workflow_and_baseline_advancement.md)

**Why:** The two primitives are complementary, not redundant. Unifying the implementation
(wrapper pattern) preserves both caller behaviours while eliminating duplicated logic.
Advancement via `make sync` keeps the container usable across multiple apply cycles without
restart, using `ADVANCED_SESSIONS` as a durable idempotency guard and container labels as
ground truth for session identity.
