---
description: Write one executable brief from a rough ask. Run the four-question expansion, rewrite the ask into the brief that asks for exactly what they name, and refine the plan and the prose with the principle corpus. Use when the operator hands over a task idea, a complaint about the current state, or one of their own prompts to deepen.
argument-hint: "[the rough ask - required]"
---

> $@

# Scope - From a Rough Ask to a Brief

**Scope:** the four questions, and the one brief they rewrite the ask into. `/scope` writes the brief and nothing else.

## Purpose

A brief is what a run reads: the premise, the material, the method, the check and the units, in the form a later run can execute.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `task-list` - where a brief's work units are filed.

## When to use

Use when the operator hands over a task idea, a complaint about the current state, or one of their own prompts to deepen.

An ask that needs decisions resolved before it can be written is [`plan.md`](plan.md)'s. Work already scoped and waiting to run is [`iter.md`](iter.md)'s. An ask whose answer is a citation is answered, not briefed.

## The four questions

Ask all four, in order, before rewriting the ask, and answer them in chat. The operator reads the answers and can correct the premise before the brief costs anything. Each question is deepened by the skills beside it, named rather than restated; every principle skill is at `$AGENT_HOME/agent/skills/<name>/SKILL.md`.

1. **What would a top professional in this field do here that the asker is not asking for?** `principle-attack-the-premise`.
2. **What is the rawest material they would start from, rather than what has already been digested for me?** `principle-guard-derived-state`, `communication-principle-only-derive-what-you-own`, `principle-guard-the-context-window`.
3. **What specific methods and tools would they use?** `principle-build-the-lever`, `principle-check-placement`, `principle-exhaust-the-design-space`.
4. **What, other than you or me, would show the result is right?** `principle-prove-it-works`, `communication-principle-show-dont-describe`.

## Rewrite the ask

Write the brief to ask for exactly what the four answers describe, and do not preserve the original framing where an answer changed it. Then state what the rewrite changed, one line per change.

## Refine the plan and the prose

The four answers say what the brief asks for. The principle corpus decides how it is formed and phrased, and each judgement is named where the brief must satisfy it, never restated.

- Forming the plan: `principle-model-the-domain`, `principle-subtract-before-you-add`, `principle-never-block-on-the-human`, `principle-match-precision-to-stakes`, `principle-sequence-verifiable-units`.
- Phrasing the brief: `communication-principle-write-for-the-reader`, `communication-principle-cut-what-carries-nothing`, `communication-principle-only-derive-what-you-own`, `communication-principle-show-dont-describe`, `communication-principle-align-the-mental-model`, `communication-principle-attach-as-you-read`, `communication-principle-one-addressing-axis`, `communication-principle-keep-a-subject-near`, `communication-principle-maximize-conceptual-leverage`.

## The brief's parts

A brief is executable when it carries:

- the premise, as one falsifiable sentence;
- what is already measured: the facts the run must not re-derive, each with the command or file that produced it;
- the rulings: the lines the run must not cross, each with its reason;
- the phases: each phase's question, deliverable and dependency order;
- the run shape: which phases fan out, which compete, and the widest wave;
- the work units: the table below;
- the model assignment: a seat per role, with why, and the seats known to be dead;
- the check that proves the result, as the artifact a reviewer reruns;
- the constraints and invariants: what the run must not do, and what must stay true across it;
- what would settle the brief: the inferences that keep it a draft.

## The work units

The brief carries a work-unit table, because a task decomposed into units is a run and a task that is not is a wish. [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md#unit-and-scope-invariants) defines it: one row per unit, naming the unit, its commit type, the owned files and its handover.

A unit is one concern. Several concerns that share a commit type are several units, and one concern crossing a data file, a prompt and a policy clause is one unit.

`/scope` emits the table and does not file it: where a row lands is the project's `task-list` convention's, and when it lands is the close of the session that runs it, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md#close-invariants).

## Hand off

Print the suggestion and stop. The brief can go two ways, and the operator picks:

- **A run.** The operator takes it to the next runbook, which reads it: [`iter.md`](iter.md) for a unit, [`plan.md`](plan.md) for a decision.
- **A saved file.** It lands at `.agents/drafts/` for a later run.

`/scope` writes neither without the operator's word, and it opens no handover, no roadmap row and no commit.

## Non-goals

- Running the brief.
- Answering the ask. `/scope` writes the instrument; the run answers it.
- Opening a session, a record or a commit.
- Resolving the decisions the four questions surface: the brief names each as a fork, with the default taken and the word that reverses it.

## Failure modes and invariants

- **The four questions skipped.** The brief then asks for the same task in better prose. The only acceptable skip is an ask this prompt already rewrote, and the skip is stated.
- **The premise kept as an assumption.** Write it down even when the evidence supports it.
- **A digest mistaken for a source.** A report about the system is not the system. Name the primary source, or say that none exists.
- **The brief grown instead of deepened.** More subjects is a bigger task; the same subject with a sharper entry point is a deeper one.
- **A judgement restated instead of named.** The skill is its source, and the brief is not.

Invariants: one brief per ask; every ruling carries its reason; no session, no commit.
