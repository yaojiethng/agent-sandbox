# Numbering scheme census and churn study

**Status:** settled

## Direction and parent story

The request: introduce academic-grade numbering discipline into this repository's prose, so a section, a question, a figure or a task carries a label a reader can point at unambiguously. The candidate bases were gstack's D-numbering, ISO 2145, ISO/IEC Directives Part 2, MIL-STD-38784, Chicago 14.34 and RFC 7322. The roadmap row under test is M3.3.4 and its classification of numbered-versus-bulleted presentation as a structure row.

The study does not choose a standard. It measures whether the units to be numbered exist, how often anything references them, and what has actually broken. The premise every candidate scheme assumes is one sentence: numbering fails because numbers run out of order, so a scheme that fixes the order fixes the failure.

## Required reading

- [`documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) `## Durability`, the three-value lifetime axis.
- [`documentation_policy.md`](../../docs/policies/documentation_policy.md) `### Numbered vs bulleted presentation`, `### Reference handling`, `### Post-close document corrections`.
- [`20261005-14-impl-rename_the_frontmatter_gate.md`](../handovers/archive/20261005-14-impl-rename_the_frontmatter_gate.md), the handover-id collision.

## Summary

Four measurements decide the question. Numbered headings are near absent (0 to 11 percent by class, ADRs 55 percent). References concentrate on four target types, and the most-referenced positional scheme is `Step N` inside workflow prompts, not chat and not figures. The operator points at items by index in 1.2 percent of 6,889 user messages. The tree holds 6 diagram blocks across 900 Markdown files and none is captioned.

The two recorded failures are silent identifier collisions with no owner of the counter. Neither is an ordering failure. A monotonic scheme does not prevent either, and a uniqueness check at write time does. The recommendation is one grammar, one allocation policy per durability class, and a lint gate, with no new standard and no chat-specific scheme.

## Findings

### 1. The unit population, by class

Counts are Markdown files at HEAD, from `node .scratchpad/analysis/census.mjs .`. The percentage is headings that begin with a digit.

| Class | Files | Headings | Numbered headings |
|---|---|---|---|
| handover-archived | 568 | 5824 | 0% |
| handover | 123 | 1061 | 0% |
| discussion-archived | 83 | 1418 | 10% |
| skill | 37 | 222 | 11% |
| adr | 27 | 137 | 55% |
| policy | 5 | 138 | 0% |
| reference | 15 | 175 | 0% |
| roadmap | 2 | 64 | 0% |
| prompt | 16 | 179 | 0% |

The corpus is unnumbered by default. The one class that numbers is the ADR, where the numbered part is the decision section, not the document's place in a sequence.

### 2. In-degree per target type

A reference is a match of the type's grammar in any Markdown file. Median and p90 are per distinct target id.

| Target type | Distinct ids | References | Median in-degree | p90 | Max |
|---|---|---|---|---|---|
| milestone-id (`M3.3.4`) | 51 | 1138 | 8 | 66 | 216 |
| step-ref (`Step 7`) | 12 | 349 | 30 | 52 | 67 |
| skill-name (`doc-maintenance`) | 15 | 172 | 9 | 27 | 29 |
| handover-id (`20261016-07`) | 486 | 1043 | 2 | 4 | 16 |
| adr link | 38 | 70 | 1 | 4 | 8 |
| policy-section (`file.md -- Heading`) | 49 | 51 | 1 | 1 | 2 |
| anchor-link | 142 | 161 | 1 | 1 | 4 |
| section-ref (`Section 4.2`) | 4 | 4 | 1 | 1 | 1 |
| positional (`see above`) | 4 | 17 | 5 | 10 | 10 |
| figure-ref (`Figure 3`) | 0 | 0 | n/a | n/a | n/a |

Three readings follow. `Step N` is the highest in-degree positional scheme in the repo and it is already in use, so the drift risk is live and located in `workflow/coding-agent/prompts/`. Section-level addressing is nearly unused, so section numbers solve a problem the corpus does not have. Figure references do not exist.

### 3. Churn

From `node .scratchpad/analysis/churn.mjs`, over 882 commits that touch Markdown.

| Class | Added lines | Deleted lines | Heading edits | Renumbers |
|---|---|---|---|---|
| handover | 50717 | 8102 | 5665 | 9 |
| discussion | 14494 | 8525 | 1792 | 8 |
| development | 9904 | 4845 | 1299 | 21 |
| roadmap | 2634 | 2266 | 340 | 14 |
| adr | 3103 | 768 | 257 | 1 |
| policy (current tree) | 76 | 491 | 44 | 0 |

`devlog/roadmap.md` is edited in 396 of 882 Markdown commits. A handover is edited a median of once, which is the transient class behaving as designed. A renumber is a heading change where the heading text is identical after the leading number is stripped: 147 occurred, 1.4 percent of 10,685 heading edits.

Markdown grew from 309 to 984 files between June and October 2026, while the Markdown share of the tree stayed flat at 73 to 74 percent (`docs/`, `devlog/` and skills grew with the tree, not faster than it).

### 4. Diagrams

`node .scratchpad/analysis/diagrams.mjs` finds 6 diagram blocks in 900 Markdown files, 1 mermaid block and 5 box-drawing blocks, 0 images and 0 SVG files. No block has a caption line. The stated concern, that sequence and architecture diagrams are redrawn often, has no population in this tree.

### 5. Chat ordering

`node .scratchpad/analysis/transcripts.mjs` over 475 sessions and 6,889 user messages in `~/.pi/agent/sessions/--home-agentuser-sandbox--`.

| Measure | Count | Rate |
|---|---|---|
| Assistant messages with a numbered heading | 281 | 0.8% |
| Assistant messages carrying two numbering axes | 86 | 0.2% |
| User messages that point by index | 83 | 1.2% |
| User messages that are a bare digit | 7 | 0.1% |
| Index references whose preceding reply had two axes | 1 | 1.2% of index refs |

The axis collisions are the measured failure, and they are the case `documentation_policy.md` `### Numbered vs bulleted presentation` already forbids. Numbering demand is not measured: the operator rarely points by index and almost never by bare digit.

### 6. The two lapses

Both are allocation failures. Both are silent. Both were found by a reader.

| Case | Evidence | What broke | Owner of the counter |
|---|---|---|---|
| Handover id collision | [`20261005-14`](../handovers/archive/20261005-14-impl-rename_the_frontmatter_gate.md) line 69 | Two sessions took `20261005-10`; the second renumbered to `-14`. "nothing checks the sequence, so a collision is silent" | none |
| gstack D-numbering | `a81be536` (2026-04-23), `docs/askuserquestion-split.md`, `CHANGELOG.md:10237`, `TODOS.md:940` | The scheme shipped with its own defect stated: "D-numbering is a model-level instruction, not a runtime counter ... Drift over long sessions is expected; a registry (deferred to TODOs) is the long-term fix". `TODOS.md:940` records a separate open mismatch, brief letters against host-rendered numbers | the model, per message |

The gstack scheme was introduced 2026-04-23, documented 2026-05-26 in `a6fb3172`, last touched 2026-09-22 in `636175d3`. A search of `TODOS.md` at HEAD for the deferred registry found no row naming it; the deferral itself was not filed.

### 7. What the premise assumed, and what the census shows

The premise: numbering fails because numbers lose their order. The census: the failures are duplicate identifiers with no allocating authority, and two axes colliding in one reply. Order is not the broken property. Uniqueness and axis are.

## Resolution

The measurements constrain the scheme; they do not choose it. The scheme the operator wants is a numbering rule an agent applies while writing, with the cost pushed onto the commit rather than the draft. Six constraints follow from the counts above.

1. Numbers, typed by hand. The operator points at items by number because a number is shorter to type than a name, and the corpus already numbers milestones, steps and ADRs.
2. A scheme per document class, consistent across classes and with `documentation_taxonomy.md`. Each class counts its own units and restarts at its own document.
3. The scheme follows the reference-flow direction. A derived record cites its source, so the derived record writes the qualified form and the durable record never cites a transient unit. That is the same direction as the promotion topology.
4. The hot path stays free. Writing a unit costs one number; renumbering inside a document after an insertion costs one pass over that document, and is allowed.
5. The expensive path carries the check. A cross-document reference that no longer resolves is caught at commit, once, by a cheap lint that reads one document at a time.
6. No registry, allocator or baseline. The document id comes from its class and its own already-existing id form; the unit number is local and restarts.

## The criterion the evidence supports

A unit takes a number when a reader reads it in order and cites it in place. It takes an identity code when it is unordered, long-lived, or cited from another document. The class decides, because the criterion is a property of how the class is read, and a per-class declaration is what makes the schemes consistent without a per-unit decision at write time.

| Class | Ordered | Cited from elsewhere | Scheme | Evidence |
|---|---|---|---|---|
| Milestone | by dependency | yes | identity, `M3.3.4` | 621 citations from handovers |
| Roadmap task row | no | rarely | identity code | 3.1% of roadmap edits move a line; 4 citations total, 2 by long title |
| Handover | by session | yes | identity `YYYYMMDD-NN` | 1,043 citations, median in-degree 2; one silent collision |
| Discussion | no | yes | identity date, type, slug | 1,274 renames, and the state-bearing names are what broke references |
| ADR | by decision | yes | slug identity, numbered decisions | 55% of ADR headings are numbered |
| Policy | by section | yes, by name | sections numbered | 0% numbered today, 51 section-name references |
| Audit report | by discovery | yes, inside the report | `F`, `Q`, `R` restarting per report | findings cited 13 times, so the need is forward-looking |
| Prompt | by step | yes | identity per step | `Step N` holds 349 references at median in-degree 30, the most fragile positional scheme in the tree |
| Chat reply | by position | no | bare numbers, one axis | 83 index references in 6,889 messages |

Two rows rest on use cases rather than on usage. Roadmap task rows and audit findings are barely cited from other documents today, so the scheme there is a forward-looking choice, not a measurement. Every other row is justified by a count in this record.

Rejected on those constraints: a corpus-wide counter (breaks 2 and 6), a registered identity with a generated display number (breaks 4 and 6), and a numbering standard adopted whole (ISO/IEC Directives Part 2 and ISO 2145 govern a published document, not a per-class rule that an agent applies mid-draft).

## Open Questions

- Does the operator want `Step N` references migrated, or only frozen at their current meaning?
- Is a registered identity wanted for roadmap tasks before M3.5 replaces the mechanism?
- Does any workspace outside `--home-agentuser-sandbox--` show a higher index-reference rate? This study measured one workspace.

## Constraints

- One workspace of transcripts, 475 sessions. Other workspaces were not read.
- The reference extractor matches grammars, so a reference phrased in prose without the token is uncounted. The in-degree numbers are lower bounds.
- `md-link:doc-other` covers 539 distinct link targets outside the classified folders, mostly `../roadmap.md` and `changelog.md`, and is not split further.

## The broken lever

Two OpenCode workers were dispatched on independent briefs, the gstack lapse curve and the repo prose mining, pinned to `opencode/deepseek-v4.1-flash-free`. Both refused in under 3 seconds with `AI_APICallError: This API key has expired`, logged at `.scratchpad/w1/opencode-dispatch.yWBcjf/worker.log`. The mining ran in-tree instead. The dispatch path is unusable until the key is replaced.

## Reproduce

```text
node .scratchpad/analysis/census.mjs .
node .scratchpad/analysis/churn.mjs
node .scratchpad/analysis/diagrams.mjs
node .scratchpad/analysis/transcripts.mjs
cd /tmp/gstack && git log --format='%h %ad %s' --date=short -- docs/askuserquestion-split.md
cd /tmp/gstack && git log -S'D-numbering is a model-level instruction' --format='%h %ad %s' --date=short -- .
```text
