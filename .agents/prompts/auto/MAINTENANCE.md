# Maintenance record

## Source

Forked from `poteto-agent`, the subagent prompt the `poteto` skill set ships. The fork landed as `.agents/prompts/auto.md` in commit `f3e57dcd`, and `211a6fe7` later changed its argument placeholder. The upstream revision was never recorded when the prompt was installed, so it is not stated here; a reader who needs it must recover it from the installed copy.

## Adapted

**Kept.** The routing target's body: read the `poteto-mode` skill's `SKILL.md` in full, including its inline Principles index, and navigate to a leaf `principle-*` skill whenever that principle applies. The background intent, and the instruction to resume an existing `poteto-agent` rather than spawn a sibling, are carried in the description.

**Rewritten.** The dispatch line names `scripts/dispatch.sh --worker` instead of the upstream provider's `opencode-dispatch`, so a child is dispatched through this repository's interface. The argument placeholder is `$ARGUMENTS`, the form every prompt in the tree uses.

**Added.** The frontmatter (`name`, `description`, `is_background`) that makes the file an invocable prompt command in this provider.

**Dropped.** Nothing. Every line of the upstream body is present, with the dispatch line and the placeholder above as the only rewrites.

## Name

`auto` stays for now. It is the command name this repository gave the fork, and M3.2.3 decides the final name with the rest of the dispatch-command surface.

## Owner

The full command lands with `M3.2.3 - Dispatch Workflows as a Command Surface`, which owns the `/auto` conversion, the `-work` family and the final naming. Until then this prompt is a placeholder: it routes a session to the `poteto-mode` style, which the repository does not ship, and the roadmap row `auto.md` names a skill no image ships owns that dependency.
