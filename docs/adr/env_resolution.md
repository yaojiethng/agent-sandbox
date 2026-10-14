# Env Resolution

**Current:** 2026-09-18

> This ADR records the design as it stands and is expected to evolve. The
> identity-resolution surface is new and touches many entrypoints; a later
> change supersedes the current entry by adding a dated entry, per the ADR
> policy. It is not a locked contract.

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Single resolution path | The identity triple resolves through one module, not per-script parsing |
| R2 | Explicit wins | A CLI flag beats an environment variable and the `.env` file |
| R3 | No silent default | An unresolvable identity fails loudly pointing at `onboard`, never a computed guess |
| R4 | Leak-guarded env level | Only `AGENT_SANDBOX_*` keys are the environment level; a plain sourced export cannot bypass `.env` |
| R5 | Deterministic `.env` location | `.env` is found by a fixed precedence, robust to how make was invoked |

## 2026-10-10 -- Onion env resolution layers with envelope-level state

**Decision:** Configuration reaches a leaf through ordered layers, and each layer resolves only what its own contract owns, then passes a clean envelope inward as arguments. The state of the whole envelope, not of any individual key, is the unit of correctness: `unresolved` at the start, `resolved` when every key the layer's contract needs is present, `forwarded` once it crosses a boundary as arguments, and three stop states named `uninitialized`, `missing-path` and `unresolvable-key`. The entry (`agent-sandbox`) owns the identity triple through the ladder and the one whole-file load of the operator's remaining keys. Make is a folder-scoped entry that injects the `.env` path and the command shape, and resolves nothing else; it always passes the path explicitly, so the fallback never executes on that path. Three path rules hold: an unspecified path uses the CWD fallback; a specified path that does not exist is a hard error naming the path and never resolves elsewhere; the fallback is the documented standalone path, not a repair for a bad explicit one. The `AGENT_SANDBOX_*` level is a declared source and never a marker for a value another layer already resolved, because forwarding uses the ladder's explicit level, which short-circuits with no file read. Full layering, the envelope diagram and the prefix taxonomy live in [`concepts/env_resolution_layers.md`](../concepts/env_resolution_layers.md).

**Rationale:** Measured, not assumed. One `make start` chain parsed the `.env` at least seven times before this direction (census gate, 2026-10-10), and the flag level resolves with zero file reads when values are explicit, verified by a fixture file that warns on every parse and stays silent. Per-argument statuses were rejected because they multiply by key count and force callers to know ownership just to read status; the envelope status makes the boundary the unit of correctness and the ownership map the thing a gate can check.

**Rejected alternatives:** Per-argument state tagging, rejected above. A single-entry design where all resolution happens at the CLI and everything forwards, rejected because it leaves the derive boundary undefined, so a layer that derives paths and names has no stated contract. A resolved-marker namespace for forwarded values, rejected because the explicit level of the ladder is already that marker and a measurement proves it short-circuits, so a namespace would add a second mechanism for one fact.

**Edge cases / drivers:** The three stop states do not merge because their legal continuations differ: only `uninitialized` is left by `onboard` writing the source, while the other two are left by correcting the invocation. `onboard` is the sole writer of the source and the only command legal in `uninitialized`; `--refresh` keeps its write authority in the initialized state, and every other command is read-only over the source in every state. `AGENT_SANDBOX_REPO` is a fourth declared key outside the identity triple, a context variable rather than an identity field. The container envelope is a second instance of the same states whose source is the compose-generated environment, which makes compose the entry for that chain and the probes its leaves. The harness's own envelope keys carry a harness-owned prefix, reversing the 2026-09-30 no-prefix ruling at the operator's direction (2026-10-10); the prefix stays disjoint from the `AGENT_SANDBOX_*` ladder level so a resolved value can never re-enter the ladder under the resolver's own name, and the rename task is sequenced after the leaf migration because that migration collapses its blast radius to the entry, the compose layer and the tests.

