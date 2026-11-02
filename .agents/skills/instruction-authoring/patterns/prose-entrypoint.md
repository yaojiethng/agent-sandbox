# Prose entrypoint over a mechanism

Open this when you write a skill that wraps a script, a command, or any mechanism with a fixed call shape. Where a caller may hold the intent but not the invocation, expose two surfaces: the skill turns the intent into a call, and the script owns the call.

## The pattern

| Instead of | Give |
|---|---|
| a skill whose body teaches the flags | a skill whose body produces the invocation |
| a script with no prose surface | the script for a caller who knows the call, the skill for one who does not |
| a skill that performs the mechanism itself | a skill that stops at the command line |
| a second copy of the call inside each consumer | one script, called by every consumer |
| a run's values hidden inside the skill | the pin stated at the call site, visible in the invocation |

## Why

A skill that teaches an invocation becomes a second copy of it, and a copy drifts from the thing it copied. The failure is silent, because both surfaces still work; they simply stop agreeing. Dispatch is the measured instance: three resolvers, five fault lines, and one reviewer skill whose own text states three different model pairs, because every surface carried its own copy of the call.

## When it applies

All three must hold, and each is checkable before the skill is written.

1. The invocation is exact enough that a wrong one fails silently or expensively: required flags, an ordering, a value to read back afterwards.
2. A caller exists whose request names a goal rather than a call, so the caller would otherwise guess.
3. The mechanism changes independently of that intent, so a one-time copy of the command would go stale.

## When it does not apply

Any one of these is enough to withhold the skill.

1. One known call site, owned by whoever owns the mechanism. Test the call there instead of translating it.
2. One command with no required flags that fails loudly and immediately. A skill over it adds a hop and no information.
3. The skill would have to choose policy rather than translate intent, such as which model by taste or how many reviewers a change deserves. Policy belongs to a table or a decision record, where it can be reviewed.
4. The caller is a program. Give it the script; a prose surface has no reader there.
5. The work needs state held across calls, such as a session or a lock. The mechanism owns its state, and a skill cannot hold it.

## The boundary

Two outputs keep the pair honest. The skill's output is a command line, so a caller can read, copy and refuse it; the script's output is what ran and what it resolved to, including the effective value read back. A skill that returns prose about what it did has taken the mechanism back.

## The test

Name the caller whose request is underspecified, and the failure that a wrong invocation produces. If either name is missing, do not write the skill; if both are present, keep the skill's body on the translation and give the invocation to the script.
