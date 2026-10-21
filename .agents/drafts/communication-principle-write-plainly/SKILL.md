---
name: communication-principle-write-plainly
description: The plain-wording home for this repository's documentation prose. Holds what the duplication map measured, dispatches every rule to the skill or gate that owns it, and states no borrowed rule of its own. Draft, not authoritative.
---

# Write plainly

**Status:** draft

This is a home for findings, not a restatement. Every rule it needs is already held somewhere: in a filed principle, in a lint gate, in `documentation_policy.md`, or in `/technical-writing`. The value it adds is the map between them and the decision about which of them moves. A second statement of a rule is the duplication this milestone exists to remove, so this file states none.

## What the map measured (this repository)

`scripts/lint/norm-judgements.tsv` groups five lines under `j-write-plainly`, all in `prompt-authoring-conventions.md`'s sibling policy section and none in the conventions. Three of the five are already held by a gate: `doc-ascii` catches the punctuation, the numbering gate catches the numbered units, and the ledger records both as rules with an observer rather than as judgements.

What remains is ASD-STE100 conformance, which `documentation_policy.md` states as a standard a writer meets rather than as a decision a writer takes. One document states it, so the map classes it class 2: a candidate, not a filing.

Source: handover `20261020-09`, and `scripts/check_norm_ownership.sh --groups`.

## What this standard would own

Only what nothing else holds:

- The plain-wording rules live in three places today: `documentation_policy.md` `## Communication Standards`, the provider-layer `AGENTS.md` restatement of the same standard, and the operator-invoked `/technical-writing` skill. One of the three must be the home and the other two must point at it.
- The policy keeps the rules a checker holds, because a gate is a stronger home than a skill: `check_norm_ownership.sh` proves it.
- The pointer sentence left behind in each document takes a ledger kind, and that kind is decided with the filing, not here.

## Where each rule is held

| Topic | The home today |
|---|---|
| One clause at a time, releasing each phrase as it arrives | `communication-principle-attach-as-you-read` |
| Cutting the word that does no work | `communication-principle-cut-what-carries-nothing` |
| Writing for the reader rather than the session | `communication-principle-write-for-the-reader` |
| Showing the artifact instead of describing it | `communication-principle-show-dont-describe` |
| A copy points at its source, and a fast path is labelled | `principle-single-source-of-truth` |
| Which document type a document is, and the four layers of prose | `/technical-writing`, until it is subsumed |
| Punctuation, ASCII, numbering, line wrapping | the gates under `scripts/lint/`, not a skill |
| Slop patterns and AI vocabulary | `unslop` |
| The kind and observer of every prose line | `scripts/lint/norm-ownership.tsv` |

A rule this table cannot place is a finding: record it here with the ledger row that shows it, rather than writing the rule again.

## Provenance of each header

`## What the map measured` is this repository's own measurement and names its ledger. `## Where each rule is held` is navigation, and every row names its own home rather than describing it. `## What this standard would own` is a decision record, pending the filing. A rule borrowed from a standard outside this repository carries that standard's fetch date at the place it is named, never here.

## Why it stays a draft

The rejection is about the home, not the content: filing a skill for a judgement one document states would put a second home beside the policy. Promotion is one commit that moves this directory into a live root once the filing has decided the pointer sentence's kind. The route, and the skill this will subsume, are in `README.md`.
