# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Design
**Status:** Closed

## Objective

Mid-implementation design session. Identified and resolved a design gap in `make confirm` discovered during Unit F implementation. Extended the design to cover `.draft-state` as a committed branch artefact, `make confirm` as a full merge workflow, and branch topology.

## Scope

Design only — no implementation this session. Decisions recorded here apply to Unit F implementation and require one additive change to the already-implemented Unit E.

## Carried forward

None.

## Acceptance criteria

Not applicable — design session.

## Hot files

| File | Why in scope | Status |
|---|---|---|
| [`docs/discussions/design_diff_and_branch_packaging_workflow.md`](docs/discussions/design_diff_and_branch_packaging_workflow.md) | Updated: `.draft-state` primitive, `make draft` operator hint, `make confirm` full sequence, branch topology diagram, `make reject` update | ✓ Complete |
| [`docs/development/roadmap.md`](docs/development/roadmap.md) | Updated: Unit F description rewritten, acceptance criteria corrected, E marked complete | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| `make confirm` must fast-forward merge onto target — it was underspecified as "cleanup only" | Operator has no other mechanism to land draft changes on the target branch; the merge was lost in the original simplification | Design doc — `make confirm` |
| `.draft-state` committed as first commit on draft branch, not a working-directory file | Makes draft branch self-contained and pushable to remote; `make confirm` and `make reject` read from branch, not from local harness state; removed dependency on any working-directory file | Design doc — primitives, `make draft`, `make confirm`, `make reject` |
| `.draft-state` fields: `source_branch`, `from_hash`, `author`, `session` | `diffs_applied` dropped — branch content is the record; artefact directory path dropped — local harness state not persisted; author and session added for provenance without encoding local paths | Design doc — `make draft` |
| `.draft-state` dropped automatically by `make confirm` before merge | Operator should never handle harness metadata manually; dropping it in the harness keeps target branch history clean | Design doc — `make confirm` |
| `make confirm` sequence: drop `.draft-state` → rebase onto target → ff merge → delete branch | Rebase handles `FROM != HEAD` case uniformly; ff merge guarantees linear history; `.draft-state` dropped before rebase so it never appears in rebased history | Design doc — `make confirm` |
| Branch topology: draft changes always land at tip of target (Case B) | Case A (insert at branch point) requires rewriting existing host history — unacceptable; Case B (append at HEAD) is standard git workflow and produces clean linear history | Design doc — branch topology diagram |
| `make confirm` prints exact conflict recovery commands | Operator needs `git rebase --continue` / `make confirm` / `git rebase --abort` + `make reject` spelled out — not implied | Design doc — `make confirm` conflict output |
| `make draft` prints operator hint on completion | Without explicit hint, the `git rebase -i` step is invisible to the operator; hint shows exact command including target branch | Design doc — `make draft` |
| `make reject` reads `source_branch` from `.draft-state` on the branch | Consistent with removing all working-directory harness state; branch carries everything needed to undo itself | Design doc — `make reject` |
| Draft branch name is `draft/<EXPORT_TIME>-<SESSION_TS>-<sanitized-host-branch>-<sha6>` | Encodes export identity and session identity without requiring shell variables on the host; derived from folder name; M2.7 replaces `SESSION_TS` with `RUN_ID` as a clean suffix substitution | Design doc — `make draft`; roadmap F1 |
| `SESSION_TS` format unified to `YYYYMMDD-HHMMSS` with delimiter everywhere | Container names were using `YYYYMMDDHHMMSS` without delimiter — two separate `date` calls confirmed; unified format enables consistent lexicographic sort and human readability | Design doc — `SESSION_TS` primitive; roadmap F0 |
| `SESSION_NAME` dropped as a primitive | Replaced by explicit `<SESSION_TS>-<SANITIZED_HOST_BRANCH>` longform; removes one layer of indirection; M2.7 will not need to update a derived primitive | Design doc — primitives; roadmap F0 |
| `SANITIZED_HOST_BRANCH` derived once at session start, injected into container | Container-side branch name is meaningless (always main/master); host branch is the semantic identity; injecting it ensures container artifacts carry correct branch provenance | Design doc — packaging commands; roadmap F0 |
| Output paths standardised: `CHANGES_DIR/<EXPORT_TIME>-<branch>-<SESSION_TS>/`, `OUTPUT_DIR/bundles/`, `OUTPUT_DIR/diffs/` | Unified `EXPORT_TIME` prefix enables lexicographic sort by export order; `SESSION_TS` suffix identifies the producing session; M2.7 replaces suffix with `RUN_ID` | Design doc — Output Paths; roadmap F0 |
| `EXPORT_TIME` generated at packaging time, not session start | Multiple exports within a session each need distinct timestamps; session start time is not the right anchor for export ordering | Design doc — `EXPORT_TIME` primitive |
| `SESSION_SUMMARY` required argument for `package_diff` and `package_branch` | Operator or agent must describe what is being packaged; no harness-generated title for explicit packaging operations | Design doc — packaging commands |
| `BRANCH_SUMMARY` optional argument for `make draft` | Replaces auto-generated branch slug with operator-provided description; falls back to `SANITIZED_HOST_BRANCH` | Design doc — `make draft`; roadmap F1 |
| `.draft-state` fields finalised: `source_branch`, `from_hash`, `author`, `session_ts`, `host_branch`, `diff_count`, `exported-at`, `drafted-at` | All fields host-derivable or read from folder name; no local paths; no container-internal variables; M2.7 adds `run_id:` as one new field | Design doc — `.draft-state` primitive, `make draft` |
| F0 added as prerequisite unit before F1 | Path inconsistencies discovered mid-implementation require a dedicated audit pass before further draft workflow changes | Roadmap |