## 2026-09-18 -- Centralized resolver: flag-wins precedence + deterministic `.env` location

**Decision:** The sandbox identity triple (`PROJECT_NAME`, `PROJECT_DIR`, `SANDBOX_DIR`) resolves per identifier in priority order:

1. explicit CLI flag
2. `AGENT_SANDBOX_<KEY>` host environment variable
3. the per-sandbox `.env` file
4. a hard error (no runtime default), pointing at `agent-sandbox onboard`

`env_resolve_identity` in `src/libs/env_resolve.sh` is the single resolution path. `session_env_common_init` (used by start and resume) resolves through it and re-asserts the identity after loading `.env`, so a conflicting `.env` value cannot shadow explicit input. Every command keeps a hard identity requirement; the resolver lets `.env` or the env level satisfy it instead of forcing the flags.

`.env` location resolves in priority order:

1. an explicit `--env` path
2. a known sandbox dir -> `<sandbox>/.env`
3. the invocation CWD -> `./.env`

`--env` is an absolute path or a name relative to the sandbox dir, honored by both identity resolution and the run's env load: the dispatcher forwards it to `start`/`dry-run`, so a custom `.env`'s runtime values (provider vars, `SERVE_PORT`, `WORKTREE_DIR`) reach the run. Its absence falls back to `<sandbox>/.env`. A single meaning holds across the resolver and the leaf so a relative `--env` cannot silently load a different file.

`onboard` writes `.env` next to the generated Makefile. Under the `make -C` contract, `$(CURDIR)` is the sandbox directory that holds both the Makefile and the `.env`, so the Makefile computes its pointer in one line without case logic and passes it per target, dropping `--name`/`--project`/`--sandbox`. `$(CURDIR)` is portable to GNU and BSD make:

```make
ENV_FILE := $(CURDIR)/.env
```

`make -f <abs>/Makefile` from another CWD is out of contract (the dispatcher's sandbox/CWD fallbacks still apply to it). The `SANDBOX_DIR` `PROJECT_DIR-sandbox` default is written once at onboard into `.env`; it is never resolved at runtime.

**Rationale:** pi's thin-interface / deep-resolution model maps cleanly onto the three identity siblings, which were fragmented across two persistence mechanisms (the baked Makefile literal and `.env`) with duplicated per-script flag parsing. Prior behavior was file-beats-flag: a conflicting `.env` value silently overrode an explicit flag. Project identity is genuinely underivable, so a silent default hides misconfiguration. The explicit `--env` pointer makes `.env` location deterministic and independent of the invocation CWD, removing the fragility of relying on `make -C` alone.

**Rejected alternatives:**

- *File-beats-flag* -- a `.env` value overrode an explicit flag because `.env` was loaded last; the explicit input was silently lost. Superseded by flag-wins (R2).
- *Runtime `SANDBOX_DIR` derivation as a precedence level* -- resolving `dirname PROJECT_DIR/basename-sandbox` at each run reintroduces a computed default (R3). Applied once at onboard into `.env`, never at runtime.
- *Any host `PROJECT_*` var as the env level* -- a sourced plain `PROJECT_DIR` export would silently beat `.env`. Only `AGENT_SANDBOX_*` is the env level (R4).
- *CWD-only `.env` location (`make -C`) as the primary mechanism* -- fragile when make is invoked differently (`make -f`, a scripted call); demoted to the last-resort fallback (R5).
- *Project-root as a `.env` host* -- `onboard` writes `.env` only to the sandbox dir, so the project root cannot host it.

**Edge cases / drivers:** The P4 precedence pins and the study's thermo-nuclear finding (c) established the file-beats-flag baseline that the S2 flip removed. The identity flags stay accepted (backward compatible); removing them is future work, layered onto this ADR. Full primitive and consumption detail: [sandbox_identity.md](../concepts/sandbox_identity.md).
