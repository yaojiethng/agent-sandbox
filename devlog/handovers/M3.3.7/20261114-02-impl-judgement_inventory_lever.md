---
date: 2026-11-14
milestone: M3.3.7 - The judgement corpus admission
type: Implementation
status: Closed
---

# Handover - The judgement inventory lever and the four-case replay

## Objective

Build the deterministic inventory lever over the repo-owned judgement corpus and replay the four historical admissions, so the neighbour field and the gate rest on evidence rather than a hope that the mechanism would have caught them.

## Scope

The M3.3.7 row **The inventory lever and the four-case replay**. The lever reads the provider root, extracts the declared `metadata.neighbours` and the judgement cross-links in the prose, and reports structural facts only. The replay runs the lever against the four cases the design record names and records the candidates, the historical decision and the cost.

Out of scope: the `metadata.neighbours` field itself, the admission pattern, the liveness/presence gate and the baseline (the next M3.3.7 row); the migration of the existing skills (the row after it); and the passthrough judgement (its own row). The lever is a diagnostic here, not a gate: it reports findings and exits zero, and the next row's gate consumes the same analysis.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The lever prints a deterministic inventory over the provider root; two runs are byte-identical. | `node scripts/judgement_inventory.mjs --json` twice, then `diff`. | Agent [x] |
| The lever reports the four structural facts on a fixture: an unresolved declared name, a missing field, an explicit `[]`, and a duplicate declared name. | `bash tests/test_judgement_inventory.sh`, one unit per fact. | Agent [x] |
| The lever surfaces a prose judgement cross-link as a neighbour candidate and ignores a link to a non-judgement file. | The same test. | Agent [x] |
| The replay table covers all four cases, each with candidates, historical decision, cost and caught/miss. | `## Replay results` in the design record; four case names present. | Agent [x] |
| Every decision this iteration recorded is realized in the files. | Read the Decisions table against the script, test and record. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The lever is a Node script at `scripts/judgement_inventory.mjs`, not bash. | The repository's skill analysis is already Node and `scripts/skill_layers.mjs` holds the skill discovery and Markdown link walker; a bash parser would be a second implementation of both. | This record |
| The module exports `inventory(root)` and the CLI is a thin wrapper over it. | The next row's gate imports the same analysis, so the structural facts have one implementation and the gate cannot disagree with the lever. | This record |
| The judgement set is the provider-root skill directories whose name matches `^(communication-)?principle-`, and only that root. | It is the repo-owned corpus the gate will hold; the three support skills in the same root and the `$AGENT_HOME` extras are not judgements. | This record |
| The lever is a diagnostic: it exits zero with findings, and a non-zero exit is reserved for a root it cannot read. | The row's mechanism is `code` for the lever; the gate row owns the failing decision. A diagnostic that fails on today's incomplete corpus could not be run before the migration. | This record |
| The output is sorted by skill name and carries skill names only, no absolute paths or timestamps. | Two runs must print the same answer; a path or a clock would make the determinism check meaningless. | This record |
| The replay drafts live under `.scratchpad/replay/` and the results are appended to the design record. | The replay is one-time evidence, not a committed fixture; the committed test covers the lever's mechanics, and the design record already owns the case table. | This record |
| The replay catches all four cases with one decision, so A+B stands and the field, gate and migration rows proceed. | The lever surfaced the expected candidates on each case; the historical decision was the comparison. The lever does not infer a neighbour the draft never names, and a deciding document can sit outside the judgement corpus. | The design record's `## Replay results`; this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The provider root holds 28 skill directories, of which 25 are judgements; the other three are `active-tracker`, `dispatch` and `setup-model-recommendations`. | record | The lever's set rule must filter by the judgement name, not take every directory in the root. | This record |
| The design record's open question says the replay decides whether A+B stands. | record | The replay ran and all four cases are caught, so A+B stands and the field and gate rows proceed. | This record; the design record |
| The current corpus carries 25 missing fields and only three prose cross-links among judgements. | record | The field is the machine edge; the migration adds it, and the sparse cross-links mean the candidate list cannot be the gate's only input. | The field and gate row; the migration row |
| The lever surfaces the links a draft declares; it does not infer a neighbour the draft never names. | record | The admission pattern must ask the author to declare the neighbours; the lever makes the declared set small and visible, and the operator decides. | The admission-pattern and gate row |
| The first full-suite run timed out two test files under parallel load; each passed alone and the second full run was green. | record | The timeouts are deadline pressure, not a defect in this change; the suite is green on a clean run. | This record |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/judgement_inventory.mjs` | The lever: exports `inventory(root, parseFrontmatter)`, reads the provider root's 25 judgements, reports declared neighbours, missing/explicit-empty/malformed fields, unresolved/duplicate/self names, and prose cross-links; the CLI prints plain text or JSON and exits zero on findings. |
| `tests/test_judgement_inventory.sh` | Eight units: the judgement set, the four structural facts, a valid declaration, the cross-link candidate, determinism and the unreadable-root refusal. |
| `devlog/discussions/20261114-design-concluded-judgement_corpus_admission.md` | Appends `## Replay results`: all four cases caught with one decision each, so A+B stands. |
| `devlog/handovers/M3.3.7/20261114-02-impl-judgement_inventory_lever.md` | This record. |
| `devlog/roadmap.md` | Marks the lever row closed with its outcome summary and moves the design-record link to the open field-and-gate row. |
