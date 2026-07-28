# Study — Mount Wiring by Tier

**Status:** In progress

**Direction + Parent story:** M2.6.4 — Mount Model Design and Implementation. Surveys the entire mount wiring in the codebase, organised by mount model tier, to inform design decisions.

**Required reading:**
- `docs/architecture/security.md` — Trust Boundaries and Mount Models (Tiers 1–3)
- `docs/architecture/execution_model.md` — Mount Shape Rationale, Compose Generation
- `docs/architecture/tool_interface.md` — Mount Shape Guarantees, .env Runtime Variables
- `docs/architecture/sandbox_lifecycle.md` — Snapshot pipeline, resume path
- `docs/architecture/provider_lifecycle.md` — Provider config mount and copy-in/out
- `src/build/docker-compose.yml` — Base compose template
- `src/build/docker-compose.dry-run.yml` — Dry-run compose overlay
- `src/reasoning/providers/pi/docker-compose.pi.yml` — Pi provider overlay
- `src/build/compose.sh` — Compose generation script
- `scripts/start_agent.sh` — Host-side preflight and env var export
- `scripts/onboard.sh` — .env creation
- `docs/adr/20260721-adr-settled-worktree_mount_model.md` — Three-tier design ADR

---

## Summary

The codebase defines three mount model tiers in `security.md` and the worktree ADR, but only Tier 1 is implemented. Tier 2 is partially implemented (named volume for persistence) but the core architectural change — snapshot mounted read-write, agent working in snapshot instead of volume — is not done. Tier 3 has zero implementation hooks beyond the ADR. Cross-cutting issues (documentation gaps, undocumented behaviors, .env variable lifecycle) affect all three tiers.

Each tier section below states what the tier requires, whether it's achieved, and the specific gaps remaining.

---

## Cross-cutting: PROJECT_DIR Variable Flow

This affects all tiers identically, so it is documented once here rather than repeated per tier.

`PROJECT_DIR` flows through exactly three layers, all on the host side:

```
.env (stored at onboard time)
  → Makefile reads it (PROJECT_DIR ?= $(error ...))
    → agent-sandbox.sh parses --project= flag
      → start_agent.sh uses it for:
        1. Git validation (directory exists, has .git, has commits)
        2. Snapshot rsync (copies working tree to .snapshot/)
        3. Git archive (creates baseline.tar)
        4. Branch name resolution, HEAD SHA capture
```

`PROJECT_DIR` is used **exclusively on the host**. It is not exported into any compose environment. It is not present in `docker-compose.yml` or any provider overlay. It is not accessible inside either container.

The `.env` file stores it as a primitive. `start_agent.sh` derives all other path variables from `SANDBOX_DIR`, not `PROJECT_DIR`:

| Variable | Derivation |
|---|---|
| `SNAPSHOT_DIR` | `${SANDBOX_DIR}/.snapshot` |
| `CHANGES_DIR` | `${SANDBOX_DIR}/.workspace/session-diffs` |
| `INPUT_DIR` | `${SANDBOX_DIR}/.workspace/input` |
| `OUTPUT_DIR` | `${SANDBOX_DIR}/.workspace/output` |

The only derived value that references `PROJECT_DIR` is `SANDBOX_ID` = `sha256("${SANDBOX_DIR}:${HOST_HEAD_SHA}")`.

For Tier 2 and Tier 3, if `PROJECT_DIR` needs to be accessible inside the container (e.g. Tier 3 needs `PROJECT_DIR/.git` mounted), it must be exported into compose or baked at generation time.

---

## Cross-cutting: Constraints That Apply to All Tiers

These production constraints affect any new mount entry regardless of tier:

**C1 — `type: bind` must be used for all `${VAR}` host sources.** Docker Compose misclassifies `${VAR}` sources as named volumes in short volume syntax. All existing mounts use explicit `type: bind` syntax. Documented in `execution_model.md` "Why explicit `type: bind`".

