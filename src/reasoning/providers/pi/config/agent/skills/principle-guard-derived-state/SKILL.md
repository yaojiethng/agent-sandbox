---
name: principle-guard-derived-state
description: "Undetected staleness is the failure, not stored state. Run an inventory of the tree and give every artifact a mechanical way to catch its staleness: reproduce it at read time, gate it with a regenerate-and-diff, or delete it. Apply when managing a catalog, index, registry, lockfile, snapshot or generated file."
metadata:
  claim: source
  leitwort: staleness
---

# Guard derived state

Undetected staleness is the defect, not stored state, so every artifact is either derived dynamically at read time or protected by a mechanical verification gate.

**The pattern.** Evaluate the tree with three filters, applied in this order. The first that holds decides the classification.

1. Reproducibility: the derivation is bound to point-in-time state, such as a network resolution or a version that moves.
2. Auditability: the stored artifact is shipped so an external party can review the generated diff against the contents on disk, for non-repudiation.
3. Cost of derivation: how expensive the artifact is to produce, which decides how frequently we want to recreate it.

| Classification | Stored | How staleness is caught | Lifecycle | Examples |
|---|---|---|---|---|
| Authored source | yes | none, and none is needed | until it is rewritten | hand-written code, an authored document |
| Gated copy | yes | regenerate and diff, in a CI gate that asserts zero diff | until the baseline it pinned moves, and the gate reports it | lockfile pinned to a resolved version, statechart, golden file, test fixture, vendored snapshot |
| Derived on read | no, it is gitignored | computed on demand, by tooling at execution or read time | one read, one session, one request | cheap index, build output, cache |
| Dead weight | no, it is deleted | none, which is why it is deleted | ended | a committed cache, a pre-computed index nothing reads |

An artifact with no derivation is authored. Reproducibility or auditability makes it a gated copy: a lockfile records what the resolver returned, and a golden file is shipped so an external party can diff the regenerated output against it. A build directory that costs milliseconds to produce is derived on read and gitignored. A derivation that costs minutes, or needs state the tree does not hold, is stored behind a regenerate-and-diff gate. A stored artifact that no gate checks is dead weight.

**Why.** A stale file carries no warning marker, so it looks identical to a fresh one. Nothing in the file expires. Without a gate, catching the drift falls to human gardening, which operators skip. The gate turns that habit into a failing check.

**A table is half a copy and half a source.** A count of files per directory is derived, because the tree can enumerate it. A cell that carries a description, an edge or a decision is authored. The unit is the column, not the file, so secure a derived column with an extraction script or split it out of the table.

**A copy whose producer is deleted becomes authored by accident.** It survives as the only source and is maintained by hand from then on. Rewrite the producer, gate the copy, delete it, or claim it as authored. Record which one you chose.

**A cache's lifecycle is its scope.** A cache kept past that scope is a bug. A committed cache never had a scope to outlive.

**A value in a sentence is the neighbouring question.** `communication-principle-only-derive-what-you-own` at `$AGENT_HOME/agent/skills/communication-principle-only-derive-what-you-own/SKILL.md` judges a count or a total stated in prose. This one judges an artifact stored in a file. The root is shared and the object is not.

**The test.** Ask what breaks if the artifact is stale, and who detects it. If nothing detects it, the artifact is a defect, however cheap it is to reproduce.
