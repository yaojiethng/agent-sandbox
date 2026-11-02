# Maintenance record

## Source

Source: `mattpocock-skills`; see [`NOTICE`](../NOTICE) and the source record at `.agents/registry/sources/mattpocock-skills.json`, which pins the upstream repository `https://github.com/mattpocock/skills`, the revision this was taken from and the base it was compared against. The upstream path is `skills/engineering/codebase-design/`.

## Adapted

**Kept.** The skill's subject and its shape: the vocabulary as a glossary of terms with their `Avoid:` alternatives, the deep-versus-shallow argument with its two diagrams, the seam and adapter distinctions, and the two supporting files - `DEEPENING.md` for the dependency categories and `DESIGN-IT-TWICE.md` for the parallel interface-exploration pattern.

**Rewritten.** The punctuation, to the repository's ASCII rule, two spaces around a doubled hyphen for a dash and a plain hyphen for a range, and the fence on the two diagrams, which carries `text` because the Markdown gate requires a language.

**Added.** `disable-model-invocation: true`. The skill is a reference another skill or a reader opens; it is not a command the model should reach for on its own, and its vocabulary is used through `improve-codebase-architecture` rather than by being auto-invoked.

**Dropped.** The upstream `agents/openai.yaml`, which configures a sub-agent surface this repository's provider does not read, and whose dispatch here goes through the `dispatch` skill.

## Name

`codebase-design` stays. The upstream name is the one `improve-codebase-architecture`'s record and its adapted files name, so carrying it unchanged makes the reference resolve.

## Owner

The upstream project owns the content. This record owns the adaptation, and a change to the upstream skill arrives through the `source-bump` skill, which reads the pinned revision above.

## Relationship to the adapted copy

`improve-codebase-architecture` holds its own `LANGUAGE.md`, `DEEPENING.md` and `INTERFACE-DESIGN.md`. They are not duplicates of these files by accident: they carry this repository's adaptations, chiefly that a sub-agent is dispatched through the `dispatch` skill rather than spawned, and a prose form of the vocabulary. Closing that duplication - one home for the vocabulary, with the adapted skill pointing at it - is a roadmap row of its own, because it changes a working skill's structure rather than adding a reference.
