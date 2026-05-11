# Design: Container Tooling Path Relocation

**Derived from:** `recovery-layer2-investigation.md`
**All decisions resolved during:** `20260430-02-design-container_tooling_path_relocation.md`

## Summary

Relocate harness tooling from ad-hoc paths (`/libs/`, `/usr/local/bin/`) and sandbox-relative paths (`~/sandbox/libs/`) into a dedicated container directory (`/opt/sandbox/bin/`, `/opt/sandbox/lib/`, `/opt/sandbox/docs/`). Tooling versions are pinned to the Docker image and cannot drift from what the container expects.

---

## Decisions

| ID | Question | Decision | Rationale |
|---|---|---|---|
| Q-L2-2 | Directory layout under `/opt/sandbox/` | `/opt/sandbox/bin/` (entrypoints), `/opt/sandbox/lib/` (library scripts), `/opt/sandbox/docs/` (documentation) | FHS-compliant; PATH alignment for ENTRYPOINTs; separation by role |
| Q-L2-4 | ENTRYPOINT form for provider Dockerfiles | Full path + `ENV PATH=/opt/sandbox/bin:$PATH` | Zero ambiguity; consistent with sandbox Dockerfile; belt-and-suspenders |
| Q-L2-1 | Which `libs/` files to seed into each image | All 8 container-invoked files, segmented per image | External projects don't have harness libs in their sandbox snapshot; option (c) bloats with host-side files |
| Q-L2-8 | Build context segmentation | Keep segmented (`build_context_sandbox` and `build_context_agent` as separate functions) | Minimal overlap (2 shared files); smaller build contexts; easier to audit |
| Q-L2-3 | `docs/` inclusion | Agent image only; `architecture/` + `concepts/` subdirectories only | ~23 files, ~180KB; excludes devlog/ (notes), development/ (dev support), operations/ (governance for developers, not sandbox users) |
| Q-L2-7 | `session.sh` explicit copy | Yes, in both images at `/opt/sandbox/lib/session.sh` | Consequence of Q-L2-1; sourced by `package_*.sh` via relative path |
| Q-L2-6 | Backward-compatibility symlinks | None | Every consumer of old paths is updated in-scope; symlinks are a maintenance trap |
| Q-L2-5 | `dry_run.sh` path | Update absolute path from `/libs/dirs.sh` to `/opt/sandbox/lib/dirs.sh` | Always runs inside image; no symlink needed |

---

## Script category table

Relevant for maintenance: each category has a different path strategy.

| Category | Examples | Path strategy |
|---|---|---|
| **Container infrastructure** — always run from image, never from repo | `sandbox-entrypoint.sh`, `dry_run.sh` | Update absolute prefix from `/libs/` → `/opt/sandbox/lib/` |
| **Co-located tooling** — sourced via relative path from siblings | `diff.sh` → `package_branch.sh`, `package_diff.sh` → `session.sh` | Keep relative paths. **Maintenance note:** co-location dependency — if files move to different dirs in the image, update source paths |
| **Prompt templates** — code blocks call container-bundled tooling | `package-diff.md`, `package-branch.md`, `agent-sandbox.md` | Update paths from `~/sandbox/libs/...` → `/opt/sandbox/lib/...` and docs reference → `/opt/sandbox/docs/` |
| **Repo-only test scripts** — never inside image | `test_capability_layer.sh`, `test_build_context.sh` | Keep repo-relative paths. Update test assertions to reflect new image paths |

---

## File change spec — exact changes per file

### 1. `libs/containers.sh` — build context functions

**`build_context_sandbox`** — 7 files + docs:

```bash
_build_context_copy "$repo_root/libs/sandbox-entrypoint.sh"     "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/dirs.sh"                    "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/snapshot.sh"                "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/diff.sh"                    "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/package_branch.sh"          "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/session.sh"                 "$context_dir/" || return 1
# docs/
cp -r "$repo_root/docs/architecture" "$context_dir/docs/architecture" || return 1
cp -r "$repo_root/docs/concepts"     "$context_dir/docs/concepts"     || return 1
```

**`build_context_agent`** — 4 files + docs:

```bash
_build_context_copy "$repo_root/libs/provider-entrypoint.sh"     "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/dirs.sh"                    "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/package_diff.sh"            "$context_dir/" || return 1
_build_context_copy "$repo_root/libs/session.sh"                 "$context_dir/" || return 1
# docs/
cp -r "$repo_root/docs/architecture" "$context_dir/docs/architecture" || return 1
cp -r "$repo_root/docs/concepts"     "$context_dir/docs/concepts"     || return 1
```

### 2. `libs/sandbox.Dockerfile`

Replace COPY destinations and add docs COPY:

