# The Operator Surface

**Status:** draft - first write, not yet reviewed. Awaits the operator's decision.

**Scope:** the text the harness shows the operator, and where that text is defined. It names three surfaces - the hint, the help and usage, and the display - states the rule that decides what an operator reads at a boundary, and recommends one vocabulary held by a gate. In: the hint set and its situations, a usage line against its parser, the session display's rows, and the messages at a refusal, a lock, and an exit. Out: the command vocabulary itself (the CLI-to-leaf row in T10), the record formats the display reads (T11), the help status codes the router maps (the CLI-to-leaf row), the interactive helper's contract (its own note in this series), and the lint-gate ADR that predates the third gate (row 290, which rides the M3.1 gate rows).

## Context

The harness tells the operator three kinds of thing, and each kind has a different home today.

The hint surface answers "what do I run next". `session_end_hints()` in [`src/libs/session_hints.sh`](../../src/libs/session_hints.sh) is the one function that owns any of it, and it chooses an export directory among three rules; row 34 records that the choice is under-asserted, because every fixture holds exactly one export directory. Every other hint is written where it is emitted, so the same advice exists in as many forms as there are leaves that need it. Row 37 names the defect: operator command hints are defined per surface, not once.

The help and usage surface answers "what does this command take". Its text is per-leaf, and its drift is recorded in the read-through as a family: usage lines advertising flags the parsers reject (rows 138, 218, 221), a flag the usage omits that the leaf accepts (row 151), a dispatcher flag summary that omits `--interactive` for two of the five leaves that accept it (row 266), a `FORCE` help line that states one consumer's meaning for all of them (row 272), and an `INTERACTIVE` variable with one documented meaning and five leaf meanings (row 271). Every one of those rows is the same defect: the text and the parser are two records of one contract, and nothing compares them.

The display surface answers "what is the state". The session inventory builds its rows and derives the current branch and HEAD for them. The staleness marker breaks the alignment of the row it belongs to (row 81), so a decoration carries more weight than the data beside it.

Two further symptoms belong to no surface and still reach the operator. `resume` always continues into standard mode, and no document says so (row 198), so the operator learns the mode by observation. Both messages the operator sees at a lock instruct them to delete it by hand (row 284), which makes a recovery path look like routine maintenance.

The rule nobody states is the one that would settle all of it: at a boundary - a refusal, a lock, an exit, a stale image - the operator is told what happened, what it means, and what to run next, and one owner holds that text. Today each emitter decides for itself, which is why the same situation reads differently in two leaves and why no gate can object.

## Options Considered

**Option A - one vocabulary module, with a gate (recommended).** A hint is named for the situation it answers, and one module owns the situation list and its text. A leaf asks for a hint by situation and passes its own values, so the call site keeps its context and the wording has one home. The usage and help text stays per-leaf, because the parser it describes is also per-leaf, and a gate compares the two. Cost: the module needs the gate to hold it, or it drifts again; and each call site must pass values rather than prose, which is a small rewrite of the emitters.

**Option B - convention plus a lint gate, text stays leaf-local.** A convention names the situations, and the gate holds the shape: no usage line that a parser rejects, no flag a parser does not accept, one vocabulary for the situations. Smallest structural change, and it needs no new module. It leaves the text in as many places as there are emitters, so the vocabulary can still diverge, and a shape gate cannot judge whether two hints answer the same question in the same terms.

**Option C - a generated surface.** The hints and the usage lines come from one table that both the leaves and the documentation read, so no document can drift from the text. It closes the whole class by construction. It depends on the record-shape decision (T11) for the table's form, it adds a generation step to the build, and it moves the text away from the call site where its context is visible.

**Option D - status quo.** Fix each drift case where it is found. This is what the immediate fix lane did for seven of the H-sector rows, and it works one row at a time. It leaves the vocabulary undefined, so the next leaf writes the eighth hint.

## Decision

Recommend Option A, taking the cheap part of Option C now and Option B's gate as the enforcement.

**One vocabulary.** The hint set is named by situation rather than by emitter: a refusal, a lock, an exit, a stale image, a resumed session, an unfinished draft. `session_hints.sh` remains the home and grows into that vocabulary; the situation list is enumerable, which is what makes the set gateable and what makes "what does the operator see at a lock" a question a test can answer by name.

**One gate for the usage surface.** The usage text stays with each leaf, and a check compares it against the leaf's own parser spec. That is the whole repair for rows 138, 151, 218, 221, 266, 271 and 272: the two records exist already, and the gate is what makes them agree. It is the same shape as the existing lib-contract check, so it needs no new mechanism.

**The display stays with its producer.** Row 81 is a defect in a decoration, not a design problem; fix it where the row is built.

**The boundary with T10.** The CLI-to-leaf row owns the command vocabulary: what a name means, which leaf implements it, and who may run it. This document owns the text that names a command. The split matters for row 264, where the interactive branch prints a command that is not the command it runs: the fix needs T10's contract to make the printed command the executed one, and this document's rule to say that the printed line is a hint like any other.

No new file. `session_hints.sh` is the hint vocabulary; the usage surface is held by a gate rather than centralised, because the text and the parser belong to the same leaf; the display stays where it is built.

## Consequences

What this changes. The hint set becomes enumerable, and the emitters pass values instead of prose. Rows 138, 151, 218, 221, 266, 271 and 272 close when the gate lands, because the comparison is mechanical. Row 34 becomes a unit against the vocabulary rather than a fixture accident. Row 37 closes by construction, since a hint written at a call site is exactly what the gate now rejects.

What this enables. An operator-surface test that answers a situation by name, which is the form rows 34 and 276 have been reaching for. A second reader of the vocabulary: the operations and development documents can name a hint instead of restating it, so guidance drift stops being possible between them and the tool.

What this forecloses. A leaf may not write its own hint text. A new situation is added to the vocabulary, not to a leaf, so adding one is a deliberate act with a name.

What it does not do. It does not change the command vocabulary (T10), the record formats the display reads (T11), or the interactive helper's contract (its own note in this series). It does not make the text generated; Option C stays available if the set grows past what one module can hold.

Landing. A design that settles into an ADR (or into the existing interface-contract ADR), then an implementation handover: the vocabulary module, the usage gate, the emitter rewrite, and the units.

Related rows: 34, 37, 81, 198, 264, 266, 271, 272 and 284, the usage-drift rows 138, 151, 218 and 221, and row 290, which rides the M3.1 gate rows. The evidence base is sector H of [`20260924-design-active-test_suite_readthrough.md`](20260924-design-active-test_suite_readthrough.md).
