---
name: eval
description: "Runs a behaviour eval of an instruction set: a declared case set, one isolated run per configuration, grading against the fixture, and a benchmark. Operator-invoked when the question is whether a skill, prompt or policy actually changes what the agent does."
disable-model-invocation: true
---

# eval

An eval answers one question. Does this instruction set change what the agent does, and is the change worth its cost? A text check reads the document; only a run reads the behaviour.

## Purpose

Run a case set against two or more configurations of the same task, grade each run against the fixture, and report the pass rate, the wall clock and the token cost per configuration. The result is a graded table and a verdict.

**The source is the agentskills guide**, [`evaluating-skills.mdx`](https://github.com/agentskills/agentskills/blob/main/docs/skill-creation/evaluating-skills.mdx). It owns the loop, the case-file shape, the assertion rules and the benchmark shape. This skill carries only what the guide cannot know: how a run is isolated here, and what the harness supplies.

**Blinding** follows the poteto-mode [`eval` playbook](https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/eval.md). Sanitize every name a run sees. Keep the prompt an organic operator message. Never let a run learn that a comparison is happening.

**Sustained improvement**, rather than one answer, is the [hillclimb playbook](playbooks/hillclimb.md): one metric, one edit per batch, a paired control, and the decision log that says which edits were kept and which were reverted.

## When to use

- A skill, prompt or policy is about to be relied on, and nobody has measured it.
- An instruction set changed and the change claims a behaviour.
- Two wordings compete and the difference is empirical.

Not this. A document checked against the policy it encodes is cheaper and is not an eval. Reaching for a run where the assertion is a character count is also not this.

## The run

1. **Case set.** One JSON file per subject, in `evals/` beside this skill, named for the subject. A case carries `id`, `prompt`, `expected_output`, `fixture`, `assertions`, and the source of the negative case it reproduces.
2. **Fixtures.** One project per case per configuration, outside the repository, in a work root: a temp directory that does not outlive the run. Start from a `/package-eval-snapshot` bundle for a real past state, or a trimmed copy of the working tree. Inject the case's defect, then commit the fixture so the run sees a clean tree. When the baseline must not read the subject, the subject's own file leaves the baseline fixture.
3. **Isolation.** Copy the pi config directory and set `PI_CODING_AGENT_DIR` per configuration. That copy stays under the run's output slug, because it is an artefact of the run; only the worktree moves to the work root. The two configurations differ by one entry: a package root, a skill, or the fixture's copy of the policy text. Nothing else changes between them.
4. **Runs.** One `pi -p` subagent per case per configuration, in the foreground of the call that owns them, each with its own log, session file and timeout. Take the provider, model and thinking level from the project's role tags, and read the model back from the session file to prove the request was honoured.
5. **Grading.** Grade mechanically where the assertion is mechanical. Where it is not, one blind grader per case scores every configuration's output in a single pass, by sanitized label, after establishing ground truth from the fixture itself. Evidence is a quote or a line reference. A report silent on an assertion fails it.
6. **Benchmark.** Pass rate, mean wall clock and mean tokens per configuration, then the delta. The measures, logs and session files live under `$HOME/workspace/output/evals/<slug>/`, and the run's change travels beside them as a bundle of the delta from the fixture's base commit, with a patch for whatever the run left uncommitted. The worktree itself leaves nothing behind. No artefact lands in the repository.
7. **Iterate or stop.** An assertion that passes in every configuration is removed or replaced: it measures the model, not the instruction. A failure in the subject is a finding with evidence, never a silent fix. Stop when the case set stops changing the answer.

## Invariants

- A run writes nothing inside its fixture's project tree.
- A worktree does not outlive its run: the run's change comes back as a bundle, plus a patch for any remainder.
- One variable per comparison. The case set, the fixture and the prompt are identical across configurations.
- No assertion is graded without the evidence that satisfies it.
- A graded artefact stays outside the repository, at the path the benchmark names.
