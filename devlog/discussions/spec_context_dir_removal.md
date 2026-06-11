# Spec: Build Context Simplification

**Status:** Draft for operator review
**Relates to:** M2.7 Track B — Context_dir removal
**Supersedes:** `src/build/context.sh` (entire file), `build_image()` in `scripts/build.sh`
**Prerequisite for:** Two-sig model (container-sig label)

## Problem

The build pipeline uses a temp-dir assembly mechanism (`build_context_sandbox`, `build_context_agent`, `build_image`) that copies individual files from the repo into a temporary directory, then passes that temp dir to `docker build`. This introduces:

- **Two-list drift** — the set of files copied by `build_context_*` must match the `COPY` instructions in the Dockerfile. If they diverge, the build fails at the COPY step despite the assembly succeeding.
- **Unnecessary complexity** — 70 lines of context assembly, temp dir cleanup, and `context_digest()` that have no behavioural effect beyond what the Dockerfile already specifies.
- **Validation overhead** — ~500 lines of tests (`test_build_context.sh`) that test the assembly logic, not the actual invariant (every COPY source exists).

## Proposed change

**Use repo root as Docker build context.** Dockerfile `COPY` instructions use **repo-relative paths** with **entire subdirectory copies** where the subdirectory boundary is clean enough, and single-file `COPY` for the few files that live in directories with unrelated content.

