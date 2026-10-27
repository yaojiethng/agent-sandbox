---
date: 2026-10-26
type: Report
status: draft
---

# The provenance of the pattern set

Opened 2026-10-26. The question this answers is not whether a rule is well written but whether it still guards the failure that produced it: what circumstance made the rule be read, is that circumstance in a record, and does the sentence a reviewer now reads catch the code that failed.

The scan runs twice. Pass 1 is on the set as the migration left it. Pass 2 repeats it after the unslop sweep, so a cut that removes a fact a record needs shows up as a changed verdict rather than as a lost fact nobody notices.

## The question, in three parts

1. What is the origin of each entry: a recorded failure, a commit that added the rule, or the document's first draft with nothing behind it?
2. Where a record exists, is it still retrievable, and does it describe the damage precisely enough to judge a sentence against?
3. Does the current wording guard that damage: would a reviewer applying the entry to the code in the record have caught the failure?

## How it was measured

Three read-only seats, all role `_ADVISOR_DOCS`, each one brief, each with its own run directory. The free routes were quota-blocked until 2026-10-27T00:00Z, so every seat was pinned to the role line's second assignment, `deepseek/deepseek-flash` at `high`, and the confirmation is `grep -o '"model":"[^"]*"'` over the run's session file, which printed `deepseek-flash` once per seat.

| Seat | Subject | What it read |
|---|---|---|
| 1 | every bash failure recorded in this repository, and the entry that answers it | `devlog/AGENT_FEEDBACK.md` in full, then the pattern set for the covering entry |
| 2 | the nine rules a commit introduced | the commit, its diff on the conventions document, and the week's record |
| 3 | the entries written into the conventions document at its creation, with no failure behind them | the document at `05685dc2`, then `git log -S` for the entries it did not hold |

The brief files were session scratch and are not part of this record. Each seat's brief is the three questions above, plus its own assignment and the verdict table, and running the scan again means writing the same three briefs and comparing the tables.

The verdict vocabulary, fixed before the seats ran so the three reports could be read together:

| Verdict | Meaning |
|---|---|
| `guards` | a reviewer applying the entry to the code in the record would have caught the failure |
| `checkable` | no record exists, but the entry names what to look for and what to report |
| `thin` | the entry names the constraint and drops a fact the record carries, such as a detection, a condition, or the exact damage |
| `lost` | the wording does not guard the failure at all |
| `no-pattern` | a recorded failure has no entry |

## Pass 1

One row per entry. `origin` names the commit, or the record where a failure is logged. The verdict is the seat's, reconciled where two seats saw the same entry.

