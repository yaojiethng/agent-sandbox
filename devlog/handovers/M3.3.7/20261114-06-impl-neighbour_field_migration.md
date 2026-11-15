---
date: 2026-11-14
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Active
---

# Handover - The principle neighbours are declared

## Objective

Give every principle its `metadata.neighbours`, delete the baseline, and make the gate hold the corpus with no exception list.

## Scope

The M3.3.7 row **The neighbour fields on the existing principle skills are migrated**, the design record's remaining work. The batch of 25 field values is approved at the scope gate; the gate loses its baseline and `--update` in the same change, because the baseline's only purpose was the corpus before this migration.

Out of scope: the passthrough principle, which is the remaining row and the design record's last work; M3.3.6's corpus map, budget and record layer.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every principle declares `metadata.neighbours`, a list of full skill names or `[]`; the lever reports 0 missing fields and 0 findings. | `node scripts/principle_inventory.mjs` prints 25 principles and 0 findings. | Not yet defined. |
| The declared values are the batch approved at the scope gate, and every declared name resolves to a live principle. | Read the 25 frontmatter blocks; `bash scripts/check_principle_neighbours.sh`. | Not yet defined. |
| The gate holds the corpus without a baseline: a missing field fails with no baseline file present, and the baseline file and the gate's baseline/`--update` code are gone. | `test ! -e scripts/lint/principle-neighbours.baseline`; `rg -n baseline scripts/lint/principle-neighbours.mjs scripts/check_principle_neighbours.sh` and `rg -n -- --update scripts/lint/principle-neighbours.mjs scripts/check_principle_neighbours.sh` return nothing; the no-baseline case runs in the test. | Not yet defined. |
| The gate and its test cover the structural cases without a baseline, and the umbrella and suite pass. | `bash tests/test_principle_neighbours.sh`; `bash scripts/lint.sh`; `bash scripts/run_tests.sh`. | Not yet defined. |
| The roadmap row is closed, and the design record's link moves to the open passthrough row. | Read the two rows; `bash scripts/lint.sh` record lifecycle gate. | Not yet defined. |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the carriers. | Not yet defined. |

## Decisions

reverted

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The batch review surfaced an overlap among the reader-context principles: `define-terminology-before-use` and `attach-as-you-read` share the disclose-before-use shape; `keep-a-subject-near` is colocation; `single-train-of-thought` is one line and `write-for-the-reader` is the session axis. | record | The reader-context principles sit under one routing question and share the reader-cost language, so the field would encode the current grain; a merge is an admission decision, not a field value. | Roadmap: progressive context disclosure; colocation |
| The context family extends beyond the first finding: `write-for-the-reader` is the session/file grain and `link-what-the-reader-can-open` the pointer grain; `keep-a-subject-near` is the spatial half, colocation. The unifying category is progressive context disclosure. | record | The merge brief names the category and the grains, and the fields naming the affected principles are provisional. | Roadmap: progressive context disclosure; colocation |
| The forecast, the materialized result and the sediment share a deletion-rule mechanism but name separate categories; the just-in-time concept has no principle, so no semantic sibling exists. | record | Mechanism does not warrant `metadata.neighbours` siblinghood; the field keeps `write-for-the-reader`, and the umbrella is a new admission. | Roadmap: the just-in-time principle |

## Completed

| File | One-line change summary |
|---|---|
| `devlog/roadmap.md` | Roadmap maintenance check before the handover: no finding. Adds the two deferred admission rows and their sub-milestone criteria; the migration criteria drop the baseline clause. |
