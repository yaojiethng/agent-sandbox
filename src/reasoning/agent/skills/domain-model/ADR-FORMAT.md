# ADR Format

ADRs live in `docs/adr/` and follow the project's living format defined in
`docs/operations/adr_policy.md`. Read that policy before writing or editing
an ADR; this file is a working summary, not the authority.

An ADR records the *why* behind one standing principle — a pattern, interface
shape, design philosophy, invariant, or interaction contract — including the
rejected alternatives and their reasons. Local design choices ride under an
existing ADR; they do not each spawn a file.

## Unit and naming

One file per standing principle, named for the principle it governs —
`docs/adr/<principle>[-<scope>].md`, no dates or status in the name. The
agent recommends names; the operator decides them.

## Structure

```
# <Principle>

**Current:** YYYY-MM-DD

## YYYY-MM-DD -- <decision name>

**Decision:** <chosen option>
**Rationale:** <why>
**Rejected alternatives:** <each alternative and its rejection reason>
**Edge cases / drivers:** <boundary conditions that shaped the choice>

## <prev date> -- <prior decision name>
... (historical, condensed)
**Reason superseded by <new date>:** <why the old pattern was rejected>
```

The newest entry is at the top; the entry marked `Current:` is the live
decision. When the principle changes, append-and-demote: demote the current
entry to historical, condense it (keep the decision and its reason), and add
an explicit why-rejected line.

## When to offer an ADR

Spawn an ADR when a design settles a principle whose consequences reach
beyond the change that introduced it — a contract other components must match,
or a rule that stabilizes a convention for future work. Reach, not size. A
choice affecting one implementation detail in one file does not spawn an ADR.

What qualifies:

- **Architectural shape.** "We're using a monorepo." "The write model is
  event-sourced."
- **Integration patterns between contexts.** "Ordering and Billing
  communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth
  provider, deployment target — not every library.
- **Boundary and scope decisions.** The explicit no-s are as valuable as the
  yes-s.
- **Deliberate deviations from the obvious path.** Anything a reasonable
  reader would assume the opposite of. These stop the next engineer from
  "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of
  compliance requirements."
- **Rejected alternatives when the rejection is non-obvious.** Otherwise
  someone will suggest GraphQL again in six months.

If a decision is easy to reverse, skip it. If it's not surprising, nobody
will wonder why. If there was no real alternative, there is nothing to
record beyond "we did the obvious thing."
