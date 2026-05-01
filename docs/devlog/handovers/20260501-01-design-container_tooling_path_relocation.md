# Agent Handover

**Session date:** 2026-05-01
**Milestone:** Unassigned — container tooling path relocation (prerequisite for M2.x)
**Session type:** Design
**Status:** Active

## Objective

Resolve the eight open design questions (Q-L2-1 through Q-L2-8) identified in `recovery-layer2-investigation.md`, producing a confirmed design specification that an implementation session can execute without further design work.

## Scope

- Resolve all eight open design questions from the Layer 2 investigation (Q-L2-1 through Q-L2-8) through operator-directed discussion (grill-me).
- Record each decision with rationale and location.
- Produce a final design spec (`docs/devlog/discussions/design_container_tooling_path_relocation.md`) that lists every file to change, the exact change per file, and the file set for each of the two container build contexts (sandbox, agent).
- Explicitly out of scope: any implementation file edits; test changes; changes to `scripts/` (except `scripts/dry_run.sh` which is in scope per Q-L2-5).
- The prior `20260430-01-impl-*` session's objectives are superseded. This session produces the design; implementation is deferred to a subsequent session.

## Carried forward

None.

## Acceptance criteria

1. `docker build` of sandbox image exits 0; `docker run --rm --entrypoint test <sandbox-image> -f /opt/sandbox/bin/sandbox-entrypoint.sh` exits 0
2. Same for `/opt/sandbox/lib/dirs.sh`, `/opt/sandbox/lib/snapshot.sh`, `/opt/sandbox/lib/diff.sh`, `/opt/sandbox/lib/package_branch.sh`, `/opt/sandbox/lib/session.sh` in the sandbox image
3. Agent image has `/opt/sandbox/lib/dirs.sh`, `/opt/sandbox/lib/package_diff.sh`, `/opt/sandbox/lib/session.sh`, `/opt/sandbox/bin/provider-entrypoint.sh`
4. Agent image has `/opt/sandbox/docs/architecture/` and `/opt/sandbox/docs/concepts/` directories
5. `sandbox-entrypoint.sh` source paths match `/opt/sandbox/lib/...` (verified by test)
6. `make test` exits 0 with all test assertions updated
7. `grep -rn 'source /libs/' libs/ scripts/` returns 0 results (no stale hardcoded `/libs/` paths in runtime scripts)

## Hot files

| File | Why in scope |
|---|---|
| [`recovery-layer2-investigation.md`](../../recovery-layer2-investigation.md) | Source of all eight open design questions; the design spec resolves these |
| [`libs/sandbox.Dockerfile`](../../libs/sandbox.Dockerfile) | Destination prefix and ENTRYPOINT path depend on layout decision (Q-L2-2, Q-L2-4) |
| [`libs/containers.sh`](../../libs/containers.sh) | Build context functions affected by Q-L2-1 (which files) and Q-L2-8 (segmented vs unified) |
| [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) | Source paths depend on directory layout (Q-L2-2) and symlink decision (Q-L2-6) |
| [`providers/pi/provider.Dockerfile`](../../providers/pi/provider.Dockerfile) | COPY path and ENTRYPOINT form depend on Q-L2-2 and Q-L2-4 |
| [`providers/opencode/provider.Dockerfile`](../../providers/opencode/provider.Dockerfile) | Same as pi provider |
| [`providers/hermes/provider.Dockerfile`](../../providers/hermes/provider.Dockerfile) | Same as pi provider |
| [`providers/claude-code/provider.Dockerfile`](../../providers/claude-code/provider.Dockerfile) | Same as pi provider |
| [`agent/prompts/package-diff.md`](../../agent/prompts/package-diff.md) | Path references depend on layout decision (Q-L2-2) |
| [`agent/prompts/package-branch.md`](../../agent/prompts/package-branch.md) | Path references depend on layout decision (Q-L2-2) |
| [`agent/prompts/agent-sandbox.md`](../../agent/prompts/agent-sandbox.md) | Docs reference needs to update to `/opt/sandbox/docs/` |
| [`scripts/dry_run.sh`](../../scripts/dry_run.sh) | Path selection depends on Q-L2-5 (treat as container-invoked vs. symlink) |
| [`tests/test_capability_layer.sh`](../../tests/test_capability_layer.sh) | Assertion paths updated per layout decision |
| [`tests/test_build_context.sh`](../../tests/test_build_context.sh) | File count/name assertions updated per Q-L2-1 and Q-L2-8 |

## Decisions made this session

