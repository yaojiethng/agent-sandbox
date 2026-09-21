# Harness Iterative Improvement Loop

**Current:** 2026-09-21

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | A tripped mistake is captured in the iteration's record | the agent records a Finding in the handover when it trips |
| R2 | Recurrence accumulates on one entry | a repeat opens the same entry, not a sibling; the frequency record rises |
| R3 | A durable fix routes to a roadmap or skill home | the agent follows the elevated rule, not the raw tracking file |
| R4 | The operator sees the pattern and scopes elevation | the frequency signal surfaces at scoping time, not in a per-session read |

## 2026-09-21 -- Cataloguing and frequency reader model

**Decision:** this session changed the processing procedure of the improvement loop. The changes, each contrasted against the previous design:

- **Reader model.** The feedback and gotchas records are a frequency-tracking signal, not the agent's per-session behavior source (previously: the agent read open gotchas as a session-open primer).
- **Capture.** When the agent trips, it records the mistake as a Finding in the handover (unchanged from the prior design; this is how the agent learns at the moment of tripping).
- **Catalogue.** A recurrence re-opens its existing entry and extends the frequency record. Catalogue grep-first: before writing a new entry, find the same-topic entry and record the recurrence on it (previously: entries were point-in-time records with no consolidation duty at write time; consolidation ran only at the cleanup pass).
- **Elevation.** A durable fix routes to a `scoped:` roadmap row or a skill, and the agent follows that rule. The raw file is not the agent's behavior source (previously: fold accumulated patterns into a skill, per session-open primer).
- **Sweep.** At sub-milestone cleanup, a sweep applies each gotcha's durable fix across recent code (unchanged).
- **Surfacing.** The agent surfaces open entries to the operator at the pre-close review gate (unchanged).

**Rationale:** agents take instructions literally. A prohibition-style primer ("avoids or re-checks those patterns") reads as a free-floating task, because a literal reader cannot resolve what to avoid or what the action is. Recording the mistake at the moment of tripping is how the agent learns; accumulating recurrence on one entry is how the operator reads frequency and scopes a durable fix. This satisfies R1, R2, R3, and R4.

**Rejected alternatives:** kept the session-open primer with the durable skill as the elevation home (the prior model) -- rejected because the primer read as a task and added no reliable value the mistake-as-Finding capture already provides.

**Edge cases / drivers:** the writing rules now carry a literal-reader test (`documentation_policy.md`): encode a rule as an instruction that names the object and the action, not a prohibition. That test is a driver for this decision. When the reader model changes, both the raw record file and the policy pointer must change together; the raw `GOTCHAS.md` was the last surface to move in the sweep.

## 2026-08-09 -- Session-open primer reader model

**Decision:** at session open (Step 1), the agent reads the open gotchas and avoids or re-checks those patterns during the session. Sweep-and-fix at sub-milestone cleanup; fold accumulated patterns into a skill.

**Rationale:** the gotchas channel was short, so a session-open read kept the agent primed against known mistakes without much cost. It reinforced a standing directive in the root `AGENTS.md`.

**Rejected alternatives:** not recorded in the source.

**Reason superseded by 2026-09-21:** a literal agent reads "avoids or re-checks those patterns" as a task to perform, not a rule to hold. The durable fix belongs in an elevated rule the agent follows, not in a per-session read of a tracking file. The mistake-as-Finding mechanism already teaches the agent at the moment of tripping, so the primer added no reliable value and introduced a misreading risk.
