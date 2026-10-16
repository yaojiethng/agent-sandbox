# Who owns dispatch logic

**Status:** active

## Context

M3.6.1 landed the runner seam as a stopgap: `src/libs/dispatch.sh` resolves a role to a `(provider, model)` pair, chooses the pi or OpenCode backend, and prints a command; `scripts/dispatch.sh` is its front door. The seam has one live consumer, the `opencode-dispatch` skill, and the front door has no live caller.

M3.6.3 assumes the seam becomes the general dispatch path. Two of its items rest on that assumption:

- The launch-site sweep and its conformance test assume every launch site migrates onto the generalized front door.
- The dispatch-rule surface assumes the role-to-model table is the data unit, so a model move is a data edit and not a code change.

The question this record holds: what owns dispatch logic, and how does a workflow call it?

## Options Considered

The system already carries three dispatch layers, each with a distinct return:

| Layer | Owns | Returns | Exists as |
|---|---|---|---|
| Construction and routing | role to `(provider, model)` to backend to a command string | a command | the seam and its front door |
| Contract and preconditions | read-only or read-write, clean tree, brief rules, logging, read-back | a logged work product | the dispatch skills |
| Isolation and lifecycle | a worktree per worker, a branch, break points, verification, write-back | a verified file set | the `taskq_*` tools |

The options are therefore layers rather than alternatives.

1. **A generalized front door.** A workflow calls `scripts/dispatch.sh` and places the returned command. One flag mapping and one role table serve every caller; each caller executes and verifies for itself.
2. **Per-runtime skill invocation.** Each dispatch skill crafts its own invocation, the `pi-reviewer-dispatch` pattern. This is the right form for a specialized task whose effectiveness depends on a pinned reviewer; for a general worker role it makes a model move between runtimes a code change and drops the role table.
3. **A skill as the interface.** A skill owns construction and contract together. Fewer moving parts; the seam and the skill overlap.
4. **A `taskq`-shaped utility.** Dispatch becomes a harness tool that owns isolation and lifecycle. The strongest isolation; it duplicates or subsumes the seam and the skills.

## Decision

Provisional lean, subject to the M3.6.3 investigation: keep the seam as the builder, let a skill own the contract where the contract is non-trivial, and let `taskq` own isolation when a workflow needs it. A workflow addresses the layer whose return it needs: a command from the seam, a logged work product from a skill, a verified file set from `taskq`. Avoid a fourth mechanism that builds, executes and isolates, because that is where the three overlap. A specialized dispatch whose effectiveness depends on a pinned model keeps its own pin and does not route through the role table; the seam serves the general worker roles.

## Consequences

The lean keeps the role table runtime-agnostic and holds the two M3.6.3 assumptions. It leaves the front door without a live caller until the launch-site sweep gives it one.

If per-runtime skills win, the launch-site sweep's target changes and the dispatch-rule surface's data unit becomes per-skill.

If a `taskq`-shaped utility wins, the seam and the dispatch skills are candidates for retirement.

Either way, this decision is sequenced before the launch-site sweep and the dispatch-rule surface.
