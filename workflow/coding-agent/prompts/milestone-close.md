---
description: Close a milestone or sub-milestone. Compaction, changelog entry, summary-table and frontmatter write-back, review-gate reconciliation, and the close commit.
argument-hint: "[milestone name - for example M3.1 - Backpressure]"
---

> $@

# Milestone Close - Loop (Main-Agent Template)

**Scope:** record that the named milestone's work is complete.

This prompt is the loop surface for the close. Its body is in [`milestone-close-run.md`](milestone-close-run.md) as the run template, which is the M3.2.1 U4 migration target: the close procedure moves out of `milestone_policy.md` Closing the Major Loop and `iteration_policy.md` Sub-milestone close and Steps 8-9 into `milestone-close-run.md`.

## Invocation

Run the close per [`milestone-close-run.md`](milestone-close-run.md). The milestone name always comes from the operator; the same procedure closes a sub-milestone and a full milestone, stopping one level earlier for the sub-milestone.

## Prior milestone close (parked for U4)

The `iteration_policy.md` Major Loop previously carried a "Close prior milestone" step (Step 1). The step's procedure moved here so it survives until the U4 migration formalizes it. When the major-loop open needs the prior milestone closed:

- Write the changelog entry and extract the completed milestone from `roadmap.md`, per [roadmap_policy.md](docs/operations/roadmap_policy.md) -- Top-level milestone close.
- Prior milestone removed from the roadmap, changelog entry written.

This is a stub. U4 (close procedure into `/milestone-close`) replaces it with the full close body.
