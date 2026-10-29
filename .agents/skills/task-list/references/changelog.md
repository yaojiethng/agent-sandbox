# The changelog

Open this when you append a changelog entry at a milestone close, or correct a closed one.

## The entry

Changelog entries live in `devlog/changelog.md`, appended in milestone order. Each entry is self-contained and can be produced without reading the rest of the file.

```text
## M{n} - {Title}

*{One sentence: what the system can now do.}*

{Two to four sentences: what was built - mechanisms, key decisions, concrete outcomes. No file lists. Capability first, mechanism second.}

---
```

The italicised summary is the capability sentence: what an operator or agent can now do that they could not before. Name concrete components without listing files. The changelog describes completed work only. An entry that states only abstract capability is too thin; one that recounts the implementation is too heavy. The judgement is the `communication-principle-dont-forecast-undone-work` skill at `$AGENT_HOME/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md`.

## Corrections to a closed entry

A closed changelog entry does not change: it keeps its text, gains one of the markers below, and gains the successor entry that carries the correction.

| Marker | Meaning |
|---|---|
| `[SUPERSEDED in MX.X]` | the entry is closed and a later milestone carries the correction; the entry stays |
| `[REMOVED in MX.X]` | the entry is closed and the content it claimed is gone from the active system description; the entry stays |

**Marker order.** When more than one correction lands on a closed entry, the markers read newest first, oldest last. The newest marker governs; a reader acts on it. An entry never carries two markers for the same correction.

**The anchor** names the milestone that carries the correction, open or closed. A correction landing inside the current milestone is marked `[SUPERSEDED in M3]`. Work belonging to no milestone is marked with its iteration: `[SUPERSEDED in 20260927-06]`.

**The successor entry** is a new entry under the milestone that carries the correction, in the form above. Do not rewrite the marked entry, and do not delete it.

A correction that cannot be finished leaves the record as it was, with the metadata it carried before. A correction that does finish reopens the record and closes it again with the successor entry.

The shared principle, the direction, the propagation rule and the form per record type are in the [`record-correction`](../../../../workflow/coding-agent/prompts/record-correction.md) procedure, `## Correcting a record`. The decisions behind the form are in [`closed_record_corrections.md`](../../../../docs/adr/closed_record_corrections.md).