| Id | Origin | Verdict | What decides it |
|---|---|---|---|
| `p-1` | `05685dc2` rule 1.6 | repaired | `A4` carried the `realpath` condition into the variant and gave `p-1` a statement; bridge 1.6 had been holding both, which is why the pattern had lost them |
| `p-2` | `05685dc2` rule 1.7 | checkable | the anchor rule and the count rule are both in the entry |
| `p-3` | `05685dc2` rule 1.14 | checkable | the entry states two damages the original did not |
| `p-4` | `05685dc2` rule 4.1 | repaired | the entry carried a fence and no statement. `A2` added the statement; the recorded accumulator failure is still unheld and stays in the no-pattern list |
| `p-5` | `05685dc2` rule 1.12 | repaired | the original exempted `.env` values and identity variables from the export rule. `A3` carried the exception list into the entry as a variant, and bridge 1.11 stopped holding it |
| `p-6` | `05685dc2` rule 4.2 | repaired | the entry stated that `:-` keeps an empty string, and it does not. `A1` restated it as the colon versus bare distinction with both forms, and bridge 4.2 lost the sentence it had been carrying |
| `p-7` | `05685dc2` rule 1.4 | checkable | - |
| `p-8` | `0f9fbea4` | checkable | added after the document's creation, so not a migration loss; the working herestring form is not carried |
| `p-9` | `05685dc2` rule 1.14 | checkable | the subshell scoping and its damage are both stated |
| `p-10` | `05685dc2` rule 1.14 | repaired | `A5` added the `A && B` shape to the statement and the `Replaces:` line; the argument-order half of the same record still has no carrier |
| `p-11` | `d98c42a4`, fed by `[A] 2026-10-20` | guards | the SIGPIPE chain, the second case and the deceptive symptom are all kept |
| `p-12` | `05685dc2` rule 4.3 | checkable | the two-zeros damage and the guard are both stated |
| `p-13` | `[O] 2026-08-12` | guards | the record's three facts are kept whole, including the entrypoint exemption |
| `p-14` | `d15508fe`, record `20260919-19` | guards | the same-status-for-two-states defect and the missing-tool case are both stated |
| `p-15` | `05685dc2` rules 1.11 and 3.2 | checkable | the guard, its reason, and both form constraints are kept |
| `p-16` | `fc9b1424`, record `20260912-10` | guards | the ambient-read failure is named, and the parse-once rule survives |
| `p-17` | `05685dc2` rule 1.13 | checkable | the five-line limit survives as a number |
| `p-18` | `3b08478a` and `5cad0cf4`, record `20260823-10` | guards | the four classes, the sourcing damage and the dead-flag variant are kept |
| `p-19` | `05685dc2` rule 1.1 | checkable | the tab damage and the `cat -A` detection are kept |
| `p-20` | `05685dc2` rule 1.2 | checkable | - |
| `p-21` | `05685dc2` rule 1.3 | checkable | - |
| `p-22` | `05685dc2` rule 1.5 | checkable | - |
| `p-23` | `05685dc2` rule 1.8 | checkable | the disarm-on-success line survives |
| `p-24` | `0bcd85f4`, record `20261017-04` | guards | the per-container grace and the stated-duration rule are kept; the transform match-count discipline is another subject and has no carrier |
| `p-25` | `05685dc2` rule 2.2 | checkable | the naming table survives with the rename |
| `p-26` | `05685dc2` rule 2.1 | checkable | - |
| `p-27` | `[A] 2026-08-09` | guards | the leaf-library extraction and its reason are kept whole |
| `p-28` | `05685dc2` rule 1.10 | checkable | - |
| `p-29` | `6579d1bc`, record `20260926-07` | guards | all four obligations survive, including reading `PIPESTATUS[0]` |
| `p-30` | `05685dc2` rule 1.9 | checkable | - |
| `p-31` | `677b4d8a`, record `[A] 2026-09-19` | repaired | the guard held in every case measured, so `A8` left the entry as it stands and wrote the measurement into `AGENT_FEEDBACK`, whose new entry names the deleted 2026-09-19 record as its `legacy` line. See `## The two rules that state a false fact` |
| `p-32` | `677b4d8a` | checkable | added after the document's creation |
| `p-33` | `1d075806`, fed by `[A] 2026-09-19` | guards | the mechanism, both error codes, the real-directive list and the fix are kept |
| `p-34` | `c4ce06ee`, fed by `[A] 2026-09-30` | guards | the self-match, the 143 and the executable-plus-pid fix are kept |
| `p-35` | `c4ce06ee`, fed by `[A] 2026-09-30` | repaired | `A6` added the record's consequence: the next run's probe talks to the process that was never killed and reports nothing captured |

Counts over the thirty-five entries as pass 1 first read them: `guards` 10, `checkable` 18, `thin` 5, `lost` 1, `defect` 1. The repairs closed all six of those rows, `p-1`, `p-4`, `p-5`, `p-6`, `p-10` and `p-35`, and `A8` closed the seventh, so no entry in the pass 1 table still reads `thin`, `lost` or `defect`. The set pass 2 compares against holds 10 guards and 18 checkable entries. Seven entries did not exist when pass 1 ran, `p-36` to `p-42`; their first verdict is their baseline, and pass 2 reports them as new rather than as changed.

