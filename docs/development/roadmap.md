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
| M1.5 — Workflow Convergence & Directory Restructuring | [Complete — see changelog](changelog.md) |
| **Two-Layer Architecture** | |
| [M2 — Reasoning/Capability Layer Separation](#m2--reasoningcapability-layer-separation) | In progress |
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

### M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container, MCP client) and a capability layer (MCP server container, project tool interface). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

#### M2.1 — Capability Layer Prototype: Vault (MCP server, Obsidian)

**Objective:** Build and validate the first capability layer container for the Obsidian vault use case. This proves the two-layer model in practice and unblocks KV5.

**Open decisions (must resolve before implementation):**
- Working mount strategy: live vault mount (simpler, diff from git history post-session) vs sandbox copy in MCP server container (cleaner diff, harness-managed). Live mount preferred; confirm before starting.
- MCP server selection: evaluate candidates against criteria (licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency). See `investigation_mcp_server.md` — MCP server candidates table.

**Tasks:**
- [ ] Decide working mount strategy (live vs sandbox copy)
- [ ] Evaluate MCP server candidates; select one for prototype
- [ ] Build MCP server container image: base image + selected server + vault mount at `/working`
- [ ] Configure OpenCode to connect to MCP server via HTTP; confirm no working mount in OpenCode container
- [ ] Validate: OpenCode routes vault operations through MCP tools, not built-in filesystem tools
- [ ] Validate: reporting workspace works end-to-end — agent reads brief from `input/`, writes `todo.md` and progress to `.workspace/`, operator finds expected output after session
- [ ] Validate: binary file handling (vault attachments) under selected MCP server
- [ ] Design harness integration: MCP server container lifecycle (start before agent, stop after), Docker network configuration, `start_agent.sh` changes for two-container orchestration
- [ ] Implement harness integration
- [ ] Define post-session diff generation against working mount; write to `.workspace/changes/`
- [ ] Update `execution_model.md` — two-container model, capability layer lifecycle, new mount shape
- [ ] Update `security.md` — trust boundary table for two containers
- [ ] Update `agent_workflow.md` — operator workflow with two containers
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to live vault

#### M2.2 — Capability Layer Prototype: General (bash-enabled sandbox)

**Objective:** Build a general-purpose capability layer for coding and webapp workflows using bash tools. This proves the capability layer model generalises beyond vault-specific MCP servers and enables the website dev workflow.

**Known requirements (from website dev story open questions):**
- Port exposure for live reload (dev server)
- Bash tool interface (run commands, read/write files)
- XSS risk assessment for serve mode when the agent is running a live web server

**Tasks:**
- [ ] Design bash-enabled MCP server container: tool surface (bash, read, write, run_server), port exposure model
- [ ] Assess XSS risk: agent-controlled content served on an exposed port — determine acceptable mitigations
- [ ] Build bash-enabled capability layer container
- [ ] Validate with a webapp project: live reload, port accessible from host, agent makes changes visible immediately
- [ ] Update `execution_model.md` — document capability layer variants (vault vs general)
- [ ] Deferred breakdown: full task list to be defined once M2.1 harness integration pattern is established

#### M2.3 — Reasoning Layer Modularisation

**Objective:** Extract shared harness logic from the OpenCode-specific scripts so that any MCP-compatible reasoning layer can be added without rewriting shared infrastructure. The provider interface under the two-layer model is the MCP protocol — per-provider work is limited to container configuration and mode support.

**Depends on:** M2.1 harness integration pattern established (so extraction reflects the correct two-container boundary).

**Tasks:**
- [ ] Audit `providers/opencode/start_agent.sh` — extract shared logic (snapshot, mount construction, env loading, MCP server lifecycle) into `lib/`; leave only OpenCode-specific invocation
- [ ] Audit `container-entrypoint.sh` — extract shared startup sequence into sourced lib; leave only provider exec step; move from `providers/opencode/` to `lib/` or shared location
- [ ] Evaluate checkpoint scripts in `workflow/knowledge-vault/scripts/` for promotion to `scripts/` as first-class harness tooling; integration testing against at least one non-vault workflow required before treating as general infrastructure
- [ ] Document execution modes formally in `execution_model.md`: `serve`, `start`, `dry-run`, `headless` (reserved)
- [ ] Define what a conforming reasoning layer provider must supply: mode support declarations, container config, MCP client configuration
- [ ] Validate OpenCode provider conforms after refactor
- [ ] Deferred breakdown: Claude Code provider integration — full task list after M2.3 shared logic extraction is complete and [investigation_claude_code.md](../discussions/investigation_claude_code.md) open questions are resolved

#### M2.4 — Apply Workflow: Capability Layer Diff Pipeline

**Objective:** Redesign the apply workflow to reflect the two-layer model: diff generated post-session from capability layer working mount, agent commit history preserved, checkpoint branch pattern formalised.

**Depends on:** M2.1 capability layer implementation (diff pipeline mechanics depend on how the working mount is structured).

**Known design (from M1.6 scoping, now reframed):**
- Export full commit history from capability layer working content using `git format-patch` or equivalent
- `apply` creates a checkpoint branch from current host HEAD before touching anything
- Agent commits replayed onto a named branch (`agent/<task-id>`); original branch intact
- Resolve: archive `patch.diff` or drop in favour of replayable commit history

**Deferred decisions to resolve in this milestone:**
- Checkpoint branch pattern — formalise as the standard `apply` convention. The vault workflow established a checkpoint branch pattern (dated branch from HEAD before each session; apply diff after review; roll back if rejected) validated through KV4. Determine whether this pattern composes with or supersedes the current `patch.diff` model under the capability layer diff pipeline.
- Investigation into checkpointing methods — evaluate snapshotting from a clean git ref rather than working tree (operator designates a commit SHA or tag; a dirty or broken working tree has no effect on what the agent sees).
- Pre-session checkpoint automation — evaluate automating checkpoint creation before each session (e.g. as part of `make start`). Defer if manual workflow has not been validated at scale by this milestone.

**Tasks:**
- [ ] Confirm checkpoint branch pattern as the standard apply convention (resolves deferred decision)
- [ ] Agree on export format (`git format-patch` vs bundle vs other)
- [ ] Parameterise agent branch naming (`agent/<task-id>`) — single-agent case
- [ ] Implement diff pipeline in capability layer (or harness post-session script)
- [ ] Update `apply_workspace.sh` — checkpoint branch creation, replay commits
- [ ] Resolve patch history consideration — archive or drop
- [ ] Resolve checkpointing method — clean git ref vs working tree snapshot
- [ ] Decide pre-session checkpoint automation — implement or explicitly defer beyond M2.4
- [ ] Update `agent_workflow.md` and `execution_model.md`

#### M2.5 — Session Persistence (Reasoning Layer)

**Objective:** Preserve OpenCode session history across container runs. Provider-specific to the OpenCode reasoning layer; scoped here as a reasoning layer concern separate from the capability layer.

**Depends on:** M2.3 (reasoning layer modularisation, so session DB mount is cleanly scoped to the provider).

**Tasks:**
- [ ] Identify host-side storage location for session DB (per-project, in `SANDBOX_DIR`)
- [ ] Add mount for `~/.local/share/opencode/` into reasoning layer container
- [ ] Update `execution_model.md` — document session DB mount
- [ ] Verify DB survives container restart and is correctly re-attached on next run

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