```dockerfile
COPY sandbox-entrypoint.sh /opt/sandbox/bin/sandbox-entrypoint.sh
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY snapshot.sh /opt/sandbox/lib/snapshot.sh
COPY diff.sh /opt/sandbox/lib/diff.sh
COPY package_branch.sh /opt/sandbox/lib/package_branch.sh
COPY session.sh /opt/sandbox/lib/session.sh
COPY docs/ /opt/sandbox/docs/
RUN chmod +x /opt/sandbox/bin/sandbox-entrypoint.sh
```

Update ENTRYPOINT:
```dockerfile
ENTRYPOINT ["/opt/sandbox/bin/sandbox-entrypoint.sh"]
```

Remove old `RUN chmod +x /usr/local/bin/sandbox-entrypoint.sh` and old COPY lines.

### 3. `libs/sandbox-entrypoint.sh`

Update 3 source paths (lines 39, 57, 93):

| Old | New |
|---|---|
| `source /libs/dirs.sh` | `source /opt/sandbox/lib/dirs.sh` |
| `source /libs/snapshot.sh` | `source /opt/sandbox/lib/snapshot.sh` |
| `source /libs/diff.sh` | `source /opt/sandbox/lib/diff.sh` |

### 4. `scripts/dry_run.sh` (line 28)

| Old | New |
|---|---|
| `source /libs/dirs.sh` | `source /opt/sandbox/lib/dirs.sh` |

### 5. `providers/*/provider.Dockerfile` (x4: pi, opencode, hermes, claude-code)

All four get the same changes:

```dockerfile
# Old COPY lines:
COPY dirs.sh /libs/dirs.sh
COPY provider-entrypoint.sh /usr/local/bin/provider-entrypoint.sh

# New COPY lines:
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY provider-entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY session.sh /opt/sandbox/lib/session.sh
```

Add ENV PATH before ENTRYPOINT:
```dockerfile
ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "<provider>"]
```

Replace existing ENTRYPOINT line entirely. Keep all other lines.

### 6. `agent/prompts/package-diff.md`

6 occurrences of `bash ~/sandbox/libs/package_diff.sh` → `bash /opt/sandbox/lib/package_diff.sh`:

| Line | Old | New |
|---|---|---|
| 16 | `bash ~/sandbox/libs/package_diff.sh` | `bash /opt/sandbox/lib/package_diff.sh` |
| 24 | `bash ~/sandbox/libs/package_diff.sh --all` | `bash /opt/sandbox/lib/package_diff.sh --all` |
| 32 | `bash ~/sandbox/libs/package_diff.sh --baseline=<sha>` | `bash /opt/sandbox/lib/package_diff.sh --baseline=<sha>` |
| 40 | `bash ~/sandbox/libs/package_diff.sh --session-summary=...` | `bash /opt/sandbox/lib/package_diff.sh --session-summary=...` |
| 41 | `bash ~/sandbox/libs/package_diff.sh --all --session-summary=...` | `bash /opt/sandbox/lib/package_diff.sh --all --session-summary=...` |
| 42 | `bash ~/sandbox/libs/package_diff.sh --baseline=... --session-summary=...` | `bash /opt/sandbox/lib/package_diff.sh --baseline=... --session-summary=...` |

### 7. `agent/prompts/package-branch.md`

1 occurrence (line 14):

| Old | New |
|---|---|
| `bash ~/sandbox/libs/package_branch.sh --session-summary=add_format_patch_support` | `bash /opt/sandbox/lib/package_branch.sh --session-summary=add_format_patch_support` |

### 8. `agent/prompts/agent-sandbox.md` (line 4)

| Old | New |
|---|---|
| `in this project's \`docs/\` folder` | `in \`/opt/sandbox/docs/\`` |

### 9. `libs/package_diff.sh` — usage comment (line 35)

| Old | New |
|---|---|
| `#   bash ~/sandbox/libs/package_diff.sh [--baseline=<sha>] [--name=<label>]` | `#   bash /opt/sandbox/lib/package_diff.sh [--baseline=<sha>] [--name=<label>]` |

### 10. `tests/test_capability_layer.sh` (lines 127-136)

Update 4 path assertions:

| Old | New |
|---|---|
| `-f /usr/local/bin/sandbox-entrypoint.sh` | `-f /opt/sandbox/bin/sandbox-entrypoint.sh` |
| `-f /libs/snapshot.sh` | `-f /opt/sandbox/lib/snapshot.sh` |
| `-f /libs/diff.sh` | `-f /opt/sandbox/lib/diff.sh` |
| `-f /libs/dirs.sh` | `-f /opt/sandbox/lib/dirs.sh` |

### 11. `tests/test_build_context.sh` (lines ~152-169)