| ID | Decision | Rationale | Reference |
|---|---|---|---|
| Q-L2-2 | Layout: `/opt/sandbox/bin/` + `/opt/sandbox/lib/` + `/opt/sandbox/docs/` | FHS-compliant; PATH alignment for ENTRYPOINTs; role separation | `design_container_tooling_path_relocation.md` |
| Q-L2-4 | Full-path ENTRYPOINT + `ENV PATH=/opt/sandbox/bin:$PATH` | Zero ambiguity; consistent with sandbox Dockerfile | Same |
| Q-L2-1 | Seed all 8 container-invoked files, segmented per image | External projects don't have harness libs in sandbox snapshot | Same |
| Q-L2-8 | Keep segmented build contexts | Minimal overlap (2 shared files); smaller contexts; easier to audit | Same |
| Q-L2-3 | Agent image only; `architecture/` + `concepts/` subdirectories | ~23 files, ~180KB; excludes devlog/development/operations/ | Same |
| Q-L2-7 | `session.sh` explicitly in both images | Sourced by `package_*.sh` via relative path | Same |
| Q-L2-6 | No backward-compatibility symlinks | Every consumer updated in-scope; symlinks are maintenance trap | Same |
| Q-L2-5 | `dry_run.sh` absolute path update to `/opt/sandbox/lib/dirs.sh` | Always runs inside image; no symlink needed | Same |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| Script category table (container-infra / co-located / prompt-templates / repo-only) with per-category path strategies needs to be persisted for maintenance | design | Persistent reference — recorded in `design_container_tooling_path_relocation.md` |
| `system_overview.md` links to `project_index.md` (in development/) — link will break when development/ is excluded from baked docs. Broader concern: concept/architecture docs cross-reference dev/ops/doc folders, violating the sandbox-vs-coding-agent contract. Operations/ and development/ should be logically folded into a coding-agent workflow/ and taken out of the overarching docs/ repository. Same for devlog/ (artifacts of the coding-agent workflow). | architecture | Not in scope — big renaming change for future investigation |
| Prompt templates (`defer.md`, `wrapup.md`, `new-session.md`, `new-session-v2.md`) reference `docs/operations/iteration_policy.md` etc. by project-relative path. Only resolves when project IS agent-sandbox (dogfooding). Seeding docs into `/opt/sandbox/docs/` doesn't fix these — they reference operations/ which is excluded. | pre-existing concern | Deferred — these need a separate mechanism or a decision to seed operations/ too |
| Repo directory structure for bash scripts does not properly organise files according to logical requirements (not against functionality, not against use location). The script category table (container-infra / co-located / prompt-templates / repo-only) surfaces a diagnosis: files are grouped by `libs/` or `scripts/` directory rather than by their lifecycle (image-baked vs host-only vs bind-mounted), creating ambiguity about what path strategy each file needs. | architecture | Not in scope — restructure needed as a separate investigation |

## Completed this session

| File | Change summary |
|---|---|
| `docs/devlog/discussions/design_container_tooling_path_relocation.md` | Created — complete design spec with exact per-file change descriptions, script category table, and proposed AC |
| This handover | Created with all 8 decisions, mid-session findings, and acceptance criteria |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| Prompt templates (`defer.md`, `wrapup.md`, `new-session.md`, `new-session-v2.md`) referencing `docs/` by project-relative path | Out of scope — these reference operations/ policy, not architecture/concepts docs | Future session (after docs restructuring investigation) |
| Docs restructuring: fold operations/ + development/ into a coding-agent workflow/, remove from overarching docs/ | Big renaming change, not in scope | Future investigation |

## Next session

**Context handover:** Prior implementation handover `docs/devlog/handovers/20260430-01-impl-container_tooling_path_relocation.md` — superseded by this design session. The implementation thread can be resumed once the design spec is confirmed.

**Sub-milestone:** Container tooling path relocation (prerequisite).
**Trigger B:** Not applicable — not a sub-milestone close.
**Blocking questions:** None — all eight design questions resolved.
**Watch-outs:**
- The use of `lib/` (not `libs/`) per FHS convention — ensure no Dockerfile COPY or script path uses `libs/` under `/opt/sandbox/`
- The `agent-sandbox.md` prompt reference to `docs/` is being updated — verify the other prompt templates (`defer.md`, `wrapup.md`, `new-session.md`, `new-session-v2.md`) are intentionally out of scope
- File count assertions in `test_build_context.sh` change significantly (sandbox: 4→7+docs, agent: 2→4+docs)
**Session start grep:**
- `grep -rn 'source /libs/' .` — verify all cleared after implementation
- `grep -rn '/usr/local/bin/' libs/ providers/` — verify all updated
- `grep -rn '~/sandbox/libs/' agent/prompts/` — verify all updated

**Conclusions from this session:**
- The `/opt/sandbox/bin/` + `/opt/sandbox/lib/` + `/opt/sandbox/docs/` layout is confirmed, with no backward-compat symlinks
- All 8 container-invoked libs files are seeded into their respective images, segmented by container type
- docs/ is seeded into the agent image only, limited to `architecture/` + `concepts/`
- `dry_run.sh` gets an inline absolute path update; `sandbox-entrypoint.sh` gets 3 absolute path updates
- Prompt templates `package-diff.md` (6 occurrences), `package-branch.md` (1 occurrence), and `agent-sandbox.md` (1 reference) get path updates
- Test assertions in `test_capability_layer.sh` and `test_build_context.sh` get updated paths and counts
- Provider Dockerfiles get new COPY lines, `ENV PATH`, and full-path ENTRYPOINTs
- A future investigation is needed to restructure docs/ with a coding-agent workflow/ boundary
