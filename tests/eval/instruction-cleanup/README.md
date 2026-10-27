# The instruction-cleanup fixture

Frozen inputs for the instruction-cleanup test case, taken on 2026-10-26 because the corpus they hold is about to be rewritten. The six review carriers and the two cleanup prompts are the subject of the case; the owner documents are what the pass is allowed to consult when it recommends that a rule be replaced by a pointer; the briefs and their generators are what a run was actually told.

This directory is not an eval harness, a case set, or a runner. It holds no assertions and no expected output, because the rulings those would come from do not exist yet. What it fixes is the input side: a stable copy of what the case reads.

```text
room/    the files a run may read, and nothing else
briefs/  the two prompt templates the runs were composed from
tools/   the two generators that composed them, with the ablation preamble inline
SOURCES.md   provenance per file: source path, source blob, byte count
SHA256SUMS   integrity of every file below room/, briefs/ and tools/
```

## How a run uses it

Copy `room/` into a temporary directory outside this repository and point the run's working directory at the copy. The copy is the isolation: the carriers live inside a tree that holds the census rulings, the comparison records and the feedback log, and a run that can read the tree reads the answers instead of judging the prompt. Thirty of the thirty-five cells of the first ablation attempt did exactly that, and the cost was the run.

The run writes nothing into this directory. A run that edits its surface is measuring a different surface on every cell.

## Resolving a citation

A record that cites `bash-coding-conventions.md` by line number cites the copy here, not the live file: the consolidation edits the live file, and every edit moves the lines below it. The census recommendations and the comparison report both quote it by line, and those numbers resolve against `room/bash-coding-conventions.md.orig` and against nothing else.

## What may join `room/`

A file joins the room only when a candidate recommendation cites it as the owner of a rule under judgement. The five owner documents here are the ones the census recommendations actually named, and adding a sixth narrows what a run can discover, so it is a decision to be recorded rather than a convenience. `room/skills/` holds the three skill files the recommendations cite, renamed to carry their source rather than their relative location.

Nothing else joins. Not `devlog/`, which holds the rulings. Not `.scratchpad/`, which held the earlier fault lists. Not the other two audit files, which the census row excludes as settled records.

## Why the snapshot rather than the live tree

The consolidation rewrites both halves of the case: it folds, splits and deletes the carriers, and it deletes or rewrites sections of the prompt under test. A fixture that pointed at the live tree would silently become a different case after that work, and a later comparison would be against a corpus nobody chose. The copies are dated and hashed so that a reader can say which corpus a result was measured on.

## Verifying it

```bash
cd tests/eval/instruction-cleanup && sha256sum -c SHA256SUMS
```

A mismatch means the snapshot was edited after the fact. The fix is to restore the file from the source path named in [`SOURCES.md`](SOURCES.md), or to take a new snapshot with its own date, never to recompute the checksum.

## Why the files carry `.orig`

A verbatim copy of a document with relative links cannot resolve them from a new location, and a snapshot must not be edited to satisfy a lint rule. The suffix keeps the documentation and linking gates from reading the copies as authored prose, so the snapshot stays byte-identical without an ignore rule that would also hide a real defect in this directory later.
