// Acceptance-criteria verification form classifier.
//
// One classifier, two consumers: scripts/replay_criteria.sh decides which
// cells it can run, and the handover format gate (handover-format.mjs)
// decides whether an `Agent [x]` mark is backed by something runnable. Both
// import this module, so the vocabulary that decides a runnable row is
// stated once.
//
// The four forms, judged from the backticked spans in the Verification cell:
//   command -- exactly one command span, no other span, and no residual word
//              outside the list that carries no claim
//   path    -- one or more path spans, no command span, and the same residual
//              rule
//   mixed   -- one command span alongside another span or words the command
//              does not decide, so no one run decides the whole claim
//   prose   -- no command span at all, or two or more command spans
//
// A `command` cell carries an expectation, drawn from the closed set below,
// because the exit status alone does not always state the claim: `grep` exits
// 1 on no match, which is what "prints nothing" asserts.
//
// CLI: --table FILE prints one TSV line per criteria row
//      (lineno, form, subject, reason). --json FILE prints one object per row
//      with the cell's criterion and Result mark beside those four, which the
//      replay script reads because a path subject joins its paths with
//      newlines and a TSV reader would split it.

import { readFileSync } from "fs";

// A reader that closes the pipe early, such as `head`, ends the table rather
// than failing it.
process.stdout.on("error", (error) => {
  if (error.code !== "EPIPE") throw error;
  process.exit(0);
});

/** A span whose first word is a program the replay script can run. */
const COMMAND_RE = /^(bash|sh|scripts\/|\.\/|grep|rg|test|ls|git|awk|sed|perl|find|node|npm|npx|pi|jq|make|curl|timeout)\b/;

/** A span that names a file by its extension. */
const PATH_EXT_RE = /\.(md|sh|mjs|js|ts|tsv|json|txt|yaml|yml)$/;

/** A character that makes a span more than one bare token. */
const META_RE = /[\s`$(){}[\]*?<>|&;'"!]/;

/**
 * Words that carry no claim of their own, so a cell made only of a span and
 * these still reads as one decidable statement.
 */
const ALLOW = new Set([
  "the", "is", "clean", "passes", "pass", "returns", "nothing", "no",
  "output", "prints",
]);

/**
 * The expectation a `command` cell states beyond "it succeeds". `exit0` is
 * the default a cell with no residual words carries. `empty` is the cell that
 * says the command prints nothing, where a non-zero exit is part of the pass.
 */
function expectationOf(words) {
  if (words.includes("nothing")) return "empty";
  if (words.includes("no") && words.includes("output")) return "empty";
  return "exit0";
}

// A path span is a single token: one span holding spaces is a sentence about
// files or a command line whose last word carries an extension, and running
// it as a path would report a missing file that the cell never named.
function isPath(span) {
  if (META_RE.test(span)) return false;
  if (PATH_EXT_RE.test(span)) return true;
  return span.includes("/") && !span.startsWith("/");
}

/** The residual words of a cell, with a span removed in place of each span. */
function residualWords(text) {
  return text
    .replace(/\s+/g, " ")
    .trim()
    .split(" ")
    .filter(Boolean)
    .map((word) => word.replace(/^[^A-Za-z0-9]+/, "").replace(/[^A-Za-z0-9]+$/, "").toLowerCase())
    .filter(Boolean);
}

/**
 * Classify one Verification cell.
 *
 * @param {string} cellText
 * @returns {{form: "command"|"path"|"mixed"|"prose", subject: string, reason: string}}
 */
export function classify(cellText) {
  const text = String(cellText === undefined || cellText === null ? "" : cellText);
  const spans = [];
  const stripped = text.replace(/`([^`]+)`/g, (_, inner) => {
    spans.push(inner.trim());
    return " ";
  });
  const words = residualWords(stripped);
  const residualAllowed = words.every((word) => ALLOW.has(word));
  const kinds = spans.map((span) => (COMMAND_RE.test(span) ? "command" : isPath(span) ? "path" : "other"));
  const commandSpans = spans.filter((_, i) => kinds[i] === "command");
  const commandCount = commandSpans.length;

  if (commandCount === 1 && spans.length === 1 && residualAllowed) {
    return {
      form: "command",
      subject: spans[0],
      expect: expectationOf(words),
      reason: "one command span and nothing else",
    };
  }
  if (commandCount === 1) {
    const reason = spans.length > 1
      ? "a command span alongside spans it does not check"
      : "a command span alongside words it does not check";
    return { form: "mixed", subject: commandSpans[0], reason };
  }
  if (commandCount === 0 && spans.length > 0 && kinds.every((kind) => kind === "path") && residualAllowed) {
    return { form: "path", subject: spans.join("\n"), reason: "path spans and nothing else" };
  }
  if (commandCount > 1) {
    return { form: "prose", subject: commandSpans.join("; "), reason: "two or more command spans, so no one run decides it" };
  }
  if (spans.length === 0) {
    return { form: "prose", subject: "", reason: "no backticked span" };
  }
  const allPaths = kinds.every((kind) => kind === "path");
  return {
    form: "prose",
    subject: spans.join(" "),
    reason: allPaths ? "path spans alongside words that carry a claim" : "spans name no command and no path",
  };
}

/**
 * The criteria rows of a handover text: a table line whose fourth
 * pipe-separated field carries a Result mark. Field 2 is the criterion and
 * field 3 the Verification cell, counting the empty field before the first
 * pipe as field 1.
 *
 * @param {string} text
 * @returns {{line: number, criterion: string, verification: string, result: string}[]}
 */
export function criteriaRows(text) {
  const rows = [];
  String(text).split("\n").forEach((line, i) => {
    if (!line.startsWith("|")) return;
    const fields = line.split("|");
    if (fields.length < 4) return;
    const result = (fields[3] || "").trim();
    if (!/\[[xX ]\]/.test(result) && !/\bReviewed\b/.test(result)) return;
    rows.push({
      line: i + 1,
      criterion: (fields[1] || "").trim(),
      verification: (fields[2] || "").trim(),
      result,
    });
  });
  return rows;
}

function main(argv) {
  const asJson = argv.includes("--json");
  const asTable = argv.includes("--table");
  const file = argv.filter((arg) => !arg.startsWith("--"))[0];
  if ((!asJson && !asTable) || !file) {
    console.error("usage: criteria-form.mjs (--table|--json) <handover.md>");
    process.exit(1);
  }
  const rows = criteriaRows(readFileSync(file, "utf8")).map((row) => {
    const verdict = classify(row.verification);
    return {
      lineno: row.line,
      form: verdict.form,
      subject: verdict.subject,
      expect: verdict.expect || "exit0",
      reason: verdict.reason,
      criterion: row.criterion,
      result: row.result,
    };
  });
  if (asJson) {
    process.stdout.write(`${JSON.stringify(rows)}\n`);
    return;
  }
  for (const row of rows) {
    // A path subject joins its paths with newlines, so the TSV printer spells
    // the break out; one record otherwise spans several lines and no reader
    // can split the table.
    const subject = row.subject.replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/\t/g, "\\t");
    process.stdout.write(`${row.lineno}\t${row.form}\t${subject}\t${row.reason}\n`);
  }
}

if (process.argv[1] && process.argv[1].endsWith("criteria-form.mjs")) {
  main(process.argv.slice(2));
}
