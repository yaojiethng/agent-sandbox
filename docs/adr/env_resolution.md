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
