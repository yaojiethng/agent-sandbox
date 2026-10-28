# The review loop

A run to convergence: a fresh reviewer per round, a verdict per round, one fix round per blocker. The reviewer is read-only, and `dispatch` owns the invocation.

## The rules

- **Name the range.** Name the base commit and the explicit range, `git diff <base>..<head>`. If the operator specifies the review scope in another format, convert it to a range.
- **Name the copies.** When the edit target has a seeded copy and a runtime copy, name both by full path and state which is authoritative.
- **Check in at the operator's cadence.** Confirm a check-in cadence with the operator before starting. At each check-in, send the round count, cumulative cost (tokens and dollars), open blockers with the round that raised each, and the trend. The operator decides from that message alone.
- **End each round on a verdict.** `ACCEPT` stops the loop. `BLOCK` names its blockers, and each is closed by a change the next round can see, not by argument.
