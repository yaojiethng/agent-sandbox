---
description: Port a stale branch onto a target branch by replaying the intent of each iteration. One commit per iteration; the target history reads as if the work was done there fresh; no port artifacts remain.
argument-hint: "[stale branch] [target branch] [port intent - what the stale branch was for, known supersession concerns]"
---

> $@

## Mandate

You are porting a stale branch onto a target branch. The operator named both branches and stated the port intent. Your deliverable is the stale branch's work done again correctly on the target: each iteration becomes one commit, and the target history reads as if that work had always lived there.

Three rules govern this run.

First, replay intent, not diffs. A formulaic rebase copies hunks; a port re-realizes what each iteration was for against the target's current state. Content the target already carries is dropped. Content the target superseded is adapted or dropped. Content that landed only as a failed patch is completed. The stale diff is the raw material, never the goal.

Second, preserve iteration granularity. One commit equals one iteration. The stale branch's commits each carry their own handover; the replayed commits keep the original messages and their handovers, in the historical order. No squash merges the iterations together, and no extra commit describes the port. The port leaves no scaffolding.

Third, stop on real architectural divergence. When the target's design contradicts a stale iteration's approach, or the intent is ambiguous and the records do not resolve it, stop and ask. Do not guess. Merely textual conflicts, additive merges, and stale counts are your work to resolve; design conflicts are the operator's.

## Input contract

| Input | Meaning |
|---|---|
| stale branch | The branch carrying the work to port, typically a draft export. |
| target branch | Where the work lands: the current working line, usually a `feat/` branch. |
| port intent | What the stale branch was for, plus any known supersession concerns. |

The argument slot may carry extra context: handover references, session-log locations, or operator rulings. Use them; ask for what is missing.

## Establish topology

Map the branch graph before reading any commit.

- The merge-base of the stale branch with the target, and with main. When main's head equals the base, main has nothing to supersede anything; run the supersession check against the target instead.
- What the target added since the divergence: `git log --oneline <merge-base>..<target>`, then the files those commits touched.
- What the stale branch added: `git log --oneline <merge-base>..<stale>`. Classify each commit: its type, its files, and the handover it carries or references.
- File-level overlap: which stale-touched files the target also changed since the base. Disjoint files replay cleanly; shared files need the supersession decision first. The roadmap and the project index are the usual shared files, and their edits are usually disjoint regions.

## Collect the intent

Read the handover of every stale iteration before touching any file. In this repo the handover rides inside its commit; read it with `git show <stale-commit>:<path>`. The pi session log is the fallback when a handover is missing or silent.

For each iteration record four things: the objective, the acceptance criteria, the decisions, and the deferred items. The deferred items of one iteration often become the carried-forward scope of the next; note the thread. A commit whose handover is absent may still be understood from its message and its diff, but say that you reconstructed it.

## Exclude pipeline artifacts

A draft export carries metadata that is not content.

- `.draft-state` records the export: source branch, hashes, timestamps. Never port it; on the new base it would record false state.
- `.rej` files are rejected patch remnants. They mean the iteration's intended change did not land. Realize the change on the current target and do not carry the `.rej`.
- Stray untracked handovers in the working tree describe sessions outside the branch. Flag them to the operator; do not port them.

Name the exclusion in your report. An operator expects the metadata file and the stray to be gone from the result.

## Check supersession

For each stale change set, decide one of: present, superseded, merged, live, or divergent.

- Present: the target already has the change, possibly as its own commit with a different hash. Drop it and say so. Per-file identity is `git diff --quiet <stale> <target> -- <file>`.
- Superseded: the target changed the same area with a newer design. Keep the target's version; adapt the stale intent to it, or drop the intent when the newer design made it obsolete.
- Merged: both branches changed the same document in disjoint regions, one bullet here and one row there. Keep both sides. This is the common case for the roadmap and the project index.
- Live: the change is absent from the target and uncontradicted. Port it.
- Divergent: the target's design contradicts the stale iteration's approach. Stop and ask; this verdict never resolves itself.

## Replay

Create one commit on the target for each stale iteration, in the historical order. Reuse the original commit message; it carries the type prefix and names the handover. Do not add cherry-pick provenance notes; the target history must read as original work.

Adapt the content as the current state requires, as if the iteration had run on the target. Fold current-state corrections (counts, suite totals, status lines) into the commit that owns the subject. Replace rejected-patch artifacts with the applied change. Resolve additive conflicts by keeping both branches' content.

No port commit exists. The port record is the operator session, not a commit. If the exact stale content would contradict the target's own recent edits, the target's edits win; your job is the stale intent, layered on top of the target's reality.

## Verify

- The ported files equal the stale branch's trees where the replay was faithful: `git diff --quiet <stale> <target> -- <file>`, per file.
- The tree diff against the stale branch shows only excluded artifacts, target-side content, and applied corrections.
- The test suite is green under the repo runner; lint is clean on the changed scripts.
- `git status` is clean apart from operator-owned strays you flagged earlier.

## Close

Report the topology, the supersession verdict per change set, the commits created, and the verification numbers. Name everything dropped and why. Surface the deferred items from the ported handovers and the strays in the working tree. End with the one question that matters: whether the port intent is fully realized on the target.
