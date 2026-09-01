# Prompt Eval Protocol

**Status:** Draft  --  working document linked from `20260522-story-active-prompt_eval_infrastructure.md`. Not yet formal policy.

## Purpose

Define a structured process for evaluating prompt templates and skill documents against project policy. Distilled from the three-way `new-session` eval (sessions 20260522-01, 20260522-02).

---

## When to Eval

| Trigger | Scope |
|---|---|
| Policy document revised | All skills/prompts that encode that policy |
| New skill/prompt created | That skill/prompt against relevant policies |
| Variant comparison | All candidates against the same golden dataset |

---

## Eval Process

### 1. Define the golden dataset

For the policy being tested, enumerate invariants the prompt/skill must satisfy. Each invariant is:

- **A checkable claim**  --  answerable by grep, diff, or structural inspection
- **Policy-grounded**  --  traces to a specific section of a policy document
- **One-dimensional**  --  tests one thing, not a compound assertion

Example (from new-session eval):

| Invariant | Grounding |
|---|---|
| I1  --  No "Step 1b" references | `iteration_policy.md` Step naming |
| I2  --  No compaction at Step 1 | `roadmap_policy.md` Steps 8-9 |
| I3  --  Post-close bookkeeping recovery present | `handover_policy.md` Step 1 recovery check |
| I4  --  Scope + AC gates present | `handover_policy.md` Gates 1 and 2 |

### 2. Write code-based evaluators

For each invariant, write a deterministic check. Prefer grep over LLM:

```bash
# I1: No stale step references
grep -qi "step.*1b" "$f" && echo "FAIL I1" || echo "PASS I1"

# I2: No compaction at Step 1 (allow negations)
grep -qi "compact.*step 1\|compaction.*step 1" "$f" | grep -qi "no longer" && echo "PASS I2 (negation)" || ...
```

Code-based evaluators are free, fast, and reproducible. They produce false positives on negation/clarification text  --  flag these for human triage, don't remove them.

### 3. Run one variant per variable

When comparing variants, isolate the variable. Same golden dataset, same evaluators, different prompt:

```
v1 -> eval -> {I1:FAIL, I2:FAIL, I3:PASS, I4:PASS}
v2 -> eval -> {I1:PASS, I2:FAIL, I3:PASS, I4:PASS}
v3 -> eval -> {I1:PASS, I2:PASS, I3:PASS, I4:PASS}
```

Don't interpret results until all variants have been run. The Pareto front emerges from the table, not from read-through.

### 4. Report

Output a structured table:

| Invariant | v1 | v2 | v3 |
|---|---|---|---|
| I1 | [ ] | [x] | [x] |
| I2 | [ ] | [ ] | [x] |
| ... | | | |

Then state the verdict and which failures require fix.

### 5. Behavioral eval (when available)

Code-based evaluators test prompt *content*. Behavioral eval tests prompt *execution*  --  does the agent following this prompt produce correct output? Currently blocked: session-start prompts require pre-state (handovers, roadmap) but headless `pi -p` shares the real project state. See pre-state setup gap in `20260522-story-active-prompt_eval_infrastructure.md`.

When the parallel session gap is resolved, behavioral eval adds:
- Given a project with handover X and roadmap state Y, does the agent create the correct handover?
- Does divergence detection trigger under the right conditions?
- Does the agent stop at Gate 1 / Gate 2 without producing output?

---

## Evaluator Tiers

| Tier | Method | Cost | Catches | Misses |
|---|---|---|---|---|
| **Code-based** | grep/diff on prompt text | Zero | ~80% of policy drift (stale terms, missing sections, wrong step numbers) | Semantic correctness, behavioral correctness, negation ambiguity |
| **LLM-as-judge** | Give a model the prompt + policy + rubric, ask it to score | Token cost per eval | Subjective qualities (actionability, clarity, edge case coverage) | Behavioral correctness (can't execute the prompt) |
| **Human (operator)** | Read-through + confirmation | Operator time | Everything both tiers miss | None (definitionally) |

Use the cheapest tier that catches the failure class. Code-based for regressions, LLM-as-judge for subjective quality, human for final sign-off.

---

## Limitations

1. **Negation false positives.** Grep catches "compact at Step 1" and "no longer compact at Step 1" identically. Mitigate with exclusion patterns. Accept residual false positives as triage overhead.

2. **Pre-state gap.** Behavioral evals for session-start prompts require isolated project state. Current harness has no sandboxed sessions.

3. **Golden dataset staleness.** When policy changes, add new invariants to the dataset. A stale dataset produces green results against broken prompts.

4. **Modular threshold (deferred).** When `new-session.md` grows past ~120 lines or 10 invariants, extract handover-creation logic into a separate skill (`handover-create.skill.md`). At that point, `new-session.md` becomes a coordinator that loads skills rather than inlining all rules. Design note opened 2026-05-22  --  no action until the threshold fires.

---

## Related

- [`20260522-story-active-prompt_eval_infrastructure.md`](../../devlog/discussions/20260522-story-active-prompt_eval_infrastructure.md)  --  Investigation findings, open questions, case study analysis
- [`/tmp/eval-new-session.sh`](/tmp/eval-new-session.sh)  --  Concrete eval script for new-session prompts
- `docs/operations/handover_policy.md#related-skills`  --  Skill->policy dependency mapping
