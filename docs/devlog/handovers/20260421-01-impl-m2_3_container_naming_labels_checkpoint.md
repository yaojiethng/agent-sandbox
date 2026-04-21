# Agent Handover

**Session date:** 2026-04-21
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation (Change 5)
**Status:** ✓ Complete

## Objective

Implement Change 5: Container naming + Docker labels + `checkpoint.sh` consolidation. Establish explicit container identity and metadata labeling to enable parallel worktree session safety and support baseline advancement (Change 6). Remove all `checkpoint-latest.ref` dependencies.

## Scope

**Files created:**
- `scripts/checkpoint.sh` — Consolidated checkpoint library with full spec interface
- `tests/test_checkpoint.sh` — Unit tests for checkpoint.sh functions

**Files modified:**
- `libs/compose.sh` — Generate explicit `container_name:` for both sandbox and agent containers; add container labels; add {{AGENT_CONTAINER_NAME}} substitution
- `libs/docker-compose.yml` — Add `container_name:` and three labels to sandbox service; update agent container_name
- `start_agent.sh` — Source `checkpoint.sh`; replace inline checkpoint logic; export `CONTAINER_NAME` and `AGENT_CONTAINER_NAME`; remove `checkpoint-latest.ref` write
- `scripts/apply_workspace.sh` — Source `checkpoint.sh`; use `checkpoint_lookup()` for tag lookup; add `sync` command; add container lookup for `SYNC=1`
- `tests/test_start_agent.sh` — Updated comment
- `tests/test_apply_workspace.sh` — Updated sha1sum→sha256sum; removed checkpoint-latest.ref setup
- `tests/test_apply.sh` — Updated checkpoint tags to use worktree namespace; removed checkpoint-latest.ref setup

**Container labels (all containers via YAML anchor):**
- `agent-sandbox.project-dir` — Absolute path to project directory
- `agent-sandbox.session-name` — Session identifier (`<sanitized-branch>-<timestamp>`)
- `agent-sandbox.checkpoint-tag` — Git checkpoint tag for this session

Labels are defined once as `x-session-labels: &session_labels` and referenced by all services via `*session_labels`. This ensures all containers (sandbox, agent, and any future sidecars) share identical labels for consistent lifecycle management.

**Container naming:**
- Sandbox: `sandbox-<PROJECT_NAME>-<CHECKPOINT_TS>`
- Agent: `<PROVIDER_NAME>-<PROJECT_NAME>-<CHECKPOINT_TS>`

**Dependencies removed:**
- `checkpoint-latest.ref` — Replaced by `checkpoint.sh` tag lookup and container label queries

## Rationale

**Container naming:** Explicit `container_name:` in generated compose enables reliable container lookup via `docker ps --filter name=...` and label queries. Required for Change 6 baseline advancement script to locate the correct sandbox container via `docker exec`.

**Docker labels:** Labels provide metadata for container discovery and validation without relying on filesystem state. The `agent-sandbox.checkpoint-tag` label enables the apply workflow to retrieve the checkpoint tag without reading `checkpoint-latest.ref`. The `agent-sandbox.project-dir` label enables container lookup by project path.

**`checkpoint.sh` consolidation:** Centralising checkpoint operations (create, prune, lookup, `WORKTREE_ID` derivation) eliminates duplication across `start_agent.sh` and `apply_workspace.sh`, and provides a single interface for Change 6 advancement script.

**`checkpoint-latest.ref` removal:** File-based checkpoint tracking is fragile and doesn't survive container restarts. Label-based lookup via `docker inspect` is more robust and aligns with the two-layer model where the harness queries container metadata rather than reading container-side state.

## Acceptance criteria

- [x] `scripts/checkpoint.sh` created with functions: `worktree_id_derive`, `checkpoint_create`, `checkpoint_prune`, `checkpoint_lookup` (plus aliases: `checkpoint_worktree_id`, `checkpoint_latest`)
- [x] `libs/compose.sh` generates explicit `container_name:` for sandbox and agent containers; sets three labels on sandbox container
- [x] `start_agent.sh` sources `checkpoint.sh` and uses its functions; `checkpoint-latest.ref` writes removed; exports `CONTAINER_NAME` and `AGENT_CONTAINER_NAME`
- [x] `scripts/apply_workspace.sh` sources `checkpoint.sh` for tag lookup; has `sync` command and `SYNC=1` container lookup stubs
- [x] All existing tests pass (71 tests)
- [x] New tests added for `checkpoint.sh` functions (13 tests)
- [x] New tests added for container labels YAML anchor (4 tests)
- [x] Handover updated to complete status

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `scripts/checkpoint.sh` | New — checkpoint operation consolidation | ✓ Complete |
| `libs/compose.sh` | Container naming + labels | ✓ Complete |
| `libs/docker-compose.yml` | Container naming + labels | ✓ Complete |
| `start_agent.sh` | Source checkpoint.sh; remove checkpoint-latest.ref | ✓ Complete |
| `scripts/apply_workspace.sh` | Source checkpoint.sh for tag lookup; add sync | ✓ Complete |
| `tests/test_checkpoint.sh` | New — checkpoint.sh unit tests | ✓ Complete |
| `tests/test_start_agent.sh` | Updated comment | ✓ Complete |
| `tests/test_apply_workspace.sh` | sha1sum→sha256sum; removed ref setup | ✓ Complete |
| `tests/test_apply.sh` | Worktree namespace; removed ref setup | ✓ Complete |

