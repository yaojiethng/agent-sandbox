---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The dispatch subsystem after a thermonuclear review

## Objective

Remove the structural debt a thermonuclear code-quality review found in the dispatch subsystem, preserving behaviour: one candidate shape, one availability predicate, one plan that resolves an assignment to its argv, one home for the walk's advance rule, and one transactional writer for the route memory.

## Scope

The dispatch library, its shell entrypoint, and the tests that pin them: `src/libs/dispatch/` (including the new `walk.ts`), `scripts/dispatch.sh`, `tests/dispatch/`, `tests/test_dispatch.sh`. Also the review's seat source: the `_REVIEWER` and `_ADVISOR_DOCS` lines in `.agents/model-recommendations.md`, the review-seat guidance in both `AGENTS.md` copies and the `thermo-nuclear-code-quality-review` skill, because the review's second seat died on a deprecated model the table still named.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The dispatch library's unit suite is green | `node --test tests/dispatch/machine/*.test.ts tests/dispatch/seats/*.test.ts tests/dispatch/walk/*.test.ts` prints 112 passing | Agent [x] |
| The seam's behavioural suite is green | `bash tests/test_dispatch.sh` prints 61 passed, 0 failed | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |
| The whole suite is green | `bash scripts/run_tests.sh`; one load-dependent flake re-run in isolation, per the recorded triage | Agent [x] |
| The second review seat has a live candidate | `node src/libs/dispatch/cli.ts table resolve --role _ADVISOR_DOCS` answers, and neither line names `minimax` | Agent [x] |
| The review guidance prescribes no seat count | `grep -rn "seats 2\|two seats"` over both `AGENTS.md` copies and the skill prints nothing | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A candidate is the table's own `Assignment` | `SeatCandidate` duplicated it and carried four fields no reader consumed; one shape deletes the conversion chain | `seats.ts` |
| Availability is one exported predicate | `select` and the seat path asked the same question three ways; one predicate answers all three | `machine.ts` |
| `plan` selects from the whole role list and prints the assignment and the command | `select` returned a bare route and four call sites re-parsed the level; one call serves the walk, and the walk needs no cursor because every outcome that advances leaves its route unselectable | `cli.ts`, `scripts/dispatch.sh` |
| The plan record is pipe-separated with empty fields, not sentinels, and one shell function decodes it | a tab is whitespace to `IFS`, so an empty level collapsed and shifted the runtime; a positional line with `-` and `1` sentinels was read by two parsers | `cli.ts`, `scripts/dispatch.sh` |
| A seat's disposition is the walk's rule, scope included | the seat path rotated every capability failure, spending the role's line on a fault no model repairs | `seats.ts`, `walk.ts` |
| The level grammar and the key delimiter each have one search | the pin's validator copied the table's regex, and two delimiter searches let `x at high at low` pass | `table.ts`, `cli.ts` |
| The lock the route memory takes is recoverable | an exclusive lock with no holder made one killed process block every later attempt for the session | `state.ts` |
| The mode is one value, and the CLI's options are declared per command | ten mode booleans and a contradiction matrix left the mode unnamed; the CLI's generic flag map let a typo become a default | `scripts/dispatch.sh`, `cli.ts` |
| The seat plan is a NUL-delimited record, and both run states have decoders | a line protocol and a raw cast made the wire format and the resumed run untyped | `cli.ts`, `seats.ts`, `state.ts` |
| A seat turn is one library call returning a union, and its writes are one transaction | the handler recorded each seat in its own locked write, read the memory three times and re-derived the blocked reason from a second clock | `seats.ts`, `state.ts`, `cli.ts` |
| The rotation reads the route memory instead of a private list of dropped indices | the dropped list disagreed with the memory when two seats shared a dead candidate, and one test pinned the disagreement | `seats.ts` |
| The route record holds no sentence | four types threaded a text field that no decision read | `types.ts`, `machine.ts`, `state.ts` |
| The transition table names the invariant, its one checked column | its event and target columns were prose that had already drifted, and the suite checked neither | `machine.ts` |
| A cooldown and a dead set are answered by the selection, not by a length test | the seat start reported a cooling route as unroutable, with exit 4 and no wait, while the plan path reported blocked | `cli.ts` |
| One vocabulary array per union, in the machine | the decoder and the CLI each held a copy of `REASONS`; drift silently emptied the whole memory | `machine.ts`, `state.ts`, `cli.ts` |
| One `applyWrites` loop for every writer of the memory | the turn, the single-attempt record and the turn's transaction each applied the same transitions | `machine.ts`, `state.ts`, `seats.ts` |
| One builder per runtime, deriving the command from its argv | `argvFor` had no production caller and already disagreed with `commandFor` on the binary's quoting | `launch.ts` |
| The worker's precedence is stated where the walk is described | the reference said a worker "adds" the tree rule while the code replaces the class rules with it | `docs/reference/dispatch.md` |
| A usage error is its own class, and the seam reports it with exit 2 | a missing flag exited 1 through `required` beside `fail`'s 2, so one class of mistake had two codes | `table.ts`, `cli.ts` |
| A selection's refusal has one text and one code, and the seat turn reports through it | the blocked and unroutable answers were encoded twice, and the seat's exit-4 text named no route | `cli.ts`, `seats.ts` |
| The walk's mode is the discriminated field | `WalkInput` made every caller state the other mode's fields, so a seat asserted a `treeChanged` its mode ignores | `walk.ts` |
| Which modes own a non-mode flag is one relation | four hand-written blocks over `GIVEN` stated one rule in four places | `scripts/dispatch.sh` |
| The run directory has one preflight | the worker and the seat run validated it twice, with two messages, and both created it inline | `dispatch_worker.sh`, `scripts/dispatch.sh` |
| A single recorded attempt is a list of one | `recordAttempt` repeated `recordOutcomes`'s lock, load, metering and save | `state.ts` |
| A refusal carries its exit code, and a usage error carries 2 | the wrapper passed a code that `refuse` dropped, so the class existed without its contract | `cli.ts` |
| A silent success records nothing | the seat wrote `success` for a zero exit with an empty log, while the general path records `unknown` | `seats.ts` |
| The seating refuses a zero seat count beside its empty-candidate refusal | the only bound lived in the shell, so a second caller could review nothing and exit zero | `seats.ts` |
| The supervisor classifies a block once per poll | it started one node process per candidate line inside the loop that watches the process | `cli.ts`, `dispatch_worker.sh` |
| The seat's wait and dead set are the selection's answer | the tail re-derived `select`'s blocked and unroutable arms, so the two paths could drift | `seats.ts` |
| A refusal is a non-generic type | the signatures named `Selection` without its argument, which no typechecker in this tree reports | `types.ts`, `cli.ts` |
| The resumed candidate is rebuilt from its primary fields | `text`, `key` and `runtime` were persisted copies whose relationship the decoder never checked | `seats.ts` |
| A seat run's level reaches every dealt assignment | a non-pinned `--thinking` was accepted and dropped | `cli.ts` |
| A worker stops on the same unrecoverable failures as a general run | the tree branch returned before the request and account rules, so a worker spent the role's line on a fault no model repairs | `walk.ts` |
| The seat table names the capability stop it implements | the table still said every capability failure rotates, while the seat stops on an account or a request | `docs/reference/dispatch.md` |
| A malformed flag value is a usage refusal | the decoders minted the general refusal, so a bad `--class` exited 1 while a bad option name exited 2 | `cli.ts` |
| A pinned seat is one attempt | a retryable outcome on a pinned seat re-fired with no wait, because the pin bypasses the only reader of the memory, so the run could not terminate | `seats.ts` |
| A stopping seat keeps the turn's writes | the early return truncated the write list, so a capability outcome after a timeout was never recorded and the memory depended on seat order | `seats.ts` |
| The approval's residue is cleaned | the review's fourteenth round approved the unit and named three below-bar items: an unused `SeatOutcome`, an exported `LEVEL`, and two stacked doc comments | `seats.ts`, `table.ts` |
| The refusal class follows the value's owner | a pooled grammar minted the general refusal for a caller's `--pin`/`--thinking`, so one mistake had two exit codes, and the level grammar had two homes | `table.ts`, `cli.ts` |
| The pin's one-attempt rule is in the reference | the seat table stated the unpinned retry rule, and the pin's stop existed only in a code comment | `docs/reference/dispatch.md` |
| A caller's flag value is decoded at the boundary | a malformed `--thinking` or `--model` exited 1 while every other malformed flag value exited 2 | `cli.ts`, `table.ts` |
| The pin contract states its record rule once | the requirements line said the pin records nothing, contradicting the class table and the code | `docs/reference/dispatch.md` |
| One renderer layer | the top-level switch wrapped every command and seven command bodies wrapped themselves again | `cli.ts` |
| No dead declarations | an unused `select`, an unused `applyOutcome` and an unused `WalkMode` remained after the consolidation | `cli.ts`, `state.ts`, `walk.ts` |
| The walk command decodes its two shared facts once | both arms of the mode ternary repeated the class and scope decode | `cli.ts` |
| The resolver walks the availability predicate once | it selected for the refusal and then filtered for the candidates over the same list | `seats.ts` |
| One resolver answers a role, a pin and a level | `plan` and a seat run's start spelled the same resolution twice, and the seat copy ran `select` twice to discard one answer | `seats.ts`, `table.ts`, `cli.ts` |
| One selection answers the seat turn's tail | the two arms computed the same selection and threw the same invariant with two messages | `seats.ts` |
| The error vocabulary has its own module | the route machine, the memory and the seating imported the table grammar for an unrelated refusal | `errors.ts` |
| Every word of a printed command is quoted | the OpenCode binary was the one unescaped field, so a path holding a space word-split under `bash -c` | `launch.ts` |
| The `plan` command states the record it prints | the usage comment sat above the wrong function and named an index and a metered field that `plan` does not print | `cli.ts` |
| One constructor derives an assignment's key, text and runtime | three modules spelled the derivation, and the state decoder trusted the persisted copies | `table.ts`, `cli.ts`, `seats.ts` |
| The turn's refusal is the selection's value | the turn flattened it into fields and the CLI rebuilt it, renaming `earliest` to `until` | `seats.ts`, `cli.ts` |
| One renderer for a refusal, and the error carries its code | the exit code was stated in four places, and a corrupt run state exited 2 as a usage error | `table.ts`, `cli.ts` |
| The table path is required, not optional | four functions threaded a `file?` no production caller set, beside the environment override | `table.ts`, `cli.ts` |
| Every outcome class has a case, and a new one is a compile error | a `default` made a new class behave as `unknown` | `machine.ts` |
| An empty log is the walk's rule in both modes | the shell measured it in worker mode only, and the seat path restated it | `scripts/dispatch.sh`, `walk.ts`, `seats.ts` |
| The walk rule has its own unit suite | the refactor moved the policy into a module the unit suite never called | `tests/dispatch/walk/walk.test.ts` |
| The walk's advance rule lives in the library | it restated the route policy in bash, untested; `decideWalk` is the one home and the shell only fires | `walk.ts` |
| The route memory is written through one locked transaction | an atomic rename hid a non-atomic read-modify-write, so two dispatches could lose one outcome | `state.ts` |
| A pin is one attempt in either mode, and the memory never holds a pinned seat back | the two paths implemented opposite pin contracts: a pinned walk could repeat its route, a pinned seat could be blocked | `scripts/dispatch.sh`, `seats.ts` |
| The test-file split is deferred | it was an operator-approved deferral in this unit's scope, and it splits a file the review's own second round still names | roadmap row under `M3.6`: **The dispatch test file is split by mode** |
| The remaining structural findings are carried to named rows, not fixed here | consolidating `classify` and `record`, moving the turn into the library, and rebuilding the rotation are one redesign of the seat/walk seam; the review's rounds confirmed they are design, not corrections | roadmap rows under `M3.6`: **The dispatch seam resolves an attempt in one call** and **The seat run's turn is one library transaction** |
| The review converged at its fourteenth round | fourteen rounds of `_REVIEWER` returned HOLD through round 13 and APPROVE at round 14, with the remaining structural work carried by three named rows | this handover, `## Findings` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `tests/test_convention_pointer.sh` walked `.scratchpad/`, the gitignored session scratch, and failed on a previous session's prompt drafts | test defect | a repository gate must not read a tree the review never sees; the walk now skips gitignored files | this handover; the gate is corrected in the same commit |
| The review's second seat died at the provider: `_REVIEWER`'s second candidate `opencode-go/minimax-m3.1-flash-free` is deprecated | record | a dead route in the committed table, and one seat of every review spent on it | the table edited on operator direction; this handover |
| `test_interactive_session_select.sh` failed once under the parallel run and passed 37 of 37 alone | flake | the recorded load-dependent class; no cause is claimed | `AGENT_FEEDBACK.md` entry `A parallel suite run flaked one unit` |
| The review's second round found the worker walk advancing by attempt ordinal, so a skipped cooling head was re-run | correctness | the cursor is now the index the library reports, so an attempt resumes after the entry it attempted | this handover; fixed in the same commit |
| The review's second round found the seat run's state read by cast and the walk rule untested | maintainability | both now have decoders and a unit suite | this handover; fixed in the same commit |
| The review's third round found the walk planning past the end of a skipped role, so the attempt's code became a usage exit | correctness | the walk selects from the whole list, so there is no cursor to overrun; a case now pins the skipped head | this handover; fixed in the same commit |
| The review's third round found the seat verdict a triple with a degenerate member, and the run-state decoder casting its candidate list | maintainability | the verdict is a union and the decoder builds its list in a loop | this handover; fixed in the same commit |
| The review's fourth round found an empty level collapsing a tab-separated plan record, and a level-less seat failing on a `-` sentinel | correctness | the plan record is pipe-separated and the seat plan sends an empty field | this handover; fixed in the same commit |
| The review's fourth round found the seat path rotating a capability failure at the request or the account | correctness | the seat asks the walk's rule, so both agree by construction | this handover; fixed in the same commit |
| The review's fourth round found the turn handler five transactions with three memory reads, and the rotation a private list of dropped indices | maintainability | `seatTurn` answers the turn and returns its writes, which the caller records in one locked transaction; the rotation advances from the memory, so every seat on a dead route leaves it | this handover; fixed in the same commit |
| The review's fourth round found the transition table's event and target columns checked by nothing, and `RouteRecord.text` carried by four types and read by none | maintainability | the table names the invariant the suite checks; the record holds no sentence, and `record` takes no `--text` | this handover; fixed in the same commit |
| The review's fourth round found the empty-log rule in three homes and the mode written by three channels | maintainability | the shell measures the empty log in both modes and the walk decides it; `--worker` writes the one mode value | this handover; fixed in the same commit |
| The review's fourth round found three unread `GIVEN` entries and a redundant `--file` channel, and `classify` outside the refusal wrapper | maintainability | the entries and the channel are deleted; every handler refuses through the one wrapper | this handover; fixed in the same commit |
| The review's fifth round found the reference still documenting a sentence the record no longer holds | documentation | the sentence lives in the entrypoint's report, and both documents now say so | this handover; fixed in the same commit |
| The review's fifth round found a cooling candidate answered as unroutable by the seat start | correctness | the start asks `select` and prints its blocked or unroutable answer with 3 or 4; a case pins a cooling and a dead start | this handover; fixed in the same commit |
| The review's fifth round found the reason vocabulary declared twice and the turn's writes applied three times | maintainability | the arrays live in `machine.ts`, and one `applyWrites` serves every writer | this handover; fixed in the same commit |
| The review's fifth round found `argvFor` without a production caller, an unchecked seat index, unread run-state fields, an optional-field seat result, two role-line matchers and a two-mode attempt loop | maintainability | the twin builder is deleted, the decoder checks the index and seat uniqueness, the unread fields are gone, `SeatResult` is a union, one matcher serves both table paths, and the loop's mode branches are three named steps | this handover; fixed in the same commit |
| The review's sixth round found a usage error exiting 1 beside the same class exiting 2 | correctness | `UsageError` carries exit 2, `required` and the former `fail` sites throw it, and every refusal is one class or the other | this handover; fixed in the same commit |
| The review's sixth round found the seat turn's exit-4 text naming no route | correctness | the turn returns the dead routes, and both entry points render a selection through one refusal function | this handover; fixed in the same commit |
| The review's sixth round found two empty-log readings, a wrapper-only `unroutable` shape, a mode-blind `WalkInput`, three plan wrappers, four flag-mode blocks, two run-dir preflights and a duplicated transaction | maintainability | the shell measures the tail's non-whitespace, the answer carries `routes`, the walk's mode discriminates, one planner and one flag relation and one run-dir helper remain, and a single attempt is a list of one | this handover; fixed in the same commit |
| The review's seventh round found the usage exit code dropped by `refuse`, and a silent seat recording a success | correctness | the code reaches `process.exit`, and the silent seat classifies as the empty text does, so the memory holds no unearned success | this handover; fixed in the same commit |
| The review's seventh round found the walk union read across its arms, a seat bound only in the shell, a pin resolved twice and clocks read per call | maintainability | the mode narrows with its `class` shared, the seating refuses a zero count, one `pinned` applies the level once, and each command takes one `at` | this handover; fixed in the same commit |
| The review's seventh round found the supervisor classifying a line at a time and the attempt loop's three steps each forking on the mode | maintainability | one `refusal` call per poll; the loop's per-mode functions are filed as a named row | this handover; the loop row under `M3.6` |
| The review's eighth round found the seat's tail re-deriving the selection | maintainability | the active candidates are handed to `select`, whose blocked and unroutable arms answer the turn | this handover; fixed in the same commit |
| The review's eighth round found the reference contradicting the walk on a worker timeout, and a level dropped in seat mode | correctness | the reference states the shared stops first and the tree rule after; a seat's level is mapped over every dealt assignment | this handover; fixed in the same commit |
| The review's eighth round found `Selection` used without its type argument, a resumed candidate trusting derived fields, and the plan path re-spelling `pinned` | maintainability | `Refusal` is the non-generic answer, the candidate is rebuilt from its primary fields, and both paths call `pinned` | this handover; fixed in the same commit |
| The review's ninth round found a worker advancing past an account or request failure, and the reference and a test disagreeing about it | correctness | the shared stops sit above the mode branch, the reference says a worker adds the tree, and a case pins the account and the tree stops | this handover; fixed in the same commit |
| The review's tenth round found the seat table contradicting the capability stop, and the `plan` usage comment describing a record `plan` no longer printed | maintainability | the table splits model/provider from account/request, and the comment sits on `cmdPlan` and names `key\|level\|runtime` | this handover; fixed in the same commit |
| The review's eleventh round found a malformed flag value exiting 1 beside a malformed option exiting 2, and `refusing` applied at two layers | maintainability | the decoders throw `UsageError`, the seven inner wrappers are gone, and the top-level switch is the one renderer | this handover; fixed in the same commit |
| The review's twelfth round found a pinned seat re-firing forever on a retryable outcome, and a malformed `--thinking`/`--model` still exiting 1 | correctness | a pinned seat stops on a retryable outcome like the pinned walk, and `decodeLevel`/`decodePin` refuse a caller's malformed value as a usage error at the boundary | this handover; fixed in the same commit |
| The review's thirteenth round found a stopping seat truncating the turn's writes, so the memory depended on seat order | correctness | every fired seat's outcome is written before the first stop is reported, and a two-seat case pins both writes | this handover; fixed in the same commit |
| The review's thirteenth round found `table resolve --pin` exiting 1 for a value `plan --model` refuses with 2, and the level grammar in two modules | maintainability | the grammar owns the class (`pin=true` refuses as usage) and exports `decodeLevel`; `decodePin` and the CLI's copy are gone | this handover; fixed in the same commit |
| The review's thirteenth round found the reference stating the unpinned retry rule for a pinned seat | maintainability | the pin paragraph states that a pin is one attempt and its retryable outcome stops the run | this handover; fixed in the same commit |
| The review's twelfth round found the requirements line saying a pin records nothing, against the class table and the code | maintainability | the line now says the pin reads no route, and the record rule has its one statement in the class table | this handover; fixed in the same commit |
| The review's eleventh round found three dead declarations, a repeated enum decode in `cmdWalk`, and the resolver's double availability walk | maintainability | the declarations are deleted, `cmdWalk` decodes its shared facts once, and the resolver filters once and asks `select` only for the empty case | this handover; fixed in the same commit |
| The review's tenth round found the resolver spelled twice and the seat tail's partition left as two selections | maintainability | `resolveAttempts` is the one resolver, `plan` takes its first candidate, and the tail selects once over the list the seat has left | this handover; fixed in the same commit |
| The review's tenth round found the error vocabulary inside the table grammar, the OpenCode binary unquoted, and one refusal shape beside the one renderer | maintainability | `errors.ts` holds `DispatchError`/`UsageError`, `launch.ts` quotes the binary, and `refuseSelection` throws the coded error | this handover; fixed in the same commit |
| The review's ninth round found the decoder trusting a persisted runtime and the assignment derivation spelled three times | maintainability | `assignmentOf` is the one constructor, and the decoder rebuilds from the primary fields | this handover; fixed in the same commit |
| The review's ninth round found the turn flattening the selection, three refusal renderers, a `file?` no caller set, and a `default` that swallowed a new outcome class | maintainability | the turn carries a `Refusal`, one renderer reads the error's code, the table path is required, and the switch is exhaustive | this handover; fixed in the same commit |

