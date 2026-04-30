# Recovery — Change A (Reconstruction)

**Purpose:** track the reconstruction of A.1, A.4, A.2, A.3 as clean logical commits on top of pre-cleaned, design-rescoped baseline.

**Position in recovery flow:**

1. Investigations (`recovery-investigations.md`)
2. Pre-clean (`recovery-pre-clean.md`)
3. 20260430 design step (`recovery-design-step.md`) — **scopes the work below against the cleaned tree**
4. **Change A reconstruction (this file)**
5. Change B implementation (`recovery-change-b.md`)

**Order:** A.1 → A.4 → A.2 → A.3.

A.4 sits between A.1 and A.2 deliberately: A.4 extracts a helper used by A.1's data model code, so landing it second gives subsequent commits a clean view of the diff pipeline before the CLI shape changes underneath. Original timeline had A.4 last, which mixed concerns.

**This file's scope statements may be stale until the design step updates them.** The original handovers' file lists assumed pre-clean had not happened. After pre-clean lands, parts of A.1's data-model work, some of A.3's doc work, and possibly more will be already done. The 20260430 design step (§ O-4) updates each A.x section against actual remaining work. Treat the sections below as starting points pending that update.

---

## Cross-cutting notes (read first)

### Reconstruction philosophy

These commits are reconstructions, not historical replays. The diff for each commit should match the *logical scope* of its A.x section per handovers, not the exact commit boundaries from the lost timeline. Where the original timeline mixed concerns (e.g. router extraction lumped into A.1), these commits separate them.

### Open question: Router 1 placement

