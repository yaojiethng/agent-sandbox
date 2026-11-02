# Maintenance record

## Source

Source: `mattpocock-skills`; see [`NOTICE`](../NOTICE).

## Adapted

**Kept.** The domain-modeling method, the glossary, the glossary-map structure, the examples, and the ADR triggers.

**Rewritten.** The file names are `GLOSSARY.md` and `GLOSSARY-MAP.md`, matching the upstream rename from `CONTEXT.md`. `ADR-FORMAT.md` describes this project's living decision-record format, because the upstream sequential-numbering template conflicts with the `decision-records` convention; `SKILL.md` links that convention beside it. `SKILL.md` and `GLOSSARY-FORMAT.md` carry the ASCII punctuation sweep and labeled fenced blocks.

**Added.** This maintenance record, and the pointer to the `decision-records` convention.

**Dropped.** The upstream `CONTEXT-FORMAT.md`, replaced by `GLOSSARY-FORMAT.md`, and the upstream ADR numbering and optional-section template.

## Name

The skill was `domain-model` and is now `domain-modeling`, taken from the upstream rename at `a496f55`. The rename landed with the edge's bump in the same unit; `improve-codebase-architecture` is its only caller and was rewritten against the new name there.