## Recorded failures with no pattern

Each one is a failure an operator or an agent recorded, whose lesson had no carrier in the pattern set when pass 1 ran. `A7` gave each one a home, named in the last column. The argument-order half of the `p-10` record joined them as `p-42`, because `p-10` is about a claimed success rather than about a command line. The two mutation rules were split by subject: the part that is bash semantics became `p-43` and the `p-18` variant, and the part that is instrument discipline stayed in the testing patterns written as logic, with no bash in it.

| Record | The failure | What a pattern would say | Home |
|---|---|---|---|
| `[A] 2026-10-06` | an accumulator summed with `name+=value` and no integer declaration concatenated byte counts, and a zero-prefixed total then failed as octal | declare an accumulator integer, or assign through arithmetic expansion; report the iteration count, not only the total | `p-37` in `declaration.md` |
| `[A] 2026-10-05` | an apostrophe inside a default value opened a quote, and bash reported the syntax error at the last line of the file | keep a default free of apostrophes, or assign it on its own line; `grep -c "'"` gives the odd count | `p-38` in `declaration.md` |
| `[A] 2026-09-25` | `&& false` and `-n /dev/null` inside `[[ ]]` are true, so four mutation bites reported a survivor against an unchanged guard | a mutation is evidence only if the mutant differs from its backup and the changed line is the site the verdict depends on | `.agents/skills/testing/patterns/mutation-evidence.md`, with `p-43` in `failure-handling.md` for the truthiness rule |
| `[A] 2026-09-25` | three guards that errexit already provides survived mutation because no unit can fail on them | whether an explicit guard decides anything depends on the call context, because errexit is suspended in the body of a function invoked in a condition | the `p-18` variant in `shell-options.md`, with `.agents/skills/testing/patterns/mutation-evidence.md` for the instrument rule |
| `[A] 2026-10-20` | a `cd` inside a command substitution died with the subshell, so a test ran in the repository root and committed it | a directory change inside a subshell has no effect outside it; run the work inside the subshell, or resolve a path instead | `p-39` in `path-resolution.md` |
| `[A] 2026-10-26` | a child inherited stdin and consumed the loop's work list, and a retry keyed to any non-zero exit repeated timeouts | close a child's stdin when it reads from it, and key a retry to one named transient condition | `p-40` in `script-boundaries.md`, `p-41` in `failure-handling.md` |

Two of these, the mutation-idiom families, describe a test instrument rather than a form a review of production code reports. That is a reason to file them somewhere other than the pattern set, not a reason to leave them unrecorded.

## The two rules that state a false fact

Both were carried across the migration unchanged, so neither is a defect the migration introduced. They are recorded here because the provenance question is what surfaced them: an entry traced to its origin, and the origin was wrong.

### `p-6`: `:-` does default an empty value

The entry's `Replaces:` line says the form it replaces "keeps an empty string and never applies the default". Measured:

```text
v is empty;  ${v:-HEAD} = [HEAD]   ${v-HEAD} = []
```

`:-` substitutes on unset and on null; the no-colon form is the one that leaves an empty value alone. So the entry's wrong form does not fail, and its right form does the same thing as the wrong form, which makes the entry a false finding generator: a reviewer applies it to `${VAR:-default}` and reports code that behaves as written. The real rule in the family is to use `-` rather than `:-` when an empty value is meaningful, and to say so.

The same inverted sentence stands in the bridge at rule `4.2`, so the document and the pattern disagree with bash in the same way.

### `p-31`: the mechanism the record states does not reproduce

The record behind rule `4.4` says an unguarded read from an absent file "aborts the call site even if the call is wrapped in `||`". Measured under `set -euo pipefail` in this container's bash:

