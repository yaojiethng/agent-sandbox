# Interactive Command Contract

**Status:** draft - first write, not yet reviewed. Awaits the operator's decision.

**Scope:** the contract between a leaf script and the interactive helper that collects its inputs, and the uniform meaning of `--interactive` across the five leaves that accept it: what the helper returns, which layer it belongs to, who owns the prompt vocabulary, how the interactive path converges with the flag path, the non-tty and end-of-input policy, the derived equivalent-command display, and the units that pin the contract. Out: the picker's rendering internals (the read-through's rows 260 and 261), the dispatcher boundary (the CLI-to-workflow note), the flag declaration surface (the resolver note), the diff state contract (the diff-invariants note), and the Make translation of any new variable.

## Context

The operator's model for the mode is: `<script> --interactive` delegates to a helper, the helper asks the questions that the operator did not answer on the command line, and it hands back a fully specified command that the script executes. The helper is a user interface. It is not a workflow, and it owns no effect.

The tree does not realise that model. No leaf receives a command, and the five call sites use three different shapes.

| leaf | what its `--interactive` branch does | shape |
|---|---|---|
| `prune.sh` 307-318 | builds `PRUNE_CMD` as an `agent-sandbox prune ...` string, prints it as "Equivalent non-interactive command", passes it to `interactive_confirm_or_abort`, then runs its own in-process delete path | the model, except the leaf builds the string and the helper only confirms it, so the printed command does not drive the run |
| `apply.sh` 208-215 | previews the diff, calls `interactive_confirm_or_abort "Apply:" "$DIFF_FILE"`, prints `Running: make apply DIFF=...`, then calls `apply_run` with four further arguments | confirmation only; the printed line is not the run (row 264) |
| `draft.sh` 583-632 | confirms the patch list, then `interactive_select_channel` and `interactive_select_bundle`, then continues in-process with `BUNDLE_NAME` | two **values** returned, no command |
| `start_agent.sh` 133-180 | `interactive_pick` for the provider, `interactive_pick` for the image build policy, then a confirmation, then continues with `chosen` and `policy` | two **values** |
| `resume_agent.sh` 113-140 | `interactive_pick` for a session, then a confirmation, then continues with `chosen` | one **value** |

The helper's realised contract is therefore "return one token" or "confirm a plan that a leaf already built". Three consequences follow, and each is recorded as a finding.

**The vocabulary is split without a rule.** The helper hardcodes the `draft` subcommand, the three channel names, the autosave mtime rule, the `.export-status` field names, and the column widths, while the provider list and the build-policy labels stay in the leaf. The apply arm of the channel selector and the `diffs` channel were removed in the bundle refactor and the helper's docstrings still name both (row 257); its header still names its pre-move path, three of its four functions, and one of its four sources (row 258); its picker's usage line names a parameter that no longer exists (row 259).

**The interactive path and the flag path are separate code paths that meet only at the effect.** Three leaves continue in-process with a returned value, and the two paths are compared by no unit. `prune.sh`'s "Equivalent non-interactive command" line is the only stated equivalence in the tree, and nothing checks it; `apply.sh` prints a command that omits the project, the sandbox, the branch, and force, so the one line that claims to state the run states a different one (rows 264 and 265).

**The non-tty policy is not a policy.** `interactive_confirm_or_abort` prints a warning when stdin is not a terminal and then reads anyway; the warning is stated in its docstring and asserted nowhere (row 263). `interactive_pick` discards the read status, so end of input is indistinguishable from an empty entry and, with no default, it loops: probe-fed closed stdin with two entries and no default produced 240,014 copies of "Invalid selection. Try again." in three seconds without returning (row 256). Every unit pipes its answers in, so every unit runs on the non-tty path.

**The flag's meaning is defined five times.** Each leaf parses `--interactive` itself and branches on it; the helper never sees the flag. The dispatcher's flag summary lists it for `resume`, `prune`, and `apply` and omits it for `start` and `draft`, both of which parse it (row 266), and `start_agent.sh` refuses it outside standard mode with a roadmap pointer, so the deferral is real and undocumented in the flag's own terms.