**C2 — Host paths must be baked at compose generation time, not resolved at runtime.** `compose_generate` in `compose.sh` substitutes `{{VAR}}` placeholders before output. `${VAR}` placeholders that are not baked get relativised by `docker compose config --no-interpolate`. Any new mount with a host path must use a `{{WORKTREE_DIR}}` baked placeholder (like `{{PROJECT_DIR}}` is baked today). Documented in `execution_model.md` "Why host paths are baked".

**C3 — Pi provider uses direct bind mounts into AGENT_HOME, bypassing copy-in/copy-out.** Three Pi mounts (`prompts/`, `sessions/`, `skills/`) are mounted directly, unlike Hermes and OpenCode which use the copy-in/copy-out mechanism at `/opt/provider-config/`. This means worktree sessions that need provider skills/sessions must handle these mounts differently per provider. Undocumented — only discoverable by reading `docker-compose.pi.yml`.

**C4 — Provider compose overlays are inconsistent across providers.** Not all providers support all modes (standard, serve, dry-run). The serve overlays for different providers have different mount configurations. Adding a worktree mount must account for which overlays it interacts with.

**C5 — .env variable lifecycle is undocumented.** `tool_interface.md` lists only `PROJECT_DIR`, `SANDBOX_DIR`, `SERVE_PORT`, and `AUTOSAVE_INTERVAL`. Missing: `MAKEFILE_VERSION`, `AGENT_BRIEF`, provider API key variables. No single document traces which variables are written once, read at runtime, or exported to compose.

---

## Tier 1 — Copy + Tar (current default)

### What it requires

From `security.md` (invariants 1–6) and the compose template:

| Requirement | Implementation |
|---|---|
| `PROJECT_ROOT` not mounted into any container | ✅ Achieved — PROJECT_DIR is host-only (see cross-cutting) |
| `PROJECT_DIR/.git` not mounted into any container | ✅ Achieved — .git is not referenced in any compose path |
| No paths outside `.bootstrap/` + `.workspace/` | ✅ Achieved — 6 explicit bind mounts, all within those paths |
| No Docker socket | ✅ Achieved — no `/var/run/docker.sock` in any compose overlay |
| Mutation only after human review (via staged.diff) | ✅ Achieved — `make apply` pipeline, `staged.diff` staging |
| Gitignored files not in snapshot | ✅ Achieved — `snapshot_copy_worktree` uses rsync with `.gitignore` exclusion |
| `.snapshot/` mounted read-only, capability layer only | ✅ Achieved — `read_only: true` in docker-compose.yml |
| `.workspace/session-diffs/` mounted RW, capability layer only | ✅ Achieved |
| `workspace/input/` mounted RO, reasoning layer only | ✅ Achieved |
| `workspace/output/` mounted RW, reasoning layer only | ✅ Achieved |
| Agent works in `sandbox/` (Docker volume, via `--volumes-from`) | ✅ Achieved |

### Current implementation

The current mount shape for Tier 1:

| Host path | Container path | Mode | Owner | Container |
|---|---|---|---|---|
| `${SNAPSHOT_DIR}` | `/home/agentuser/.snapshot/` | RO | Harness | Capability only |
| `${CHANGES_DIR}` | `/home/agentuser/workspace/session-diffs/` | RW | Harness | Capability only |
| `${INPUT_DIR}` | `/home/agentuser/workspace/input/` | RO | Operator | Reasoning only |
| `${OUTPUT_DIR}` | `/home/agentuser/workspace/output/` | RW | Agent | Reasoning only |
| `${SANDBOX_DIR}/.<provider>/` | `/opt/provider-config/` | RW | Harness | Reasoning only |
| `sandbox-data` named volume | `/home/agentuser/sandbox/` | RW | Docker | Both (`--volumes-from`) |

