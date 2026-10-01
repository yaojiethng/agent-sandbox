---
description: Draft - run a bounded review loop over a committed diff range - a fresh reviewer per round, ACCEPT or BLOCK, one fix round per block, capped at three rounds.
argument-hint: "[diff range] [reviewer - a skill or a brief]"
---

> $@

# Bounded Review Loop - Run (Main-Agent Template)

**Scope:** how the primary agent reviews a committed diff range to a verdict, without looping: the reviewer invitation, the verdict contract, the fix round, the cap, and the cheap classes swept before every round.

## Purpose

One reviewer, one range, one verdict per round, a cap on the rounds. The primary spawns a fresh reviewer for each round, triages the verdict, fixes the blockers, and converges. The reviewer never edits and never commits.

Use this loop for any review whose outcome is a verdict rather than a proposal: a run's landed units, an iteration's delivery, or a single unit under scrutiny. A loop that cannot converge by the cap reports the open blockers instead of grinding.

## Preconditions

1. **The range is committed, and the tree is clean.** The reviewer reads `git diff <base>..<head>`. A dirty tree lets the reviewer mistake an unfinished attempt for landed work.
2. **The reviewer is named.** A skill (for example `thermo-nuclear-code-quality-review`) or a brief written for this review. Name it, and name the bar it reviews against.
3. **The operator's release**, when the loop runs inside a gated iteration.

## The invitation

```bash
timeout 1800 pi --provider <provider> --model <model> --thinking <level> \
  -p "$(cat /tmp/review/<round>.brief)" > /tmp/review/<round>.log 2>&1
echo "pi rc=$?"
```

The invitation states: the exact range, the reviewer's bar, the required verdict, the round number, the blocker history from earlier rounds, and the model and thinking level (the reviewer cannot see its own invocation flags). Read the model and thinking level from the `_REVIEWER` role recommendation in the project-level `AGENTS.md`; use the first listed when one reviewer is needed.

Read the report from the log: `tail -30 <log>`. A review with no explicit verdict did not happen.

The required tail:

```text
VERDICT <ACCEPT|BLOCK>
BLOCKER <n> <file> <one line>
NOTE <n> <file> <one line>
```

## The bar

State the bar in the invitation. Two are in use:

- The **thermo-nuclear bar**: the Approval Bar of `thermo-nuclear-code-quality-review` - no structural regression, no missed simplification that deletes complexity, no unjustified file-size explosion, no spaghetti growth, no hacky abstraction. Its presumptive blockers are listed in that skill.
- A **task bar**: the acceptance criteria of the unit or run under review, each with its check.

Non-blocking observations are `NOTE` lines. They become roadmap tasks or handover findings; they never extend the loop.

## The loop

1. **Sweep the cheap classes first.** Before each round, the primary checks them itself: documents that pin strings, commands, exit semantics or counts the change altered, one term or count spelled differently across records, and header or usage text that lags the behaviour. These classes are enumerable, and a reviewer spending a round on them is a round wasted.
2. **Review.** Spawn a fresh reviewer for the round. Never reuse a reviewer's context: the reviewer must read the code, not the previous round's reasoning.
3. **Triage.**
   - `ACCEPT`: stop the loop. Record the `NOTE` lines.
   - `BLOCK`: diagnose each blocker, fix it, and commit the fix round as one commit. Then go to 1 with the blocker history added to the invitation.
4. **Cap at three rounds.** If the range is not accepted by round 3, stop and report the open blockers with the round that raised each. A range that will not converge by then has a structural problem that more rounds mask; the operator decides whether to narrow the scope and continue or to take the blockers as tasks.

## Invariants

- A subagent never commits; the primary commits every fix round.
- A fresh reviewer per round; the only carried context is the blocker history the invitation states.
- No blocker is closed by argument: only by a change the next round can see in the range.
- The verdict is on the exact range it was given; a new commit after a verdict invalidates that verdict.
- One loop per range; the cheap-class sweep is not a round.
