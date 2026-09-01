# Agent Handover

**Date:** 2026-05-25
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Housekeeping
**Status:** Active

## Objective

Survey the current file tree structure (`libs/`, `scripts/`, `agent/`, `providers/`) to inform the upcoming structural cleanup spec — no file changes, no path substitutions, purely an orientation pass.

## Scope

**In scope:** Information gathering — map existing files, understand what each file does, which build contexts reference them, and how the proposed `harness/` tree would relate to the current structure. This session produces no code changes.

**Out of scope:** Any actual file moves, path substitutions, or structural changes. The chore session's spec must be agreed before any file changes are made.

## Carried forward

None.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`libs/`](../libs/) | Primary source of files slated for the `harness/` tree |
| [`scripts/`](../scripts/) | Contains entrypoints and build pipeline; some files may move |
| [`agent/`](../agent/) | Provider workflow files; may be partially affected |
| [`providers/*/`](../providers/) | Provider-specific files; reference point for build context |
| [`story_container_layer_model.md`](story_container_layer_model.md) | Proposed target structure for harness/ tree |
| [`spec_container_layer_redesign.md`](spec_container_layer_redesign.md) | Implementation sequence, audit findings, deferred decisions |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| **Directory model: `src/` tree with `libs/`, `reasoning/`, `capability/`, `scripts/`, `build/`** | Flat tree avoids unnecessary nesting; deployment target is primary split, life stage secondary | `spec_container_layer_redesign.md rule 7` |
| **`package_branch.sh` and `package_diff.sh` → `src/libs/`** | Both are cross-target (host exec + container). Co-located for consistency. | rule 7.5 Q1 |
| **`compose.sh` and `containers.sh` → `src/build/`** | Pure build pipeline code — paired with compose templates | rule 7.5 Q2, Q5 |
| **`snapshot.sh` → `src/libs/` whole (no split)** | Host and capability both use it. Not worth splitting now. | rule 7.5 Q4 |
| **Provider host-side files → nested under `src/reasoning/providers/<n>/`** | Provider-owned files stay with provider, even when host-executed | rule 7.5 Q3 |
| **`devlog/` → root level** | Agent development history is not project documentation | rule 7.1 |
| **`harness/` rejected** | Unnecessary nesting; files go directly into their deployment target directory | rule 7.1 |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|---|
| Handover file not in packaged diff. Root cause chain: (1) `/opt/sandbox/lib/package_diff.sh` failed at line 33 because it sources `diff.sh` which is not deployed to the reasoning container — only the capability container has it. (2) Fell back to `git diff HEAD` which skips untracked files (the handover is new). (3) `make apply` applied the incomplete diff, missing the handover. This is part of a broader structural bug: `package_diff.sh` (reasoning layer) sources `diff.sh` — a file that doesn't exist in the reasoning image. It works on the host because all libs/ files are co-located there, but fails inside the container. | Bug | Packaging from inside the reasoning container is broken. The `diff.sh` dependency of `package_diff.sh` must be resolved before container-side packaging can work. For future packages: use `git diff HEAD` with explicit `git add -N` for untracked files, or produce the diff from the host side. |

## Completed this session

| File | Change |
|---|---|
| [`spec_container_layer_redesign.md`](../discussions/spec_container_layer_redesign.md) | Added rule 7 with full directory model: 36 files assigned to new paths, 8 unresolved questions resolved to 0, dependency-trace-based rationale for every placement. |

## Deferred items

- Actual implementation of the structural cleanup (file moves, path substitutions, reference updates) — requires spec to be confirmed and an implementation session to be opened.

## Next session

Sub-milestone: M2.7 — Session Identity and Harness Versioning
Trigger B: Not run (mid-milestone, no sub-milestone completed)

**Conclusions from this session:** The directory model for the structural cleanup has been agreed:
- `src/libs/` — cross-target libs (dirs, session, routing, diff, snapshot, package_branch, package_diff)
- `src/reasoning/` — agent container (providers/<n>/, agent/, provider-entrypoint.sh, Dockerfiles)
- `src/capability/` — sandbox container (Dockerfile.sandbox, sandbox-entrypoint.sh)
- `src/scripts/` — host-level orchestration (all CLI entrypoints, workflow scripts, templates)
- `src/build/` — build pipeline code (compose templates, compose.sh, containers.sh)
- `devlog/` — moved from docs/devlog/ to root
- All 36 files from libs/, scripts/, providers/, agent/ have been assigned a destination in the assignment table
- All 5 open questions were resolved during the session
- The spec document (`spec_container_layer_redesign.md`) contains the complete model
- Next session: implementation of the structural cleanup (file moves + path substitutions)
