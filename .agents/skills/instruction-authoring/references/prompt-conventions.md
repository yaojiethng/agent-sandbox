# A prompt's conventions

A prompt is a file the operator or a model starts by name. Where it runs, what its frontmatter holds and what its body may assume differ from a skill's in four ways.

## Where it runs, and where its references resolve

A prompt runs at the path the image gives it: a module's prompt from `/opt/workflow/agent/modules/<module>/prompts/`, a harness prompt from `/opt/workflow/agent/prompts/`, a provider's own prompt from `$AGENT_HOME/agent/prompts/`. The repository tree is not there.

So a link reaches only a path that ships, and a document that ships nowhere is named in a code span rather than linked. The `linking` convention states the test; the manifest at `src/build/container-interface.json` declares which roots ship.

## Frontmatter

**`description`.** State what the prompt does and when to use it, in the words a reader or the model would say or think. Front-load the triggering word, keep one trigger per branch, and cut what the body already carries.

Write it in the imperative or the third person, and pick one per prompt: the loop prompts use the imperative (`iter`: "Open a new iteration"), while `plan` uses the third person. Do not claim one voice for the set.

The frontmatter is YAML. An unquoted value cannot hold a colon, a leading dash or a trailing colon; wrap such a value in double quotes and escape an inner double quote. An apostrophe needs no quoting. Pi drops a prompt whose frontmatter does not parse, with no message in the session, so it never appears in the command list. `scripts/check_document_shape.sh` fails the gate on any unparseable block in the tree.

**`argument-hint`.** Where the prompt accepts an argument, state the argument's shape and whether it is optional. `iter` names the type words it accepts; `plan` marks its argument required.

**`$ARGUMENTS`.** A prompt that forwards the operator's text to its body opens with `> $ARGUMENTS` after the frontmatter. Write `$ARGUMENTS`, not `$@`: pi substitutes both, OpenCode substitutes only `$ARGUMENTS`, so one spelling serves both runtimes from one file. The decision is `docs/adr/instruction_surface_declaration.md`.

## The body

A prompt is steps, reference or both, per `writing-for-agents` `## Information hierarchy`, and each step ends on a completion criterion. A prompt that reads or writes project records opens with the conventions block the [skill's front door](../SKILL.md) states.

## Naming

A prompt's name states its subject, not its mechanism: a noun phrase (`task-queue`, `milestone-close`), or a gerund that names the activity (`documentation-pass`). Avoid `helper`, `utils`, and names that restate the loading mechanism.

A name changes when the scope changes, and the rename ships with the documentation pass that follows it.

## The review

One prompt or skill that was just written goes to [`../runbook/review.md`](../runbook/review.md). A set of instruction text that has grown by accretion goes to `prose-review`'s `instruction-cleanup` runbook. Neither runs without the operator's word.