**Placement.** The helper sits in `scripts/workflows/` beside four CLI leaves, defines no `usage` and no `main`, and `route_help`'s whitelist keeps `interactive` out of the subcommand table, so `bash scripts/workflows/interactive.sh --help` exits 0 with no output (row 148; probe P5 of the interactive pass).

**Evidence.** Rows 148, 256, 257, 258, 259, 260, 261, 263, 264, 265, and 266. Probes: the picker's EOF loop with and without a default (P1, P2), `interactive_select_channel apply` (P3), the unknown-array-name guard (P4), the file run as a script (P5). Bites: I1 through I14 of the interactive pass, of which I1 and I2 are the EOF path, I8 the unknown-subcommand guard, and I3, I9, I10, I11, and I12 the picker core that is already pinned.

## Options Considered

### Option area 1 - what the helper returns

**Option A - one value per answer.** The status quo. Each answer crosses a process boundary as a token, and a leaf that needs two answers calls twice. Cost: the fully specified command never exists as one object, so no unit can compare the interactive run with the flag run, and the leaf's continuation code is a second execution path.

**Option B - an argv.** The collector returns a token list for the leaf's own parser, and the interactive mode then re-enters the same path the flags take. Equivalence holds by construction, and one unit per leaf can state it. Cost: each leaf needs a collector and its normal path must accept a constructed argv.

**Option C - a command string.** `prune.sh`'s form. Cost: a string must be re-parsed or `eval`ed to run, which reintroduces the construct the record work is removing, and it is what produced the `apply` line that states a different command from the one it runs (row 264).

### Option area 2 - the helper's layer

**Option A - keep it in `scripts/workflows/`.** The status quo, and the source of row 148: a library among leaf scripts, invisible to every caller's dependency list.

**Option B - move it to `src/libs/`.** The picker's pagination, option-0 injection, and index padding are generic UI, and the host libraries are where generic host code lives.

**Option C - a new `scripts/interactive/`.** A third top-level directory for one component. Cost: more structure than the component needs.

### Option area 3 - who owns the vocabulary

**Option A - the helper.** The status quo for channels: the prompt text, the channel names, and the autosave rule live in the library. Only `draft.sh` uses them.

**Option B - the leaf.** The status quo for the provider: the leaf passes the entries and the helper renders, asks, and returns the choice. This is the split that keeps leaf knowledge out of a generic library.

**Option C - a declaration table per leaf.** One table listing each prompt, its type, and its default, with the helper as an engine over the table. Cost: this is the declaration problem the resolver note already defers, and it is larger than the mode needs.

### Option area 4 - convergence

**Option A - collect, then re-enter the leaf's normal path with the collected argv.** One path to test, and the equivalence statement becomes a fact rather than a claim.

**Option B - keep a separate interactive branch.** The status quo. Cost: two paths per leaf, and no unit compares them (row 265).

### Option area 5 - non-tty and end of input

**Option A - fail closed.** When stdin is not a terminal, refuse and name the flags that replace the prompts. The EOF loop becomes impossible by construction, and a CI invocation gets a usable error instead of a hang (row 256).

**Option B - warn, then read anyway.** The status quo for the confirmation helper. Cost: the warning states a problem it does not act on, and the picker hangs on EOF.

**Option C - refuse even a piped answer.** Cost: it breaks the 32 existing units, which drive the helper by piping.

### Option area 6 - the equivalent-command display

**Option A - derive it from the argv.** One printer, so the displayed string cannot disagree with the run.

**Option B - omit it.** Cost: `prune.sh`'s line is useful, and the operator loses the audit trail it gives.

**Option C - hand-build it per leaf.** The status quo: `prune.sh`'s line matches its run and `apply.sh`'s does not (row 264).

### Option area 7 - coverage

**Option A - one convergence unit per leaf.** Given the answers, the composed argv equals the argv the explicit flags build. This is the contract test the model needs, and it is the only unit that would have caught row 264.

**Option B - the primitives only.** The status quo: 32 units drive the helper and no unit drives a leaf's interactive branch end to end.

