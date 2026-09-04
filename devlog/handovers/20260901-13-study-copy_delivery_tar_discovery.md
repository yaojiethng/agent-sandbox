# Handover 20260901-13 — study copy-delivery tar pipeline: layered discovery tests + delivery design docs

**Milestone:** M2.6 - Session Persistence
**Type:** study
**Status:** Closed
**Date:** 2026-09-01

## Objective

Operator-directed. The copy-delivery snapshot pipeline stages the working tree twice (rsync to
`.snapshot/`, then rsync into the sandbox volume) alongside a `baseline.tar`. Questions raised:

1. Is `.snapshot/` needed at all, and can staging move to tmp?
2. Can the two-artifact pipeline (rsync tree copy + `git archive HEAD` baseline) be replaced by a
   tar-only mechanism — one serialization, one extraction?
3. The deferred host-side volume-seed task (roadmap_future "Copy-Model Seeding", decision
   `20260818-02`) removes the RO mount entirely; its dependency (compose file-set mechanism) has
   since landed.

This iteration is **discovery, not implementation**: validate tar-only feasibility with layered
tests before any pipeline rewrite, and promote the two settled delivery-model design records to
maintained docs.

## Acceptance Criteria

- AC1: Discovery test layer 1 — file-list parity between the current pipeline output (rsync
  `snapshot_copy_worktree` + `git archive HEAD`) and the proposed tar-only method, across a
  fixture matrix (tracked / untracked / deleted / renamed / gitignored incl. nested / global
  excludesFile / `.git/info/exclude` / negation patterns / symlinks / exec bits / empty dirs /
  case-conflict / submodules). Divergences reported explicitly, not asserted away.
- AC2: Discovery test layer 2 — the proposed tar method builds an archive whose extraction
  reproduces the source tree exactly: file list, content hashes, modes, symlink targets.
- AC3: Discovery verdict recorded — does tar-only preserve the sandbox `git status` parity
  invariant (index=HEAD, worktree=on-disk) and exclusion correctness? Findings state the
  go/no-go and the open design decision(s) for implementation (index/worktree split mechanism,
  seed transport).
- AC4: Delivery design docs promoted: `docs/concepts/copy_delivery.md` (from
  `20260730-design-settled-copy_model.md`, updated: RO-mount marked current-until-seeding,
  host-side seed + tar-only as settled direction pending this discovery) and
  `docs/concepts/mount_delivery.md` (from `20260730-design-settled-mount_model.md`, stubbed:
  settled decisions kept, wired-not-runnable status kept, tar work out of scope). Both link the
  ADR `docs/adr/sandbox_delivery_model.md`; historical design records remain in
  `devlog/discussions/` cross-referenced.
- AC5: Roadmap updated — seeding task notes the discovery outcome; doc promotion recorded.

## Out of scope (this iteration)

- Seeding implementation, compose changes, entrypoint changes (next iteration if discovery passes).
- `snapshot_copy_files` / `snapshot_enumerate_files` deletion (rides with the impl iteration).
- Session-lifecycle doc extension + conceptual dispatch hub (operator plan note, below).

## Completed

| Task | Evidence |
|---|---|
| Discovery layer 1 -- file-list parity | `scripts/manual/discovery_tar_filelist_parity.sh`; 15-case fixture matrix; output in Findings |
| Discovery layer 2 -- tar round-trip fidelity | `scripts/manual/discovery_tar_roundtrip.sh`; lossless (list/hashes/modes/symlinks) |
| Delivery design docs promoted | `docs/concepts/copy_delivery.md`, `docs/concepts/mount_delivery.md`; registered in `project_index.md`; cross-linked from `sandbox_lifecycle.md`, `security.md` |
| Roadmap updated | `devlog/roadmap.md` new open item (host-side seed + git-enumerated tar); `devlog/roadmap_future.md` seeding entry updated with discovery outcome |
| Verification | ShellCheck clean on both discovery scripts; `run_tests.sh` 706 passed / 67 failed / 0 skipped — identical to the HEAD baseline in this environment (docker-dependent tests; verified via `git stash` comparison), no new failures |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Two promoted docs (copy + mount), not one combined | roadmap treats M2.6.5/M2.6.6 as separate paths with separate security models; a combined file blurs the delivery-aware entrypoint logic |
| D2 | ADR not created for delivery mechanism | `docs/adr/sandbox_delivery_model.md` already carries the why; promoted docs link to it. Verified content covers the two-axis decision; seed/tar mechanism is an implementation choice, not a new principle |
| D3 | Discovery tests standalone host-side scripts, no docker | layers 1-2 need only rsync/tar/git; layer 3 (volume seed e2e) belongs to the impl iteration |

## Findings

**F1 -- Go verdict on git-enumerated tar.** The proposed method (git ls-files enumeration ->
`tar --null -T`, extract once in-container) reproduces the current pipeline's semantics across
the whole fixture matrix. Round-trip is byte-lossless including modes and symlinks. The
index/worktree split (index=HEAD, worktree=disk) must be reconstructed in-container from the
seeded tree plus baseline state -- open design point for the impl iteration, alongside seed
transport (`docker cp` vs `docker run --rm`).

**F2 -- Current pipeline has a latent exclusion leak (security-relevant).** rsync treats
`!pattern` in an exclude file as *clear the exclude list*. A global excludesFile containing
`!keep.debug` silently leaks every previously excluded file -- `drop.debug` AND the
globally-ignored `globalonly.txt` -- into the sandbox copy, with only a generic warning for
`info/exclude` rules. This violates the gitignored-files-never-cross-the-boundary invariant
(`security.md` note 7 context). The git-enumerated tar honors negation correctly. Discovery
layer 1 catches and reports this divergence; the leak exists in production today.

**F3 -- Empty directories are rsync-only.** The tar mechanism cannot carry them (git cannot
represent them either; the baseline commit already lacks them). Invisible to `git status`;
recorded as an accepted behavior change when seeding lands.

**F4 -- `tar -tf` quoting artifact.** Non-ASCII names are backslash-escaped in listings;
comparisons must extract and enumerate from the extracted tree (the layer-1 script does).

**F5 -- `project_index.md` is not pulling its weight (operator question, this session).** The
agent has never used the index to locate a document -- all lookups in this and prior sessions
resolve via grep/`ls`/cross-links, which cannot go stale. The index is maintained per-iteration
(edit cost every diff) yet consumed by nobody. Genuinely valuable content exists only in the
governance annotations (freeze table: "reference-only, do not edit"); the descriptive Notes
column duplicates what grep finds, and the temp/last-touched columns go stale silently.
Candidate directions if the operator pursues it: slim to the freeze/governance table only, add a
mechanical completeness check (every `docs/` file registered; every registration resolves), or
fold the routing need into the session-lifecycle/dispatch-hub doc plan (handover Deferred).
Recorded as a finding only -- no action taken this iteration.


## Deferred

- **Session lifecycle + conceptual dispatch hub** (operator, this session): extend
  `docs/architecture/sandbox_lifecycle.md` into a session-lifecycle document and add a big
  conceptual document with dispatch links across concepts/architecture. Good plan, not this
  iteration.
- Roadmap_future seeding subtasks (drop SNAPSHOT_DIR from compose template, re-scope preflight
  gate to fresh-init, re-examine `snapshot_dir` session-state writes) — belong to the impl
  iteration that lands seeding.