Sandbox context: add assertions for `package_branch.sh` and `session.sh`; update file count from 4 to 7 (excluding docs/).

Agent context: add assertions for `package_diff.sh` and `session.sh`; update file count from 2 to 4 (excluding docs/).

```bash
# sandbox context — 7 files + docs/
assert_file_exists  "sandbox: contains sandbox-entrypoint.sh" "$context/sandbox-entrypoint.sh"
assert_file_exists  "sandbox: contains dirs.sh"               "$context/dirs.sh"
assert_file_exists  "sandbox: contains snapshot.sh"           "$context/snapshot.sh"
assert_file_exists  "sandbox: contains diff.sh"               "$context/diff.sh"
assert_file_exists  "sandbox: contains package_branch.sh"     "$context/package_branch.sh"
assert_file_exists  "sandbox: contains session.sh"            "$context/session.sh"
assert_file_exists  "sandbox: contains docs/architecture"     "$context/docs/architecture"
assert_file_exists  "sandbox: contains docs/concepts"         "$context/docs/concepts"
assert_dir_file_count "sandbox: contains at least 6 files"    "$context" 6

# agent context — 4 files + docs/
assert_file_exists    "agent: contains dirs.sh"               "$context/dirs.sh"
assert_file_exists    "agent: contains provider-entrypoint.sh" "$context/provider-entrypoint.sh"
assert_file_exists    "agent: contains package_diff.sh"        "$context/package_diff.sh"
assert_file_exists    "agent: contains session.sh"             "$context/session.sh"
assert_file_absent    "agent: does not contain sandbox scripts" "$context/sandbox-entrypoint.sh"
assert_file_absent    "agent: does not contain snapshot.sh"    "$context/snapshot.sh"
assert_file_absent    "agent: does not contain diff.sh"        "$context/diff.sh"
assert_dir_file_count "agent: contains at least 4 files"       "$context" 4
```

---

## Files with no change needed

| File | Why unchanged |
|---|---|
| `libs/diff.sh` | Already uses BASH_SOURCE-relative path for sourcing `package_branch.sh` |
| `libs/package_diff.sh` | Already uses `SCRIPT_DIR`-relative path for `session.sh` |
| `libs/package_branch.sh` | Already uses `SCRIPT_DIR`-relative path for `session.sh` |
| `libs/session.sh` | Sourced by siblings via relative path only |
| `libs/diff_workflow.sh` | Host-side only, never invoked inside container |
| `libs/draft_workflow.sh` | Host-side only, never invoked inside container |
| `libs/compose.sh` | Host-side only, never invoked inside container |
| `libs/_templates/` | Host-side only |
| `libs/docker-compose.yml` | Host-side only |
| `libs/docker-compose.dry-run.yml` | Host-side only |
| `scripts/` (excluding `dry_run.sh`) | Host-side only |
| All other `agent/prompts/` files | No container-path references |

---

## Files needing update but out of scope

| File | Issue | Note |
|---|---|---|
| `agent/prompts/defer.md` | References `docs/operations/iteration_policy.md` — not baked into image | Pre-existing concern; all prompt templates rely on sandbox `docs/` for agent-sandbox itself |
| `agent/prompts/wrapup.md` | Same | Same |
| `agent/prompts/new-session.md` | Same | Same |
| `agent/prompts/new-session-v2.md` | Same | Same |

These prompt templates reference agent-sandbox policy docs by project-relative path and are only resolvable when the project IS agent-sandbox (dogfooding). Fixing them would require baking operation policies into docs/ or restructuring how workflow prompts resolve documentation — deferred to future session.

---

## Acceptance criteria (proposed)

1. `docker build` of sandbox image exits 0; `docker run --rm --entrypoint test <sandbox-image> -f /opt/sandbox/bin/sandbox-entrypoint.sh` exits 0
2. Same for `/opt/sandbox/lib/dirs.sh`, `/opt/sandbox/lib/snapshot.sh`, `/opt/sandbox/lib/diff.sh`, `/opt/sandbox/lib/package_branch.sh`, `/opt/sandbox/lib/session.sh`
3. Same for agent image: `/opt/sandbox/lib/dirs.sh`, `/opt/sandbox/lib/package_diff.sh`, `/opt/sandbox/lib/session.sh`, `/opt/sandbox/bin/provider-entrypoint.sh`
4. Agent image has `/opt/sandbox/docs/architecture/` and `/opt/sandbox/docs/concepts/` directories
5. `sandbox-entrypoint.sh` source paths match `/opt/sandbox/lib/...` (verified by test)
6. `scripts/run_tests.sh` (or `make test`) exits 0 with all test assertions updated
7. `grep -rn 'source /libs/' libs/ scripts/` returns 0 results (no stale hardcoded `/libs/` paths in runtime scripts)