The snapshot pipeline runs two stages on the host before containers start:
1. `snapshot_copy_worktree` — rsync from `PROJECT_DIR` to `.snapshot/` (respects gitignore)
2. `snapshot_archive_head` — `git archive HEAD` produces `baseline.tar` in `.snapshot/`

On container start, `snapshot_init_git` unpacks `baseline.tar` into `sandbox/`, commits it as "baseline", then overlays working tree from `.snapshot/` via rsync.

### Documentation gaps for this tier

- **D1 — Stale SOP reference.** `security.md` line 53 links to `standard_operating_procedures.md` for "operational guidance" on secrets handling, but the SOP is a STRIDE mitigation index, not operational guidance. The link resolves correctly but the label is misleading.
- **D2 — `.env` variable lifecycle undocumented.** See cross-cutting C5.

### Verdict

**Tier 1 is fully achieved.** All requirements are implemented. The two documentation gaps (D1, D2) are minor.

---

## Tier 2 — Mount + Tar

### What it requires

From `security.md` and the worktree ADR, Tier 2 makes one change to Tier 1:

| Requirement | Change from Tier 1 |
|---|---|
| `SANDBOX_DIR/.snapshot/` mounted RW into capability layer | **Changed** — was RO in Tier 1, must be RW for Tier 2 |
| No copy step at startup | **Changed** — no anonymous volume copy; `snapshot_init_git` runs against mounted `.snapshot/` |
| Agent works in `.snapshot/` (mounted) instead of `sandbox/` volume | **Changed** — working tree lives on host-mapped filesystem |
| `.snapshot/` not mounted into reasoning layer | **New explicit** — same as Tier 1 implicitly |
| Session persistence across restarts (via bind mount) | **New** — `.snapshot/` survives container restart |
| Named volume persists sandbox git state | ✅ Already achieved (M2.6.2) |

### Is it achieved?

**Partial.** M2.6.2 implemented the named volume (`sandbox-data`) for git state persistence, but the core Tier 2 changes were not implemented:

| Requirement | Status | Evidence |
|---|---|---|
| `.snapshot/` mounted RW | ❌ Not done | Still `read_only: true` in `docker-compose.yml` |
| No anonymous volume copy | ❌ Not done | `snapshot_init_git` still copies `.snapshot/` into `sandbox/` volume |
| Agent works in `.snapshot/` (mounted) | ❌ Not done | Agent still writes to `sandbox/` volume; `.snapshot/` is RO |
| `.snapshot/` not in reasoning layer | ✅ Implicitly achieved | `.snapshot/` is only mounted in capability layer |
| Named volume exists | ✅ Achieved | `sandbox-data` named volume in compose |

### Gaps to achieving Tier 2

1. **G2a — `.snapshot/` mount must become RW.** Change `read_only: true` to `read_only: false` (or remove the flag) in `docker-compose.yml`.
2. **G2b — Agent working directory must change from `sandbox/` volume to `.snapshot/` mount.** The agent currently writes to `/home/agentuser/sandbox/` (the Docker volume). It must write to `/home/agentuser/.snapshot/` (the mounted directory). This affects:
   - `snapshot_init_git` — must initialize git in `.snapshot/` not in `sandbox/`
   - Entrypoint paths — the agent's working tree moves
   - Provider config — copy-in/copy-out targets may change
   - `--volumes-from` may become unnecessary
3. **G2c — Snapshot pipeline may need changes.** `snapshot_copy_worktree` and `snapshot_archive_head` write to `.snapshot/` on the host. If `.snapshot/` is mounted RW, the copy step in the container entrypoint can be skipped — but the existing pipeline can continue as-is since the host already populates `.snapshot/`.

### Documentation gaps for this tier

- **Same as Tier 1 (D1, D2)** plus:
- **D3 — `sandbox_lifecycle.md` describes Tier 1 only.** The resume path section (M2.6.2) documents the named volume but does not describe Tier 2's mount-based model. Line 94 states "The host repository is never mounted" — correct for Tier 1 but does not qualify by tier.

