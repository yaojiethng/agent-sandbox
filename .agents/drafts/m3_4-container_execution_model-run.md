# M3.4 -- Container Execution Model and Environment Ownership

The run brief for M3.4. Draws on the plan session of handover `20261015-09`. Status: draft until the operator releases it.

## The premise under test

The harness over-prescribes the project's development environment. The proposed fix is a declaration surface: the project declares its image, mounts, volumes, services and lifecycle, and the harness reads the declaration while keeping the session guarantee plane.

Falsification: if moving the declaration to the project cannot hold the one-diff-source-of-truth invariant, or if the security posture cannot be rebaselined against a project-supplied build, then the answer is not a declaration surface and the model returns to M3.4.1.

## What is already measured

| Fact | Command or file |
|---|---|
| `build_sandbox` hardcodes the capability Dockerfile | `scripts/build.sh:165` |
| The capability Dockerfile says to copy and customise, but nothing reads a project copy | `src/capability/dockerfile:4` |
| The copy-delivery sandbox volume is per-session | `src/build/docker-compose.copy.yml:18` |
| `$AGENT_BIN`, `$HOME/.local/bin` and `/tmp` carry no mount row | `src/build/docker-compose.yml`, `src/reasoning/providers/pi/docker-compose.pi.yml` |
| The pre-commit hook calls a harness-repo script | `src/capability/git-hooks/pre-commit.sh:85` |
| `tier` collides twice, on the build tiers and the dispatch tiers | `src/reasoning/base.dockerfile:3`, `model-failover/router.ts:8` |
| `plane` carries zero uses | grep across `docs/`, `src/`, `workflow/` |
| The `active-milestone` scalar cannot hold two branches | `devlog/roadmap.md` M3.5 |
| No project service, port, lifecycle or hook seam exists | grep across `src/build/`, `scripts/onboard.sh` |

## The rulings

- The session guarantee plane stays harness-owned. The diff pipeline reads exactly one filesystem.
- No project-supplied build or mount reaches the host without a stated posture in the ADR.
- `layer` stays reserved for the container architecture. No new use of `tier`, `boundary`, `scope` or `context` for execution extent or ownership.
- Historical records are not retro-renamed.

## The phases

Ordered by the stabilization rule. Each phase closes on a live `spread` run, not on a document.

1. **The model.** Done by the plan session: the ADR, `system_overview.md`, `terminology.md`. The remaining work is the propagation sweep and the gate.
2. **The declaration seam.** Design it, run it against `spread`, triage, fix, repeat.
3. **Persistence.** State what survives teardown, deliver it, run the migration cycle on `spread`.
4. **Service topology and the trust boundary.** Rebaseline the posture before any project service runs.
5. **The verification surface.** The project's own verification must run launch to evidence inside the environment.
6. **Project-owned checks and skills.** The project's hooks and checks replace the harness prescriptions.

Phase 2 gates phases 3 to 6, and phase 4 gates phase 5 and 6.

## The work units

