# Code snippets in reference documentation

A code block in a document is a copy of something the system already holds: a command from the Makefile, a path from the container layout, a signature from the source. A copy goes stale silently, so the four patterns below are ranked by how much of the drift they remove. This reference is the detail behind [`../SKILL.md`](../SKILL.md) `## Drafting`.

Four patterns, in increasing strength:

1. **Extract at build.** Sphinx `literalinclude` with line tags into the real source, MkDocs `pymdownx.snippets`, Docusaurus MDX imports. The example is a pointer rendered as a block, so it cannot drift; the source is the single truth.
2. **Execute or compile it.** Rustdoc doc-tests compile and run every fenced Rust block; Python `doctest`; Go `Example` functions assert their output; `mdbook test`. TypeScript's `twoslash` type-checks snippets in prose and renders hover types from that, which is why the TypeScript handbook's examples are trustworthy.
3. **Generate the reference from the source.** rustdoc, `autodoc`, TypeDoc, godoc. Signatures cannot drift because nobody wrote them.
4. **Version the docs with the release**, so "as built" has a version to mean.

## The stopgap this repository holds

None of the four is built here. The position is pattern 1, reached by hand: **derive instead of restating**. Where a document needs a command, a path or a signature that a file in this repository owns, the document names that file and lets the reader open it, rather than copying its lines into a fence. What stays in a fence is what has no owner to point at: a diagram, a shape, a skeleton, output quoted from a tool.

Patterns 2 and 3 are the ones to reach for when a fence keeps coming back. A block that names a path, a command or a signature the repository owns is a candidate for extraction, and the gate below is what makes its absence visible.

## Marking a block

A block declares where it came from, on the line directly above the opening fence:

```text
<!-- snippet: derived scripts/templates/Makefile.template -->
<!-- snippet: generated docker build --help -->
<!-- snippet: illustrative -->
```

- **`derived <path>`** states the file this block was lifted from. The gate compares the block against that file, so the block fails when the source moves on without it.
- **`generated <command>`** states the command that produced the block, for output quoted from a tool. Nothing re-runs it; the marker is the provenance a reader needs to refresh the block.
- **`illustrative`** states that the block has no source: a diagram, a section skeleton, a shape. It is the honest marker for a block whose only truth is the document.

## What the gate checks

`scripts/check_code_snippets.sh` reads every fenced block under `docs/`, skipping `docs/adr/archive/` because a record describes the system as it stood when the record was taken.

| Finding | The block |
|---|---|
| `UNDECLARED` | carries no marker and is not in the baseline |
| `STALE` | claims `derived <path>` and its lines are no longer in that file |
| `NOSOURCE` | claims `derived <path>` and no such file exists |
| `UNKNOWN-KIND` | carries a marker naming none of the three above |
| `PRUNABLE` | is in the baseline and no longer exists |

The baseline, `scripts/lint/code-snippets.baseline`, grandfathers the blocks that were in the tree when the gate landed. A new block declares itself; an edited grandfathered block leaves the baseline, so `node scripts/lint/code-snippets.mjs --update` is the edit that states an intent to change one.
