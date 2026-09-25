# Study: Prune Rule 2 Orphan-Discovery Reliability

**Status:** settled -- recommendation recorded on the roadmap (T9, Session and Harness Identity); implementation deferred.

## Direction + Parent story

Parent: roadmap track T9 - Session and Harness Identity. Prune Rule 2's discovery key (`agent-sandbox.session-id`) is part of the session-identity label contract, which T9 owns. Triggered by the incident recorded in [`investigation_prune_rule2_orphan_visibility.md`](investigation_prune_rule2_orphan_visibility.md): `make prune` removed 7 stale records (Rule 1) and zero resources (Rule 2) in one pass; the host carries 64 leftover volumes, at least 6 of them orphaned by that run alone. This study evaluates the fix candidates; it does not implement them.

## Required reading

- [`investigation_prune_rule2_orphan_visibility.md`](investigation_prune_rule2_orphan_visibility.md) -- incident record: established facts, open question, host evidence
- [`scripts/prune.sh`](../../scripts/prune.sh) -- `rule2_orphan_resources`, `_session_id_of`, `_sid_is_orphaned`
- [`src/libs/common.sh`](../../src/libs/common.sh) -- `sandbox_dir_canon`
- [`20260923-design-active-session_identity_and_sandbox_command_ergonomics.md`](20260923-design-active-session_identity_and_sandbox_command_ergonomics.md) -- owning identity design
- [`20260831-08-impl-prune_label_reliability.md`](../handovers/20260831-08-impl-prune_label_reliability.md) -- prior label-reliability work and its constraints

## Summary

Rule 2 removes resources whose session has no `.compose/<session-id>.yml` record. Discovery is strictly label-value based: filter by `agent-sandbox.sandbox-dir` (exact value), read `agent-sandbox.session-id`, test the record. The candidate fix has two independent parts: treat empty session-id labels as orphans, and bake the canonical label value at create time so filters and labels always agree. Both are small, label-only, and restore the registry-truth invariant without changing the discovery model.

## Findings

### Finding 1 -- Empty session-id labels are permanent orphans

Code-verified: `_sid_is_orphaned` returns kept for an empty sid (`[[ -n "$sid" ]] || return 1`). A resource that carries the project and sandbox labels but no session-id can never have a record (records are keyed by sid), so it is an orphan by the registry-truth model. The host carries 21 such volumes. Fix A: treat empty-session-id resources as orphans when the project+sandbox label filters already selected them. This is a one-line change to the orphan test.

### Finding 2 -- Label-value spelling can hide whole eras

The baked `sandbox-dir` label comes from the exported `SANDBOX_DIR` spelling at compose-up time; Rule 2 filters on the `readlink -f` canonical spelling (`sandbox_dir_canon`). A trailing slash, `~` form, or symlink path at create time produces a label value the filter never matches, hiding every resource of that era. The 6+ volumes orphaned by the recorded run escaped despite complete labels; no other mechanism in the code explains the miss. Host verification is pending (commands in the incident record). Fix B: bake the canonical value at create time so the filter and the label always agree, by construction.

### Finding 3 -- The two fixes are independent and small

Fix A touches `_sid_is_orphaned`; Fix B touches the label source (the compose generation env). Neither changes the registry-truth model, the discovery-key shape, or the prune contract. Fix A is the safer immediate win (it closes the demonstrably present class). Fix B prevents future eras from drifting and removes the spelling hazard class. Together they cover both blind classes recorded in the incident.

### Finding 4 -- Legacy resources need operator settlement, not code

Pre-label and pre-rename resources (unlabeled networks, the `agent-sandbox.run-id` label era) are invisible to label-value discovery by construction; no code change makes them visible. One-time host-side settlement (relabel or sweep) is the established resolution (`20260831-05` recorded the same conclusion). The record-guarded volume class is removable now with [`scripts/manual/cleanup_orphan_volumes.sh`](../../scripts/manual/cleanup_orphan_volumes.sh).

### Finding 5 -- Build cache is a separate scope question

The registry prune never runs `docker system prune` or a builder-cache sweep; 3.2 GB of build cache reclaimed on this host is unaffected by any Rule 2 fix. A cache/image scope decision is out of this study's candidate set.

## Open Questions

- Host verification of Finding 2: does the exact filter value match the baked labels? The commands are in the incident record; the answer changes Fix B's priority, not its validity.
- Relabel legacy resources, or settle-forward only? The decision is operator-run either way; code does not depend on it.

## Constraints

- Label-only matching; no docker name-pattern matching (operator constraint, `20260831-06` and `20260831-08`).
- No shift back to `docker system prune`; it removes kept sessions' volumes and breaks resume.
- Registry-truth only: a resource is pruned iff its session has no record; a kept session's resources are never touched.

## Resolution

Recommendation: adopt Fix A and Fix B as one label-contract change under T9, with Fix A first. Rationale: both are small, label-only, and restore the registry invariant without name matching or system prune; Fix A closes the demonstrated class, Fix B removes the drift class. The recommendation is recorded as the roadmap T9 task "Prune Rule 2 orphan-discovery reliability" (2026-09-24). Implementation is deferred to the T9 design iteration. Until then, host-side volumes are removed by the manual cleanup script (record-guarded, confirmed), and legacy resources settle operator-run.
