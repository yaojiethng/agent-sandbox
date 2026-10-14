# Onion-style env resolution with envelope-level state

**Status:** settled

The decision, the layer diagram and the prefix taxonomy are recorded in [`docs/adr/env_resolution.md`](../../docs/adr/env_resolution.md) (2026-10-10 entry) and [`docs/concepts/env_resolution_layers.md`](../../docs/concepts/env_resolution_layers.md). This document keeps the exploration that settled the shape.

## Context

The operator set the architecture for environment and argument resolution during the 2026-10-10 session. The leaf scripts assume their configuration arrives fully formed, with no error checking beyond catastrophic-failure guards. Make and agent-sandbox are two entrypoints into one leaf-dispatch system with different semantics: make is folder-scoped and may inject defaults that follow from the folder, such as the location of the `.env`; agent-sandbox is the global command. All resolution, parsing and validation belong above the leaves.

This design explores how that layering is pinned, after the session established three facts. The census gate (`tests/test_env_read_discipline.sh`) pins every site that parses a `.env`: 12 sites across 8 files, with one `make start` chain parsing the file at least seven times. The prelude in `src/libs/session_env.sh` acts as a second entry, resolving the identity triple again after `scripts/agent-sandbox.sh` already resolved it at the CLI. And the `AGENT_SANDBOX_*` environment level in the ladder (`src/libs/env_resolve.sh`) currently serves two roles, a declared source the operator may bake and an implicit marker, which is the ambiguity this design resolves.

## Options Considered

**Per-argument state tagging.** Each configuration key carries its own resolution status. Rejected: the state multiplies by the key count, a caller must know which layer owns which key to read the status, and the invariant that matters is a property of the envelope, not of any single value.

**Single-entry resolution with one load.** All parsing happens at the CLI entry and everything forwards as arguments. Rejected as the whole answer: it leaves the derived-configuration boundary undefined, so a layer that derives values (paths, container names) has no stated contract, and it forces the container's compose layer to re-enter through the CLI shape.

**Onion layers with envelope-level state.** Each layer presumes the envelope it receives is resolved, resolves the keys its own contract owns, derives nothing from lower sources, and passes a clean envelope inward. Chosen: it makes the boundary the unit of correctness, it matches the ladder that already exists, and the state is one status over the whole envelope.

## Decision

**The envelope, not the argument, carries the state.** The configuration state of a chain is one status over the whole envelope, checked at layer boundaries:

- `uninitialized`: no source answers. Only `onboard` is legal, because it is the command that creates the source.
- `unresolved`: the source exists but no layer has resolved it.
- `partial`: some keys resolved, some not. No layer may forward this state.
- `resolved`: every key the layer's contract needs is resolved.
- `forwarded`: the envelope crossed a boundary as arguments. It is immutable inward.
- `failed`: a hard stop with one error text.

**The ladder's flag level is the forwarding mechanism, and this is measured, not assumed.** With all three identity values explicit, `env_resolve_identity` returns the flag value and emits zero warnings from a fixture file that prints a warning whenever `env_load` parses it. A forwarded value therefore short-circuits the ladder with no file read. The mechanism the whole model needs already exists in `src/libs/env_resolve.sh`.

**Layer ownership is disjoint, and the ownership map is part of the contract.** The entry layer (`agent-sandbox`) owns the identity triple and the whole-file load of the operator's remaining keys. Make owns the folder-scoped default for the `.env` location and shape translation only, and resolves nothing. The subcommand layer owns derived configuration (paths, session names) and resolves nothing. The leaf owns nothing and reads nothing. Each key has exactly one owning layer.

**The `AGENT_SANDBOX_*` level plays one role, not two.** It is a declared source an operator may bake, and it is never a marker for a value another layer already resolved, because the envelope travels as arguments and the flag level is its marker. This resolves the ambiguity directly.

**Onboard is a state carveout, not an exception.** It is the only command legal in the uninitialized state and the only writer of the source. `--refresh` keeps its write authority in the initialized state. Every other command is read-only over the source in every state.

**Value constants move to the entry; name constants stay where they are.** Filenames and record keys are format contracts shared by a reader and a writer. Defaults and fallbacks are undeclared configuration and are removed from the libs to the owning layer.

## Consequences

The census shrinks in a fixed order, each step a census amendment: the prelude stops resolving, the make template stops including the `.env`, the resume enrichment site disappears, and the probes' bootstrap fallback is deleted in favour of a loud failure. The chain's parse count becomes one in the direct path and one in the make path, measured by the census gate rather than estimated.

Two consequences are accepted deliberately. A caller outside both entry shapes, invoking a subcommand directly, must satisfy the layer contract itself, and that is a documented caller obligation rather than a supported path. And the container boundary inherits the model unchanged: compose is that chain's entry, and the probes become leaves that presume their environment.

Open branches the operator owns are recorded in the roadmap rows this design writes back: whether the CLI's CWD fallback for the `.env` path survives alongside make's folder-scoped default, and whether any baked level outranks the file in a deployed chain.