| Case | Result |
|---|---|
| function with an unguarded read from a missing file, called with `\|\| true` | survived, rc 0 |
| the same read as a compound command, `\|\| true` | survived, rc 0 |
| the same function called with no guard | rc 1, and the statements after it did not run |
| the function called with `$1` unset under `set -u`, guarded by `\|\| true` | rc 1, the guard did not hold |

A guarded call survives a missing file; what escapes the guard is the shell's own expansion failing under `set -u`. `p-31` therefore keeps the constraint, which is right, and states the firing condition that reproduces. The record in `devlog/AGENT_FEEDBACK.md` `[A] 2026-09-19` still carries the false mechanism, and is a correction owed to that file.

## What pass 1 asks the operator to rule

| Code | Item | Proposed |
|---|---|---|
| A1 | `p-6` states a false claim about `:-` | restate the rule as the `-` versus `:-` distinction, with the measured behaviour in the entry, and correct bridge `4.2` |
| A2 | `p-4`, `p-5` and `p-6` carry a fence and no statement paragraph, against `patterns/README.md` | write the missing statement for each, which is also where the accumulator rule and the export exception belong |
| A3 | `p-5` dropped the export exception list | carry the exception list in the entry, since a reader without it flags three legitimate exports |
| A4 | `p-1` dropped the condition for `realpath` | carry it in the variant bullet |
| A5 | `p-10` dropped the `A && B` guard shape | add it to the statement and the `Replaces:` line |
| A6 | `p-35` dropped the consequence the record names | state what the stale process does to the next run |
| A7 | five recorded failures have no pattern, and a sixth is folded into `p-4` | add them as entries, or file them outside the pattern set with the reason |
| A8 | the record behind `p-31` states a mechanism that does not reproduce | correct the `AGENT_FEEDBACK` entry, naming the measurement |

## Pass 2

The sweep ran as `c8200c9b`: 29 replacements across nine files, each applied by exact match so a missed anchor fails the script rather than skipping the edit. Pass 2 then re-read every entry against the verdict it carried in, in three seats pinned the same way as pass 1, split by file group rather than by the pass 1 brief, because the question had changed from "what produced this rule" to "does the rule still carry what that answer said".

| Seat | Files | Rows |
|---|---|---|
| 1 | `declaration.md`, `quoting.md`, `file-content.md`, `shell-options.md`, `arguments.md` | 12 entries |
| 2 | `failure-handling.md`, `path-resolution.md` | 18 entries |
| 3 | `script-boundaries.md`, `filenames.md`, `processes.md`, `operator-facing-text.md`, `shellcheck.md`, `sourcing.md`, `README.md` | 13 entries and the README |

Result over 43 entries: 41 `holds`, 2 `stronger`, 0 `weakened`. The two `stronger` rows are `p-18`, where "inherits the consumer's regime" and "dead surface that widens every signature it threads through" became statements of the mechanism, and `p-29`, where the noun compound "empty-output-as-sentinel" became a clause. No entry lost a detection, a firing condition or a damage, so the sweep is not a loss and the baseline stands.

### Two facts the second pass found, neither of them the sweep's

Both were already in the text when pass 1 ran, and both are wrong in the same way as the two the first pass caught: a rule asserting a mechanism nobody had run.

`p-10` said an `a && b` chain "reports only `b`'s result", so "a failed `a` skips everything after it, the chain returns success". Measured: `f(){ false; }; f && echo b; echo $?` prints `1`, and with a function returning 3 the status is 3. The chain carries `a`'s status; what goes missing is that nothing reads it, the script continues, and the next command overwrites it. The entry now says that.

`p-26` said an edge is "`source` or `exec`, which runs the target inside the caller's process". `exec` replaces the caller's process image rather than running inside it, so the two edges depend on the target for different reasons. The entry now names both and how each works.

This is the third instance of the class the `[A] 2026-10-26` entry in `devlog/AGENT_FEEDBACK.md` carries, and the recurrence is recorded on that entry rather than as a new one.
