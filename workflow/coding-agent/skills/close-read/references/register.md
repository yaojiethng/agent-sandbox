# The register

The findings of a close read are one JSON object per line, one line per finding, appended to `register.jsonl` beside the run's `report.md`. The record is the reasoning a reader follows; the register is the labels, and a label lives in exactly one of the two.

## The line

Keys in this order, and no others:

| Key | Type | Rule |
|---|---|---|
| `id` | integer | assigned 1..n in the order findings are recorded; never renumbered and never reused |
| `files` | array of strings | repo-relative paths, the file or files the finding sits in |
| `title` | string | one sentence stating the defect, not the fix and not the class |
| `class` | string | one of the seven below |
| `evidence` | string | what was observed and how: the unit, the command, the comparison |
| `status` | string | `open`, the only value a close read writes |

```json
{"id":7,"files":["src/libs/env.sh"],"title":"A loaded value is never asserted to reach a child process, so the export can be dropped silently.","class":"coverage","evidence":"Replacing export with printf -v left all four units green.","status":"open"}
```

A later pass adds `sector`, `action` and `assigned_to` to the lines it dispositions. A read never writes them.

## The classes

The class says what kind of claim failed, so subject area belongs in `files`. Free text here fails: a class field with no value set ends up with a value per author, and no grouping survives that.

| Class | Means |
|---|---|
| `coverage` | no unit pins the behaviour |
| `assertion` | a unit exists and asserts too little, or the wrong thing |
| `logic` | the behaviour is wrong for some input |
| `contract` | a claim and the thing it claims about disagree: header, docstring, document or sibling interface |
| `dead` | code, parameter or guard with no effect |
| `robustness` | fails, or misleads, on input it should handle |
| `design` | a seam, boundary or duplication judgement rather than a defect |

## Appending and correcting

A new finding is a new line at the end of the file. A correction rewrites that one line and touches no other, because each line stands alone; that is what the record this replaces could not do, where a single bad edit anchor duplicated a row and left the table tail out of order.

## Deriving a view

Read the register when a count is needed and never write the result into the record. This prints one row per class and the total:

```bash
node -e 'const fs=require("fs");const rows=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(Boolean).map(l=>JSON.parse(l));const c={};for(const r of rows)c[r.class]=(c[r.class]||0)+1;for(const [k,v] of Object.entries(c).sort())console.log(v+"\t"+k);console.log(rows.length+"\ttotal")' register.jsonl
```

## Naming

`workspace/output/close-read/<YYYYMMDD>-<slug>/`, the directory identifying the run, so a later pass can name the register it read. The operator may name another location, and then that location is the run's identity.
