# Patterns

The canonical forms a bash review names in a finding. One entry is one form, its statement, and the wrong forms it replaces.

## Ids

An id is assigned once, from the next number after the highest ever used. Ids are global across the set, not per file, because a tag table and a bridge heading cite an id without naming a file. An id is never reused, never renumbered and never backfilled, so the next id is one past the highest present. The order of entries inside a file is subject order, not id order, so a new pattern takes the next id and goes wherever it reads best.

## Retiring an entry

An entry is retired in place, never deleted: the heading stays, the fence and the statement come out, and one line says where the content went.

```text
## What retired into this set

`docs/development/bash-coding-conventions.md` held the bash rules before this set existed, as thirty-five numbered sections. Every one is now an entry here and the document is gone. A record written before the retirement cites it by section number; each section was titled after the subject the entry now carries, so the entry is found by searching this directory for that subject.

## p-12 Retired, folded into p-20
```

That keeps the highest id present equal to the highest id ever used, so no counter and no ledger has to be kept in step, and a finding citing a retired id still resolves to a line that says where it went. A retired id therefore never needs to be remembered anywhere outside the set.

Nothing checks this either. A renumbering is visible in a diff as id churn; a reused id is not visible at all, which is why retirement is a tombstone rather than a deletion.

## An entry

```text
## p-N Title

<fence, or a statement where the rule has no form>

<the statement: what the wrong form does, and the constraint>

Replaces: <the wrong forms, named>
```

A pattern with no fence is a rule with no canonical code. The statement is what makes an entry a rule rather than a snippet: a snippet alone does not tell a reviewer what to report. An entry that fixes a name or has a second legitimate shape carries `- Names:` and `- Variant:` bullets. An entry with more than one field puts them in one bullet list, with `Replaces:` last; an entry with a single field writes `Replaces:` as a plain line.

## Finding an id

```bash
grep -rn '^## p-' workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/
```

No stored index. An index mapping ids to files is derived state and goes stale on the first insertion.