### Verdict

**Tier 2 is not achieved.** The named volume (M2.6.2) was a prerequisite, but the three core changes (RW mount, agent working in snapshot, no volume copy) are unimplemented. Minimal engineering: change one `read_only` flag and redirect entrypoint paths.

---

## Tier 3 — Mount + Worktree

### What it requires

From `security.md` Tier 3 invariants (revised from Tier 1) and the worktree ADR:

| Requirement | Implementation needed |
|---|---|
| `SANDBOX_DIR/.snapshot/` mounted RW into capability layer | Inherited from Tier 2 — not done |
| `PROJECT_DIR/.git` mounted RO into capability layer only | **New** — not done, no compose entry exists |
| `PROJECT_ROOT` working tree not mounted | Inherited — working tree is not mounted |
| `.git/config` and `.git/hooks/` made RO before session | **New** — `chmod a-w` on host before container start |
| `--network=none` on agent container | **New** — no compose entry sets this |
| Main branch pointers write-protected via `chmod a-w .git/packed-refs` | **New** — after `git pack-refs --all` |
| Worktree lifecycle (create/remove/branch naming) | **New** — no scripts exist |
| Agent commits go to `PROJECT_DIR`'s object store (agent branch) | **New** — git access inside container, command adaptation |
| Branch diff replaces `staged.diff` as review artefact | **New** — `make draft`/`confirm`/`reject` adaptation |
| Snapshot pipeline replaced by `git worktree add` | **New** — no code paths exist |

### Is it achieved?

**Not achieved.** Zero code paths exist. The only artifact is the ADR.

| Requirement | Status | Evidence |
|---|---|---|
| `.snapshot/` mounted RW | ❌ Not done | Same as Tier 2 gap |
| `PROJECT_DIR/.git` mounted RO | ❌ Not done | No compose entry; no script prepares `.git` permissions |
| `.git/config` + `.git/hooks/` RO before session | ❌ Not done | No preflight step |
| `--network=none` on agent | ❌ Not done | No compose override or env var |
| Main branch write-protected | ❌ Not done | No preflight step |
| Worktree lifecycle scripts | ❌ Not done | No `git worktree add`/`remove` in any script |
| Command adaptation (draft/confirm/reject) | ❌ Not done | All commands operate on diff pipeline, not branches |
| Agent commits to object store | ❌ Not done | Container has no access to `PROJECT_DIR/.git` |
| Snapshot pipeline replaced | ❌ Not done | `start_agent.sh` always runs rsync + archive |

### Gaps to achieving Tier 3

1. **All Tier 2 gaps (G2a–G2c)** — Tier 3 requires everything Tier 2 needs, plus:
2. **G3a — Mount `PROJECT_DIR/.git` into capability layer.** New compose entry: `type: bind, source: ${PROJECT_DIR}/.git, target: /home/agentuser/.git, read_only: true`. Requires `PROJECT_DIR` to be exported into compose (currently host-only — see cross-cutting).
3. **G3b — Preflight permission hardening.** Before container start, on the host:
   - `chmod a-w "$PROJECT_DIR/.git/config"`
   - `chmod a-w "$PROJECT_DIR/.git/hooks/"`
   - `git -C "$PROJECT_DIR" pack-refs --all && chmod a-w "$PROJECT_DIR/.git/packed-refs"`
   - Restore writable after session end.
4. **G3c — `--network=none` on agent container.** Either add to compose template or to provider overlays.
5. **G3d — Worktree lifecycle.** Script or workflow to:
   - `git -C "$PROJECT_DIR" worktree add --detach "$SNAPSHOT_DIR" <baseline>`
   - Resolve branch naming convention (e.g. `agent/<session-ts>-<slug>`)
   - On session end: remove worktree, prune