| # | Unit | Commit type | Owned files | Handover |
|---|---|---|---|---|
| U1 | The vocabulary propagation sweep over the live instruction surfaces | `docs` | `docs/`, `workflow/`, `.agents/skills/` | own |
| U2 | The vocabulary gate: `layer` only for the container architecture | `test` | `scripts/check_instruction_surfaces.sh` | own |
| U3 | The declaration surface: where a project declares its environment, and the reader | `feat` | `src/build/`, `docs/reference/execution_model.md` | own |
| U4 | The image build path: the project Dockerfile, the `snapshot.sh` dependency, preflight UID/GID, `REBUILD` reach | `fix` | `scripts/build.sh`, `src/build/` | own |
| U5 | The per-image lib inventory manifest and drift test | `test` | `src/build/container-interface.json`, `scripts/check_container_layout.sh` | own |
| U6 | The onboarding and refresh generated-artifact contract | `feat` | `scripts/onboard.sh`, `scripts/templates/` | own |
| U7 | Image identity, naming and stamping agreed with `harness_versioning.md` | `docs` | `docs/adr/harness_versioning.md`, `src/build/image.sh` | own |
| U8 | The container-harness contract and `.compose/<sid>.yml` ownership | `refactor` | `src/build/compose.sh` | own |
| U9 | The pre-snapshot validation gate | `feat` | `scripts/start_agent.sh` | own |
| U10 | Dependency locking for the provider images | `build` | `src/reasoning/providers/*/base.dockerfile` | own |
| U11 | The project-declared persistence contract and its volumes | `feat` | `src/build/`, `docs/reference/execution_model.md` | own |
| U12 | Environment-change persistence: installs, caches, virtual environments | `feat` | `src/capability/` | own |
| U13 | Harness identity split from the mounted-project session state | `refactor` | `src/libs/`, `docs/` | own |
| U14 | Structured task log persistence | `feat` | `src/libs/`, `docs/` | own |
| U15 | Multi-service environments: the project environment may be several services | `feat` | `src/build/` | own |
| U16 | The trust-boundary rebaseline and threat model for a project-supplied environment | `docs` | `docs/development/threat_model_stride.md`, `docs/development/security.md` | own |
| U17 | Port publish and service discovery for project services | `feat` | `src/build/`, `src/reasoning/providers/pi/docker-compose.serve.yml` | own |
| U18 | The verification contract: launch, drive, observe, isolate, cleanup, evidence | `feat` | `.agents/skills/`, `docs/reference/` | own |
| U19 | The browser and CDP toolchain in the environment | `build` | provider dockerfiles | own |
| U20 | The vault project as the second-project portability proof | `test` | `devlog/discussions/`, fixtures | own |
| U21 | The project hook seam: the project's hooks replace the harness hook | `fix` | `src/capability/entrypoint.sh`, `src/capability/git-hooks/` | own |
| U22 | Project-owned checks run inside the environment | `feat` | `.agents/skills/`, `docs/` | own |
| U23 | Skill specialization verified through the project `.agents/skills` cell | `docs` | `.agents/skills/`, `docs/adr/coding_agent_project_bindings.md` | own |

## The consolidation

Each unit above names the rows it takes over. The close removes the originals from their current sections so no row is tracked twice.

| Taken-over row | Current home | Lands as |
|---|---|---|
| `A controlled vocabulary for layer` | T8 | U1, U2 |
| `Evaluation of stage construction` | T7 | U3 |
| `Per-image lib inventory manifest and drift test` | T4 | U5 |
| `Onboarding and refresh: one generated-artifact contract` | T4 | U6 |
| `Image identity and version semantics` | T9 | U7 |
| `Image naming and stamping` | T9 | U7 |
| `The container-harness contract` | T9 | U8 |
| `The image build path` | T9 | U4 |
| `Pre-snapshot validation gate` | T6 | U9 |
| `Dependency security` lockfile | M7 | U10 |
| `Environment-change persistence (install layers across runs)` | T7 | U12 |
| `Separate harness identity from the mounted-project session state` | T9 | U13 (persistence half; identity half stays T9) |
| `Structured task logs` | T6 | U14 |
| Network, resource and allowed-directory policy | M7 | U15, U16, U17 |
| `Git boundary and repository state` hook part | T7 | U21 (hook part; git discipline stays T7) |
| `Gate upkeep` project-hook seam | M3.1.2 | U21 (seam part; gate cost and procedure stay M3.1.2) |
| Vault capability layer prototype portability arm | W1 | U20 (portability arm; MCP specifics stay W1) |

New rows with no current home, filed by U3, U11, U15 and U18: the environment declaration surface, the persistence contract, the service topology, and the verification surface.

## The model assignment

Resolve each role from `$AGENT_HOME/model-recommendations.md`. `_IMPLEMENTER` for the seam and code units. `_ADVISOR` for U16, the threat-model rebaseline. `_REVIEWER` for the pre-close pair on the model and the seam.

## Verification

| Check | Artifact |
|---|---|
| The vocabulary has one sense per term | `docs/reference/terminology.md` |
| The model survives a fresh-context read | the ADR and `system_overview.md` |
| The declaration seam produces an applicable diff bundle | a `spread` run, apply on the host |
| Persistence survives teardown | a `spread` run across two sessions |
| The posture is stated for every project-supplied input | the threat model |
| The verification contract runs launch to evidence | a `spread` run |
| No consolidated row is duplicated | a grep per taken-over term |
| The gates stay green | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` |

## Constraints and invariants

- One diff source of truth.
- The session record survives teardown.
- No project-supplied build or mount reaches the host without a stated posture.
- No retro-rename of historical records.

## What would settle this brief

- Whether the project declaration is a Dockerfile, a compose overlay, a devcontainer, or a harness-specific manifest. The brief takes the harness-specific manifest as the default and the word that reverses it is `devcontainer`.
- Whether phase 4 gates phase 5, or they proceed together. The brief takes the gate.
- Whether U20 runs before the seam is stable. The brief takes after.