## Blast radius on already-implemented units

| Unit | Status | Impact |
|---|---|---|
| A — INIT_SHA | ✓ Complete | None |
| B — Remove checkpoint tags | ✓ Complete | None |
| C — `package-branch` | ✓ Complete | None |
| D — `make apply` update | ✓ Complete | None |
| E — `make draft` redesign | ✓ Complete | **One addition required:** `.draft-state` first commit not yet implemented. Add before or as part of Unit F. See below. |
| F1 — `.draft-state` + finish `make draft` | Pending | Contains the E addition; implement first |
| F2 — `make confirm` / `make reject` / `make sync` removal | Pending | Depends on F1 |
| G — `.skills` update | Pending | No impact from design changes; depends on F2 |

## E addition required

`make draft` needs one addition not present in the current implementation: after creating the draft branch and before applying any diffs, commit a `.draft-state` file as the first commit:

```bash
cat > .draft-state <<EOF
source_branch: $SOURCE_BRANCH
from_hash: $BRANCH_FROM
author: $(git config user.name) <$(git config user.email)>
session_ts: $SESSION_TS
host_branch: $SANITIZED_HOST_BRANCH
EOF
git add .draft-state
git commit -m "draft-state: ${SESSION_TS}-${SANITIZED_HOST_BRANCH}"
```

Note: this is a stub showing the fields that must exist. F1 adds the full field set (`diff_count`, `exported-at`, `drafted-at`) — implement the full `.draft-state` definition from the F1 spec, not this stub.

This can be folded into the Unit F implementation session rather than reopening E. Implement `.draft-state` commit first, then implement `make confirm` reading from it.

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation — Unit F0 (path and timestamp audit).
**Interface note:** 128k context, no reasoning. Read this section fully before touching any file.

---

### Orientation

Unit F0 is a normalisation pass only. No new behaviour is introduced. Every change is a find-and-replace of a wrong value with the correct one. The locked spec is:

| Variable | Correct derivation | Format |
|---|---|---|
| `SESSION_TS` | `$(date +%Y%m%d-%H%M%S)` once at top of `start_agent.sh` | `20260423-081334` (with delimiter) |
| `SANITIZED_HOST_BRANCH` | current branch in `PROJECT_DIR` at session start, sanitized | `main`, `feature-M2_3` |
| `EXPORT_TIME` | `$(date +%Y%m%d-%H%M%S)` at packaging time inside each command | `20260423-143012` |
| `SESSION_NAME` | **dropped** — replaced by `${SESSION_TS}-${SANITIZED_HOST_BRANCH}` longform wherever needed | — |

| Artifact | Correct output path |
|---|---|
| `diff_on_exit` | `$CHANGES_DIR/<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/` |
| `package_branch` | `$OUTPUT_DIR/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` |
| `package_diff` | `$OUTPUT_DIR/diffs/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/` |
| Container (capability) | `sandbox-<project>-<SESSION_TS>` (delimiter in timestamp) |
| Container (reasoning) | `<provider>-<project>-<SESSION_TS>` (delimiter in timestamp) |
| `make apply` default | latest entry under `$OUTPUT_DIR/diffs/` by lexicographic sort |