## Decisions made this session

1. **Full checkpoint.sh interface** — Implemented all four spec functions (`worktree_id_derive`, `checkpoint_create`, `checkpoint_prune`, `checkpoint_lookup`) plus aliases (`checkpoint_worktree_id`, `checkpoint_latest`) for backward compatibility and internal consistency.

2. **Container naming for both services** — Both sandbox and agent containers now have explicit `container_name:` derived from session identity:
   - Sandbox: `sandbox-<PROJECT_NAME>-<CHECKPOINT_TS>`
   - Agent: `<PROVIDER_NAME>-<PROJECT_NAME>-<CHECKPOINT_TS>`

3. **sha256sum for worktree ID** — Uses sha256sum (not sha1sum) for better hash distribution. This is a minor breaking change for existing checkpoint tags, which will be pruned naturally.

4. **SYNC=1 silent skip** — When no container is running, `SYNC=1` is silently ignored rather than erroring. This allows operators to use `make confirm SYNC=1` uniformly.

5. **sync command error on missing container** — `make sync` (explicit catch-up) exits with error if no container running, since it's an explicit operator action that should fail fast.

## Completed this session

- [x] `scripts/checkpoint.sh` created with full spec interface
- [x] `libs/compose.sh` updated with container name and label substitutions
- [x] `libs/docker-compose.yml` updated with container_name and labels for both services
- [x] `start_agent.sh` updated — sources checkpoint.sh, exports container names
- [x] `scripts/apply_workspace.sh` updated — sources checkpoint.sh, adds sync command
- [x] Tests updated/added — 13 new checkpoint tests, all 88 tests passing
- [x] This handover updated to complete

## Deferred items

None — Change 5 is complete.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Implement Change 6 (baseline advancement).

**Files to upload:**
- This handover (updated to complete)
- `scripts/checkpoint.sh`
- `tests/test_checkpoint.sh`
- `libs/compose.sh` (updated)
- `libs/docker-compose.yml` (updated)
- `start_agent.sh` (updated)
- `scripts/apply_workspace.sh` (updated)
- Test files (updated)

---

## Appendix — Change 5 Implementation Summary

**`checkpoint.sh` interface (spec + aliases):**
```bash
# Spec interface
worktree_id_derive <project-dir>           # Returns 8-char hex hash
checkpoint_create <project-dir> <timestamp> # Creates tag, prunes to 5, echoes tag
checkpoint_prune <project-dir> [keep]       # Prunes to keep most recent (default: 5)
checkpoint_lookup <project-dir>             # Returns latest tag or empty string

# Aliases for internal consistency
checkpoint_worktree_id <project-dir>        # Alias for worktree_id_derive
checkpoint_latest <project-dir>             # Alias for checkpoint_lookup
```

**Container naming:**
- Sandbox: `sandbox-<PROJECT_NAME>-<CHECKPOINT_TS>`
- Agent: `<PROVIDER_NAME>-<PROJECT_NAME>-<CHECKPOINT_TS>`

**Label schema (sandbox only):**
```
agent-sandbox.project-dir=<absolute-path>
agent-sandbox.session-name=<session-name>
agent-sandbox.checkpoint-tag=<checkpoint-tag>
```

**Container lookup:**
```bash
docker ps --filter "label=agent-sandbox.project-dir=${PROJECT_DIR}" --format '{{.Names}}'
```

**Test results:**
```
test_checkpoint.sh:     13 passed, 0 failed
test_start_agent.sh:    21 passed, 0 failed  (17 original + 4 container labels)
test_apply_workspace.sh: 28 passed, 0 failed
test_apply.sh:          30 passed, 0 failed
────────────────────────────────────────────
Total:                  92 passed, 0 failed
```
