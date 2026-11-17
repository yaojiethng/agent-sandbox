# The principle cross-references, censused

**Status:** open
**Date:** 2026-11-16
**Instrument:** `.scratchpad/census.mjs`, throwaway; it reads the 25 principle `SKILL.md` files under `src/reasoning/agent-runtime/pi/config/agent/skills/` and prints one row per cross-reference.

## Why this exists

The corpus survey needs the references that already exist before it proposes an edge. This is the read-only half of the survey's first row: it edits no skill, and it records each reference with the named part it sits under, the pointer form and the target. The field `metadata.neighbours` is not its output; the existing corpus declares `[]`, and the survey map carries the edges.

## The measure

30 references across 15 of the 25 principles; 10 principles carry none.

| Form | Count |
|---|---|
| bare skill name in a code span | 21 |
| `$AGENT_HOME/...` code path | 6 |
| relative Markdown link | 3 |

The dominant named part is `What it does not cover` (12), then `Where another rule wins` (4), `The test` (5), and `The brief's other half` (2). The first-pass kind is 23 neighbour candidates, 5 references and 2 external.

## The census

| Source | Named part | Form | Target | First-pass kind |
|---|---|---|---|---|
| `communication-principle-align-the-mental-model` | The test | agent-home-path | `communication-principle-define-terminology-before-use` | reference |
| `communication-principle-align-the-mental-model` | The test | bare-name | `communication-principle-define-terminology-before-use` | reference |
| `communication-principle-attach-as-you-read` | Where another rule wins | agent-home-path | `communication-principle-define-terminology-before-use` | neighbour-candidate |
| `communication-principle-attach-as-you-read` | Where another rule wins | bare-name | `communication-principle-define-terminology-before-use` | neighbour-candidate |
| `communication-principle-cut-what-serves-nothing` | What it does not cover | bare-name | `communication-principle-maximize-conceptual-leverage` | neighbour-candidate |
| `communication-principle-cut-what-serves-nothing` | What it does not cover | bare-name | `communication-principle-single-train-of-thought` | neighbour-candidate |
| `communication-principle-cut-what-serves-nothing` | What it does not cover | bare-name | `principle-single-source-of-truth` | neighbour-candidate |
| `communication-principle-dont-forecast-undone-work` | Where another rule wins | agent-home-path | `principle-match-precision-to-stakes` | neighbour-candidate |
| `communication-principle-dont-forecast-undone-work` | Where another rule wins | bare-name | `principle-match-precision-to-stakes` | neighbour-candidate |
| `communication-principle-keep-a-subject-near` | Where another rule wins | agent-home-path | `principle-single-source-of-truth` | neighbour-candidate |
| `communication-principle-keep-a-subject-near` | Where another rule wins | bare-name | `principle-single-source-of-truth` | neighbour-candidate |
| `communication-principle-keep-a-subject-near` | Where another rule wins | bare-name | `principle-single-source-of-truth` | neighbour-candidate |
| `communication-principle-link-what-the-reader-can-open` | What it does not cover | bare-name | `communication-principle-write-for-the-reader` | neighbour-candidate |
| `communication-principle-maximize-conceptual-leverage` | The test | agent-home-path | `communication-principle-define-terminology-before-use` | reference |
| `communication-principle-maximize-conceptual-leverage` | The test | bare-name | `communication-principle-define-terminology-before-use` | reference |
| `communication-principle-maximize-conceptual-leverage` | What it does not cover | bare-name | `communication-principle-cut-what-serves-nothing` | neighbour-candidate |
| `communication-principle-rewrite-syntax-never-semantics` | What it does not cover | bare-name | `principle-single-source-of-truth` | neighbour-candidate |
| `communication-principle-show-dont-describe` | What it does not cover | bare-name | `communication-principle-cut-what-serves-nothing` | neighbour-candidate |
| `communication-principle-show-dont-describe` | What it does not cover | bare-name | `communication-principle-link-what-the-reader-can-open` | neighbour-candidate |
| `communication-principle-single-train-of-thought` | What it does not cover | bare-name | `communication-principle-cut-what-serves-nothing` | neighbour-candidate |
| `communication-principle-single-train-of-thought` | What it does not cover | bare-name | `communication-principle-maximize-conceptual-leverage` | neighbour-candidate |
| `communication-principle-state-intent-delegate-method` | The brief's other half | markdown-link | `principle-say-what-done-looks-like` | neighbour-candidate |
| `communication-principle-write-for-the-reader` | What it does not cover | bare-name | `communication-principle-cut-what-serves-nothing` | neighbour-candidate |
| `communication-principle-write-for-the-reader` | What it does not cover | bare-name | `communication-principle-link-what-the-reader-can-open` | neighbour-candidate |
| `principle-check-placement` | The test | bare-name | `principle-encode-lessons-in-structure` | external |
| `principle-check-placement` | The test | markdown-link | `principle-minimal-corrections` | reference |
| `principle-check-placement` | The test | bare-name | `principle-sequence-verifiable-units` | external |
| `principle-justify-materialization-cost` | A value in a sentence is the neighbouring question | agent-home-path | `communication-principle-only-derive-what-you-own` | neighbour-candidate |
| `principle-justify-materialization-cost` | A value in a sentence is the neighbouring question | bare-name | `communication-principle-only-derive-what-you-own` | neighbour-candidate |
| `principle-say-what-done-looks-like` | The brief's other half | markdown-link | `communication-principle-state-intent-delegate-method` | neighbour-candidate |

## What it says

The corpus is sparse in cross-references, and the forms are uneven. A bare name is not openable. An `$AGENT_HOME` path is not openable by a shipped reader, because the target is outside the image. Only three references are Markdown links a repository reader can follow.

Two references point outside the repo-owned corpus: `principle-check-placement` names `principle-encode-lessons-in-structure` and `principle-sequence-verifiable-units`, which live in `src/reasoning/agent/skills` rather than the provider root. The survey's card set is the provider root, so those two are cross-layer references, not candidates for the map.

The census is the candidate source, not the edge set. It tells the survey where to look and gives the normalisation decision its evidence. The link normalisation stays conditional: a required `See also` section would be a body-shape change, and the relation kinds are not settled yet.
