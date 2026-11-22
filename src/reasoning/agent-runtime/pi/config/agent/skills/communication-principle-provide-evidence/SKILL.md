---
name: communication-principle-provide-evidence
description: "Provide the evidence instead of a sentence that describes what a file, a command or a rule does: the template, the command, the example, or the output."
metadata:
  intent: "A claim gives way to the evidence that settles it: less to check, and better input into a decision."
  mechanism: "A template, a command, an example, a diagram or the output stands where a description would ask for interpretation."
  leitwort: evidence
  neighbours:
    - principle-vacuous
    - principle-say-what-done-looks-like
---

# Provide evidence

Provide the evidence in place of the description: the template, the command, the example, the diagram, or the output that proves the rule was followed.

**The pattern.** Replace the description with the evidence, written out with its articles and verbs.

| Instead of | Give |
|---|---|
| "call the helper with the retry option" | `helper.run({ retries: 2 })` |
| a paragraph explaining how a request travels | the request-flow diagram |
| "the build fails when the cache is stale" | the command that clears the cache |
| "the verbosity flag", "that option" | `--verbose` |
| "schema changes can cause issues" | "a column rename fails the build" |
| "write the outcome back to the roadmap" | the roadmap rows to add, listed |
| a statement that the work was done, and a description of it | the diff, or the command output that shows it |
| "the database stays close at hand" | "`.toSQL()` returns the exact string sent to the database" |
| "SQL you can read", "types that follow your schema" | the query it produces, the type it emits |
| "a dial worth turning" | "a parameter worth varying" |
| an aphorism, or personified code ("the plan holds it") | the literal act, and its subject |
| "Parser rejects bad date -> exit 2, no write" | "The parser rejects a bad date, exits with code 2, and writes nothing." |

**Why.** The evidence cannot be misread. A command runs or it does not, so the meaning survives the writer. An assumption about compliance is not evidence; the output is.

**The case.** A rule names what the writer has in front of them at that moment -- the caveat, the cross-reference, the table cell -- not a need the reader holds, which is not in the document.

- When you write a caveat, put it beside the rule it qualifies.
- When a step sends the reader back to an earlier place, restate that place at the reference.

**What it does not cover.** Whether the reader can open the evidence: [`communication-principle-link-what-the-reader-can-open`](../communication-principle-link-what-the-reader-can-open/SKILL.md). Whether the description should exist at all: [`communication-principle-cut-metadiscourse`](../communication-principle-cut-metadiscourse/SKILL.md). Whether the stopping point was stated before the work started: [`principle-say-what-done-looks-like`](../principle-say-what-done-looks-like/SKILL.md).

**The test.** Must the reader interpret, or can they copy? Where a rule applies, is there output that shows it was followed? Can it be restated as an instruction, a fact or a number? Could it sit unchanged in another project's documentation? A no to either: cut it. How would an English teacher make this rule actionable: does it name a case in the document, or an act of writing?
