# Env and Argument Resolution Layers

**Role:** Defines how configuration reaches a leaf script: which layer owns which environment source, how the resolved envelope travels, and what state the whole envelope holds at each boundary. The companion to [Context Resolution](context_resolution.md), which covers where code locates its dependencies; this document covers where values come from.

**Status of the system today:** the resolver and the ladder are shipped; the layering this document describes is the target, and the migration toward it is tracked by the census gate. Sections mark what is implemented and what is pending.

---

## The layers

```text
SOURCES                     ENTRY                    DERIVE                   LEAVES

explicit flags ---------+
AGENT_SANDBOX_* ---------+-->  agent-sandbox <sub> --> subcommand --> leaf script
.env at <path> ----------+     ONE ladder pass,      prelude: paths,     no reads,
                              ONE bulk load,         names, derived     no resolution,
make (folder-scoped) --------> validates, then       values; resolves   catastrophic
                              forwards the triple    nothing            guards only
                              as arguments
```

Two entrypoints reach the same dispatch. The global command resolves directly. Make is folder-scoped, so it owns exactly one fact the global command cannot know, the `.env` location for the folder, and it forwards that as an explicit `--env` path. Make resolves nothing else and includes nothing.

The container is a second instance of the same chain. Compose generates a new envelope for the container from the resolved host envelope, and the container's probes are leaves that presume their environment.

## The envelope states

The state is one status over the whole envelope, not a status per key. States do not multiply by layer, because a layer is a transition over the envelope, not a dimension of it.

```text
                    entry resolves
   +------------+ ------------------> +----------+ ------------------> +-----------+
   | unresolved |                     | resolved |   forward as args   | forwarded|
   +-----+------+                     +----------+                     +-----------+
         |                                                                |
         | guard fails: no source / path missing / key unresolvable        | consumed by leaf
         v                                                                v
   +---------------+   +---------------+   +------------------+
   | uninitialized |   | missing-path  |   | unresolvable-key |
   +-------+-------+   +---------------+   +------------------+
           | only legal continuation: onboard creates the source
           v
        (unresolved)
```

The three stop states do not merge, because their legal continuations differ: only `uninitialized` is left by `onboard` writing the source; the other two are left by correcting the invocation. Merging them would hide which of those two facts holds.

The container envelope is a second instance of the same six states. Its source is the compose-generated environment rather than the `.env`, and it starts fresh at `unresolved` in the container.

## Ownership map

Each environment source has exactly one owning layer. A key owned by an inner layer is never resolved by an outer one, and no leaf resolves anything.

| Source family | Owner | Consumers |
|---|---|---|
| identity triple (`PROJECT_NAME`, `PROJECT_DIR`, `SANDBOX_DIR`) | the entry, through the ladder | every subcommand |
| the whole-file load of the operator's remaining keys | the entry, one bulk load | subcommands and leaves as exported values |
| the `.env` path for a folder | make, when invoked through make | the entry |
| the `.env` path otherwise | the CWD fallback in the resolver | the entry |
| derived paths and names (image names, container names, session names) | the subcommand prelude | its leaf chain |
| the container environment | compose | the container's leaves |

## The prefix taxonomy

Four families of environment name exist today, and the model gives each one a layer.

| Family | Example | Layer rule |
|---|---|---|
| `AGENT_SANDBOX_*` | `AGENT_SANDBOX_PROJECT_DIR`, `AGENT_SANDBOX_REPO` | the harness's declared source level. It competes in the ladder and is never a marker for a value another layer already resolved |
| the bare envelope | `SANDBOX_DIR`, `SESSION_ID`, `PROVIDER_NAME`, the `DIR` family | unprefixed today by the 2026-09-30 ruling, reversed 2026-10-10: the harness's own variables take a harness-owned prefix, filed as a post-migration task under M3.4, and the prefix stays disjoint from the ladder's level |
| provider-owned | `PI_PROVIDER`, `PI_MODEL`, `PI_SESSION_ID`, `PI_REASONING_LEVEL` | the provider rolls its own; the harness passes it through and defines none of it |
| tool knobs | `DRY_RUN_IDENTITY`, `DOCKER_STUB_*`, `INSTALL_DIR`, `INSTALL_OS` | per-tool test and install controls; never part of the resolution ladder |

One finding from this taxonomy: `AGENT_SANDBOX_REPO` names the harness repository root and sits outside the identity triple, so "the triple plus the repo root" is the real declared set. The resolver treats it as a context variable (see [Context Resolution](context_resolution.md)) rather than an identity field.

## Path rules

Three rules, one of them measured.

**No path specified, the CWD fallback applies.** A global command invoked outside make resolves `<cwd>/.env`. This is the documented standalone path and it stays.

**A specified path fails fast when missing.** An explicit `--env` that names a nonexistent file is a hard error naming the path. It never falls through to another source and never silently resolves elsewhere. The current resolver falls through to the generic error, so this is a behavior change still pending.

**Make always passes the path explicitly.** The template derives the folder's `.env` path and passes it as `--env`, so the fallback never executes on the make path and a bad folder path fails at the make layer with its own error.

## Why forwarded values need no marker

The ladder's explicit level short-circuits with no file read. Measured on 2026-10-10: with all three identity values explicit, `env_resolve_identity` returned the flag values and emitted zero warnings from a fixture file that prints a warning whenever `env_load` parses it. A forwarded argument therefore satisfies the next layer with no parse, which is why the envelope travels as arguments and needs no resolved-marker namespace.

## References

- [`docs/adr/env_resolution.md`](../adr/env_resolution.md) -- the decision record, including the 2026-10-10 entry for this layering
- [`src/libs/env_resolve.sh`](../../src/libs/env_resolve.sh) -- the ladder
- `tests/test_env_read_discipline.sh` -- the census gate pinning every `.env` read site
- [`devlog/discussions/20261010-design-draft-onion_env_resolution.md`](../../devlog/discussions/20261010-design-draft-onion_env_resolution.md) -- the exploration that settled the shape
