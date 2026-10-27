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

One row per entry, read against the commit or record that produced it. Thirty-five rows over the entries that existed then: ten `guards`, eighteen `checkable`, seven `repaired`, and nothing left in `thin`, `lost` or `defect`. The seven repairs are the `A1` to `A6` rows below and the six recorded failures that had no carrier, and each landed in the entry it named. The full row set stays in this record's history, one revision back.

## Failures that had no carrier, and the entries they became

Each is a failure an operator or an agent recorded, with no rule behind it when pass 1 ran. Every one now has a home: the accumulator and the apostrophe default are `p-37` and `p-38`, the `cd` inside a command substitution is `p-39`, a child eating stdin is `p-40`, a retry keyed to any non-zero exit is `p-41`, an option after a positional argument is `p-42`, and the two mutation-idiom families became `p-43` and a variant on `p-18`, because a test instrument is not a form a review of production code reports.

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

## Pass 2

The sweep ran as `d601e8d5`: 29 replacements across nine files, each applied by exact match so a missed anchor fails the script rather than skipping the edit. Pass 2 then re-read every entry against the verdict it carried in, in three seats pinned the same way as pass 1, split by file group rather than by the pass 1 brief, because the question had changed from "what produced this rule" to "does the rule still carry what that answer said".

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
