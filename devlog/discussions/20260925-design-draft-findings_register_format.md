# Findings Register Format

**Status:** draft
**Scope:** the machine-readable form of the read-through findings register, and of any findings register that follows it.

## Context

The read-through recorded 312 findings as prose rows in a Markdown table, with the labels a plan needs (sector, class, action, files) split across a second table. Every count in the surrounding prose was hand-maintained, and the tables were hand-sorted. Four defects followed, all found after the pass closed.

- The close-out stated 46 test files carrying BDD blocks; the tree held 49.
- The close-out stated 16 consolidation clusters; the map held 31.
- The roadmap stated 49 note rows; the triage table held 50.
- Twenty-seven rows carried unescaped pipes in a table cell, and eighteen code spans carried padding, giving 20 MD056 and 18 MD038 lint findings. The register was lint-clean only because blank lines and a prose paragraph split it into fragments, and a table that is not one table is not parsed as a table.

The consequence is not cosmetic. A plan session reading those numbers gets a total that does not match the register, and any script over the register needs an escape-aware, row-number-keyed, section-confined parser, which is three rules more than a data file needs.

The fan-out brief already requires each subagent to emit a machine-readable findings block beside its prose. This decision promotes that block to the register of record, so the convention and the record are the same object.

Constraints measured in this image: perl's core `JSON::PP` and node both parse JSON with no new dependency. No YAML parser is present in perl, `js-yaml` is absent, and `jq` and `python3` are absent.

## Options Considered

**Option A - keep the Markdown tables and add a validator script.** The tables stay the source of truth, so the escaping rule, the sort order and the fragment risk all remain, and the validator would have to re-implement a parser for a format that has no schema. Rejected.

**Option B - one YAML file.** YAML reads more comfortably than JSON for a human editor, but no parser is present in this image: it would add a dependency and, worse, restrict every reader to the one language that gets the parser. Rejected.

**Option C - one JSON document holding an array of findings.** A single `findings.json` is valid JSON as a whole, so any JSON tool can open it. Every append rewrites the file, and a diff covers whole regions rather than one finding. Rejected for a register that grows one row at a time.

**Option D - JSON Lines, one finding per line, paired with the prose register.** Each line is a complete JSON object, so the file appends without rewriting, diffs one finding per hunk, and streams through a per-line parse. It is not valid JSON as a whole document: a parser that reads the entire file fails on it by design, and each line is what parses. Chosen.

**Option E - adopt an external issue tracker now.** Better query and dedup, but it imports a service, a credential surface and a workflow before the labels exist. The labelled data is the prerequisite, so this option waits. Deferred to the roadmap-mechanism rewrite study (roadmap T5), which now names the register file as its first step.

## Decision

Adopt Option D.

The register keeps its prose and gains a companion data file, `20260924-design-active-test_suite_readthrough.jsonl`, with one object per finding row and these fields.

| Field | Type | Meaning |
|---|---|---|
| `id` | integer | the row's stable identifier; never renumbered |
| `title` | string | the one-line machine label, taken from the finding's lead sentence |
| `sector` | string | the triage sector letter, or `-` |
| `class` | string | the finding class |
| `action` | string | one of `fix`, `note`, `docs`, `observe`, `other` |
| `action_text` | string | the action as the triage table states it |
| `action_kind` | string | `code`, `test`, `docs`, `comment`, or `none` |
| `files` | array of strings | the files the finding names |
| `status` | string | `open`, `resolved`, `accepted`, `blocked`, `needs-decision`, or `stale` |
| `refs` | array of integers | other rows the finding names as the same defect |

The split is by kind of content, not by audience: the data holds what a query needs, and the prose holds the reasoning. A label appears in exactly one place, so the two records cannot disagree about it.

The file's name is the report's name with a different extension: `20260924-design-active-test_suite_readthrough.md` pairs with `20260924-design-active-test_suite_readthrough.jsonl`. A register's data file is therefore found from its report, never by scanning a directory for data files.

The `status` field is how a finding is checked off, and it holds one of six values. `open` means no action taken yet. `resolved` means the fix landed and its unit passes. `accepted` means the disposition is to leave the behaviour as it is, with the reason on the row. `blocked` means the row could not be worked where it landed, usually because its file belongs to another owner. `needs-decision` means a design choice comes first. `stale` means the finding no longer matches the tree. The field is a plain string, and its values are fixed; a new value is a change to this table, not a free choice at write time.

Counts are read from the data file and never asserted in prose. A stated count is a claim with no owner; a computed count cannot drift from the thing it counts.

Query examples. With `jq`, once the dependency lands:

```bash
jq -s 'length' 20260924-design-active-test_suite_readthrough.jsonl
jq -c 'select(.status=="open" and .action=="fix")' 20260924-design-active-test_suite_readthrough.jsonl
jq -r 'select(.sector=="I") | .id' 20260924-design-active-test_suite_readthrough.jsonl | wc -l
jq -s 'group_by(.class) | map({class: .[0].class, n: length}) | sort_by(-.n)' 20260924-design-active-test_suite_readthrough.jsonl
```

With the perl core module, which is present today:

```bash
perl -MJSON::PP -ne '$j=decode_json($_); $st{$j->{state}}++; END{print "$_=$st{$_}\n" for sort keys %st}' 20260924-design-active-test_suite_readthrough.jsonl
perl -MJSON::PP -ne '$j=decode_json($_); print "$j->{id} $j->{title}\n" if $j->{sector} eq "I" && $j->{state} eq "open"' 20260924-design-active-test_suite_readthrough.jsonl
```

No reader script and no new lint gate. The data file is a log, and the queries above are its whole interface. The operator's direction was explicit: this is a cleaner way to record the findings, not a new tool to maintain, and live counts are no longer needed inside a pass.

## Consequences

The register becomes a pair: prose for reasoning, data for labels. A finding's identity is its `id`, and the consolidation map, the triage table and any plan reference that id rather than a position in a table.

The `read-through-run.md` register-integrity rules change shape. The contiguous-table rule, the sector-split threshold and the table-shaped integrity check are replaced by the schema rule plus one scripted pass over the data file. The fan-out brief's findings block is now this schema, so a subagent's output drops into the register without translation.

The stated-count defect class closes. The "counts are computed, never asserted" rule applies to the register first and to any document that summarises it.

Two risks are accepted. The first is drift between the two records; the control is that a label is written once, in the data, and the prose refers to the id. The second is that a JSON Lines file invites schema creep; the control is the fixed field table above, and a field that is not in it needs a decision recorded here first.

The register-format question is now the first step of the issue-tracker question: the roadmap-mechanism rewrite study (roadmap T5) owns adopting a tracker, and this file is the labelled data that makes the step possible.

Propagation checklist for this decision:

| File | Change | Status |
|---|---|---|
| `devlog/discussions/20260924-design-active-test_suite_readthrough.jsonl` | new: 312 findings as JSON Lines | done |
| `devlog/discussions/20260924-design-active-test_suite_readthrough.md` | Format section declares the companion file and the computed-count rule | done |
| `workflow/coding-agent/prompts/read-through-run.md` | register-integrity rules replaced by the schema and the data check | done |
| `workflow/coding-agent/prompts/fanout-run.md` | findings block and integrity check point at the schema | done |
| `devlog/discussions/20260925-design-draft-readthrough_process_review.md` | item 6 superseded; the register format now has its own decision record | done |
| `devlog/roadmap.md` | the roadmap-mechanism rewrite study names the register file as its first step | done |
| `docs/operations/documentation_policy.md` | its "issue tracker" reference needs a target (proposed, awaiting release) | pending |
