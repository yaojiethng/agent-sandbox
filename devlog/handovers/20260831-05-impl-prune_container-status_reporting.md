# Handover — 20260831-05-impl prune container-status reporting

**Status:** Closed
**Iteration:** 20260831-05
**Type:** impl
**Milestone:** M2.6 - Session Persistence
**Predecessor:** 20260831-04 (impl) — resume tooltip on shutdown (closed)

## Objective
`make prune` should report the actual container/image/network/volume removals it
performs (and space reclaimed), not just the `.compose/<session-id>.yml` record
removals of Rule 1. Currently prune ends at "removing record: ...yml" +
"Prune complete." with no visibility into the Rule-2 docker resource teardown —
the operator cannot tell what was actually pruned or whether anything did not
happen.

## Scope
- IN: `scripts/prune.sh` (and the registry-based prune it delegates to) — surface
  what Rule 2 removes (containers, networks, stale volumes by rule) and any
  space-saved signal, when it runs; keep `--dry-run` behaviour coherent with the
  new reporting.
- OUT: changing what prune prunes; the resume/stale criteria logic; unrelated
  cleanup.

## Carried forward
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template +
  duplicate-ID); image-digest tracking (decided, deferred).

## Acceptance criteria
- AC1: A `make prune` run that removes resources shows the docker resources it
  removed (and, where available, space reclaimed), not only the `.yml` records.
- AC2: `--dry-run` reports what *would* be removed without acting, consistent
  with the non-dry reporting.
- AC3: `Nothing to prune` remains accurate when no resources and no records are
  removable.
- AC4: Tests + lint clean.

## Hot files
- `scripts/prune.sh`.

## Findings
- (populated) NEW **Finding (label reliability)**: the `agent-sandbox.sandbox-dir` / `.session-id` labels on docker resources are **unreliable** — leftover `*-sandbox-data` volumes and dangling resources exist on the host that carry no consistent labels, so prune's Rule 2 (label-only discovery) never sees them and they hang. This is the root cause behind the operator's `make prune` showing record removal but no resource removal: the surviving resources are mislabelled and invisible to label-filtered discovery. **Deferred to next iteration** — requires relabelling/settlement of existing resources; a one-time host-side `docker system prune -a --volumes -f` (operator-approved, run by hand) clears the known leftovers now.
- (populated) **Rollback**: an earlier draft of `diagnose_prune_orphans.sh` added docker **name-pattern** detection (matching `*-sandbox-data` / `-<sid>` suffixes) and a `--mode=cleanup --yes`. Rolled back — name-pattern matching is presumptuous and **not durable** once multi-`SANDBOX_DIR` support returns: volume names are ambiguous across sandboxes, so pattern matching would be trigger-happy and claim other sandboxes' resources.
- (populated) Bug already observed: unexpanded `~/...` in `--sandbox` breaks every label filter + registry lookup (falsely-clean output); the diagnostic now expands a leading `~`.

## Completed
- `scripts/prune.sh`: applied the two held reporting candidates after operator confirmation — (1) rationale one-liner above Rule 2 (`Rule 2 removes only orphans ... not docker system prune, which would delete kept sessions' unreferenced volumes and break resume`); (2) lean output suppression: removed the per-resource `removing orphaned container/network/volume` echo lines so docker's own rm output carries the per-resource ids, keeping the `Rule 2 -- N orphaned resources:` header. No change to prune logic/selection.
- `tests/knowledge/diagnose_prune_orphans.sh`: report-only, label-based diagnostic (expands `~`, flags `record=MISSING` leaks, never mutates docker). Rolled back the earlier name-pattern + cleanup-mode draft.
- (populated) Suite + lint clean.

## Deferred items
- (populated) **Fix label reliability** (next iteration): settle/relabel existing mislabelled docker resources so prune's Rule 2 discovery is reliable; the diagnostic stays label-only until then. Multi-`SANDBOX_DIR` support must not reintroduce name-pattern matching.

## What's Next
M2.6 - Session Persistence.
Watch-outs: dual-grep bridge; full-tree close-out greps.