---

### Step 1 — audit (run these greps before touching anything)

```bash
# Find all date calls — expect exactly one canonical one after F0
grep -rn 'date +' scripts/ libs/

# Find all SESSION_NAME / SESSION_TS references
grep -rn 'SESSION_NAME\|SESSION_TS\|SANITIZED_HOST_BRANCH' scripts/ libs/

# Find all output path constructions
grep -rn 'CHANGES_DIR\|OUTPUT_DIR\|session-diffs\|changes/' scripts/ libs/

# Find container name constructions
grep -rn 'container_name\|sandbox-\|pi-\|hermes-\|opencode-' libs/

# Find make apply default path resolution
grep -rn 'output/' scripts/apply_workspace.sh
```

Record every file and line number returned. That is the complete blast radius. Do not touch any file not in these results.

---

### Step 2 — `scripts/start_agent.sh`

**Expected current state:** `SESSION_TS` derived from `date` somewhere in the script, possibly without delimiter (`%Y%m%d%H%M%S`). `SESSION_NAME` constructed as `<branch>-<SESSION_TS>` or similar. `SANITIZED_HOST_BRANCH` may or may not exist.

**Required changes:**

- [ ] Move or confirm `SESSION_TS=$(date +%Y%m%d-%H%M%S)` is the very first variable derivation in the script, before any other `date` calls or variable assignments that depend on it
- [ ] Add `SANITIZED_HOST_BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD | sed 's/[^a-zA-Z0-9._-]/-/g')` immediately after `SESSION_TS`
- [ ] Remove `SESSION_NAME` derivation entirely, or replace any downstream uses of `$SESSION_NAME` with `${SESSION_TS}-${SANITIZED_HOST_BRANCH}`
- [ ] Export both: `export SESSION_TS SANITIZED_HOST_BRANCH`
- [ ] Verify no other `date +` call exists in this file after these two lines

**Verify:** `grep -n 'date +\|SESSION_NAME\|SESSION_TS\|SANITIZED' scripts/start_agent.sh` — should show exactly one `date +` call and no `SESSION_NAME`.

---

### Step 3 — `libs/compose.sh` (container naming)

**Expected current state:** Container names constructed with timestamp, likely without delimiter (e.g. `sandbox-agent-sandbox-20260423081334`).

**Required changes:**

- [ ] Find the container name construction — grep for `container_name` or the project name pattern
- [ ] Replace timestamp format: any `$(date +%Y%m%d%H%M%S)` or `${SESSION_TS}` used in container names must use the delimiter format `YYYYMMDD-HHMMSS`
- [ ] If a second `date +` call exists here for container naming, remove it — use `$SESSION_TS` from the environment instead

**Verify:** Container names produced will be `sandbox-agent-sandbox-20260423-081334`. No independent `date` call in this file.

---

### Step 4 — `libs/diff.sh` and capability layer entrypoint (diff_on_exit path)

**Expected current state:** `diff_on_exit` writes to `$CHANGES_DIR/<branch>-<timestamp>/` or `$CHANGES_DIR/<SESSION_TS>/...` — wrong folder name order and possibly wrong structure.

**Required changes:**

- [ ] Find `diff_on_exit` function — grep for `CHANGES_DIR` in `libs/diff.sh` and the entrypoint script
- [ ] Inside `diff_on_exit`: generate `EXPORT_TIME=$(date +%Y%m%d-%H%M%S)` at the start of the function
- [ ] Set output directory: `OUTPUT_DIR="${CHANGES_DIR}/${EXPORT_TIME}-${SANITIZED_HOST_BRANCH}-${SESSION_TS}"`
- [ ] Ensure `SANITIZED_HOST_BRANCH` and `SESSION_TS` are available — they are injected into container environment from `start_agent.sh`; if not currently injected via compose, add them to `libs/compose.sh` environment block
- [ ] Verify the autosave path uses the same pattern if it writes to `CHANGES_DIR`

**Verify:** On container exit, folder created is `$CHANGES_DIR/20260423-143012-main-20260423-081334/` (export time first, session TS last).

---

### Step 5 — `libs/package_branch.sh` (package_branch output path)

**Expected current state:** Output path likely `$OUTPUT_DIR/session-diffs/<branch>/` or similar — wrong subdirectory and missing `SESSION_SUMMARY`.

**Required changes:**

