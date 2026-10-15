---
description: Scope a rough ask into an executable run brief. Runs the four-question expansion before rewriting the ask, so the brief states the premise under test, the rawest source, the method, and the check that proves the result. Deliverable is one brief file. Use when the operator hands over a task idea and wants it sharpened before it runs.
argument-hint: "[the rough ask - required]"
---

> $@

# Scope - From a Rough Ask to a Run Brief

**Scope:** the scoping interview and the brief it produces. It does not open a session, resolve design decisions, or run the work.

Turn one rough ask into one executable brief. The ask arrives as the operator's own words, shaped by what they already know and already believe. The four questions below widen it before it is rewritten, because a prompt rewritten without them asks for the same task in better prose.

## Purpose

A brief is what a run reads. It carries the premise under test, the material to start from, the method, and the check that proves the result. This prompt produces that brief and nothing else.

The deliverable is one file at `devlog/briefs/`. The home is stated once, here; a change to it changes this line and the pointer in `docs/development/prompt-authoring-conventions.md` owns the rest.

## When to use

Use when the operator hands over a task idea, a complaint about the current state, or a request to rewrite one of their own prompts.

Three cases route elsewhere.

- The ask needs decisions resolved before it can be run, not sharpened. Use [`plan.md`](../../workflow/coding-agent/prompts/plan.md).
- The work is already scoped and needs executing. Use `iter.md`.
- The ask is a question with a cited answer, not work. Use the `how` skill if the run is not yet known; a scoping brief with no run to brief is not this prompt's subject.

## The four questions

Ask all four, in order, before writing a word of the brief. Answer them in chat. The operator reads the answers and can correct the premise before the brief costs anything.

1. **What would a top professional in this field do here that the asker is not asking for?** Name the moves the ask leaves out: the measurement that should come first, the artifact that should exist and does not, the constraint the ask treats as fixed but is not.
2. **What is the rawest material they would start from, rather than what has already been digested?** Name the primary sources: the transcripts, the logs, the vendor documentation, the git history, the recorded data. Name the digest being handed over instead, and why starting from it inherits its blind spots.
3. **What specific methods and tools would they use?** Name the instruments, not the intentions. A probe, a script, a state machine, a bakeoff, a state-of-the-art technique. Name the tool that produces the evidence.
4. **What, other than the asker or the agent, would show the result is right?** Name the external check: a gate, a measurement, a second reader, a live artifact, a vendor's own documentation. A check the agent could run itself is not an external check.

Each question has a failure mode worth watching for.

- A question answered with a restatement of the ask answers nothing. Push until it names something the ask does not contain.
- An answer the tree already holds is not an answer to question 1 or 2. Search before writing it down, and cite what was found.
- Question 4 answered with "the tests pass" is not an external check. Name the artifact a reviewer reruns.

## Rewrite the ask

Write the brief to ask for exactly what the four answers describe. Do not preserve the original framing where an answer changed it. The commonest rewrite is a premise moved to the front as a thing to falsify rather than a thing to assume.

Then state what the rewrite changed. One line per change, so the operator sees the edit rather than the result.

## The brief's shape

A brief carries these parts. Omit one only when the run genuinely has none.

| Part | Holds |
|---|---|
| The premise | what is under test, and what its falsification would mean for the scope |
| What is already measured | the facts the run must not re-derive, each with the command or file that produced it |
| The rulings | the lines the run must not cross, stated with the reason |
| The phases | each phase's question, deliverable and dependency order |
| The run shape | which phases fan out, which compete, and the widest wave |
| The model assignment | a seat per role, with why, and the seats known to be dead |
| Verification | the checks, each naming the artifact that proves it |
| Constraints and invariants | what the run must not do, and what must stay true across it |
| What would settle this brief | the inferences that keep it a draft |

The measured-facts table is the part that pays most. A fact recorded with its command stops the next run from spending a session rediscovering it.

## Scope the record

When the ask warrants its own milestone, stage it in `devlog/roadmap.md` under the active top-level milestone, per the filing rules in the project's `task-list` convention. State the dependency on the prior sub-milestones, name the evidence, and give each task row a file and a nature of change. Do not restate a row that already exists; name it.

A task row is warranted when the work needs a design decision, spans iterations, or closes a policy gap. A one-edit defect is corrected in place and named in the handover instead.

## Close

Stop after the brief and the roadmap row. The operator reviews both, then says whether to commit. A brief written by an agent is a draft by default, whatever its author claimed.

## Non-goals

- Running the brief. This prompt ends at the artifact.
- Resolving the decisions the four questions surface. A surfaced decision goes in the brief as an open fork with the default taken and the word that reverses it.
- Answering the ask. `/scope` produces the instrument that answers it.

## Failure modes and invariants

- **The four questions skipped.** The brief then asks for the same task in better prose. The only acceptable skip is an ask already rewritten by this prompt, and the skip is stated.
- **The premise kept as an assumption.** An unstated premise is the failure the first question exists to catch. Write it down even when the evidence supports it.
- **A digest mistaken for a source.** A report about the system is not the system. Name the primary source or say that none exists.
- **A self-check offered as verification.** The agent's own test is not question 4's answer.
- **The brief run before it is reviewed.** A brief is a draft until the operator releases it.

Invariants: one brief per ask; every measured fact carries its command; every ruling carries its reason; no task row that duplicates an existing one.
