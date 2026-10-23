---
description: "Draft - close the class of error where an agent reaches a model the operator never named, or names a model inline, and reports neither. States the problem and the command that re-derives it, so a reader with no access to the session that wrote this can re-diagnose it against the current tree."
argument-hint: "[scope - gate, filing, or both - optional]"
---

> $@

# Close the Model Bypass

## The problem

An agent reaches a model the operator never named, and reports neither the substitution nor the reason. A measured instance: a grading pass and an adversarial review were both run on `deepseek/deepseek-v4-pro`, a pair appearing in no line of `~/.pi/model-recommendations.md`, and the choice surfaced only when the operator asked why.

The cause is structural rather than careless. The role table is one route to a model, and agent-facing instructions print another. Each of these routes was verified on 2026-10-18.

- **A role line can resolve to nothing reachable, and nothing refuses first.** Every candidate answered `403`, `opencode/*` with `FreeTierError` and `opencode-go/*` with `permission_error`. The dispatch reported `verdict=` empty for both, because neither message matched the refusal vocabulary.
- **A pair no role names can be pinned** through the `--model` pin.
- **A direct invocation bypasses the seam.** An agent that runs `pi --provider <provider> --model <model> -p` reaches a model with no resolver, no fallback and no record.
- **Nothing reconciles intent against outcome.** No check compares the pair a brief asked for against the pair that ran. Searching `src/libs/dispatch.sh` and the dispatch skill's `dispatch.sh` for a mismatch check returns nothing.

## Re-diagnose it from the tree

The carrier list is a measurement and it ages. Re-derive it before acting on any list, including the one below.

```bash
grep -rln -- "--provider \\|--model " .agents workflow src/reasoning/providers/pi/config/agent src/reasoning/agent/config 2>/dev/null \
  | grep -v "opencode-dispatch/SKILL\\|pi-reviewer-dispatch/SKILL"
```

That command returned the following on 2026-10-18, before this file existed. Treat the paths as a starting point, not as the answer. Re-running it after this file lands also returns this file, because the prose above states both flag tokens; that self-match is the reason the matcher must target an invocation shape rather than the bare token.

```text
.agents/audits/test-assertion-sweep-brief.md
.agents/drafts/adversarial-review-run.md
.agents/drafts/maintenance.md
.agents/drafts/review-loop-run.md
.agents/drafts/review-pass-run.md
.agents/drafts/sequential-work.md
.agents/drafts/task-queue.md
src/reasoning/providers/pi/config/agent/AGENTS.md
src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md
src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/dispatch.sh
workflow/coding-agent/skills/eval/scripts/run_case.sh
```

Three of those are legitimate callers of the seam rather than carriers, and the gate must name them rather than discover them. `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/dispatch.sh` runs the seam. `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` documents the provider rather than instructing an agent. `workflow/coding-agent/skills/eval/scripts/run_case.sh` is a test harness.

For each remaining carrier, decide whether the fix is a gate the actor cannot pass or an instruction the actor must remember. Prefer the gate. Discard an instruction-only fix unless no gate is possible.

## The ruling this run obeys

dispatch owns the set of models this container can call, and its seam design lands in a future milestone. A run executing this prompt does not design that seam. Work that changes how dispatch resolves, probes or records reachability belongs to that milestone and is listed below as filed.

## In scope now, the gate

Add one claim to `scripts/check_instruction_surfaces.sh`, with fixture tests through its existing `INSTRUCTION_SURFACE_SCAN_ROOT` seam. The claim: no agent-facing instruction names a provider or a model, only a role.

Two constraints on the matcher, both found by writing this file. Match an invocation shape, such as a line beginning `pi --provider` or a literal `model:` value, rather than the bare flag token, because this document states both tokens in prose and a naive grep fails on the rule's own sentence. And keep the exempt set explicit, so adding a legitimate caller is a deliberate edit rather than a silent widening.

Show the gate failing on today's tree before the fix and passing after. That failing run is the proof the rule bites.

## Filed to the dispatch milestone

- **A capability record** published by dispatch and probed per backend. Facts measured 2026-10-18, to be re-measured rather than trusted. `GET https://api.deepseek.com/models` answers 401 without the key and 200 in 0.13s with it, listing `deepseek-flash` and `deepseek-v4-pro`. A `max_tokens: 1` completion answers 200 in 0.63s. `GET https://opencode.ai/inference/go/v1/models` answers 200 with no auth header at all, so it proves catalogue access and says nothing about inference access. A direct inference POST answers 400 `MissingSessionID`, so that backend cannot be probed out of band and the probe costs what the dispatch costs. `auth.json` stores the string `$DEEPSEEK_API_KEY` rather than a key, so a probe that treats the value as a key reports a false green.
- **A refusal of a pair no role line names**, covering the `--model` pin, with its test.
- **A distinct exit code** for all-candidates-refused, once a caller exists that reads it.
- **Reconciliation** of the pair a brief declared against the pair that ran, printing both.

## Reporting rules

Every claim carries its evidence or its label in the same sentence. For each item say whether it is a gate or an instruction, and whether anything reads it. An output with no reader is filed, not built.

## Deliverable

Three lists. What closes the class today with code, what is filed to the dispatch milestone and why, and what is refused as not earning its place. Plus the failing-then-passing gate output, and a falsification section naming the result that would have overturned each conclusion.