### Option area 8 - the flag surface

**Option A - all five leaves, uniformly.** One rule for the operator, and the dispatcher's summary lists it on every line. The `start` serve/dry-run refusal stays, recorded as its own deferral.

**Option B - the three leaves the dispatcher documents.** Cost: it removes the flag from `draft` and `start`, which are exactly the two leaves with the most to collect, and it fixes a documentation gap by deleting functionality.

## Decision

Proposed, not settled. The recommendation is option B in area 1, option B in area 2, option B in area 3, option A in area 4, option A in area 5, option A in area 6, option A in area 7, and option A in area 8.

1. The collector returns an argv for the leaf's own parser, not a value per answer and not a shell string. The leaf then re-enters its normal path with that argv, so the interactive run and the flag run are the same code path.
2. The helper moves to `src/libs/interactive.sh` and keeps only generic primitives: ask (free text with a default), pick (a numbered list with pagination and option-0 injection), and confirm (y/N). It returns the answer and nothing else.
3. The vocabulary stays with the leaf. Channel names, prompt text, and the autosave rule move into `draft.sh`'s collector; the provider list and the build-policy labels stay where they are.
4. The interactive path converges before any side effect. Each leaf keeps one collector whose output is the argv the flag path already builds.
5. A non-tty stdin fails closed with a message naming the flags that replace the prompts. End of input is an abort, not an empty entry, which is the contract `interactive_pick`'s docstring already states.
6. The equivalent-command line is derived from the argv by one printer, so a displayed command and an executed command cannot disagree.
7. One convergence unit per leaf: answer the prompts, then compare the composed argv to the flag-built argv. The primitives keep their existing units.
8. `--interactive` stays on all five leaves and the dispatcher's summary lists it on every line; the `start` serve/dry-run refusal is recorded as a deferral in the flag's own terms.
9. The ADR home is a new `docs/adr/interactive_command_contract.md` (name to confirm at settlement). The flag-parse half lands in `docs/adr/command_flag_parsing.md`, which the CLI-to-workflow note already claims.

## Consequences

What closes. Row 148 closes with the move, because the file stops being a library in a leaf directory. Rows 256, 257, 258, 264, 265, and 266 close with the contract: the EOF loop becomes a primitive's abort, the leaf vocabulary leaves the helper, the printed command becomes derived, and the equivalence gets a unit. Rows 259, 260, 261, and 263 stay coverage units on the primitives; the rewrite absorbs them, but each remains a unit of its own.

What retires. `interactive_select_channel` and `interactive_select_bundle` retire with the vocabulary move; `draft.sh` gains one collector that asks for the channel, the bundle, and the patch selection, and returns them as flags. The two per-leaf continuation branches retire into the collected argv. `prune.sh`'s hand-built string retires into the derived printer. The helper keeps the pagination, the option-0 injection, and the index padding, which are its only non-trivial code and are already pinned (bites I3, I9, I10, I11, I12).

What it forecloses. The helper stops being able to select a channel or a bundle on its own, so any future caller that wants a bare selector must supply its own vocabulary. That is the intended layering, and it is also the reason the change is not free: `draft.sh`'s interactive path is the most-used one and it grows a collector.

The risks. A converged path is only converged if it is the only path; a leaf that keeps its old branch alongside the collector recreates row 265 in a new form, so the convergence unit is the guard. The argv a leaf builds must be exactly the argument set its parser accepts, or the interactive mode fails in the parser rather than in a prompt; the convergence unit catches that too. And a fail-closed non-tty policy changes behaviour for any caller that pipes answers into a leaf rather than into a test, which is why the primitives keep their piped units and the leaves' convergence units pipe their answers into the collector.

Out of scope, with the series in mind: the picker's rendering, the dispatcher boundary, the declaration surface, the diff state contract, and the Make translation of the flag. The series and its index line are recorded in the read-through's Design notes section.

Evidence and disposition live in [`20260924-design-active-test_suite_readthrough.md`](20260924-design-active-test_suite_readthrough.md): rows 148 and 256 through 266, and the interactive pass's unit table and bite sweep.
