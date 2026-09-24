# Design: session identity and the sandbox command surface (M3 - T9)

## Context

A design review of the harness asked how complected the repository is. The review applied the uncomplect lens (Hickey's simple-versus-easy separation, Ousterhout's deep-module test, Young's deletability horizon, domain boundaries, and explicit lifecycle) to the tree as it stands. This document records the resulting findings and the operator direction that followed.

The review is a survey, not an implementation plan. It names what is braided, states what the deliverable would be, and leaves the decision open. The findings feed two roadmap rows under T9.

Scope of the survey: `src/libs/` (20 sourced files), `src/capability/`, `src/build/`, `scripts/` (8 `check_*.sh` gates), `tests/`, `docs/`, and `devlog/`. The survey did not read `scripts/check_*.sh` bodies or `workflow/knowledge-vault/` in full; the unknowns section records both.

## Verdict

More complicated locally, simpler overall.

The process machinery is the visible cost of one invariant: no output reaches the repository without human review. Most of the machinery is justified. One cluster is accidental: session identity and the session record. The record trail agrees with that reading. Six ADRs touch session identity - `session_identifier.md`, `container_host_correspondence_mechanism.md`, `archive/20260831-adr-settled-single_canonical_session_identity.md`, `sandbox_identity.md`, `archive/20260901-adr-settled-version_identity_mechanism.md`, and `drift_state_coherence.md`.

## Complection map

| Concern | Braided together | Independent values | Separation move |
|---|---|---|---|
| Session identity (`src/libs/session_env.sh`, `src/libs/draft_state.sh`) | Where a session is: run arguments, the `AGENT_SANDBOX_*` environment, the sandbox `.env`, `.git/SESSION_STATE`, `.compose/<id>.yml`, and directory names. `draft_parse_folder_name` recovers the start time by substring parse (`SESSION_TS="${BASENAME:0:15}"`) | The session id, its start time, its host branch | One versioned session record. The environment and the directory names become projections of it |
| Delivery mode (`src/build/docker-compose.copy.yml`, `src/build/docker-compose.mount.yml`, `session_state_write_set`) | The transport with the seed. The copy overlay comment states that the two modes differ only in the `init_sha` source, and that each overlay must not inherit the other's wiring | The transport, the init commit | Factor `init_sha` resolution into the seed command. The overlays carry transport wiring only |
| Container contract (`src/libs/session_state.sh` `container_contract_check`, `scripts/check_lib_contract.sh`) | The image bake version with the version recorded in the sandbox | The contract version | Already separated by the minimisation decision in `drift_state_coherence.md`. The surviving narrow check is correct |
| Host-side prelude (`src/libs/session_env.sh`) | Precedence policy (explicit flag wins over `AGENT_SANDBOX_*`, which wins over `.env`) with the mechanism that exports the derived values into compose | The identity, the derived values | Extract the precedence rule as a pure decision function. The prelude keeps the derivation |
| Test meta-layer (8 `scripts/check_*.sh`, `tests/knowledge`) | The quality gate with the checks that verify the gate itself. `check_lib_liveness.sh` and `check_test_liveness.sh` both answer reachability, one from the library side and one from the test side | Coverage, contract | Keep one liveness gate. Keep `check_lib_contract.sh` as the single contract gate |
| Diff destinations (`src/libs/routing.sh`, `src/libs/resume_list.sh`) | Per-commit exports under `session-diffs/session/` with a single overwritten checkpoint under `session-diffs/autosave/`, plus the fallback ordering rule in resume | The exported diffs | One record-keyed diff tree. Autosave becomes the latest-revision projection |
| Workflow state (`devlog/`, 504 files) | The agent's process state expressed as Markdown, read and written every iteration | The milestone facts, the process | Keep. The braid is deliberate and the operator reviews it |

Six rows reduce to one fact: truth about a session has no single home.

## Record question

The container boundary is guarded. The session-record schema is not. `drift_state_coherence.md` calls the pair `.compose/<id>.yml` and `.git/SESSION_STATE` a resume-breaking contract written by host and read by container. `container_contract_check` guards the container boundary with `interface_contract_version`. No version names the record pair as a unit, so a format change to either half breaks resume at run time with no detection. This is the defect the drift decision removed for image identity.

## Command surface direction

The operator raised a second complection: the per-sandbox Makefile and the `SANDBOX_DIR` argument.

Today an operator reaches the harness in two idioms. The repo `Makefile` covers install, onboard, and test. The per-sandbox `Makefile`, generated from `scripts/templates/Makefile.template`, covers the run and lifecycle targets, and the operator calls it as `make -C <sandbox-dir> <target>`. The T4 make-evaluation row records the cost: make acts as a directory-based script wrapper, it parses arguments in its own idiom (`PROVIDER=pi` against `--provider=pi`), and it carries a second help and error surface that must match the CLI.

The direction under exploration:

- Remove the generated per-sandbox Makefile and call `agent-sandbox` directly.
- Give the CLI a registry. `onboard` writes a record. Each later command resolves its sandbox directory and its per-sandbox defaults from that record, so the operator stops re-passing `--sandbox`, `--project`, and `--name`.
- Decide whether `SANDBOX_DIR` stays an explicit flag or becomes registry-only.

The registry answers the argument-passthrough complaint and removes one help and error surface. It also moves risk: the registry becomes durable state that the harness must keep coherent with the filesystem, and a stale record must fail loudly instead of resolving to a moved or deleted sandbox.

## Options considered

### Command surface

| Option | Trade-offs |
|---|---|
| Keep the per-sandbox Makefile | No new state. Keeps two invocation idioms, two help surfaces, and the argument-passthrough cost the T4 row records |
| Direct `agent-sandbox` calls with explicit flags | One idiom and one help surface. The operator re-passes the identity arguments on every command |
| Registry written by `onboard` | One idiom, no argument passthrough, one help surface. Adds durable state with a staleness and coherence obligation. Storage candidates: a name-keyed config file per user, environment variables, or an explicit `SANDBOX_DIR` that stays authoritative |

### Record versioning

| Option | Trade-offs |
|---|---|
| Version the record pair as a unit | Resume compares the record revision before it reads fields. A format change fails loud and names itself. Adds a field and a comparison to both writers |
| Keep the record implicit | No change to the writers. A format change breaks resume at run time with no detection, which is the state today |

## Open questions

- Does the registry own the sandbox directory, or does `SANDBOX_DIR` stay authoritative and the registry hold defaults only?
- Where does the registry store records, and how does a record report a moved or deleted sandbox?
- Which lifecycle targets beyond argument convenience does the per-sandbox Makefile carry? The answer sets the removal cost.
- Does `workflow/knowledge-vault/` (13 files, 765 lines of scripts with their own story and changelog) share the identity or command-seam problem?

## Unknowns ledger

Known facts: the identity sources, the compose overlay split, the contract-check coverage, and the two invocation idioms, each read from source.

Known unknowns: the `scripts/check_*.sh` bodies (not read in full), the knowledge-vault subsystem, and the exact set of per-sandbox Makefile targets that carry behaviour beyond argument passing.

Suspected unknown unknowns: whether any consumer outside this repository reads `.compose/<id>.yml` or `SESSION_STATE` in a form that a version field would break.

## Decision

Not yet decided. This document is the exploration record. It settles into an ADR when the operator decides between the options above.
