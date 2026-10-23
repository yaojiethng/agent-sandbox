---
reader: [agent]
---

# Dispatch

Dispatch resolves a role to a model, decides whether that model may be attempted in this session now, runs one delegated subagent, and records what the attempt ended in. This document states what the mechanism guarantees, the route machine behind those guarantees, what one invocation does, and the vocabulary a failure is reported in. Its reserved terms are defined in [`terminology.md`](terminology.md); this document links them and never restates them.

## Parties and the Value

A caller is a prompt, a skill or a script that needs a subagent to do work. It holds an intent and a brief, and it supplies a [role](terminology.md#role), a brief file and a working directory. It does not supply a model.

Dispatch holds the three answers the caller cannot derive from what it holds: which [assignment](terminology.md#assignment) the role names, whether that route may be attempted at this moment, and what the previous attempt on that route ended in.

The value is a fact with an owner. A model id written at a call site is measured once and then decays, and nothing reports the decay, so the call site keeps naming a model that stopped working weeks ago. The [role table](terminology.md#role-table) holds that fact where it can be reviewed, and the route memory is what turns a spent route into a statement rather than a timeout.

## Requirements

- A caller names a role, never a model. A model named explicitly is a pin: it reads no route and records none, because a pinned run is not routed.
- The role table is the only source of a role's models. No default model exists, and a role the table does not name is refused by its own name rather than resolved to something the table never mentioned. Nothing validates an assignment against a runtime's catalogue: whether a named model exists is the operator's fact, and the table states it. An id that does not exist surfaces at the provider: a text naming the model marks that route dead and the walk advances, and text the classifier does not know stops the walk as unclassified rather than guessing.
- An assignment is validated as a whole line, and a malformed line fails the resolution instead of reaching a command.
- A [role line](terminology.md#role-line) may list several assignments in preference order. A repeat of one already listed adds no fallback, and the first line whose tag matches is the line, so a second line for one role is ignored.
- An attempt happens only when the route memory allows it at this moment. When no entry of the role may be attempted, the refusal names why: the routes are cooling and the earliest wait is given, or the routes are dead and each is named.
- The route memory is session-scoped and dies with the container. It is one small file named by the session, overridable with `DISPATCH_STATE_FILE`, and it is never a bind-mounted path: a memory that outlives the session is a record, and this one is not a record.
- Only a recorded outcome writes to the memory. The clock is applied when the memory is read, so expiry needs no writer, and a missing or unreadable file loads as an empty memory rather than an error.
- A read-write worker attributes its change set to a named base revision, and a second model never runs over a first model's edits.
- A fixed run pins its assignment at its call site. It is not routed, and the route memory never learns from it.

## The Resolution Path

The table is read from `DISPATCH_REC_FILE` when it is set, then from the repository's `.agents/model-recommendations.md`, then from the agent home. The first two read the same file in a normal tree; the third is the copy a container falls back to when the repository one is absent.

A role is a tag matching `_[A-Z][A-Z0-9_]*`, and its line lists assignments separated by semicolons. The list is returned in the order the table wrote it, with repeats dropped and every entry validated. The head of that list is the assignment a one-model request uses, and a route is recorded under that assignment with its thinking level stripped, so two levels of one model share one record.

## The Control Flow

One machine and one loop.

The route machine has four states. A route is untried before its first attempt, ready after a success, cooling until a stated moment with a reason and a strike count, or dead for the session. Its only events are an attempt that succeeded, an attempt that failed, and the clock. Cooling expires to untried, never to ready, because no evidence arrived in between. A dead route does not leave that state for the session.

| From | Event | To |
|---|---|---|
| untried | attempt succeeded | ready |
| ready | attempt succeeded | ready |
| any | transient failure | cooling: flaky |
| any | rate limit | cooling: rate |
| any | plan limit | cooling: quota |
| any | timeout | cooling: timeout |
| any | capability at model, provider or account | dead |
| any | capability at request | unchanged |
| any | unclassified failure | unchanged |
| cooling | clock reaches the stated moment | untried |

Selection answers with one of three things: attempt this entry, blocked until a stated moment for a stated reason, or unroutable because every entry is dead. The loop then either finishes or moves to the next entry, so the walk itself carries no state beyond the attempt it is on.

An invocation without `--run` prints the command it would have run and stops there. It records nothing, so its report is a prediction rather than a measurement, and the caller reads only the command.

An executed run walks the role's list. It attempts the selected entry, classifies what the attempt ended in, records that outcome, and advances only when the [outcome](terminology.md#outcome) says another entry can help. It stops on a `capability` outcome whose scope is the request or the account, on `timeout`, and on `unknown`.

A worker run adds the tree to that decision. It requires `--run` and refuses `--dir`, because a worker edits the repository root. It defaults `--base` to `HEAD` and `--run-dir` to a fresh temporary directory, captures a recovery point before the first attempt, measures the change set against the base before and after each attempt, and stops the walk when the tree changed, whatever the attempt's outcome. Two models over one change set is not a fallback, it is two workers in one unit.

A worker attempt is supervised. It ends early when its log carries a sentence the classifier reads as a refusal, because the CLI retries a refused request silently and stays alive on a subscription it never closes. It ends when its log has stopped growing below a small size, which is the same silent retry seen from outside. It ends at `DISPATCH_TIMEOUT`, default 1800 seconds, and `DISPATCH_STALL`, default 15, sets the silence window. A worker that exits zero with an empty log is a failure, because the log is the only evidence that it ran.

## Invariants

A failure never moves the next possible attempt earlier than the memory already holds.

A malformed request leaves the route record untouched, because the repair is the brief and not another model.

An unclassified failure leaves the route record untouched, because a guess about the route is worse than no record of it.

A dead route stays dead for the session, and a success clears the strike count.

The clock is the only way out of cooling. No dispatch attempt, and no other event, brings a cooling route forward.

## The Launch Sites

One entrypoint reaches a model on behalf of a caller. It prints the command it would run, runs one attempt and records it, or runs one read-write worker and reports its change set. It also answers three inspection questions: which assignments a role resolves to, what the route memory holds now, and whether the role's runtimes are present on this host.

A skill or a prompt carries the instruction that turns an intent into that invocation, and reads back what ran. A launch site may not carry its own resolver, restate the role table, or substitute a model the table does not name. Each of those existed beside this mechanism at one point, and each read as agreement with a table it had never seen. `scripts/check_launch_sites.sh` holds the rule instead of the reader: it fails a source file that names a launcher's own flags outside the library, the entrypoint and the reviewer's fixed run, so a call site added later cannot reopen the door it closes.

A fixed run is not a launch site. It pins one assignment because its contract fixes it, and it is reproducible precisely because no route decision is available to it.

## Failure and Its Vocabulary

A failure carries a class, a scope and, for a route that will be tried again, a reason. The class says whether another attempt can help. The scope says what would have to change first. The reason says how the wait is set.

| Class | Scope | What happened | What the run does next |
|---|---|---|---|
| `transient` | none | an overload, a reset, a bad gateway, or an attempt the supervisor ended while it printed nothing | the route cools for a growing backoff and the next entry is tried |
| `quota` | none | a rate limit | the route cools for a growing backoff, capped at fifteen minutes, and the next entry is tried |
| `quota` | account | a plan or daily limit, which lifts at a stated horizon | the route cools to the next UTC midnight and the next entry is tried |
| `timeout` | none | the attempt outlived its limit without an answer | the walk stops: a second attempt spends the same budget |
| `capability` | model | the model is disabled or unavailable to this account | the route is dead for the session and the next entry is tried |
| `capability` | provider | the provider is not configured or refuses this tier | the route is dead for the session and the next entry is tried |
| `capability` | account | the account is unfunded or unauthorised | the route is dead, and the walk stops: no other model repairs an account |
| `capability` | request | the request itself is malformed | the record is untouched and the walk stops, because every model receives the same request |
| `unknown` | none | no pattern matched the provider's sentence | the record is untouched and the walk stops; the caller reads the sentence |

A quota record states what happened, not what remains. It holds the moment the route may be tried again, the reason, the strike count, and the provider's own sentence. A count of metered attempts sits beside it in the same state. A remainder is not recorded, because two sessions spending one pool make any remainder a fiction.

The exit codes are part of the interface. Zero means an attempt ran, a command was printed, or an inspection question was answered. One means a refusal before any attempt: no git work tree, an unresolvable base, a pre-state that could not be captured, a role the table does not name, or a change set git could not compute. Two means a usage error. Three means blocked, and the message names the earliest wait. Four means unroutable, and the message names the dead routes. Any other code is the last attempt's own, so a caller reads the worker's failure without a translation layer.

A worker prints one line for each attempt it spent, so a caller reads every entry beside the one that worked.

## Where This Was Decided

The decision that one table is the source of a role's models, and that a second copy is a defect rather than a convenience, is recorded in the ADR `docs/adr/single_source_model_recommendations.md`.

The decision that a dispatch made from inside pi names a role, that one door resolves it, and that the shape is settled for that problem and re-decided when the problem grows, is recorded in the ADR `docs/adr/pi_subagent_dispatch.md`.

The reserved terms this document uses are defined once in [`terminology.md`](terminology.md), including the terms retired in favour of them.

The mechanism has four parts. `scripts/dispatch.sh` is the entrypoint and holds the loop. `src/libs/dispatch/table.ts` holds the role table's grammar and `launch.ts` beside it the argv shape of each runtime. `src/libs/dispatch_worker.sh` holds the git measurement and the process supervision. The route machine is `src/libs/dispatch/`, and its transition table and its invariants are data that the test suite holds itself to.
