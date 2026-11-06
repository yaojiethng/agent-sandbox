# Prose entrypoint over a mechanism

Open this when an instruction wraps a script, a library or a service with a fixed call shape.

## The pattern

The mechanism and the instruction are two surfaces over one utility. The mechanism is what can be designed and tested; the instruction is the human-friendly surface, and it turns an intent into a call. The mechanism keeps the invocation.

| Instead of | Give |
|---|---|
| an instruction that teaches the flags | one that produces the invocation |
| an instruction that performs the mechanism itself | one that stops at the command line |
| the call copied into each consumer | one script, called by every consumer |
| a run's values held inside the instruction | the pin at the call site |

A skill or a prompt may carry the entrypoint; step 2 settles which, so this pattern starts once that is settled.

## When it applies

All three must hold.

| It applies when | Because |
|---|---|
| A wrong invocation fails silently or expensively | the instruction is what stops the call going wrong |
| The caller's request names a goal, not a call | otherwise there is nothing to translate |
| The mechanism changes independently of that intent | a one-time copy of the call goes stale |

## When it does not apply

Any one withholds the instruction.

| Withhold when | Because |
|---|---|
| One call site, and the mechanism's owner owns it | test the call there instead of translating it |
| The command takes no flags and fails immediately when miscalled | an instruction over it adds a hop and no information |
| The instruction would pick policy -- which model, how many reviewers | policy belongs where it can be reviewed, a table or a decision record |
| The caller is a program | give it the script; prose has no reader there |
| The run holds state across calls -- a session, a lock | the mechanism owns its state, and an instruction cannot hold it |

## Why

An instruction that teaches an invocation is a second copy of it, and the copy stops agreeing with the original with nothing reporting it. Dispatch is the measured instance: three resolvers, and one reviewer skill whose own text states three different model pairs.

## The boundary

The instruction's output is a command line, so a caller can read, copy and refuse it; the mechanism's output is what ran and what it resolved to. A body that teaches the flags has taken the invocation back, and an output that reports on what it did has taken the mechanism back.

## The test

Name the caller whose request is underspecified and the failure a wrong invocation produces. With either missing, write no instruction.
