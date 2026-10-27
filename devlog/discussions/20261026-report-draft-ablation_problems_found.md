---
date: 2026-10-26
type: Report
status: draft
---

# Problems found attempting the section ablation

## Objective

Record what an attempt to measure the cleanup prompt's sections surfaced: four ways its own harness failed, and one structural reason the measurement could not have worked in this repository. This is not a result. The attempt produced no section impact, and nothing here should be read as one.

## What the attempt was

Remove one `##` section at a time from `workflow/coding-agent/prompts/instruction-cleanup.md` and re-run the pass over the same carriers, so that a section whose removal costs no faults is one the census can delete. Twelve sections, three carriers, three replicates, plus a baseline arm that is the prompt unchanged: a hundred and seventeen cells, ordered replicate-major so that a stop leaves complete replicates rather than complete arms. Each cell is one `opencode run` over one brief, and a brief is the pass's own text behind a preamble stating the surface, the shape of the return, and that the run stops after the judgement.

An arm is the landed prompt with exactly one section deleted, heading and body, nothing else touched. The frontmatter, the title, the `$ARGUMENTS` line and the Scope paragraph survive in every arm, so no arm loses the surface statement or the convention pointer.

## What it produced

Nothing usable. Thirty-five cells of a hundred and seventeen ran before the free tier ran out, and every one of them is discarded: their logs, their status sheet and the parsed table they fed were deleted with the run. What survives is the generator, the thirteen prompts, the thirty-nine briefs and the hundred-and-seventeen-cell plan, all under `.scratchpad/ablation/`, so a resumed run is one invocation away.

The last refusal is the real one, and it does not take either of the forms the earlier ones took:

```text
level=ERROR message="stream error" modelID=deepseek-v4.1-flash-free
  error.error="AI_APICallError: Free usage limit reached.
  Free models work in OpenCode (https://opencode.ai); subscribe to OpenCode Go to keep going"
```

A trivial "reply PONG" call afterwards takes ninety seconds and returns no text, so the tier is exhausted rather than rate-limited.

The attempt also sizes the tier: sixty-eight sessions were created in about forty minutes before it ran out, carrying 133701 output tokens between them. A hundred-and-seventeen-cell grid therefore needs two quota windows, not one, and a resumed run is better planned as seventy cells at a time.

## Why no cell could have measured the prompt

Thirty of the thirty-five cells read a file outside the carrier, thirty of them read a prior record or an earlier fault list, and the worst opened seventeen outside files. The `kelsey` baseline spent its whole wall time grepping the tree and reading `.scratchpad/cmp/b.session` rather than judging the carrier.

The cause is structural, and it survives any resumption that keeps the working directory as it is: the carriers live in `.agents/audits/` inside this repository, and this repository holds the ground truth for the question the grid asks.

- `.scratchpad/cmp/b.session` and `.scratchpad/cmp/run-a/seat1-turn1.log` hold the single-file comparison's fault lists, which quote the carrier's own rules with sites.
- `devlog/discussions/20261026-report-settled-census_six_carriers.md` holds a hundred and twenty-three fault sites across the same six carriers.
- `devlog/AGENT_FEEDBACK.md` and the drafts under `.agents/drafts/` carry rulings on the same wording.

The vector is the shell, not the file read: across the sixty-eight sessions of the attempt the model made 472 `bash` calls and 71 file reads, and thirty-six of the forty-four sessions that called a tool at all referenced a path outside the carrier, about ten references each. A brief that states which file to judge therefore bounds nothing, because the model's default way of orienting is to run shell commands over the tree and print what it finds. Containment has to be a property of the directory the process runs in, which is what the eval case set row now requires, and it cannot be prose.

A list produced under those conditions measures the tree, not the prompt. The constraint that follows is stated where the cases are constructed, on the eval case set row of [`devlog/roadmap.md`](../roadmap.md): a case directory holds the carrier and the files that case names, and nothing else. It changes what the provenance arm measures here, because an ownership lookup into another surface is no longer possible, so that arm would test the recommendation the prompt can state without looking.

## The harness defects, and why no cell asked the model anything

Five traps fired before any cell reached the prompt, and each is recorded with its symptom, its correction and the place this repository must learn it in [`20261026-05-workflow-opencode_run_harness_defects.md`](../handovers/20261026-05-workflow-opencode_run_harness_defects.md): the child consuming the loop's stdin, a refusal that arrives in two shapes, a retry keyed to any non-zero exit, six processes sharing the one SQLite file behind `opencode`, and `--variant high` returning an empty turn.

What matters here is not the list but where each one lands: every trap either exits silently, hangs to its wall cap, or records a cell carrying no fault list. A cell that reports success in this grid is a cell nobody can read, which is why the grid could not have answered the question it was built for.

## What a resumed run needs

The room from the eval case set row, a brief that says one file may be read and the tree may not be searched, both refusal shapes matched, stdin detached, the lock as the only retry, and a wall cap set from the observed range of 144 to 531 seconds rather than at nine hundred.

Nothing in this record rules on which section is load-bearing. The grid has not answered its question, and no partial matrix survives to be read as if it had.