The original A.1 commit (per the operator's recall) included the extraction of routing logic from `draft_run` and `apply_run` into `agent-sandbox.sh`. This was lumped because of how the work fell out, not because it's a data-model concern.

**Decision needed:** do we keep this lumping or move router extraction into A.2 (where it belongs logically)?

**Recommendation:** move to A.2. The reasons to keep with A.1 are fidelity to the original; the reasons to move are logical cleanliness and the fact that A.2's CLI-shape changes are exactly where router placement belongs. The recovery is the moment to choose cleanliness over fidelity — that's the whole point of doing this fresh.

This file assumes the move to A.2. If the operator decides otherwise, A.1 expands and A.2 contracts; mark this section as resolved and adjust scope.

### Open question: `draft_run` folder interface ownership

The current contract per handovers: `draft_run` takes `SOURCE_DIR` (an absolute path). The directory must contain `patches/*.diff` and optionally `uncommitted.diff`.

**Unresolved:** who owns the folder shape contract? Right now it's de facto split — `package_branch` produces it, `draft_run` consumes it, neither file has a normative description of the shape. The contract lives in the design doc by description but not in code.

**Disposition for recovery:** do not redesign. Reconstruct the contract as described. Note this as an open item to revisit *after* recovery is complete. Premature reasoning about ownership while the tree is in a broken state is not productive.

**Where this question lives next:** add to roadmap backlog or to a future design session under M2.3's heir.

### Item 10 (diff helper unification) status

The diff helper extraction is now scoped to A.1 — not pre-clean. The 20260430 design step decides the helper's interface (per `recovery-design-step.md` § O-3); A.1 implements the chosen interface and migrates the three call sites.

If Q-I-1 reveals the helper is already unified in the recovered tree (handovers under-described what landed), the design step records this and A.1 has nothing to do for unification. Otherwise, A.1's scope expands to include the helper introduction and migration.

The design step's output sets A.1's actual scope. Until then, treat the section below as a placeholder that may shrink or grow.

---

## A.1 — Data model: output format unification

**Logical scope:** unify packaging output format. Consolidate `SESSION_STATE` as the single source of truth (write side already landed in pre-clean). Remove sweep commit from `diff_on_exit` / `diff_on_autosave`. Rename `changes.diff` to `uncommitted.diff` everywhere it is generated. Introduce per-commit patches under a `patches/` subfolder.

**Files in scope (from handover 05, may shrink based on what pre-clean already covered):**

- `libs/diff.sh` — remove `diff_commit_pending`; add `write_uncommitted_diff` and `write_all_changes_diff` (or unified helper per I-1); rewrite `diff_on_exit` and `diff_on_autosave` as thin dispatchers calling `package_branch`; rename `BASELINE_SHA` parameter to `since_sha`
- `libs/package_branch.sh` — extract `package_commits`; rewrite `package_branch` as dispatcher orchestrating `package_commits` + the diff helper(s); reads `init_sha` from `SESSION_STATE` (already covered in pre-clean P-1b)
- `libs/package_diff.sh` — rename `changes.diff` → `uncommitted.diff` in output; remove `--baseline` flag and `resolve_baseline` function; simplify to use unified helper if I-1 resolves to unification
- `libs/sandbox-entrypoint.sh` — remove `BASELINE_SHA` variable (already partly covered by P-1a; verify what remains)
- Tests: `test_diff.sh`, `test_package_branch.sh`, `test_package_diff.sh` for the new format

**Not in this commit:**

- `SESSION_STATE` write side (pre-clean P-1a)
- Test fixture migration to `SESSION_STATE` (pre-clean P-1c)
- Router extraction (now A.2)
- Router unit tests (pre-clean P-3)
- `changed-files/` extraction (A.4)

**Items folded in from elsewhere:**

- Item 10 (diff helper unification) — pending I-1; if confirmed not done, lands here.

**Verify before:**

- pre-clean is fully landed, tree green
- I-1 has been resolved
- the squashed recovery commit's diff for the files in scope is well-understood (re-read the diff against pre-cleaned tree, not against original baseline, since pre-clean has changed parts of these files)

**Verify after:**

- `scripts/run_tests.sh` exits 0
- `diff_on_exit` produces `session/uncommitted.diff`, `session/all-changes.diff`, `session/patches/*.diff` — no `session/changes.diff`, no `session/staged.diff`, no sweep commit (acceptance criteria 4 from handover 05)
- `diff_on_autosave` produces `autosave/uncommitted.diff`, `autosave/patches/*.diff` (criterion 5)
- `package_diff.sh` writes `uncommitted.diff` (criterion 7)

**Open items to log against this commit:**

- (none expected — log as they arise)

---

## A.4 — `changed-files/` extraction

**Logical scope:** extract the inline `changed-files/` copy logic from `libs/package_diff.sh` into a shared `write_changed_files` function in `libs/diff.sh`, parameterised by `SINCE_SHA`. Wire into both `package_branch` dispatcher (uses `INIT_SHA`) and `package_diff.sh` (uses `HEAD`). No operator-visible behaviour change.

**Files in scope (from handover 09):**

- `libs/diff.sh` — add `write_changed_files(SANDBOX_DIR, SINCE_SHA, OUTPUT_DIR)`. Two-source file list, dedup via `sort -u`, working tree copies preserving structure, deleted files skipped, empty cleanup
- `libs/package_branch.sh` — dispatcher calls `write_changed_files` after the diff helpers; sources `diff.sh` at top level
- `libs/package_diff.sh` — replace inline 3-source copy logic with single `write_changed_files` call using `HEAD`
- Tests: 4 new tests in `test_package_branch.sh` (manifest, copies, uncommitted, dedup); 3 new tests in `test_package_diff.sh` (manifest, copies, untracked)
- Architecture docs: add `changed-files/` to directory tree in `execution_model.md` and output layout in `sandbox_lifecycle.md`

**Why second instead of last:**

A.4 introduces a primitive that A.1 conceptually relies on (the file copying that was inline in A.1's `package_diff.sh` simplification). Landing A.4 second makes A.1's diff smaller in retrospect — the inline copy logic in `package_diff.sh` doesn't appear in A.1's diff because A.4 has already extracted it.

If you prefer A.4 last (matching original timeline), A.1's `package_diff.sh` includes the inline logic that A.4 then extracts. That's a more honest reflection of the original work but produces churn on `package_diff.sh` across two commits.

This file assumes A.4 second.

**Verify before:**

- A.1 landed cleanly, tree green
- the squashed recovery commit's diff for `package_diff.sh` shows the post-A.4 state (i.e. uses `write_changed_files`); confirm before reconstructing

**Verify after:**

- `scripts/run_tests.sh` exits 0
- `changed-files/` populated in both `output/diffs/<session>/` (from `package_diff`) and `session-diffs/<session>/session/` (from dispatcher)

---

## A.2 — CLI contract: `--channel` flag and routing

**Logical scope:** restructure `apply` and `draft` CLI around a single `--channel` flag. Remove `--session` absolute-path support. Move routing logic out of `draft_run` and `apply_run` into `agent-sandbox.sh`. Update `Makefile.template` to map `AUTOSAVE=1` and `BUNDLE=1` to `--channel=…`.

**Files in scope (from handover 06):**

- `libs/diff_workflow.sh` — rewrite `apply_run` to take a file path directly (4 args: PROJECT_DIR, DIFF_FILE, BRANCH, FORCE). No hardcoded filename. No internal routing.
- `libs/draft_workflow.sh` — rewrite `draft_run` to take `SOURCE_DIR` + `SESSION_NAME` (6 args). Apply `patches/*.diff` sequentially, then `uncommitted.diff` if present. Update `draft_read_export_time` for new layout.
- `scripts/agent-sandbox.sh` — add `--channel` flag parsing; add `resolve_source_for_draft` and `resolve_diff_for_apply` router functions; update `apply`/`draft` dispatch; reject absolute paths in `--session` with clear error.
- `libs/_templates/Makefile.template` — add `AUTOSAVE=1` → `--channel=autosave`, `BUNDLE=1` → `--channel=bundles` mappings.
- `tests/test_diff_workflow.sh` — rewrite for new `apply_run` contract (file-path input, no resolution).
- `tests/test_draft_workflow.sh` — update for new `draft_run` signature; add `test_draft_applies_uncommitted_diff`.
- `tests/libs/session_fixtures.sh` — rename `changes.diff` → `uncommitted.diff` in fixtures; add `all-changes.diff`.

**Items folded in from elsewhere:**

- Router extraction (was originally lumped in A.1 — see cross-cutting notes)
- Stale comment updates in `scripts/onboard.sh`, `libs/sandbox-entrypoint.sh`, `libs/dirs.sh` that reference old filenames (handover 06's "Completed this session" lists these)

**Not in this commit:**

- Router unit tests (pre-clean P-3b, P-3c)
- Architecture doc updates (A.3)
- Anything from Section B

**Verify before:**

- A.4 landed cleanly, tree green
- the routers are not yet tested — pre-clean P-3b/c will have already added tests, but those tests assert against the *post-A.2* shape. If the routers don't exist yet, the tests can't have run yet either. Sequencing tension: the pre-clean tests assume A.2 has landed.
- **resolve before starting A.2:** either (a) pre-clean P-3b and P-3c land *after* A.2 instead of before, or (b) the tests are written against stub routers that A.2 then fleshes out. Cleanest path: move P-3b and P-3c to *after* A.2 in the overall sequence. Update `recovery-pre-clean.md` accordingly when you make this call.

**Verify after:**

- `scripts/run_tests.sh` exits 0
- `make draft` (no flags) resolves `--channel=session`
- `make draft BUNDLE=1` resolves `--channel=bundles`
- `make apply` (no flags) resolves `--channel=diffs`
- `make apply AUTOSAVE=1` resolves `--channel=autosave`
- `--diff=<path>` bypasses channel resolution
- `--session` rejects absolute paths

---

## A.3 — Documentation alignment + design doc consolidation

**Logical scope:** align architecture documents with the unified contract. Add emergency recovery snippets to quickstart. Consolidate the design doc's Contract Amendments section to reflect the final state (not the multi-stage A.1/A.2/A.3/B partition that originally lived there).

**Files in scope (from handover 07, plus consolidation work):**

- `docs/architecture/execution_model.md` — `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff` in directory tree and mermaid diagram
- `docs/architecture/sandbox_lifecycle.md` — remove sweep commit description; rename filenames; `INIT_SHA` file → `SESSION_STATE` (partly covered in pre-clean P-2a; verify what remains)
- `docs/architecture/tool_interface.md` — add `make draft`/`confirm`/`reject`; rewrite `make apply` with new flag set; update `make dry-run`
- `docs/concepts/sandbox_host_correspondence_model.md` — update correspondence cycle and command map
- `docs/architecture/system_overview.md` — update diff output description; remove "legacy" framing on `make apply`
- `docs/development/project_index.md` — update `Last touched in` for A.1 and A.2 files (the cleanup of stale `.sh` entries was pre-clean P-2d)
- `docs/development/testing_policy.md` — `staged.diff` → "diff files" in anti-pattern examples
- `docs/development/quickstart.md` — rewrite recovery section: remove checkpoint tags (deleted feature); add recovery snippets for missing diff, wrong branch, rebase conflict, bad diff
- `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` — **consolidate**: replace the multi-section A.1/A.2/A.3/B partition with a single final-state Contract Amendments section reflecting the system as built. This is the file that was touched in three sessions originally; this is its single touch.

**Not in this commit:**

- The 20260430 design handover (separate file, covered by `recovery-change-b.md`)
- New design questions for B (those go in `recovery-change-b.md`)

**Verify before:**

- A.2 landed cleanly, tree green
- pre-clean P-2a (sandbox_lifecycle.md INIT_SHA fix) and P-2c (design doc INIT_SHA fix) have already landed; A.3 does *not* re-touch those references but does broader updates to the same files

**Verify after:**

- `scripts/run_tests.sh` exits 0
- no stale references to `changes.diff`, `staged.diff`, `BASELINE_SHA`, `diff_commit_pending`, or absolute `--session` paths remain in `docs/` or `libs/` (excluding intentionally-historical sections)
- design doc has *one* Contract Amendments section, not the multi-stage partition

---

## A.5 — (placeholder)

No A.5 identified yet. The deferred-items trace produced no bucket-B items requiring a new section. If something surfaces during reconstruction (e.g. I-1 reveals scope that doesn't fit cleanly into A.1), record it here and consider whether it warrants its own commit or folds into an existing A.x.

---

## Exit criteria for Change A

1. `scripts/run_tests.sh` exits 0 at the recovery branch tip.
2. Each A.x commit's diff matches its logical scope per the section above. No bug fixes lurking inside reconstruction commits — those should have landed in pre-clean.
3. The squashed recovery commit's tree matches the post-A.3 tree (modulo any items deliberately deferred).
4. `recovery-change-b.md` is updated with any open questions surfaced during A.x reconstruction.
5. The roadmap reflects A.1, A.4, A.2, A.3 as complete and Section B as the only remaining M2.3 work.
