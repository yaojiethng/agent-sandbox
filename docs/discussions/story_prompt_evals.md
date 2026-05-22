# Story — Prompt Eval Infrastructure

**Status:** Investigation in progress

## Context

The project maintains a growing set of prompt templates and skill documents that encode policy into instruction sequences for the coding agent. When policy documents are revised — as `roadmap_policy.md`, `handover_policy.md`, and `iteration_policy.md` were in session `20260522-01` — all skills and prompts that encode those policies must be updated to reflect the new rules. Currently, the only method for verifying that a skill correctly reflects updated policy is a manual read-through comparison.

This is fragile. Skills that drift from policy produce incorrect agent behaviour — tasks skipped, gates missed, compaction not performed. The only discovery mechanism is an operator noticing the error during a session, or a future audit finding the drift.

## Pain Points

1. **No automated detection of skill-policy drift.** When a policy document changes, no mechanism surfaces which skills reference it. The operator must remember or discover by reading each skill.

2. **No way to verify skill correctness without a human in the loop.** Running a skill in a real session is the only test — but that's expensive, distracts from session work, and can't be done at scale.

3. **Skills encode different granularities of the same policy.** `new-session.md` and `new-session-v2.md` both attempt to encode Steps 1–2 and Gates 1–2 of the minor loop, but with different levels of detail, different structural approaches, and different staleness. Without a comparison mechanism, we don't know which one is correct or whether either is.

4. **Headless evaluation (e.g. `pi -p`) doesn't help for session-start skills.** The skill under test would try to create a handover, run recovery checks on a real roadmap, and operate on the current project state — all side effects that conflict with the active session.

5. **The comparison surface grows quadratically.** Each policy revision produces N skills to check. Each skill references M policy sections. The audit load is N × M and grows with every policy change and every new skill.

## Constraints

Any solution must satisfy:

- **No side effects on the active session.** Evaluating a skill must not create handovers, mutate the roadmap, or modify the working tree.
- **Repeatable.** Running the same eval against the same skill and policy state must produce the same result.
- **Operator-reviewable.** Outputs must be structured so a human can confirm correctness without reading every line of policy and skill in parallel.
- **Low ceremony.** If setting up an eval is more work than a manual read-through, it won't be used.
- **Compatible with the existing policy architecture.** Evals must reference canonical policy documents, not fork or duplicate them.

## Open Questions

1. **What does an eval look like for a prompt/skill?** Is it a structured assertion table (e.g. "skill line X references policy section Y — correct / stale / missing")? A diff between the skill's implied policy steps and the canonical policy steps? A trace of expected agent actions given mock state?

2. **How do we isolate side effects?** Could we run evaluations inside a temporary sandbox container with a mock project state? Does pi support a headless mode with tool-output mocking?

3. **How do we track skill→policy dependencies?** Should skills declare their dependent policies explicitly (a `## Dependencies` section), or should the mapping be maintained as a separate registry?

4. **What is the minimum viable eval?** If we can't build a full system immediately, what's the lightest mechanism that catches drift before it enters a session?

## Investigation Findings

### Source analysis — Capability evals for model selection (Mima case study)

A published case study describes selecting a local 3B model to replace Claude Sonnet for production summarization features. The approach maps directly to our prompt/skill evaluation problem:

**Core pattern: capability eval → golden dataset → evaluators → Pareto tradeoff**

1. **Golden dataset** — A set of ideal outcomes to measure generated outputs against. For prompts/skills, this is a checklist of invariants the skill must satisfy: correct step numbers, correct policy references, absence of stale terminology, presence of required gates. Not a collection of outputs — an invariant spec.

2. **Evaluator types** — Three tiers, mapped to our domain:
   - **Code-based (deterministic, fast, free):** grep/structural checks. "Does the skill reference `Step 1b`?" (fail — should be `Step 2`). "Does it mention compaction at Step 1?" (fail — moved to Steps 8-9). These catch the most common drift patterns at zero cost.
   - **LLM-as-judge (slow, costly, good for subjective):** "Is this skill's language actionable for an agent?" "Does it cover edge cases?" Useful for final verification, not as a primary check.
   - **Human (operator review):** The final gate — operator confirms code-based + LLM-as-judge results.