## Completed

| File | Change |
|---|---|
| [`types.ts`](../../src/libs/dispatch/types.ts) | `Availability` and the generic `Selection`; the dead `Verdict` and `Outcome.metered` removed |
| [`machine.ts`](../../src/libs/dispatch/machine.ts) | `availability` exported; `select` takes candidates and returns the chosen one |
| [`seats.ts`](../../src/libs/dispatch/seats.ts) | candidates are assignments; the pinned flag; typed records; `seatTurn` and `seatResult`; no dead state |
| [`state.ts`](../../src/libs/dispatch/state.ts) | a strict `decodeState`, a shared JSON reader and writer, and the locked `recordAttempt` and `recordOutcomes` transactions |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | a skipped-head walk case; the `command` cases renamed to `plan` |
| [`devlog/roadmap.md`](../roadmap.md) | the parser row closed on landing; the test-split row remains open |
| [`walk.ts`](../../src/libs/dispatch/walk.ts) | the advance rule, in one place |
| [`cli.ts`](../../src/libs/dispatch/cli.ts) | `plan` and `walk` commands; validated outcome decoding; the seats result protocol |
| [`dispatch.sh`](../../scripts/dispatch.sh) | one plan call, one pin rule, the library's walk decision, no parsed prose |
| [`table.ts`](../../src/libs/dispatch/table.ts) | an empty model is malformed, whatever the provider; one role-line matcher and one read for a listing |
| [`launch.ts`](../../src/libs/dispatch/launch.ts) | one command builder; the argv twin deleted |
| [`walk.ts`](../../src/libs/dispatch/walk.ts) | the mode is the discriminator, so each mode carries only the facts it reads |
| [`dispatch_worker.sh`](../../src/libs/dispatch_worker.sh) | `dispatch_run_dir`, the one run-directory preflight; one classifier call per poll |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | the record holds no sentence; the worker's tree rule replaces the class rules |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | the report names the role and the attempt, not a sentence in the memory |
| [`model-recommendations.md`](../../.agents/model-recommendations.md) | the deprecated candidate removed from `_REVIEWER` and `_ADVISOR_DOCS` |
| [`AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the review guidance names the role and lets the caller set the seat count |
| [`SKILL.md`](../../src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md) | the skill prescribes no seat count |
| [`tests/dispatch/`](../../tests/dispatch/) | the suites follow the candidate, availability and record shapes |
| [`test_dispatch.sh`](../../tests/test_dispatch.sh) | the seat result protocol and the walk's one message |
| [`test_convention_pointer.sh`](../../tests/test_convention_pointer.sh) | the gate skips gitignored files |
| [`roadmap.md`](../roadmap.md) | the two deferred findings filed as named rows |
