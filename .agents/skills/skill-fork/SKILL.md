---
name: skill-fork
description: Fork an upstream skill, runbook, prompt or instruction into this tree, and keep it current against upstream. Use when the operator asks to vendor a skill from a remote set, fork or clone an upstream artifact, or bump an existing fork to a newer revision.
---

# skill-fork

Upstream text reaches this repository one of two ways, and each has its own procedure.

| Carrier | What it means | The test that settles it |
|---|---|---|
| vendored | an in-tree artifact whose text came from an upstream; this repository carries and maintains it | the store at `.agents/registry/sources/` holds an edge for it |
| installed | text a package brings, which a session loads from the sandbox home; this repository carries only the declaration | a `packages` entry in the sandbox's `settings.json` resolves to it |

`in-tree` is the container both words sit under, so a home-grown skill is in-tree and not vendored. One rule joins the two carriers: **a name has one route.** A name an installed package provides cannot also be vendored until the package excludes it and the store holds its edge.

## Which half

| The operator says | Open |
|---|---|
| vendor this, fork this, take this upstream skill into the tree | [`patterns/fork-and-strip.md`](patterns/fork-and-strip.md) |
| bump this fork, take the new upstream revision, re-base this fork | [`patterns/vendor-bump.md`](patterns/vendor-bump.md) |
| bump the installed package, update the pstack install | [`patterns/package-bump.md`](patterns/package-bump.md) |
| which artifacts does this provider have that we must strip | [`patterns/provider-artifacts.md`](patterns/provider-artifacts.md) |

## The pipeline it belongs to

Ingestion has three members: this skill's fork pattern brings an upstream artifact in, the store edge keeps its source and adaptation so a bump has facts to read, and the shipped [`backlog-triage`](../../../workflow/coding-agent/prompts/backlog-triage.md) prompt turns what the pipeline leaves into filed work. It stays in this repository rather than moving into a workflow module, because the store and its gate are harness state; [`module_instruction_payload.md`](../../../docs/adr/module_instruction_payload.md) states why, and the deferred work of shipping it is in [`roadmap_future.md`](../../../devlog/roadmap_future.md#skill-ingestion-as-a-workflow-module-indefinitely-deferred).

A fork is opt-in maintenance. An artifact with no edge is one nobody bumps, and nothing requires an edge; the store exists so that a bump has facts to read, and its reader is the maintainer running one.

## The edge is the boundary

The store at `.agents/registry/sources/` is the record, and it points at the tree: an edge names the local path, the upstream path and the revision the next merge starts from. `patterns/vendor-bump.md` `## Register an edge` states the shape and the fields; write it at vendoring time, because that is when the facts are known.

Nothing points the other way, and the store's gate holds that: an artifact carries no record file and no source line, and one that appears is a finding. A copy of the source in the file drifts from the edge -- the review runbook's line named a change the upstream never made -- so a reader who wants to know where a skill came from opens the store. Keeping the edge true is the operator's, since a wrong edge breaks the next bump and nothing else.

## Writing a skill that is not a fork

A skill written here - not installed from upstream - has no edge and no upstream. Take `instruction-authoring` instead: it owns the authoring steps, the signpost and the authoring patterns.