3. **Capability eval** — Run once per policy change. Feed all dependent skills through the same code-based evaluators. Result: a table of which skills passed which invariants. The only variable is the skill — same evaluators, same policy revision.

4. **One variant per variable** — When comparing skills (v1 vs v2), run both against the same golden dataset. Isolate what each does differently. v2 adds divergence detection; v1 is shorter. The tradeoff is coverage vs. token cost.

5. **Regression eval** — Live with the project. When a policy file is touched, a CI step runs code-based evaluators on all dependent skills. Flags violations before a stale skill enters a session.

### Concrete approach for new-session v1 vs v2

**Golden dataset — invariants a correct session-start skill must satisfy (post-20260522-01 policies):**

| # | Invariant | Check |
|---|---|---|
| I1 | References scope gate as "Step 2", not "Step 1b" | grep |
| I2 | Does NOT perform compaction at Step 1 (moved to Steps 8-9) | grep |
| I3 | Trigger B recovery: create handover → run Trigger B → record → present in scope | grep for ordering keywords |
| I4 | Includes both scope gate (Gate 1) and AC gate (Gate 2 / Step 5) | grep |
| I5 | References canonical policy docs rather than restating them | grep for policy file references |
| I6 | Does NOT reference "before compacting or creating" (old Trigger B wording) | grep |
| I7 | Does NOT reference old compaction model ("compact any fully-completed task groups" at Step 1) | grep |
| I8 | Contains correct session type table (8 types) | grep |

**Evaluators to run now (code-based, zero cost):**

```bash
# For each skill file $f:
grep -qi "step.*1b" $f && echo "$f: STALE — references Step 1b instead of Step 2"
grep -qi "compact.*step 1\|compaction.*step 1\|compact.*task groups.*previous session" $f && echo "$f: STALE — compaction referenced at Step 1"
grep -qi "before compacting or creating" $f && echo "$f: STALE — old Trigger B fallback wording"
grep -qi "recovery check.*trigger B\|trigger B.*recover" $f && echo "$f: CHECK — does Trigger B ordering match new policy?"
```

**Pareto tradeoff for v1 vs v2:**

| Dimension | v1 | v2 |
|---|---|---|
| Length (token cost) | ~50 lines | ~90 lines |
| Divergence detection | None | Two-step type + topic check |
| Explicit commands | None (assumes agent knowledge) | `ls`, `grep` commands inline |
| Policy staleness risk | References old policy by reference (harder to detect drift) | Inlines old policy concepts (easier to detect drift) |

v2 is the Pareto-dominant option for correctness — it's longer but every line of length is justified by correctness coverage. v1 is shorter but misses divergence detection entirely.



4. **How do we test session-start prompts without an active session?** The current system has no mechanism for parallel or sandboxed sessions — running a session-start prompt headless still operates on the real project state (handovers, roadmap). This is a known limitation related to parallel session support, scoped somewhere in M2 but not yet assigned to a specific milestone. Marked as a gap in the current eval approach: code-based evaluators (grep) work fine, but behavioral evals that require the prompt to produce actual handover output cannot be run without disrupting the active session.

5. **Code-based evaluators can't parse negation.** The I2 check (`grep -qi "compact.*step 1"`) false-flags V3 which says "Compaction is no longer a Step 1 action." Dumb grep catches the proximity of "compaction" and "Step 1" but can't distinguish instruction ("compact at Step 1") from clarification ("do NOT compact at Step 1"). Fix: add exclusion patterns (`grep ... | grep -v "no longer"`) or accept that code-based evaluators produce false positives that require human triage.

## Open Questions (revised)

1. **What is the minimum viable eval?** The code-based evaluators above (grep for stale terms) can run immediately at zero cost. Is that sufficient for a first iteration, or do we need LLM-as-judge from day one?

2. **How do we track skill→policy dependencies?** A `## Dependencies` section in each skill listing which policy documents it encodes (per the [Related Skills table added to `handover_policy.md`](docs/operations/handover_policy.md#related-skills)) vs. a central registry. Which is lower-maintenance?

3. **Where do regression evals live?** A CI step that runs on policy file changes, or a pre-commit hook, or a manual script invoked during session-open recovery checks?

Not yet reached.
