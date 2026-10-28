---
name: principle-justify-materialization-cost
description: "Whether to materialize a generated result, and what catches its drift if you do. Use when a build, script, gate, test or pipeline produces a result that could become a file."
metadata:
  claim: source
  leitwort: materialization
---

# Justify the materialization cost

Whether to store a generated result is a decision you keep paying for: a materialized copy must be maintained, and it drifts without a warning. The question is not whether storing is cheap but whether deriving again costs more than the upkeep. Derive by default; materialize when re-deriving is the expensive side, and gate the copy.

**The pattern.** Ask three questions in this order. The first that holds decides.

1. **Can the result be derived again?** If not, materialize it. A derivation bound to point-in-time state, such as a network resolution or a version that moves, or to data that no longer exists, is the highest cost there is.
2. **Must an external party see the recorded derivation, not only the result?** A lockfile records what the resolver returned; a golden file is shipped so a reviewer can diff the regenerated output. Materialize it and gate the copy.
3. **How expensive is the derivation?** Minutes of compute, or state the tree does not hold: materialize it and gate the copy. Milliseconds: derive it.

| Classification | Materialized | Drift caught by | Lifecycle | Examples |
|---|---|---|---|---|
| Authored source | no | none, and none is needed | until it is rewritten | hand-written code, an authored document |
| Gated copy | yes | regenerate and diff, in a CI gate that asserts zero diff | until the baseline it pinned moves, and the gate reports it | lockfile pinned to a resolved version, statechart, golden file, test fixture, vendored snapshot |
| Derived on read | no | computed on demand, by tooling at execution or read time | one read, one session, one request | cheap index, build output, cache |
| Dead weight | yes | none, which is why it is deleted | ended | a committed cache, a pre-computed index nothing reads |

**Why.** A materialized copy carries no warning marker, so it looks identical to a fresh one. Nothing in the file expires. Without a gate, catching the drift falls to human gardening, which operators skip. The gate turns that habit into a failing check.

**A table is half a copy and half a source.** A count of files per directory is derived, because the tree can enumerate it. A cell that carries a description, an edge or a decision is authored. The unit is the column, not the file, so secure a derived column with an extraction script or split it out of the table.

**A copy whose producer is deleted becomes authored by accident.** It survives as the only source and is maintained by hand from then on. Rewrite the producer, gate the copy, delete it, or claim it as authored. Record which one you chose.

**A cache's lifecycle is its scope.** A cache kept past that scope is a bug. A committed cache never had a scope to outlive.

**A value in a sentence is the neighbouring question.** `communication-principle-only-derive-what-you-own` at `$AGENT_HOME/agent/skills/communication-principle-only-derive-what-you-own/SKILL.md` judges a count or a total stated in prose. This one judges the artifact a file stores. The root is shared and the object is not.

**The test.** Look for the cost that materialization avoids: an impossible re-derivation, state the tree cannot hold, or minutes of compute. If none holds, derive it. If one does, materialize it and gate the copy. Then ask what breaks if the copy drifts, and who detects it; if nothing does, the copy is unjustified.
