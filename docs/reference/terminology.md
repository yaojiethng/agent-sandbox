---
reader: [agent, operator]
---

# Terminology

> Registry of reserved technical terms. Add new terms under their own header; keep each term's identity, scope, and relationships together under it.

## Usage

These are reserved technical terms: use them with exactly the meanings defined below, and do not use either as a bare noun or loose synonym in prose or code. Historical records and past handovers are not retro-renamed. Deprecated tokens are noted in the relevant term's entry.

## session

One container lifecycle, from container start to teardown. The harness unit of execution. Has a resume path and a persisted state file.

### Identity

- `SESSION_ID` (formerly `RUN_ID`, deprecated)
- `SESSION_TS`, `SESSION_STATE`

### Scope

Session-scoped resources: the container lifecycle, the compose project, the named volume, the session-diffs channel.

### Relationships

- A session may contain zero or more [iterations](#iteration).

**Last updated:** 2026-08-19

## iteration

One work cycle that produces a handover and a commit. The operator unit of governance. Targets one sub-milestone step; recorded in `devlog/handovers/`.

### Identity

- Handover `YYYYMMDD-NN`; governed by `iteration_protocol.md`

### Scope

Iteration-scoped resources: a draft branch, a diff bundle.

### Relationships

- An iteration is hosted within exactly one [session](#session).
- The `iter` prompt (formerly `new-iteration`, formerly `new-session`) opens an iteration.

**Last updated:** 2026-08-19

## staleness

A session's or image's divergence from the current project or build content, in one of two distinct dimensions:

- **sandbox staleness** -- the session's recorded `host-head-sha` differs from the current project `HEAD`. Means the git state the sandbox was built from is out of date (the repo has moved on). Computed over the `.compose` registry record (`host-head-sha` vs current `git rev-parse HEAD`).
- **image staleness** -- retired. The interim `agent-sandbox.container-sig`-based comparison (image content vs recomputed source signature) is removed (P3, 2026-09-19). Image identity is now the recorded image-ID digest (`agent-sandbox.agent-image-digest` / `agent-sandbox.sandbox-image-digest`); the container-boundary contract is the interface-contract version, ADR `docs/adr/interface_contract_compatibility.md`.

### Identity

- sandbox staleness: `agent-sandbox.host-head-sha` vs current `HEAD` (registry-truth).
- image staleness: retired (2026-09-19); image identity is the recorded digest.

### Scope

- Applies per session (sandbox staleness); image staleness is retired.
- Staleness is **surfaced** in `resume --list` and used as a **selection criterion** in `prune` (Rule 1); it is not a blocking resume gate.

### Relationships

- `session_stale` (`resume_agent.sh`/shared lib) computes sandbox staleness.
- Image staleness detection is a superseded principle: the settled direction retires list-time staleness in favour of recorded version identity -- see `docs/adr/drift_state_coherence.md` and `docs/adr/harness_versioning.md`. Until that implementation lands, the behaviour above is current.

**Last updated:** 2026-08-21

## role

The tag a brief is dispatched under: `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR_CODE`, `_ADVISOR_DOCS`, `_ORCHESTRATOR`. A brief names its role, and the role names what runs it.

### Identity

- These five tags; no other tag is dispatched. The advisor is two tags because its two review shapes ran on different models, which a conditional inside one role line could not express, so the condition became the role.
- Recorded as the tag that prefixes a line of the role table.

### Scope

A role is scoped to one brief and is resolved before a worker starts. A request names a role and a number of seats n. The role's line supplies the candidates: its entries filtered to those that can be attempted now, m of them. Seats fill by rotating through the candidates, so seat i takes candidate ((i - 1) mod m) + 1. A request with n at most m runs distinct models, and a request with n above m repeats them in written order. Seats fire in turns: a turn launches its seats concurrently and ends when its slowest attempt does, and every outcome is read at that boundary, so the candidate set has one writer per turn.

### Relationships

- Resolved from the [role table](#role-table) into a [role line](#role-line).
- Occupied by one or more seats. A seat is one occupant of a role in one run; it is not a synonym for the role, and it does not select its own assignment.
- Heterogeneity is a request for more than one distinct model from the same list, which the seat walk takes in written order. It is not a second list and not a second role.

**Last updated:** 2026-10-23

## role table

The one file that names a role's assignments: `.agents/model-recommendations.md`, committed to the repository.

### Identity

- Path: `.agents/model-recommendations.md`.
- A caller that must read another table names it in `DISPATCH_REC_FILE`.
- A file at `$AGENT_HOME/model-recommendations.md` is an installed copy of the same content, not a role table.

### Scope

One line per role. Each line holds a preference list: distinct assignments in preference order, separated by `;`, the first being the preferred one. A request that needs more than one distinct model takes them from the head of the list in that order. The table's own `Format:` line states that grammar, and it is the only place the grammar is stated.

### Relationships

- Read by the dispatch library to resolve a [role](#role).
- An edit changes routing with no code change, and a reordering is also an edit, because the order is the preference.
- Where the installed copy and the committed copy disagree, the committed copy is the table and the installed copy is stale.

**Last updated:** 2026-10-22

## role line

One line of the role table: a role tag, a colon, and that role's preference list.

### Identity

- `_ROLE: <assignment>; <assignment>`; the `;` separator and the written order are both meaningful.
- The `Format:` line of the role table states the grammar.

### Scope

One line per role. A role with no line is absent, which is a failure rather than a default.

### Relationships

- Holds a preference list of [assignments](#assignment).
- Its candidates are the entries that can be attempted now, in written order, m of them.
- A request for n seats fills seat i from candidate ((i - 1) mod m) + 1, so the first m seats are distinct models and seat m + 1 repeats the first.
- A seat whose attempt ends retryably retries its own assignment in the next turn.
- A seat whose attempt ends unretryably drops that candidate as unreachable and takes the candidate after it in the remaining rotation, wrapping to the first when the failed one was last, in the next turn.
- A request whose role has no candidate is refused, and the refusal names why.
- Truncating the list at its first entry discards the fallback rather than selecting the preference.

**Last updated:** 2026-10-23

## assignment

One entry of a role line: a model id, the runtime that serves it, and an optional thinking level.

### Identity

- `<provider>/<model>`, optionally followed by `at <level>`, so a whole entry reads `deepseek/deepseek-flash at high`.
- Deprecated tokens: **pair**, **triple**, **recommendation**.

### Scope

Enough to launch one worker: the model id selects the model, the provider derives the runtime, and the level is passed when the line carries one.

### Relationships

- One of the preference list on its [role line](#role-line).
- Distinct within its role line: two entries naming one model are one assignment, and the repeat is ignored.
- Its [runtime](#runtime) is derived from its [provider](#provider) and its model by one declared map, so the provider alone does not decide it.
- Its model id begins with a provider prefix. That prefix names a provider and never the runtime.

**Last updated:** 2026-10-23

## provider

The namespace a model id belongs to: the part before the first slash.

### Identity

- `deepseek`, `opencode`, `opencode-go`, `openrouter`.
- Deprecated as a name for the executable: **provider** in the sense of the `pi` or `opencode` program.

### Scope

A provider is served by one runtime, declared in one map. Nothing in the provider's name decides that map.

### Relationships

- `<provider>/<model>` composes a model id.
- `opencode` and `opencode-go` are provider prefixes; `opencode run` invokes the runtime of the same name.
- Served by one [runtime](#runtime), chosen from the map rather than inferred from the prefix.

**Last updated:** 2026-10-22

## runtime

The executable that runs a worker: `pi` or `opencode`.

### Identity

- `pi`, invoked with `-p`.
- `opencode`, invoked with `run`.
- Deprecated tokens: **backend**, and **provider** in the launcher sense.

### Scope

Chosen by the dispatch library from the assignment's provider and its model together: within the OpenCode provider set a model id ending `-free` runs on the CLI and every other model runs on pi, and an assignment with no model refuses rather than defaulting. No caller names a runtime, and no worker chooses one.

### Relationships

- Serves one or more [providers](#provider), per the declared map.
- Located at the [launch site](#launch-site) that resolves. A runtime that cannot be located is a failure to launch, not an assignment to another runtime.
- A runtime is not a model provider: `opencode` names both a runtime and a set of provider prefixes, and the two senses never share a field.

**Last updated:** 2026-10-23

## launch site

A place that starts a worker.

### Identity

- The entrypoint: `scripts/dispatch.sh`, which prints the command for a role or runs it with `--run`.
- The library it calls: `src/libs/dispatch/`, which resolves a role and derives the runtime.

### Scope

A site may resolve, launch, or both. Only the library resolves a [role](#role). A site that resolves is dispatching. A run that pins its assignment instead, for an invocation that must not move when the table changes, still goes through the door and resolves nothing: its input is its own contract, stated in one place. Its attempt is recorded, so it is evidence about the route and not about how resolution chooses.

### Relationships

- A site that launches calls the library for the assignment, so one role resolves one way everywhere.
- Resolution is the default, and a pin is the caller's override of it: a pinned run resolves nothing, so it says nothing about how the resolver chooses, while its recorded attempt still teaches the memory what the route did.
- A runtime-specific launcher beside the entrypoint is a duplicate of it, not a fourth kind of site.
- Not a **carrier**, which is a file that states dispatch behaviour in prose.
- Two sites that disagree about one step are drift, not two mechanisms.

**Last updated:** 2026-10-22

## outcome

What one attempt at an assignment ended in.

### Identity

- `success`, `transient`, `quota`, `capability`, `timeout`.
- `unknown`, reported with its denominator: per attempt, per request, or per distinct failure text.
- Deprecated tokens: **result**, **class**.

### The classes

Each class answers whether another attempt can succeed, and when. What must change first is the verdict's scope, a separate field, so the two never share one word.

| Class | Means | The signal | The caller |
|---|---|---|---|
| `success` | the worker ran and returned | exit 0 with output | stop, record |
| `transient` | the same request may succeed on the same model, now | connection reset, 5xx, overloaded, stream cut, an empty body under a 200 | advance; the horizon is seconds |
| `quota` | a rate or plan limit with a reset horizon | `429`, `Rate limit exceeded`, `FreeUsageLimitError`, `GoUsageLimitError`, `Insufficient account funds` | advance now, and cool the route until the horizon |
| `capability` | the model cannot do this task, whatever its health | `Model is unavailable`, `Model access is disabled`, `FreeTierError`, `can only be used from within`, `Provider is not configured`, `invalid_request_error`, `Failed to deserialize`, `Invalid API key` | advance only when the repair is another model or another provider; otherwise stop |
| `timeout` | the attempt exceeded its wall-clock budget without an answer | no exit inside the budget | stop and report; a second attempt costs the same budget |
| `unknown` | the text matched nothing declared | any refusal text outside the list | stop, and record the text with its denominator |

A caller advances to the next assignment when the class is `transient` or `quota`, or when the class is `capability` and its scope is the model or the provider. It stops for `success`, `timeout`, `unknown`, and for `capability` whose scope is the request or the account.

Three boundaries the classes turn on, each with a case behind it:

- A plan limit is `quota`, not `capability`, because it has a horizon and lifts. Only an expired key or an unknown user is an account fault that never lifts.
- `invalid_request_error` and `Failed to deserialize` are `capability` with scope `request`, and they stop. Another model receives the same request.
- `timeout` is ambiguous between a slow provider and a model too slow for the task, and no text separates them. The record carries the duration beside the class, and the class stops by default.

### Scope

One outcome per attempt. It decides whether the next entry of the preference list is tried.

### Relationships

- A retryable outcome, meaning `transient` or `quota`, yields to the next assignment; `capability` yields only when its scope is the model or the provider.
- The report the library returns on failure is a verdict, not an outcome: it names the role, the attempt, and the provider's own sentence.
- Recorded against the assignment it belongs to, not against the route alone.
- The share of `unknown` is the classifier's own health, so it is reported with the denominator it was counted over.

**Last updated:** 2026-10-22
