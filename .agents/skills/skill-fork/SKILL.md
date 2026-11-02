---
name: skill-fork
description: Fork an upstream skill, runbook, prompt or instruction into this tree, and keep it current against upstream. Use when the operator asks to vendor a skill from a remote set, fork or clone an upstream artifact, or bump an existing fork to a newer revision.
---

# skill-fork

An upstream artifact comes into this tree as a fork: it keeps what earns its place, loses what belongs to the upstream's provider, and carries an edge in the source store so a later bump knows what it came from. This skill owns that lifecycle, both halves of it.

## Which half

| The operator says | Open |
|---|---|
| vendor this, fork this, install this upstream skill | [`patterns/fork-and-strip.md`](patterns/fork-and-strip.md) |
| bump this, take the new upstream revision, re-base this fork | [`patterns/upstream-bump.md`](patterns/upstream-bump.md) |
| which artifacts does this provider have that we must strip | [`patterns/provider-artifacts.md`](patterns/provider-artifacts.md) |

A fork is opt-in maintenance. An artifact with no edge is one nobody bumps, and nothing requires an edge; the store exists so that a bump has facts to read, and its reader is the maintainer running one.

## The edge is the boundary

The store at `.agents/registry/sources/` is the record, and it points at the tree: an edge names the local path, the upstream path and the revision the next merge starts from. `.agents/skills/skill-fork/patterns/upstream-bump.md` `## Register an edge` states the shape and the fields; write it at vendoring time, because that is when the facts are known.

Nothing points the other way. The artifact carries no record file and no provenance line, so a reader who wants to know where a skill came from opens the store. Keeping the two in step is the operator's, since a wrong edge breaks the next bump and nothing else.

## Writing a skill that is not a fork

A skill written here - not installed from upstream - has no edge and no upstream. Take `skill-scaffolder` instead: it owns the authoring steps, the signpost and the authoring patterns.
