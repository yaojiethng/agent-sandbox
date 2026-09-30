# Investigation -- prune Rule 2 does not remove orphaned session volumes

**Status:** Active -- root-cause verification pending; host-side remediation provided.

---

## Summary

`make prune` removed 7 stale session records (Rule 1) and zero orphaned resources (Rule 2) in the same pass. The host still holds 64 `-sandbox-data` volumes. At least 6 of them belong to sessions whose records that run deleted; Rule 2 should have removed them and did not. Rule 2 is blind to two classes of orphaned resources: volumes whose `agent-sandbox.session-id` label is empty are never orphan-tested, and the label-value filters can miss the spelling baked into older labels. The session-identity label contract is the root area; it belongs to roadmap track T9 (Session and Harness Identity).

## Incident evidence

- Prune run with env `/home/yaojie/sandbox/agent-sandbox/.env`: Rule 1 removed records `22192c`, `541b4c`, `659fd9`, `676b6d`, `a34cde`, `dryrun-6ec2bb`, `efb54e`. No Rule 2 section printed. Output ends with "Prune complete."
- Host state after the run:
  - 2 running containers for session `0f02b3` (a live session; its record exists, so it is a keeper).
  - 1 network, `agent-sandbox-0f02b3_default` (the live session's network).
  - 64 volumes named `agent-sandbox-<hash>_<hash>-sandbox-data`; 43 carry an `agent-sandbox.session-id` label, 21 carry none.
  - Volumes `22192c`, `541b4c`, `659fd9`, `676b6d`, `a34cde`, `efb54e` still exist; their records were removed by this run.
- Manual `docker system prune` (operator-run): removed network `agent-sandbox-d7a4a6_default` and 3.2 GB build cache. Plain `docker system prune` does not remove volumes, so the volume backlog was untouched.

## Established facts

1. Rule 2 discovery is label-value based (`scripts/prune.sh`, `rule2_orphan_resources`). Volumes are filtered by `label=agent-sandbox.sandbox-dir=<canonical SANDBOX_DIR>` (exact value match), then orphan-tested by reading the `agent-sandbox.session-id` label and checking for `SANDBOX_DIR/.compose/<sid>.yml`.
2. `_sid_is_orphaned` returns "kept" for an empty session-id (`[[ -n "$sid" ]] || return 1`). The 21 empty-label volumes are permanently invisible to Rule 2.
3. The `sandbox-dir` label value is baked from the exported `SANDBOX_DIR` spelling at compose-up time (compose resolves `${SANDBOX_DIR}` at runtime). Prune compares against the `readlink -f` canonical spelling (`sandbox_dir_canon` in `src/libs/common.sh`). Any spelling drift (trailing slash, `~` form, symlink) hides every resource of that era.
4. The record is the last surviving artifact of an ended session. Teardown (`docker compose down`, `src/build/compose.sh` `session_teardown`) removes containers and the network; copy delivery keeps only the named volume, mount and dry-run deliveries keep nothing. A record removal therefore cannot "trigger" a container prune: the containers are already gone.
5. Containers and networks carry the same label schema since commit `9222116` (2026-08-11); resources created before that commit (or before the `RUN_ID` to `SESSION_ID` rename) carry older or absent labels and are invisible to label-value filters. This matches the recorded finding in `20260831-05`.

## Open question

Why did the 6 volumes orphaned by this run escape Rule 2? The value-mismatch hypothesis (fact 3) fits the evidence: if the filter value never equals any baked label value, Rule 2 finds nothing and prints nothing. It is consistent with a host where Rule 2 has never removed a volume. The hypothesis is not yet verified on the host. Verification commands:

```bash
docker volume ls --filter label=agent-sandbox.sandbox-dir \
  --format '{{.Label "agent-sandbox.sandbox-dir"}}' | sort | uniq -c
docker volume ls --filter "label=agent-sandbox.sandbox-dir=/home/yaojie/sandbox/agent-sandbox" \
  --format '{{.Name}}' | wc -l
grep -E '^(SANDBOX_DIR|PROJECT_NAME|PROJECT_DIR)=' .env
docker volume inspect agent-sandbox-22192c_22192c-sandbox-data --format '{{json .Labels}}'
ls .compose/
```

## Impact

- Volume data accumulates: 64 volumes on this host, none auto-removed by Rule 2.
- "Prune complete." gives false confidence: the registry-truth invariant (every session fully pruned or fully kept) is violated for the invisible classes.
- The live session (`0f02b3`) is unaffected. Docker refuses to remove an in-use volume, and its record exists, so no provided command touches it.
- Build cache (3.2 GB on this host) accumulates by design: the registry prune never runs `docker system prune` or a builder-cache sweep. That is a separate scope question, not this incident's defect.

## Host-side remediation

The commands below run on the host from the sandbox directory. They implement the Rule 2 registry-truth test by hand. Each loop is a dry-run-able listing first, then removal; both are idempotent and safe to re-run. The scripted form is `scripts/manual/cleanup_orphan_volumes.sh`: it lists the orphans, asks for confirmation, then removes them, and prints the no-label review list separately.

1. List volumes whose session-id has no record:

```bash
cd /home/yaojie/sandbox/agent-sandbox
for v in $(docker volume ls --filter label=agent-sandbox.sandbox-dir --format '{{.Name}}'); do
  sid="$(docker volume inspect "$v" --format '{{index .Labels "agent-sandbox.session-id"}}')"
  [[ -n "$sid" ]] || continue
  [[ -f ".compose/$sid.yml" ]] || printf 'orphan: %s (session %s)\n' "$v" "$sid"
done
```

2. Remove those volumes:

```bash
cd /home/yaojie/sandbox/agent-sandbox
for v in $(docker volume ls --filter label=agent-sandbox.sandbox-dir --format '{{.Name}}'); do
  sid="$(docker volume inspect "$v" --format '{{index .Labels "agent-sandbox.session-id"}}')"
  [[ -n "$sid" ]] || continue
  [[ -f ".compose/$sid.yml" ]] || docker volume rm "$v"
done
```

The guard never removes a volume whose record exists, so resume candidates stay intact.

3. Review the 21 empty-label volumes before removal. They are permanent orphans under the current code (fact 2) and never referenced by any record. One item needs individual review: `agent-sandbox-af381c_sandbox-data` predates per-session volumes (its name has no session prefix) and may hold the earliest sandbox state.

```bash
docker volume ls --filter label=agent-sandbox.sandbox-dir --format '{{.Name}}' \
  | while read -r v; do
      sid="$(docker volume inspect "$v" --format '{{index .Labels "agent-sandbox.session-id"}}')"
      [[ -n "$sid" ]] && continue
      printf '%s\n' "$v"
    done
```

Then run `docker volume rm <each reviewed name>`.

## Follow-up work

Fix candidates need a design decision; the owning scope is roadmap track T9, because the prune discovery key is the session-identity label contract.

- Treat empty-session-id resources that still carry the project and sandbox labels as orphans in Rule 2 (a resource with no session-id can never have a record).
- Bake a canonical label at create time so the filter value and the baked value always agree.
- Settle legacy resources (relabel or one-time sweep), operator-run; `20260831-05` recorded the same conclusion.
- Decide build-cache and image scope for prune separately (plan item `20260513-11` item 4 is unresolved).

## Related

- Roadmap: [`devlog/roadmap.md`](../roadmap.md#t9---session-and-harness-identity) -- T9, Session and Harness Identity.
- Design: [`20260923-design-active-session_identity_and_sandbox_command_ergonomics.md`](20260923-design-active-session_identity_and_sandbox_command_ergonomics.md).
- Prior finding: [`20260831-05-impl-prune_container-status_reporting.md`](../handovers/20260831-05-impl-prune_container-status_reporting.md) -- label reliability finding.
- Prior work: [`20260831-08-impl-prune_label_reliability.md`](../handovers/20260831-08-impl-prune_label_reliability.md).
- System docs: [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) (prune section), [`docs/concepts/sandbox_identity.md`](../../docs/concepts/sandbox_identity.md) (label lifecycle).
