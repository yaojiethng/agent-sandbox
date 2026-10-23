# Who owns dispatch logic

**Status:** settled

## Context

The problem is a dispatch made from inside pi, where the candidates are a pi subagent and an OpenCode CLI worker, and the cheapest pool of models answers `403 FreeTierError` to pi's own clients. Something has to decide which executable runs a given brief, and that decision is the operator's rather than the caller's.

M3.6.1 landed the runner seam as a stopgap: `src/libs/dispatch.sh` resolved a role to a `(provider, model)` pair, chose the pi or OpenCode backend, and printed a command; `scripts/dispatch.sh` was its front door. The seam had one live consumer, the `opencode-dispatch` skill, and the front door had no live caller. M3.6.3 assumed the seam would become the general dispatch path, and two of its rows rested on that assumption: the launch-site sweep, which assumes every launch site migrates onto the generalized front door, and the dispatch-rule surface, which assumes the role-to-model table is the data unit, so a model move is a data edit and not a code change.

Both rows then landed, and they answered the question with a mechanism rather than an argument. The seam is now `scripts/dispatch.sh` over `src/libs/dispatch/` and `src/libs/dispatch_worker.sh`; a role resolves to an ordered list of assignments; the runtime follows the assignment; the front door has three callers and one allowlisted fixed run; and `scripts/check_launch_sites.sh` fails a launch site that carries its own resolver. What remained was to state the principle the tree now embodies, and the boundary of the problem it is fit for.

## Options Considered

The system carries three dispatch layers, each with a distinct return:

| Layer | Owns | Returns | Exists as |
|---|---|---|---|
| Construction and routing | role to assignment to runtime to a command string | a command, one recorded attempt, or one worker's change set | the entrypoint and its library |
| Contract and preconditions | read-only or read-write, clean tree, brief rules, logging, read-back | a logged work product | the dispatch skills |
| Isolation and lifecycle | a worktree per worker, a branch, break points, verification, write-back | a verified file set | the `taskq_*` tools |

The options were therefore layers rather than alternatives.

1. **A generalized front door.** A workflow calls `scripts/dispatch.sh` and places the returned command. One flag mapping and one role table serve every caller; each caller executes and verifies for itself.
2. **Per-runtime skill invocation.** Each dispatch skill crafts its own invocation, the `pi-reviewer-dispatch` pattern.
3. **A skill as the interface.** A skill owns construction and contract together.
4. **A `taskq`-shaped utility.** Dispatch becomes a harness tool that owns isolation and lifecycle.

## Decision

Chosen: the generalized front door, with the contract in a skill and isolation in the queue. A caller addresses the layer whose return it needs, and no fourth mechanism builds, executes and isolates together.

The shape is settled for the problem above and not for dispatch in general. A scope change re-decides the principle rather than extending it: a third runtime as a dispatch target, a dispatch that needs a worktree per attempt, a caller that is not an agent running in pi becoming a first-class caller, and selection that optimises cost per attempt instead of following the written order.

The authority is [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md), which states the principle, its rationale, the three rejected alternatives with their failure loci, and those four scope changes. This record stays the exploration record and does not restate the decision.

## Consequences

The role table stays runtime-agnostic, the door has its three callers, and a model move is a data edit on every path. The runtime follows the assignment rather than the provider's name, so a provider serves whichever executable the model requires.

The fixed run keeps its pin and sits outside the door: `review-dispatch.sh` resolves nothing, so it stays reproducible, and its behaviour is not evidence of how dispatch routes.

The contract layer holds no model of its own. The worker skill stated a default model until handover `20261023-22`, which was the shadow the dispatch-rule surface row owns; it now names a role and no model, and the shape test holds it there.

A scope increase re-opens this record. The rejected options are not foreclosed by it: a third runtime changes the runtime rule and the argv builder, and a caller that needs isolation composes the queue rather than replacing the door.
