# Handover 20260917-06: study - centralized env precedence resolver

## Status

Closed

## Type

Study

## Milestone

M2.6 - Session Persistence (general cross-cutting track)

## Objective

Evaluate and recommend a centralized, explicit env-precedence model for the sandbox identity triple (`PROJECT_NAME`, `PROJECT_DIR`, `SANDBOX_DIR`), mirroring pi's thin-interface / deep-resolution design, and record a stable, refactor-friendly implementation plan with the results of a thermo-nuclear code review.

## Scope

Candidate evaluation for the env-precedence feature only. This iteration makes no production code changes. It produces a recommendation, a phased implementation plan (prefactors, then incremental feature landing), and an adversarial review record. The implementation itself is future `impl` iterations.

The candidate: a pi-style precedence chain - CLI flag > host env var > per-sandbox `.env` file - with NO default level. The `.env` file is located in the provided sandbox dir, or in the directory the command is invoked from. Target B (thin interface, deep resolver) is the goal; prefactor A (name into `.env`) is the foundation.

## Carried forward

The deep dive conducted in the prior session (the analysis of `--sandbox`/`--project`/`--name` routing, single-source state, the injection mechanism, and pi's hierarchy) is the input to this study. Its conclusions are restated in the Decisions table below.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| 1 | A recommended precedence model is stated and recorded | Handover Decisions table names the chain and its no-default rule | done |
| 2 | The implementation path separates prefactors from the feature | Plan in What's Next/roadmap names P1-P4 as no-behavior-change steps before S1-S4 | done |
| 3 | A thermo-nuclear subagent review ran and its results are recorded | Handover Findings/Decisions cite the VERDICT and the 10 numbered corrections | done |
| 4 | The plan is refactor-friendly for a stale branch | Plan names migration for existing sandboxes (P1), fixes P4-before-P1 ordering, and houses P2 apart from P3 | done |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/onboard.sh` | sed `<project-name>` injection, `_write_env_file`, refresh - the injection asymmetry |
| `scripts/templates/Makefile.template` | the `PROJECT_NAME := <project-name>` literal and the `-include .env` source |
| `src/libs/session_env.sh` | the hand-rolled `.env` loader and its precedence behavior |
| `src/libs/common.sh` | base flag parsing - the centralization target |
| `scripts/agent-sandbox.sh` | the thick interface - requires all three flags per subcommand |
| `scripts/start_agent.sh` | SANDBOX_DIR derivation default + `--env` flow; the thin-interface seam |
| `Makefile` (root) | dogfood special case: hardcoded `PROJECT_NAME`, `--project=$(CURDIR)` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Adopt target B: centralized precedence resolver with a thin CLI surface | Mirrors pi's `--session-dir` / `PI_*` / settings.json / default model. Current 7/11/12-way flag-parsing and 4-layer re-marshalling collapse into one module | this handover |
| Precedence per identifier: CLI flag > host env var (`AGENT_SANDBOX_*`) > per-sandbox `.env` > **no runtime default** | Identity is genuinely underivable (name != project basename); a silent default hides misconfiguration. Missing at all levels is a hard error pointing at `onboard`. The `SANDBOX_DIR` `PROJECT_DIR-sandbox` default is written into `.env` once at onboard, never resolved at runtime | this handover |
| `.env` location: the provided sandbox dir when given, else the invocation CWD | Clean mirror of pi's CWD-relative `.pi/settings.json`. A `make -C sandbox start` recipe already runs with CWD = sandbox, so it resolves the local `.env` with no identity flags | this handover |
| No global settings level in this feature | Only the per-sandbox `.env` exists today; a global level is YAGNI. Deferred | roadmap |
| Prefactor A first: move `PROJECT_NAME` into `.env`, drop the sed injection | Removes the injection asymmetry and gives the resolver a single `.env` store; the necessary foundation for B | this handover |
| Prefactors (P1-P4) ship before the feature (S1-S4); P4 (baseline tests) precedes P1 | P4 locks today's behavior before P1 mutates the `.env` schema, so the schema change cannot outrun its tests (review correction 2) | this handover |
| Last-level fallback is the `.env` file, never a computed default | Operator constraint. The `SANDBOX_DIR` derivation is applied ONCE at onboard (writes `SANDBOX_DIR=PROJECT_DIR-sandbox` into `.env`), not as a runtime resolution level (review correction 6) | this handover |
| Resolver env-var level reads only `AGENT_SANDBOX_*` keys, never the plain `PROJECT_DIR`/`SANDBOX_DIR`/`PROJECT_NAME` exports from `session_env` | A leaked sourced export would otherwise silently beat `.env` (review correction 5) | this handover |
| P2's unified loader lives in a new `src/libs/env.sh`, not `common.sh` | Keeps P2 and P3 from colliding in the same file on the stale-branch rebase; they are read-side vs parse-side and must not merge (review correction 7) | this handover |
| The advertised parse duplication is 7/11/12 files, not 11/12/16 | Corrected by review; `--project` (11 files) is the largest and is never centralized | this handover |
| Today `.env` overrides an explicit `--sandbox`/`--project`; B's flag-wins is a net-new flip | Traced: `start_agent.sh:209-211` make these globals; `session_env.sh:59` exports `.env` last over them. B must state and test this flip (review finding c) | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| PROJECT_NAME persists only as the baked Makefile literal and the `.env` header comment; it is not a `.env` variable, unlike its two siblings | contradiction | next iteration |
| The `.env` is loaded by two consumers with different semantics: Makefile `-include` (make vars) and `session_env.sh` (hand-rolled export loop). The bash parser was hardened (`0576b92`) which shows the divergence is a real seam | contradiction | next iteration |
| `--name`/`--project`/`--sandbox` are parsed in 7/11/12 files respectively (review-corrected); `--project` is the largest and is never centralized; only name+sandbox is centralized in `common.sh` | scope change | next iteration |
| Resolved by review: today `.env` overrides an explicit `--sandbox`/`--project`. `start_agent.sh:209-211` assign the identity as globals; `session_env.sh:59` (`.env` export loop) runs after the CLI arg export and wins. B's flag-wins is a net-new flip, not match-today; a P4 regression test must pin it | blocker -> resolved | design record |
| Thermo-nuclear review VERDICT: APPROVE-WITH-CORRECTIONS. 10 corrections; two must-fix: (1) P1 does not migrate existing `.env` (no `PROJECT_NAME` key, `_run_refresh` never inserts one) - add explicit insert + migration test; (2) P4 must precede P1 | steering | this handover / roadmap |
| `package_branch.sh` parses none of the identity flags; the dispatcher requires `--sandbox` but does not forward it (`agent-sandbox.sh:241-248`) - the `package-branch` host path is broken today and must be excluded or fixed in S2 | bug | next iteration |
| Env-var leak risk: `session_env` exports plain `PROJECT_DIR`/`SANDBOX_DIR`/`PROJECT_NAME`; resolver must read only `AGENT_SANDBOX_*` keys and guard a leaked plain export | scope change | next iteration |
| `make -C sandbox` runs recipes with CWD = sandbox (claim d confirmed); `make -f <abs>/Makefile` keeps the invocation CWD and breaks CWD-`.env` lookup. The `make -C` contract must be documented in the ADR (review correction 10) | scope change | next iteration |
| `agent-sandbox` `package-branch` path is broken today (requires `--sandbox`, never forwards it) - exclude or fix in S2 (review correction 8) | bug | next iteration |
| Resume `--list`/`--interactive` need only `--sandbox`; the resolver must expose sandbox-only partial resolution or resume listing breaks (review correction 8) | scope change | next iteration |

## Completed

| File | Change |
|---|---|
| `devlog/handovers/20260917-06-study-env_precedence_resolver.md` | Study record: recommendation, precedence model, phased plan, thermo-nuclear review folded in |
| `devlog/roadmap.md` | Generated task entry for the env-precedence feature under M2.6 cross-cutting |

## Deferred items

None.

## What's Next

Implement the env-precedence feature in phased `impl` iterations. B is the target; A is its foundation. The operator has directed that prefactors stabilize project state and add tests before the feature lands, because the working branch is stale and feature changes will rebase onto it.

**Phase P (prefactors - no behavior change):**

- P1: move `PROJECT_NAME` into `.env`; drop the sed `<project-name>` injection and the template literal; bump template version.
- P2: unify `.env` loading into one library function.
- P3: centralize base flag parsing/validation in `common.sh`.
- P4: behavioral baseline tests (name-to-image/container routing, `.env` read, SANDBOX canonicalization).

**Phase S (incremental feature landing):**

- S1: new `src/libs/env_resolve.sh` - precedence resolver + `.env` location selection (provided dir, else CWD); unit tests per level.
- S2: wire the resolver into entrypoints (start/resume, then build/stop/prune, then workflows).
- S3: thin the CLI and sandbox Makefile (drop per-call identity flags; rely on `.env` via CWD or `--env`).
- S4: documentation + ADR for the precedence model; update CLI usage, identity docs.

Resolved design questions before impl: the CLI-vs-file precedence is now known - today `.env` wins (file beats an explicit flag); B makes flag-wins a net-new flip that a P4 test must pin. No runtime `SANDBOX_DIR` derivation level; the default is applied once at onboard into `.env`.

Phase **P** corrections folded in (from thermo-nuclear review):

- P1 must ADD `PROJECT_NAME=` insertion to `_run_refresh` (value is already present - `_validate_refresh` requires `--name`, `onboard.sh:186-194`) plus a dedicated migration test. Do not rely on the version bump to migrate.
- P4 (behavioral baseline, incl. the `.env`-beats-flag regression test) ships FIRST, before P1.
- P2's unified loader goes in a new `src/libs/env.sh`, separate from `common.sh` (P3's home) to avoid rebase collision.
- Flag-parse counts are 7/11/12 (name/project/sandbox); `--project` is the largest uncentralized set.

Phase **S** additions: package-branch fix-or-exclude (dispatcher requires `--sandbox` but never forwards it, `agent-sandbox.sh:241-248`); resume `--list`/`--interactive` need sandbox-only partial resolution; resolver env-var level reads only `AGENT_SANDBOX_*`.

Watch-out items:

1. Existing onboarded sandboxes have a `.env` WITHOUT `PROJECT_NAME`; P1's refresh insert must detect and add it, and the resolver must treat absence as a hard error, not fall back to a derivation.
2. Template version bump (4->5) interacts with the refresh staleness path in `_run_refresh`; the bump alone does not migrate.
3. `make -C` is the CWD contract; `make -f <abs>/Makefile` breaks CWD-`.env` resolution.

**Conclusions from this iteration:** the happy-path wiring is correct but fragmented: three siblings split across two persistence mechanisms, four layers of re-marshalling, duplicated parsing (7/11/12), and one resolved correctness flip (`.env` beats an explicit flag today). pi's model maps cleanly; the unified `.env` store (P1) unblocks everything else. Thermo-nuclear review APPROVE-WITH-CORRECTIONS; its 10 corrections (two must-fix) are folded into the phased plan above and reflected in the roadmap task entry.