- [ ] `SESSION_SUMMARY` is an optional argument (first positional arg or named flag). If not provided, fall back to `${SANITIZED_HOST_BRANCH}` — e.g. `"$OUTPUT_DIR/bundles/${EXPORT_TIME}-${SANITIZED_HOST_BRANCH}-${SESSION_TS}"`
- [ ] Generate `EXPORT_TIME=$(date +%Y%m%d-%H%M%S)` at start of function
- [ ] Set output directory: `"$OUTPUT_DIR/bundles/${EXPORT_TIME}-${SESSION_SUMMARY:-$SANITIZED_HOST_BRANCH}-${SESSION_TS}"`
- [ ] Create the directory before writing: `mkdir -p "$OUT_DIR"`
- [ ] Verify `SESSION_TS` and `SANITIZED_HOST_BRANCH` are available in environment (injected from container start)

**Verify:** Calling `package_branch "my-summary"` produces `$OUTPUT_DIR/bundles/20260423-143012-my-summary-20260423-081334/0001.diff ...`. Calling `package_branch` with no argument produces `$OUTPUT_DIR/bundles/20260423-143012-main-20260423-081334/0001.diff ...`.

---

### Step 6 — `libs/package_diff.sh` (package_diff output path)

**Expected current state:** Output path likely `$OUTPUT_DIR/<timestamp>-<description>/changes.diff` — close but wrong subdirectory (`diffs/` missing).

**Required changes:**

- [ ] `SESSION_SUMMARY` is an optional argument. If not provided, fall back to `snapshot` — e.g. `"$OUTPUT_DIR/diffs/${EXPORT_TIME}-snapshot-${SESSION_TS}/changes.diff"`
- [ ] Generate `EXPORT_TIME=$(date +%Y%m%d-%H%M%S)` at start of function
- [ ] Set output path: `"$OUTPUT_DIR/diffs/${EXPORT_TIME}-${SESSION_SUMMARY:-snapshot}-${SESSION_TS}/changes.diff"`
- [ ] Create parent directory before writing

**Verify:** Calling `package_diff "fix-snapshot"` produces `$OUTPUT_DIR/diffs/20260423-143012-fix-snapshot-20260423-081334/changes.diff`. Calling `package_diff` with no argument produces `$OUTPUT_DIR/diffs/20260423-143012-snapshot-20260423-081334/changes.diff`.

---

### Step 7 — `scripts/apply_workspace.sh` (make apply default resolution)

**Expected current state:** `make apply` default reads from `$OUTPUT_DIR/` root or `$OUTPUT_DIR/<latest>/changes.diff`.

**Required changes:**

- [ ] Update default resolution to scan `$OUTPUT_DIR/diffs/` for the latest entry by lexicographic sort
- [ ] Keep `DIFF=<path>` explicit override unchanged — it accepts any path

**Verify:** Running `make apply` with no arguments and a file at `$OUTPUT_DIR/diffs/20260423-143012-fix-snapshot-20260423-081334/changes.diff` applies that file.

---

### Step 8 — environment injection audit

**Required check:**

- [ ] Confirm `SESSION_TS` is in the environment block passed to the container in `libs/compose.sh` or equivalent
- [ ] Confirm `SANITIZED_HOST_BRANCH` is also injected — it is new and likely not yet present
- [ ] If either is missing, add to the compose environment block

**Verify:** Inside a running container, `echo $SESSION_TS` and `echo $SANITIZED_HOST_BRANCH` both return values.

---

### Step 9 — SESSION_NAME removal sweep

**Required check:**

- [ ] `grep -rn 'SESSION_NAME' scripts/ libs/` — every remaining reference must be replaced with `${SESSION_TS}-${SANITIZED_HOST_BRANCH}` or removed
- [ ] Do not leave `SESSION_NAME` as an exported variable — remove the export if present

---

### Completion check

Before closing the session, run all audit greps from Step 1 again and verify:

- [ ] Exactly one `date +` call exists in `scripts/start_agent.sh` (the `SESSION_TS` derivation) — all other `date +` calls are local `EXPORT_TIME=$(date +%Y%m%d-%H%M%S)` lines inside packaging functions (`diff_on_exit`, `package_branch`, `package_diff`); no `date +` calls exist anywhere else in `scripts/` or `libs/`
- [ ] No `SESSION_NAME` references remain
- [ ] No `session-diffs/` path references remain (replaced by `bundles/` or `diffs/` or `changes/`)
- [ ] Container names in compose use delimiter format
- [ ] Tests pass: `./tests/test_apply_workspace.sh` exits 0
