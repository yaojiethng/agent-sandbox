# Fork an upstream skill

Open this when a skill arrives from an upstream set. The move is to install the upstream file set, fork it into this tree, and strip every mechanic that belongs to the upstream's provider.

## The move

| Instead of | Give |
|---|---|
| copying the upstream file set and leaving its provider mechanics | a fork whose every provider-specific call goes through this repository's interface |
| editing the upstream in place | an installed source in this tree, with the upstream's revision recorded |
| a fork no one can bump | an edge in the source store, naming the source, the revision and what the fork changed |

## The steps

1. **Pin the source, and register the edge.** Copy the upstream repository, license and copyright into a source file at `.agents/registry/sources/<source-id>.json` if it is new, and add an edge for this artifact: `local_path`, `kind`, `parent`, `upstream_path`, and `origin` and `base` at the pinned revision. [`upstream-bump.md`](upstream-bump.md) `## Register an edge` states the shape. When the exact revision was never recorded, stop and ask the operator rather than inventing one. Done when `node scripts/source_bump.mjs check` is clean and the edge names the artifact and the revision.
2. **Copy the file set.** Keep the upstream's sibling structure (`SKILL.md` plus `LANGUAGE.md`, `INTERFACE-DESIGN.md`, and so on) unless a sibling is provider-specific and has no pi counterpart. Done when every upstream file is either present or named in the edge's `record.dropped`, with the reason.
3. **Inventory the provider mechanics.** Walk [`provider-artifacts.md`](provider-artifacts.md) against every file. Done when the inventory marks each list entry present or absent, and names any artifact the list does not hold so the list can grow.
4. **Strip each one.** Replace the mechanism with this repository's interface, not a deletion: a subagent goes through the `dispatch` skill, which resolves the role and records the log; a parallel fan-out is several such dispatches, one brief each. Do not teach the invocation here; the dispatch skill owns it. Done when no upstream artifact survives and each replacement names the dispatch skill and the capability the child has.
5. **Record the adaptation.** Write the edge's `record`: `kept`, `rewritten`, `added` and `dropped` state what the fork kept, changed, added and left out, and why; `name` states whether the upstream name survived, and `source` narrates anything the source facts do not carry. Done when the record names every artifact the inventory found and `node scripts/source_bump.mjs check` is clean.
6. **Verify.** Run `node scripts/source_bump.mjs format`, `bash scripts/lint.sh` and `bash scripts/run_tests.sh`, then run the skill's own entry point or a dry pass. Done when the gates are clean and the skill's first step can be followed from the tree alone.

## The test

Name the edge, the revision and the artifact the fork replaced. If any is missing, the fork is a copy, not a fork, and nothing will tell you when it drifts.
