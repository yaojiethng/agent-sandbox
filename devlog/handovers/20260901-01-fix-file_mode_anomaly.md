# Agent Handover

**Date:** 2026-09-01
**Milestone:** M2.6 - Session Persistence (standalone infrastructure fix)
**Type:** fix
**Status:** Closed

## Objective

Resolve the recurring bug where every new agent container materialised a
working tree with `+x` (755/777) on ~346 non-executable files, producing
mode-only `git status` churn in the container (incl. `.md`/`.json`).

## Scope

Root-cause the working-tree mode mutation seen in-container, attribute it to a
concrete layer, fix at the source, and sweep documentation that presumes a
host-repo `core.fileMode` setting.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Root cause identified and attributed to a concrete layer, evidenced by reproducible commands | **done** - host tree spurious `+x` + host/container `core.fileMode` asymmetry |
| AC2 | Fix applied at the source layer so a fresh container/checkout no longer carries `+x` on non-executables | **done (operator)** - host tree normalised + host `core.fileMode=true`; no harness code change needed |
| AC3 | A freshly materialised tree shows zero mode-only deltas vs the baseline commit | **done** - container reset; `git status` empty, worktree 595x 644 + 5x 755 matching the index |
| AC4 | Host-`fileMode` presumptions cleaned from documentation | **done** - `AGENT_FEEDBACK` `[A] 2026-08-10` claim corrected + dated post-edit annotation; code comments confirmed accurate (kept) |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/start_agent.sh` | sets `core.fileMode` in `WORKTREE_DIR` from `filesystem_tracks_exec_bits` |
| `src/capability/snapshot.sh` | Layer-2 `rsync -a` overlay + KNOWN ISSUE block on exec-bit handling |
| `devlog/AGENT_FEEDBACK.md` | `[A] 2026-08-10` entry - the presumptive host-repo `core.filemode=false` claim; corrected this iteration |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `--no-p` overlay hardening proposed then **retracted**; no harness code change taken | would regress exec fidelity (untracked executables) and mask host-side corruption; host fix is the correct layer | this handover |
| Host repo `core.fileMode=true` to match the container's `true` (kill the asymmetry) | both gits agree on exec-bit truth; prevents host `git status` masking the tree | operator-actioned |

## Findings

| Finding | Type | Impact |
|---|---|---|
| **Root mechanism: the `rsync -a` Layer-2 overlay in `snapshot_init_git` preserves the operator's on-disk host modes into every new container's working tree.** `src/capability/snapshot.sh` does `git archive HEAD` -> `baseline.tar` (correct index modes 644/755 -> baseline commit), then overlays the operator's tree via `rsync -a --delete "$SNAPSHOT_DIR/" "$SANDBOX_DIR/"`. `-a` includes `-p` (preserve perms), so the agent's working tree is overwritten with the host on-disk modes. Worktree was 326x 777 + 248x 644 + 25x 755 vs index 594x 100644 + 5x 100755 (~346 spurious `+x`). Index/commit modes were correct, so the repo layer is healthy. | bug | current iteration |
| **Why the host did not see it: host repo ran `core.fileMode=false`, masking the 777; the container sets `core.fileMode=true` (via `filesystem_tracks_exec_bits` capability probe) and surfaced it.** Two git repos disagreed over the same tree. The corruption lived on the host disk (777 on non-executables); the container's exec-aware git reported what the host's exec-ignoring git masked. | bug | current iteration |
| **`--no-p` on the overlay considered and rejected** (retracted): would regress exec fidelity for executables and mask host corruption rather than surface it. The harness deliberately reports exec-bit truth via `core.fileMode=true`. | steering | current iteration |

## Postmortem (user-actioned host-side fix)

**Symptom:** every new agent container showed 346 mode-only working-tree changes
(644 -> 755/777), including `.md`/`.json` where `+x` is meaningless; `git status`
churn identical across runs.

**Diagnosis (container view):** the container's git ran `core.fileMode=true` over an
index that was correct (594x 644 + 5x 755) and a working tree carrying ~346 spurious
`+x`. The `rsync -a` overlay preserved the operator's host on-disk modes into the
volume. The harness code, repo index, and dockerfile were all exonerated (no recursive
`chmod` in `scripts/`+`src/`; `git archive` produced correct baseline modes; nothing
in-container invents 777).

**Root cause (host + git-config asymmetry):** the host check-out physically carried `+x`
(777) on ~346 non-executable tracked files, and the host repo's `core.fileMode=false`
made host `git status` ignore it - so the host looked clean while the container (which
forces `core.fileMode=true` from `filesystem_tracks_exec_bits`) reported the truth. Same
tree, two git configs, two verdicts.

**Resolution (operator):** normalised host tree exec bits (strip `+x` on tracked 644,
keep/restore on 755 - `fix_exec_bits` logic) and set host `core.fileMode=true`, then reset
the container. Verified: `git status` empty; worktree 595x 644 + 5x 755 now matches the
index. No harness code change required.

**Takeaways:** (1) a host repo passed to the harness should run `core.fileMode=true` so
host and container git agree - git auto-writes `true` on exec-capable filesystems at
clone, but network/exotic mounts can silently set `false` and re-create the asymmetry;
(2) spurious `+x` on the host tree is host-side checkout/extraction hygiene, not a
harness defect; (3) the container's `filesystem_tracks_exec_bits` capability gating is
correct and should be left as-is.

## Completed

| File | one-line change summary |
|---|---|
| `devlog/handovers/20260901-01-fix-file_mode_anomaly.md` | diagnosis + postmortem + decision/finding record (this handover) |
| `devlog/AGENT_FEEDBACK.md` `[A] 2026-08-10` | corrected stale host `core.filemode=false` claim to the host/container asymmetry diagnosis; added `[Post-edit annotation -- 2026-09-01]` |

## Deferred items

None.

## What's Next

Sub-milestone unchanged (M2.6 - Session Persistence).

Watch-outs:
- Closed historical handover `20260810-13` still records the host `core.filemode=false`
  claim - accurate at the time; left as a session record (not edited). The
  `AGENT_FEEDBACK` annotation and this handover are the corrected record chain.
- The container `core.fileMode` gating (`filesystem_tracks_exec_bits`) and the
  `rsync -a` overlay are correct and must not be `--no-p`-ed.