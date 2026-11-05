// The record cutover, held once for every gate that reads a record.
//
// A record dated before this date keeps an old-format name and may sit in a
// state the vocabulary no longer holds, because the corpus predates the rules.
// Two gates exempt it: the name gate (scripts/lint/record-name.mjs) and the
// lifecycle gate (scripts/lint/record-lifecycle.mjs).
//
// Deleting this constant is how the T5 cleanup row in devlog/roadmap.md ends:
// when no record predates the rules, no gate needs to exempt one.

export const RECORD_CUTOVER = "20261105";
