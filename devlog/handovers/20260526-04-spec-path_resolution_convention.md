# Agent Handover

**Session date:** 2026-05-26
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Spec
**Status:** Closed

## Objective

Catalogue every distinct path resolution pattern used across `libs/`, `scripts/`, `tests/`, and container entrypoints; choose a single convention; produce a migration spec with every source path that must change when the libs/ files move to their new locations.

## Scope

**In scope:**
- Catalogue every `source` statement, `SCRIPT_DIR`/`_DIR` variable, and path derivation pattern across all shell files
- Determine a single convention for host-side and container-side path resolution
- Map every source path that references a file that will move (per the libs/ refactor design)
- Produce a migration spec: for each file being moved, list every source/COPY/exec reference with its old and new path

**Out of scope:**
- The file moves themselves — implementation deferred to an impl session
- The directory structure decisions — already settled in `20260526-design-shared_library_organisation.md`

## Carried forward

| Item | From handover |
|---|---|
| Path resolution convention — 6 inconsistent patterns found across the codebase; must choose one and produce a migration spec before the libs/ moves | `20260526-03-design-shared_library_organisation.md` Deferred items |

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `libs/*.sh` (all 15) | Every file has a self-resolution or source pattern that needs cataloguing | ✅ Catalogued, 6 patterns found |
| `scripts/*.sh` (all 12) | Source paths reference libs/ files that will move | ✅ Catalogued |
| `tests/test_*.sh` (all 20+) | Source paths reference ../libs/ or $REPO_ROOT/libs/ | ✅ Catalogued |
| `libs/sandbox-entrypoint.sh` | Hardcoded /opt/sandbox/lib/ paths | ✅ No change this session |
| `providers/pi/provider.Dockerfile` | COPY paths that must update | ✅ Migrated in spec table |
| `libs/sandbox.Dockerfile` | COPY paths that must update | ✅ Migrated in spec table |
| `libs/containers.sh` | build_context_* COPY paths | ✅ Migrated in spec table |
| `scripts/dry_run_reasoning.sh`, `dry_run_capability.sh` | Hardcoded /opt/sandbox/lib/ paths | ✅ No change this session |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Three-layer interface seam: container-only (hardcoded /opt/sandbox/lib/) ← cross-context (self-resolution) → host-only (\$AGENT_SANDBOX_REPO / \$REPO_ROOT) | Each layer has different deployment and invocation constraints that dictate its path resolution strategy | Spec doc §Interface Seam |
| Cross-context libs use self-resolution with canonical `_SCRIPT_DIR` variable | Must work in both host and container; \$AGENT_SANDBOX_REPO and \$REPO_ROOT don't exist inside containers | Spec doc §Layer 2 |
| Host libs sourced by agent-sandbox.sh use `$AGENT_SANDBOX_REPO` | Only ever sourced by agent-sandbox.sh which sets this variable; eliminates inconsistent self-resolution vars | Spec doc §3b |
| Host scripts use `$REPO_ROOT` | Already the existing pattern; they always run from repo checkout | Spec doc §3c |
| Test files use `$REPO_ROOT` | Always run from repo checkout; replaces mixed relative-path patterns | Spec doc §3d |
| agent-sandbox.sh keeps `$AGENT_SANDBOX_REPO` macro | Must survive `make install` moving the script outside the repo | Spec doc §3a |
| Container paths unchanged this session | Container-side reorganisation is a separate concern from host-side libs move | Spec doc §Layer 1 |

## Mid-session findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Six different self-resolution variable names across libs/ — `_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, `_PD_SCRIPT_DIR`, `_DW_SCRIPT_DIR`, `_ISS_SCRIPT_DIR`, plus inline `$(cd...)` in draft_workflow.sh | Inconsistency | Standardise to `_SCRIPT_DIR` as part of the libs/ refactor; eliminates cognitive overhead | Spec doc §Findings |
| draft_workflow.sh computes its own directory 3 times inline instead of storing it in a variable | Inefficiency | Fix when switching to `$AGENT_SANDBOX_REPO` — the self-resolution pattern is removed entirely | Spec doc §Findings |
| Hardcoded `/opt/sandbox/lib/` in entrypoints is fragile but not broken — single source of truth per image | Observation | Could be replaced by an ENV variable in the Dockerfile, but out of scope for this session | Spec doc §Findings |
| Dockerfile COPY paths reference `libs/` sources that will move (e.g., `COPY dirs.sh /opt/sandbox/lib/dirs.sh`) — the source side of every COPY will break | Impact | Must update COPY source paths in both sandbox.Dockerfile and provider.Dockerfile as part of the libs/ refactor | Spec doc §Summary table |

## Completed this session

| File | Change |
|---|---|
| File | Change |
|---|---|
| `devlog/discussions/20260526-spec-path_resolution_convention.md` | Full spec document: three-layer interface seam, context resolution convention per layer, source path migration table (every source/COPY/exec path with old → new), standardised self-resolution variable naming, findings |
| `docs/concepts/context_resolution.md` | Published concept document: describes how files determine their runtime context (host / ambiguous / container) and resolve dependencies accordingly. Broader than path resolution — covers identity determination, conventions, and the interface seam between layers. |

## Deferred items

None.

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning

**Next session: Implementation — path resolution cleanup.** Apply the source path migration table from the spec document: update every source/COPY/exec path to match the new context resolution convention. This is the prerequisite for the libs/ file moves — paths must point to the new locations before files can move, or paths update at the same time.

~70+ source path updates across ~40 files (libs/, scripts/, tests/, Dockerfiles, containers.sh build_context functions).

**Conclusions from this session:**
- Context resolution follows a three-layer interface seam: container context (hardcoded `/opt/sandbox/lib/`) → ambiguous context (self-resolution with `_SCRIPT_DIR`) → host context (`$AGENT_SANDBOX_REPO` or `$REPO_ROOT`)
- Ambiguous-context libs (session-state, routing, diff, package-branch, package-diff, dirs) are the bridge layer — they use self-resolution because they must work in both host and container
- All 6 self-resolution variables standardised to `_SCRIPT_DIR`
- Host libs switch from self-resolution to `$AGENT_SANDBOX_REPO`
- Test files switch to `$REPO_ROOT` consistently
- Container paths unchanged this session; Dockerfile COPY source paths must update when sources move
- Published as `docs/concepts/context_resolution.md`