6. **G3e — Command adaptation.** `make draft`/`confirm`/`reject` must operate on branches in `PROJECT_DIR` rather than applying diff files. The internal apply logic was unified in M2.6.4 pre-design (now shared via `_apply_patch_file`/`apply_and_commit`), but the commands still target diff files, not branches.
7. **G3f — Snapshot pipeline bypass.** `start_agent.sh` must detect worktree mode and skip `snapshot_copy_worktree`, `snapshot_archive_head`, and related preflight. Entrypoint must skip `snapshot_init_git`.
8. **G3g — `--volumes-from` may become unnecessary.** If the agent works in `.snapshot/` (mounted) rather than `sandbox/` (volume), the anonymous volume and `--volumes-from` may be eliminated. This changes the container dependency model.

### Documentation gaps for this tier

- **D4 — `sandbox_lifecycle.md` contradicts Tier 3.** Line 94: "The host repository is never mounted and cannot be reached from inside the container." This is false for Tier 3 where `.git` IS mounted. Must be qualified by tier.
- **D5 — `security.md` tier descriptions use inconsistent language.** Tiers 1 and 2 say `PROJECT_ROOT → not mounted into any container`. Tier 3 says `PROJECT_ROOT → not mounted (working tree is not mounted)`. The invariant table (line 143) correctly captures the nuance ("PROJECT_ROOT's **working tree** must not be mounted"), but the tier summary blocks above it are inconsistent. An operator reading Tier 1/2 descriptions will infer "PROJECT_ROOT is never mounted" is an absolute invariant — it is tier-specific.
- **D6 — `tool_interface.md` mount shape table has no tier columns.** The single mount shape table does not show which mounts change between tiers. Currently shows only Tier 1 shape.
- **D7 — `execution_model.md` mode composition table has no worktree mode.** The table lists standard, serve, and dry-run but not worktree. Compose generation description does not mention conditional mount entries.

---

## Open Questions for the Design Session

| Question | Affects |
|---|---|
| Should the worktree mount use a `{{WORKTREE_DIR}}` baked placeholder or a `${WORKTREE_DIR}` runtime variable? (C2 suggests baked is required) | G3a |
| Does the worktree model need its own compose overlay file or a conditional mount in the base template? | G3a |
| Should Pi's direct bind mounts (prompts, sessions, skills) be part of the worktree model, or should all providers use copy-in/copy-out? | C3 |
| Does `--volumes-from` become unnecessary in worktree mode, or is it retained for migration compatibility? | G3g |
| Does `make apply` still need to exist in worktree mode, or does branch-diff replace it entirely? | G3e |
| Does the snapshot pipeline run at all in worktree mode? If yes, what does it produce? | G3f |
| Is the migration path (Tier 1/2 sessions continuing to work) a conditional flag at session start or a separate Makefile target? | Cross-cutting |

---

## Constraints

- `PROJECT_ROOT` working tree must not be mounted (Tier 3 invariant).
- `PROJECT_DIR/.git` may be mounted read-only into the capability layer only (not reasoning layer).
- All mounts must use explicit `type: bind` syntax.
- Host paths must be baked at compose generation time.
- The existing snapshot model must continue working as an optional workflow.
- Provider config copy-in/copy-out must work in both snapshot and worktree modes.

---

## Next Steps

1. Design session resolves open questions and produces implementation spec.
2. Implementation units (estimated, to be confirmed by design):
   - U1: Tier 2 enablement (RW snapshot mount, entrypoint redirect)
   - U2: Tier 3 compose changes (`.git` mount, conditional entries)
   - U3: Preflight permission hardening (`chmod a-w` steps)
   - U4: Worktree lifecycle (create/remove/branch naming)
   - U5: Command adaptation (draft/confirm/reject on branches)
   - U6: Documentation updates (all tiers: security.md, sandbox_lifecycle.md, tool_interface.md, execution_model.md, provider_lifecycle.md)

---

## Resolution

To be populated at design session close.
