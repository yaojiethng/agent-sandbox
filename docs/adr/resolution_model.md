# Resolution Model

**Current:** 2026-10-16

> This ADR records the design as it stands and is expected to evolve. The identity-resolution surface is new and touches many entrypoints; a later change supersedes the current entry by adding a dated entry, per the ADR policy. It is not a locked contract.

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Single resolution path | The identity triple resolves through one module, not per-script parsing |
| R2 | Explicit wins | A CLI flag beats an environment variable and the `.env` file |
| R3 | No silent default | An unresolvable identity fails loudly pointing at `onboard`, never a computed guess |
| R4 | Leak-guarded env level | Only `AGENT_SANDBOX_*` keys are the environment level; a plain sourced export cannot bypass `.env` |
| R5 | Deterministic `.env` location | `.env` is found by a fixed precedence, robust to how make was invoked |
| R6 | Three carrier classes | an input is an argument, a configuration value or session state, and the class decides whether it persists and where (promoted by the 2026-10-16 entry) |

## 2026-10-16 -- The resolution model: three carrier classes, one precedence primitive

**Decision:** A harness input arrives by one of three carrier classes, and the class decides whether it persists and where.

| Class | Meaning | Persisted |
|---|---|---|
| Argument | input to one command invocation, per command run | never |
| Configuration | input describing harness behaviour, held consistent across runs | the sandbox `.env` |
| State | what one session recorded about itself, replayed on resume | the session record (`.compose/<sid>.yml`, `.git/SESSION_STATE`) |

One precedence primitive carries the configuration ladder. `env_resolve_one` resolves a configuration setting in priority order: the explicit value, then `AGENT_SANDBOX_<KEY>`, then the `.env` key, then a stated default. Every plane that reads a configuration setting resolves through it. An argument is the explicit level of one command's own parse, and it never resolves from `.env` or from a session record. State is read from the session record, ahead of a stated default, and is never a configuration source.

The `.env` location contract and the `make -C` contract carry over unchanged from the `2026-09-18` entry.

**Rationale:** Measured, not assumed. The census of 2026-10-16 read every value-entry and value-read site in `src/` and `scripts/`: 14 parser call sites, 34 `export` lines, three lines that read an `AGENT_SANDBOX_*` key as a resolution level, and five readers of `init_sha` implementing four different baseline rules. It found 49 of the 54 `AGENT_SANDBOX_*` occurrences to be `AGENT_SANDBOX_REPO`, which is not an identity key. It found the resume path replaying the delivery mode, the history mode and the provider from the session record.

The three classes name what the carriers do, so a setting's class decides its persistence without a per-setting judgement. This retires the four-level-versus-five-level question: the laddered settings are configuration, and the record a 2026-09-24 design note proposed as a fifth level is session state, a different mechanism with a different lifetime.

**Rejected alternatives:**

- *A five-level ladder with a session-record level* -- rejected: the record holds per-session state whose source is the session guarantee plane, not the configuration surface. A ladder that takes one file path cannot hold a per-project `.env` and a per-session record at once.
- *Reading a command argument from `.env`* -- rejected: an argument is per-command input, so a `FLATTEN` read from `.env` would let a stale project file decide one run's history mode.
- *Letting a leaf resolve a setting* -- rejected: the leaf contract is catastrophic guards only, so every resolution stays above the leaves.
- *Per-argument resolution status* -- rejected: the state is a property of the envelope, not of each key, so a per-key status multiplies by the key count.

**Edge cases / drivers:** `AGENT_SANDBOX_REPO` is a fourth `AGENT_SANDBOX_*` key, outside the identity triple, read from the ambient environment with a `$0`-derived fallback. The census found one place where the code and the ladder disagree and it is filed as a defect, not decided here: `start_agent.sh` derives `SANDBOX_DIR` at runtime, which the demoted entry rejected. The census also found `env_load` overwrites the ambient environment unconditionally, so every non-identity `.env` key beats its ambient value while only the identity triple is re-asserted; that is filed as a defect too.

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

**Edge cases / drivers:** The P4 precedence pins and the study's thermo-nuclear finding (c) established the file-beats-flag baseline that the S2 flip removed. The identity flags stay accepted (backward compatible); removing them is future work, layered onto this ADR. Full primitive and consumption detail: [sandbox_identity.md](../reference/sandbox_identity.md).

**Reason superseded by 2026-10-16:** the ladder and the `.env` location contract carry over unchanged. What changed is the model around them: this entry stated the triple's ladder without naming the carriers, so it could not say why a session-record value is not a level.
