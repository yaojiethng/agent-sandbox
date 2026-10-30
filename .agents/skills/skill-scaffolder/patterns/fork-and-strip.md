# Fork an upstream skill

Open this when a skill arrives from an upstream set. The move is to install the upstream file set, fork it into this tree, and strip every mechanic that belongs to the upstream's provider.

## The move

| Instead of | Give |
|---|---|
| copying the upstream file set and leaving its provider mechanics | a fork whose every provider-specific call goes through this repository's interface |
| editing the upstream in place | an installed source in this tree, with the upstream's revision recorded |
| a fork with no record | `MAINTENANCE.md` beside `SKILL.md`, naming the source and each change |

## The steps

1. **Pin the source.** Record the upstream repository or package, the revision or tag, and the file set. When the exact revision was never recorded, say so in the record; do not invent one. Done when `MAINTENANCE.md` `## Source` carries the value or the gap and the reason.
2. **Copy the file set.** Keep the upstream's sibling structure (`SKILL.md` plus `LANGUAGE.md`, `INTERFACE-DESIGN.md`, and so on) unless a sibling is provider-specific and has no pi counterpart. Done when every upstream file is either present or named in the record as dropped, with the reason.
3. **Inventory the provider mechanics.** Walk [`provider-artifacts.md`](provider-artifacts.md) against every file. Done when the inventory marks each list entry present or absent, and names any artifact the list does not hold so the list can grow.
4. **Strip each one.** Replace the mechanism with this repository's interface, not a deletion: a subagent goes through the `dispatch` skill, which resolves the role and records the log; a parallel fan-out is several such dispatches, one brief each. Do not teach the invocation here; the dispatch skill owns it. Done when no upstream artifact survives and each replacement names the dispatch skill and the capability the child has.
5. **Record the adaptation.** `MAINTENANCE.md` carries `## Source`, `## Adapted`, `## Name`. `## Adapted` states what was kept, rewritten, added and dropped, and why; `## Name` states whether the upstream name survived. Done when the record names every artifact the inventory found and the sections are present.
6. **Verify.** Run `bash scripts/check_frontmatter.sh` and `bash scripts/lint.sh`, then run the skill's own entry point or a dry pass. Done when the gates are clean and the skill's first step can be followed from the tree alone.

## The test

Name the upstream, the revision, and the artifact the fork replaced. If any is missing, the fork is a copy, not a fork.
