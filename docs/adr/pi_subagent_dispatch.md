# Pi Subagent Dispatch

**Current:** 2026-10-23

## 2026-10-23 -- One door decides the runtime, and the shape is scoped to the problem

**Decision:** A dispatch initiated from inside pi names a [role](../reference/terminology.md#role) and never a model. One [launch site](../reference/terminology.md#launch-site) resolves the role to an ordered preference list of [assignments](../reference/terminology.md#assignment), each carrying its [provider](../reference/terminology.md#provider), its model, its thinking level and its [runtime](../reference/terminology.md#runtime); the site prints the command or runs it, the runtime follows the assignment, a route that fails advances to the next entry, and the route memory is session-scoped. The door has two faces over one library: a shell caller reaches it through the bash entrypoint, and a caller running inside pi reaches the same library through codemode, without a process boundary between the caller and the decision. The shape is settled for that problem and not for dispatch in general: a scope change re-decides this record rather than extending it.

**Rationale:** The problem has two properties, and each rules out a simpler shape. The cheapest pool is unreachable from the caller, so one brief must be runnable by two executables: the free tier answers `403 FreeTierError` to pi's own clients, and only the OpenCode CLI reaches it. And the preference across those executables is the operator's, moving as a quota or a price moves, so it is data rather than a decision every caller re-takes. A caller that names a model restates that data: before the sweep, the worker skill carried its own default model, a role's value never reached that path, and the invocation alone did not say which model ran, while twenty-one files carried an inline `pi --provider` invocation. One door is what keeps the [role table](../reference/terminology.md#role-table) single-sourced, and `scripts/check_launch_sites.sh` holds the door mechanically rather than leaving it to a reader. The mechanism the door carries is stated in [`dispatch.md`](../reference/dispatch.md), and this record does not restate it.

**Rejected alternatives:**

### A per-runtime skill crafts its own invocation

Rejected on intent. A skill that builds its own invocation holds the runtime rule and a copy of the table's data, so a model move becomes a code change in every skill, and the caller's choice of skill decides the runtime before the table is read. The tree carries no such skill today: the reviewer's runner was the last one, and it retired into the seat path.

### A skill owns construction and contract together

Rejected on execution. The overlap has a measured cost: the worker skill carried a default model that shadowed the table, and a reader could not tell from the invocation which model had run. Construction and contract are two returns, and one file owning both hides which of them a given line comes from.

### A taskq-shaped utility owns build, execution and isolation

Rejected on intent. Isolation is one caller's need, not the problem's shape: a worktree, a branch and a break point cost what a one-brief dispatch does not need, and a utility that also serves a caller working in its own tree must add a mode that runs there, which re-derives the door. A caller that needs a verified file set composes the task queue with the door; the door does not absorb it.

**Edge cases / drivers:**

- The free tier is a shared daily quota that resets at UTC midnight, so an exhausted route is the normal path and the advance is not an error path.
- A run that pins its assignment resolves nothing, which is what makes it reproducible; its behaviour is not evidence of how dispatch routes.
- Route state is session-scoped and lost with the container, so a later session learns a route's outcome rather than trusting a remainder.
- Four scope changes re-decide this record: a third runtime becomes a dispatch target; a dispatch needs a worktree or a branch per attempt, which the task queue owns today and which a scheduler subsumes rather than this mechanism; a caller that is not an agent running in pi becomes a first-class caller rather than reusing the same question; and selection optimises cost per attempt instead of following the written order.
