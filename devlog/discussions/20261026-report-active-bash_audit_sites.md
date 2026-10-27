---
date: 2026-10-26
type: Report
status: settled
subject: the site rulings for bash-audit.skill.md
---

# The bash-audit sites

## Objective

Record, per site, what the screen ruled, so the 22 faults raised by the two census arms resolve to a written decision rather than to a conversation. A site is one line of the file; an arm is one of the two independent fault lists raised over it.

## What a fate can be

| Fate | Meaning |
|---|---|
| `moot` | the fault holds and no edit follows, because the file retires and the fault's whole content is packaging |
| `drop` | the instruction is removed from the corpus, and no successor carries it |
| `answered` | a successor already states the rule that the site states wrongly |
| `transferred` | the site's rule moves into a successor, and the wording is corrected as it moves |

## The fifteen sites

| Site | Arms | Fault | Fate | Action |
|---|---|---|---|---|
| `:1` | B1 | no frontmatter, so nothing loads or describes it | `moot` | none; the sibling files each carry a block and this one retires |
| `:3` | A6 | three extents for the target set: the sentence, the tag table and the hunt list name different rules, and a violation of a rule with no tag cannot be written as a finding | `answered` | `code-review-bash` `## Scope accepted` states the two scope kinds, and `## Returns` makes an untagged fault an observation rather than a finding |
| `:3` | B2 | no swept file set is named anywhere | `answered` | the same two slots name the set: a delta resolves to the shell files the diff touches, a set to the files the paths name |
| `:3` | A1, A2, B3 | "ranked by impact" and "read-only, one-shot" are restated at `:25` and `:29` | `moot` | none; a duplicate in a retiring file has no second site to reconcile |
| `:15` | A3, B4 | the `subshell-pitfall` replacement wraps the whole pipeline, which still swallows every stage's status | `moot` | `p-9` holds the rule and its form, and the row dies with the table |
| `:16` | A4, B5 | `shrink:` has no rule behind it, and rewards compression over the readability the conventions require | `drop` | settled before the screen closed |
| `:17` | A4, B6 | `stdlib:` has no rule behind it, and names a builtin where most replacements are `sed`, `awk` or `find` | `drop` | settled before the screen closed |
| `:21` | A5 | "bare exit" is narrower than the rule it enforces: a library function ending in `exit 1` passes, which is the form `p-13` forbids | `transferred` | the rule enters the successor as `p-13`, "Library functions return, never exit", and the phrase "bare exit" enters nowhere |
| `:21` | B8 | "circular source paths" reads as symlink cycles, not as two libraries sourcing each other | `transferred` | the rule enters the successor as `p-27`, "Keep the source graph a tree" |
| `:21` | B7 | seven hunt checks for nine tags, with nothing saying whether the hunt is exhaustive | `moot` | the tag table and the hunt list both die; the successor's Focus names entries rather than tags |
| `:25` | A7, B11 | "net: -`<N>` issues found" has no referent, and the sign reads backwards on a count of findings | `moot` | `code-review-bash` `## Returns` states the finding shape, and no successor carries a net figure |
| `:25` | A8, B10 | "`<what to cut>`" fits deletions only, so "Nothing to cut" is true while findings remain | `moot` | the successor's finding line carries the wrong form and the form to write instead |
| `:25` | B9 | "ranked by impact" names no axis, and an improvement tag has no severity to rank against a library-exit finding | `moot` | the ranking requirement is not carried |
| `:25` | A9, B12 | "Nothing to cut: Clean. Ship." issues a release verdict for code the audit never ran, which its own boundaries exclude | `answered` | `## Verdict` rests a verdict on findings rather than on a clean sweep, and gives a narrowed run none |
| `:29` | B13 | the out-of-scope list repeats "violations only" | `moot` | the enumeration's content is in `## Does not judge` |

## Why eleven of the fifteen are moot

`D11` ruled that no carrier survives at its own path, so a fault whose whole content is packaging has no destination: there is no file for the edit to land in. The class covers frontmatter, heading text, section order, filename, and the output format of a file that retires. The first such site named was `:1`, and the screen found ten more.

The consequence is that a screen over a retiring carrier does not measure the successor. The four `answered` and `transferred` rows do, because each names the slot or the entry that now holds the rule.

## The two corrections that reach the successor

Both were in the hunt list at `:21`, and both survived because that sentence's rules became the runbook's subject rather than its text.

"Bare exit in `src/libs/` and `src/build/`" is narrower than `p-13`: the audit as written passes a library function whose last statement is `exit 1`, which is the exact form the rule forbids. "Circular source paths" describes a filesystem cycle, while `p-27` is about two libraries sourcing each other, so a reviewer hunting path cycles never finds one.

The correction is the entry id, not a restatement. The Focus slot names `p-13` and `p-27` where the hunt list named "bare exit" and "circular source paths", and neither phrase enters the successor.
