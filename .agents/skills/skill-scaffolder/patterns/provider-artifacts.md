# Provider artifacts

The inventory a fork walks at step 3 of [`fork-and-strip.md`](fork-and-strip.md). It is a list of classes, not one provider's documentation: add a row when a fork meets an artifact the list does not hold, and remove a row only when no provider in use carries it.

| Artifact | What it looks like | The replacement |
|---|---|---|
| Subagent API | a provider's agent or task tool, a subagent type, a parallel subagent call | the `dispatch` skill |
| Tool name | a provider's built-in tool named in prose or frontmatter | pi's tool name, or a capability statement |
| Model or provider id | a model id, a provider name, a `provider/model` pin | a role resolved by the `dispatch` skill |
| Permission or frontmatter field | a field the upstream runtime reads and pi does not | the pi frontmatter fields |
| Provider instruction file | an instructions file the upstream loader reads, such as `CLAUDE.md` | the repository's `AGENTS.md`, or the skill's own `SKILL.md` |
| Provider config path | a hidden directory or home path the upstream loader reads, such as `.claude/` or `~/.claude/` | `$AGENT_HOME` or the repository path |
| CLI invocation | a command that launches the upstream agent | the `dispatch` skill or pi's CLI |
| Credential or environment variable | a provider-specific key or variable | the provider's own configuration, not the skill |
| Prompt argument syntax | a placeholder the upstream runtime substitutes | `$ARGUMENTS` where the prompt supports it |
| Frontmatter shape | a field set or key the pi loader drops | the pi skill frontmatter |

## Maintaining the list

A row is added by the fork that meets the artifact, and the fork's `MAINTENANCE.md` names the row. A row is removed only when no provider in use carries it, and the removal is its own change with the reason. The list is not a copy of one provider's documentation; it is the inventory this repository has met.