The build context will contain the entire repo. `docs/development/` and `docs/operations/` will ship into images (they're already shipped via the `COPY docs/ /opt/sandbox/docs/` line in the sandbox Dockerfile), but this is harmless — they're small `.md` files and have been shipping anyway.

### What changes

| Component | Change |
|---|---|
| `src/build/context.sh` | **Delete** — entire file removed (no consumers after build.sh is updated) |
| `scripts/build.sh` | Remove `source ... build/context.sh`, remove `build_image()`, remove `cleanup_build_context()`, remove `_BUILD_CONTEXT_DIRS` tracking, remove `context` temp-dir calls in `build_agent()` and `build_sandbox()`, remove `context_digest` label in docker build. Replace with direct `docker build` using `$repo_root` as context. |
| All Dockerfiles | Rewrite `COPY` instructions from flat temp-dir paths to repo-relative paths |

### Dockerfile rewrites

#### `src/capability/dockerfile` — Sandbox image

Replace 10 individual COPY lines with subdirectory copies:

```dockerfile
# Before (flat — expects files in temp-dir root):
COPY entrypoint.sh /opt/sandbox/bin/sandbox-entrypoint.sh
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY snapshot.sh /opt/sandbox/lib/snapshot.sh
COPY diff.sh /opt/sandbox/lib/diff.sh
COPY diff_export.sh /opt/sandbox/lib/diff_export.sh
COPY session_state.sh /opt/sandbox/lib/session_state.sh
COPY routing.sh /opt/sandbox/lib/routing.sh
COPY package_branch.sh /opt/sandbox/lib/package_branch.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY docs/ /opt/sandbox/docs/

# After (repo-relative — expects repo root as context):
COPY src/libs/                  /opt/sandbox/lib/
COPY src/capability/entrypoint.sh /opt/sandbox/bin/sandbox-entrypoint.sh
COPY src/capability/snapshot.sh   /opt/sandbox/lib/snapshot.sh
COPY docs/architecture/         /opt/sandbox/docs/architecture/
COPY docs/concepts/             /opt/sandbox/docs/concepts/
```

**Analysis of extras:**
- `src/libs/` → 9 files total (7 needed + `common.sh`, `draft_state.sh` — both inert, never sourced)
- `src/capability/entrypoint.sh` and `snapshot.sh` → only the 2 target files copied by name
- `src/capability/` as a dir would include the `dockerfile` itself — harmless but unnecessary. Single-file COPY avoids it.
- `docs/architecture/` and `docs/concepts/` → exact subset, clean

#### `providers/pi/provider.dockerfile` — Pi agent image

```dockerfile
# Before:
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY provider-preflight.sh /opt/sandbox/bin/provider-preflight.sh
COPY diff.sh /opt/sandbox/lib/diff.sh
COPY diff_export.sh /opt/sandbox/lib/diff_export.sh
COPY session_state.sh /opt/sandbox/lib/session_state.sh
COPY routing.sh /opt/sandbox/lib/routing.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY package_branch.sh /opt/sandbox/lib/package_branch.sh
COPY agent/skills/ /opt/workflow/agent/skills/
COPY agent/prompts/ /opt/workflow/agent/prompts/
COPY agent/config/ /opt/workflow/agent/config/

# After:
COPY src/libs/                              /opt/sandbox/lib/
COPY src/reasoning/entrypoint.sh            /opt/sandbox/bin/provider-entrypoint.sh
COPY src/reasoning/providers/pi/preflight.sh /opt/sandbox/bin/provider-preflight.sh
COPY src/reasoning/agent/skills/             /opt/workflow/agent/skills/
COPY src/reasoning/agent/prompts/            /opt/workflow/agent/prompts/
COPY src/reasoning/providers/pi/config/      /opt/workflow/agent/config/
COPY docs/architecture/                      /opt/sandbox/docs/architecture/
COPY docs/concepts/                          /opt/sandbox/docs/concepts/
```

**Analysis of extras:**
- `src/libs/` → same as sandbox, 2 extra inert files
- `src/reasoning/entrypoint.sh` → single file, no extras
- `src/reasoning/providers/pi/preflight.sh` → single file, no extras
- `src/reasoning/agent/skills/` → skills dir (all needed, no extras)
- `src/reasoning/agent/prompts/` → prompts dir (all needed)
- `src/reasoning/providers/pi/config/` → config dir (all needed)

#### `providers/hermes/provider.dockerfile` — Hermes agent image

Same structure as Pi but without `config/` or `preflight.sh`:

```dockerfile
COPY src/libs/                              /opt/sandbox/lib/
COPY src/reasoning/entrypoint.sh            /opt/sandbox/bin/provider-entrypoint.sh
COPY src/reasoning/agent/skills/             /opt/workflow/agent/skills/
COPY src/reasoning/agent/prompts/            /opt/workflow/agent/prompts/
COPY docs/architecture/                      /opt/sandbox/docs/architecture/
COPY docs/concepts/                          /opt/sandbox/docs/concepts/
```

#### `providers/opencode/provider.dockerfile` — OpenCode agent image

Identical to Hermes:

```dockerfile
COPY src/libs/                              /opt/sandbox/lib/
COPY src/reasoning/entrypoint.sh            /opt/sandbox/bin/provider-entrypoint.sh
COPY src/reasoning/agent/skills/             /opt/workflow/agent/skills/
COPY src/reasoning/agent/prompts/            /opt/workflow/agent/prompts/
COPY docs/architecture/                      /opt/sandbox/docs/architecture/
COPY docs/concepts/                          /opt/sandbox/docs/concepts/
```

#### Base Dockerfiles (`pi/base.dockerfile`, `hermes/base.dockerfile`, `opencode/base.dockerfile`, `node.dockerfile`)

**No COPY changes needed** — these already don't COPY harness files. They only contain `RUN`, `ENV`, `WORKDIR`, `USER`. The one exception is `hermes/base.dockerfile` which uses `COPY --from=builder` — this is a multi-stage build pattern, not a repo file copy. Unaffected.

### `scripts/build.sh` changes

```bash
# Remove these:
source "$REPO_ROOT/src/build/context.sh"     # line 18 — whole file deleted
_BUILD_CONTEXT_DIRS=()                       # line 28
cleanup_build_context() { ... }              # lines 32-37
build_image() { ... }                        # lines 43-62 — replaced with inline docker build

# In build_agent(), replace:
context="$(build_context_agent "$repo_root" "$provider")"
_BUILD_CONTEXT_DIRS+=("$context")
# ...with: nothing (use $repo_root as context)
#
# In build_sandbox(), replace:
context="$(build_context_sandbox "$repo_root")"
_BUILD_CONTEXT_DIRS+=("$context")
# ...with: nothing (use $repo_root as context)
#
# In build_if_missing() and build_image() calls, replace:
#   build_image "$image" "$dockerfile" "$context_dir" "$cache_flag" "$@"
# with:
#   docker build $no_cache -t "$image" -f "$dockerfile" "$repo_root" "$@"
#   (Tier 1 already uses $repo_root as context — stays the same)
#
# Remove trap cleanup_build_context EXIT lines from both functions.

# Tier 1 already uses $repo_root and stays unchanged.
# Tiers 2 and 3 currently pass "$context"; change to "$repo_root".
```

The `--label "agent-sandbox.digest=$digest"` line in `build_image()` is also removed — this label was computed on the temp-dir context. The two-sig model (next session) will add the proper container-sig label at Dockerfile level.

### Test changes

Replace `tests/test_build_context.sh` (~496 lines, 11 tests for temp-dir assembly) with a **COPY contract test**:

- For each Dockerfile in `src/` that has `COPY` instructions, extract the source paths
- Assert each source path exists in the repo at that relative path
- Also scan all `COPY` targets to ensure there are no `dockerfile` references or other artefacts that imply old flat-context paths

This eliminates the test surface from ~500 lines to ~30 lines while testing the actual invariant: every COPY source exists.

### `.dockerignore`

No changes needed. The current build has no `.dockerignore` (file doesn't exist). A future `.dockerignore` could exclude `docs/development/`, `docs/operations/`, `devlog/`, `tests/`, `node_modules/` if build context size becomes a concern, but for now the repo is small enough that the extra context is negligible.

## Drift and maintenance analysis

Before this change:
| Action | Places to update |
|---|---|
| Add a new lib file | `build_context_*()` in `context.sh` + Dockerfile COPY + tests |
| Remove a lib file | Same, reversed |
| Rename a lib | Same |

After this change:
| Action | Places to update |
|---|---|
| Add a new lib file | Dockerfile COPY only (single file, or falls into existing subdir) |
| Remove a lib file | Dockerfile COPY only (or nothing if subdir copy) |
| Rename a lib | Dockerfile COPY only |

The `src/libs/` directory is copied as a whole, so adding/removing files there needs zero Dockerfile changes. Only single-file COPY entries (`entrypoint.sh`, `snapshot.sh`, `preflight.sh`) need updating when they move or rename.

## What deletion removes

| File | Lines | Reason |
|---|---|---|
| `src/build/context.sh` | 112 | Entire file — functions moved to inline |
| `build_image()` in `scripts/build.sh` | ~20 | Replaced with inline `docker build` |
| `cleanup_build_context()`, `_BUILD_CONTEXT_DIRS` | ~10 | No more temp dirs |
| `tests/test_build_context.sh` | ~496 | Replaced with COPY contract tests (~30 lines) |
| **Total deletions** | **~638 lines** | |

## What this unblocks

1. **Two-sig model** — container-sig can be added at Dockerfile level via `LABEL` with a hash computed at build time. No temp-dir interference.
2. **Faster builds** — no file copy step before each build, Docker daemon reads directly from repo (cached by the filesystem).
3. **Simpler debugging** — inspect the build context by looking at the repo, not at a throwaway temp dir.

## Acceptance criteria

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | `src/build/context.sh` does not exist | `ls src/build/context.sh` returns non-zero |
| 2 | `scripts/build.sh` does not source `context.sh` | `grep -c "source.*context.sh" scripts/build.sh` = 0 |
| 3 | `scripts/build.sh` has no reference to `build_context_sandbox` or `build_context_agent` | `grep -c "build_context_" scripts/build.sh` = 0 |
| 4 | `scripts/build.sh` has no `build_image` function | `grep -c "^build_image" scripts/build.sh` = 0 |
| 5 | All Dockerfiles use repo-relative COPY paths (no flat filenames like `COPY entrypoint.sh`) | For each Dockerfile: grep `"^COPY "` shows only paths under `src/` or `docs/` |
| 6 | `$repo_root` is used as context for all `docker build` calls in build.sh | Manual review of `docker build` lines |
| 7 | COPY contract tests pass: every COPY source in every Dockerfile exists at its repo-relative path | `bash tests/test_build_context.sh` exits 0 |
| 8 | No `agent-sandbox.digest` Docker label is set (removed with `build_image`) | `grep -r "agent-sandbox.digest" src/` returns empty |
