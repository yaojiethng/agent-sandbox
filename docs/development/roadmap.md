# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/development/roadmap_policy.md`](../development/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| M1 — Barebones Agent Container | [Complete — see changelog](changelog.md) |
| M1.1 — Interactive Virtual Workspace / Serve Mode | [Complete — see changelog](changelog.md) |
| M1.2 — Sandbox File Isolation & Diff Workflow | [Complete — see changelog](changelog.md) |
| M1.3 — Invocation Cleanup & Onboarding Workflow | [Complete — see changelog](changelog.md) |
| M1.4 — Image Staleness Detection | [Complete — see changelog](changelog.md) |
| [M1.5 — Workflow Convergence & Directory Restructuring](#m15--workflow-convergence--directory-restructuring) | In progress |
| M1.7 — Provider Modularisation | Superseded by M2 — see [investigation_mcp_server.md](../discussions/investigation_mcp_server.md) Conclusion |
| **Two-Layer Architecture** | |
| [M2 — Reasoning/Capability Layer Separation](roadmap_future.md#m2--reasoningcapability-layer-separation) | Not started |
| **Single-Agent Coordination** | |
| [M3 — Autonomous Task Execution, Manual Review Workflow](roadmap_future.md#m3--autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M4 — Metadata Seeding](roadmap_future.md#m4--metadata-seeding) | Not started |
| [M5 — Agent-Assigned Branch Management](roadmap_future.md#m5--agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M6.1 — Task Dispatch](roadmap_future.md#m61--task-dispatch) | Not started |
| [M6.2 — Constraint Enforcement](roadmap_future.md#m62--constraint-enforcement) | Not started |
| [M6.3 — Review & CI/CD Integration](roadmap_future.md#m63--review--cicd-integration) | Not started |
| **Standalone** | |
| [M7 — Safe vs Unsafe Mode (Policy Layer)](roadmap_future.md#m7--safe-vs-unsafe-mode-policy-layer) | Not started |
| [M8 — Skills / Templates](roadmap_future.md#m8--skills--templates) | Not started |

---

## Upcoming Milestones

### **M1.5 — Workflow Convergence & Directory Restructuring**

**Objective:** Close the M1.x architecture by completing the directory restructuring and operator input channel, resolving open user stories, and recording the workflow convergence decision. M1.5 closes when the directory restructuring is implemented and documented, the input channel is in place, and all story resolution tasks are marked complete or explicitly deferred to M2.

Serve mode fix is complete. Two-layer architecture decision is recorded — conceptual model in [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md), full reasoning in [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md).

#### Directory restructuring

Harness artefacts currently live inside `PROJECT_ROOT`, polluting the project's git tree. The fix separates the project repo from the harness workspace as sibling directories under a common `WORKDIR`.

**Terminology change:**
- `PROJECT_ROOT` → `PROJECT_DIR` (the git repo, unchanged in content)
- New: `SANDBOX_DIR` — sibling to `PROJECT_DIR`, harness-owned, contains all harness artefacts

**New layout:**
```
WORKDIR/
├── project-dir/          ← PROJECT_DIR (git repo, clean)
└── project-dir-sandbox/  ← SANDBOX_DIR (harness workspace, gitignored)
    ├── Makefile
    ├── .env
    ├── input/            ← operator input channel (see below)
    ├── .bootstrap/       ← snapshot and brief (built at run time)
    └── .workspace/       ← reporting workspace (agent output)
```

`SANDBOX_DIR` defaults to `<parent-of-PROJECT_DIR>/<project-dir-name>-sandbox/`. Overridable via config.

- [x] Update `start_agent.sh` — derive `SANDBOX_DIR` from `PROJECT_DIR` by convention (overridable); write `.bootstrap/` and `.workspace/` into `SANDBOX_DIR`; rename internal variables from `PROJECT_ROOT` to `PROJECT_DIR`
- [x] Update `--root` flag to `--project` on `start_agent.sh` and the CLI wrapper
- [x] Update `lib/` path derivation where `PROJECT_ROOT` is referenced
- [x] Update `execution_model.md` — new directory layout, updated terminology, updated mount shape table
- [x] Update `agent_workflow.md` — updated operator directory layout and pre-run setup instructions
- [x] Note: onboarding skill update is a separate follow-on task; it must be written to be modular so future directory convention changes do not require a full skill rewrite

#### Operator input channel

Add a dedicated read-only input channel for the operator to pass task files, briefs, and file path lists to the agent before a run. The agent reads from this channel during the run; it cannot write back.

**Mount addition:**
```
Host: SANDBOX_DIR/input/    →    Container: /home/agentuser/.input/    (read-only)
```

The entrypoint copies contents of `.bootstrap/` and `.input/` into `sandbox/` at startup alongside the project snapshot, making them available to the agent as ordinary files.

- [x] Add `SANDBOX_DIR/input/` as a separate RO container mount in `start_agent.sh`
- [x] Update `container-entrypoint.sh` — copy `input/` contents into `sandbox/` at startup
- [x] Update `execution_model.md` — document input channel as a third container mount
- [x] Define input channel lifecycle in `agent_workflow.md`: written by operator before run, read by agent during run, operator clears or overwrites before next run
- [x] Confirm: does read access to `.workspace/` expose original repo git history? (Snapshot copy design was chosen to prevent this — verify it holds under the new layout)

#### Story resolution

- [x] Resolve [Obsidian Vault Onboarding](../discussions/story_obsidian_vault_onboarding.md) — KV1–KV4 complete. KV5 (agent modification workflow) requires two-layer architecture; promoted to M2.1. Harness-agnostic directory prerequisite addressed in directory restructuring above.
- [x] Resolve [Website Dev Project Onboarding](../discussions/story_website_dev.md) — port exposure, live reload, XSS risk assessment. Deferred to M2.2 as a bash-enabled capability layer use case. No M1.5 implementation required; open questions are M2.2 scope.
- [x] Resolve [Knowledge Store Provider](../discussions/story_provider_knowledge_store.md) — investigation complete; two-layer architecture adopted; work promoted to M2. Story closed.

#### Workflow convergence gate

- [x] Decision recorded: workflow convergence gate deferred to post-M2. The conceptual workflow (operator initiates run, agent produces diff, operator reviews and applies) is unchanged. The backing implementation changes under the two-layer model — diff pipeline migrates to the capability layer in M2. Checkpoint branch pattern remains operative. Formal apply convention decision deferred to M2.4 when the capability layer diff pipeline is designed.

---

## Deferred Decisions

### Checkpoint tooling — promote to harness scripts/

The checkpoint scripts produced in the vault onboarding story (`workflow/knowledge-vault/scripts/`) are project-agnostic by design. A decision to promote them to `scripts/` as first-class harness tooling is deferred. If promoted: integration testing against at least one non-vault workflow is required before the scripts are treated as general infrastructure.

### Checkpoint branch pattern — adopt as harness-level apply convention

The vault workflow established a checkpoint branch pattern: create a dated branch from current HEAD before each agent session; apply the diff after review; roll back to the checkpoint branch if the diff is rejected. This pattern is operationally validated through KV4. A decision to formalise it as the standard `apply` convention is deferred to M2.4, where the capability layer diff pipeline redesign will determine whether the checkpoint pattern composes with or supersedes the current `patch.diff` model.

### Investigation into checkpointing methods
Snapshot from a clean git ref rather than working tree — operator designates a commit SHA or tag; a dirty or broken working tree has no effect on what the agent sees

### Pre-session checkpoint automation

Whether to automate checkpoint creation before each agent session (e.g. as part of `make start`) is deferred until the manual checkpoint workflow is validated at scale. Revisit after M2.4 apply workflow is stable.

### Onboarding skill modularisation

The sandbox-onboarding skill currently produces a Makefile placed at `PROJECT_ROOT`. Under the new directory layout the Makefile moves to `SANDBOX_DIR`. The skill update is a follow-on task after M1.5 directory restructuring is complete. **Requirement:** the updated skill must be written to be modular — directory convention variables should be isolated so that future layout changes do not require a full skill rewrite.

---

## Future Milestones

Detail sections for M2 onward are in [`roadmap_future.md`](roadmap_future.md). The summary table above links directly to each section.

Milestone definitions in `roadmap_future.md` are planning targets and expected to evolve. When a milestone becomes active, its section is promoted into this file under `## Upcoming Milestones`.

---

## Notes

- **Core minimum usable system:** M1 + M1.1 + M1.2
- M2 introduces the two-layer architecture; all current single-container architecture docs are hot during M2
- M3 introduces structured autonomy on top of the two-layer foundation
- Manual review remains mandatory until automation is formally trusted
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../architecture/security.md).

---

## Known Limitations

- **Submodules not supported** — `snapshot_enumerate_files` detects gitlink entries and aborts with a clear message. Full submodule support (recursive enumeration into nested repos) is deferred; operators must deinitialise submodules before running the harness.

- **Stale git index causes cryptic snapshot failures** — `snapshot_enumerate_files` enumerates files via `git ls-files` against the current index. If tracked files have been deleted from disk but not staged for removal (`git rm`), `snapshot_copy_files` will fail with `cp: cannot stat`. Fix with `git rm --cached <file>` followed by a commit. A future hardening pass should add existence validation in `snapshot_enumerate_files` to produce a clear error rather than a mid-pipeline `cp` failure.

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

---

### Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 — Structural Separation — folder ownership, temperature classification, root document audience separation
- [ ] Level 2 — Review Discipline — PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 — Temperature & Freeze Policy — hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 — Change Classification Matrix — explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 — Automated Enforcement — CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents
