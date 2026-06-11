# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules — task granularity, cleanup on completion, section removal — are defined in [`docs/operations/roadmap_policy.md`](../operations/roadmap_policy.md).

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
| M2.1 — General Capability Layer Prototype | [Complete — see changelog](changelog.md) |
| M2.2 — Reasoning Layer Modularisation | [Complete — see changelog](changelog.md) |
| M2.3 — Apply Workflow: Capability Layer Diff Pipeline | [Complete — see changelog](changelog.md) |
| [M2.4 — Session and Config Persistence](#m24--session-and-config-persistence) | Complete |
| W1 — Vault Capability Layer Prototype | Deferred |
| M2.6 — Session Resume Across Provider Implementations | Not started |
| M2.7 — Session Identity and Harness Versioning | [Complete — see changelog](changelog.md) |
| **Single-Agent Coordination** | |
| [M3 — Autonomous Task Execution, Manual Review Workflow](roadmap_future.md#m3--autonomous-task-execution-manual-review-workflow) | Not started |
| **Multi-Agent Coordination** | |
| [M4 — Metadata Seeding](roadmap_future.md#m4--metadata-seeding) | Not started |
| [M5 — Agent-Assigned Branch Management](roadmap_future.md#m5--agent-assigned-branch-management) | Not started |
| **Multi-Agent Orchestration** | |
| [M6.1 — Task Dispatch](roadmap_future.md#m61--task-dispatch) | Not started |
| [M6.2 — Constraint Enforcement](roadmap_future.md#m62--constraint-enforcement) | Not started |
| [M6.3 — Review & CI/CD Integration](roadmap_future.md#m63--review--cicd-integration) | Not started |

---

## User Stories

Open stories under active investigation. Closed stories are removed from this list.

- [`story_prompt_evals.md`](docs/discussions/story_prompt_evals.md) — How do we test that skills and prompt templates correctly reflect the policy documents they encode? Manual read-through comparison doesn't scale across N skills × M policy sections.
| **Standalone** | |
| [M7 — Safe vs Unsafe Mode (Policy Layer)](roadmap_future.md#m7--safe-vs-unsafe-mode-policy-layer) | Not started |
| [M8 — Skills / Templates](roadmap_future.md#m8--skills--templates) | Not started |

---

## Upcoming Milestones

### M2 — Reasoning/Capability Layer Separation

**Objective:** Separate the harness into a reasoning layer (agent container) and a capability layer (sandbox container, working content, optional MCP server). This is the foundational architectural change that enables vault workflows, webapp workflows, provider swapping, and autonomous task execution. All M1.x architecture documents are hot during this milestone and updated sub-milestone by sub-milestone.

Conceptual model: [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md)
Design rationale: [`investigation_mcp_server.md`](../discussions/investigation_mcp_server.md) — Conclusion

#### M2.4 — Session and Config Persistence

**Objective:** Establish the provider config lifecycle — onboarding-time population, seeding of provider-layer prompts/skills, and session history persistence — ensuring state survives between container restarts across all host filesystem types.

**Work completed:**
- Directory bind mount (M2.7) — session history persists via `sessions/` bind mount; `bin/` cross-device mv issue resolved by owning the directory in the image (see `providers/pi/provider.Dockerfile`) rather than tmpfs, which was removed for simplicity
- Provider-layer prompts/skills seeded from `providers/<n>/config/agent/` via onboarding
- Auth tokens stored as env var references in `auth.json` (ephemeral by design — security feature, prevents write-back of secret values)
- Selective bind mount pattern (`sessions/`, `prompts/`, `skills/` persisted; remaining config ephemeral via copy-in) — resolution for cross-filesystem `utime()`/`EPERM` issue on macOS/Windows Docker Desktop

**Status:** Complete. Design settled; implementation artifacts applied (M2.7+). See handovers `20260407-03-close-m2_4.md`, `20260513-10-impl-settings_json_collision_fix.md`, `20260522-05-design-pi_agent_mount_strategy.md`.

**Scope note:** M2.4 covers config and state persistence infrastructure. It does not define or validate provider-level session resume — the ability to continue a prior conversation. That is scoped to M2.6.

#### W1 — Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone — separate workflow for the Obsidian vault use case. Re-activate when KV5 timeline demands it. See `roadmap_future.md` for task checklist.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first, then add MCP server as enhancement. Unblocks KV5.

#### M2.6 — Session Resume Across Provider Implementations

**Objective:** Define and implement true session persistence — the ability to resume a prior conversation — for each supported provider. M2.4 established that state survives between sessions; M2.6 defines what resuming that state actually means per provider and how the harness supports it.

**Depends on:** M2.4. **Scope:** Investigation-first. Characterise session file format, export mechanism, and resume invocation for pi, Hermes, and opencode. Design harness support based on findings. Known starting points:

- **pi**: requires explicit `pi export` to write session files; resume requires session ID and specific invocation flags. Neither is currently triggered or passed by the harness.
- **Hermes**: assumed to live-load conversation history from home directory on startup — not validated.
- **opencode**: session persistence mechanism unknown. Requires investigation before any design work.

Each provider may result in a different integration pattern. Investigation findings should be recorded as named investigation documents before implementation begins.

**Related story:** [`story_agent_state_persistence.md`](docs/devlog/discussions/story_agent_state_persistence.md) — Agent state under AGENT_HOME must survive across container restarts. The bind mount approach fails on cross-filesystem mounts (utime/EPERM). Defines the persistence model that M2.6's session resume mechanism depends on.

**Moved from M2.7:**
- [ ] Autosave and session-save reliability — Autosave subshell has no resilience; EXIT trap discards `diff_export` return value. Scope permanent solution — test save behaviour within dry-run.

#### M2.7 — Session Identity and Harness Versioning

**Status:** Complete. Hash-based identity model (SANDBOX_ID, RUN_ID), container lifecycle (naming, labels, stop/prune), artefact paths, build pipeline simplification (repo-root context, COPY contract tests), two-sig model (container-sig label + preflight), generic pre-flight validation, dual-layer dry-run seam testing, DIFF_TYPE flag, --no-renames flag. See handover chain `20260609-01` through `20260611-04` and changelog entry.

**Deferred from M2.7:**
- Harness-sig — deferred to `roadmap_future.md`
- Process improvements (fast-track criteria, decision recording, stale skill reference) — deferred, not milestone-scoped

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

- **Bad diff applied to host repo corrupts future snapshots** — `PROJECT_DIR` is never mounted during a run and the agent works exclusively in `sandbox/`, so a bad run cannot corrupt the host repo during execution. The risk is after the operator applies a bad diff — the host repo is then in a bad state and future snapshots reflect it. See [Recovery](#recovery) in `docs/development/quickstart.md` for how to reset to a known-good state.

- **`make start opencode` and `make start hermes` do not share a capability layer** — each provider invocation builds and runs its own capability layer image independently. They should share a single capability layer per project, since the sandbox, snapshot pipeline, and diff pipeline are provider-agnostic. This is a known architectural gap; resolving it requires the capability layer build and lifecycle to be fully decoupled from the provider selection path.

- **Multi-service project composition not supported** — projects that run multiple services (e.g. a web app with a database and test containers) have no mechanism to inject additional services alongside the harness-managed sandbox and agent. A deferred design task is to define a composition method — likely an operator-supplied overlay that `start_agent.sh` merges with the generated base — that lets projects define their own containers without forking the harness template. See `execution_model.md` for the deferred discussion.

### Deferred (not milestone-scoped)

- **Docs restructuring investigation** — The docs/ directory currently mixes architecture/concepts/operations/development/ discussions/devlog into a single tree. Architecture and concepts docs are baked into container images; operations and development docs are coding-agent workflow artifacts that should logically live in a separate namespace. Investigation deferred — no immediate use case warrants it, and the current layout is functional.

- **`docker compose down -v` race with EXIT trap** — When `stop.sh` runs `docker compose down -v`, the `-v` flag removes anonymous volumes referenced by `volumes_from`. If Docker Compose removes those before the sandbox container's EXIT trap finishes writing the session export, the export could be interrupted. Triaged as a plausible error but unlikely to be causing current problems — session-diffs are a bind mount (not affected by `-v`), and anonymous volume references on the agent service do not block the sandbox trap. Recorded for completeness from handover audit finding F3. No milestone assigned.

### Addressed in upcoming milestones

- **Host-side harness staleness** *(deferred)* — after `git pull`, the installed `agent-sandbox` CLI may silently execute changed scripts/libs from the repo checkout. `container-sig` does not detect this (it detects image staleness, not CLI staleness). A self-contained binary with semantic versioning is needed to close this gap. Scoped as a standalone future milestone in [`roadmap_future.md`](roadmap_future.md) §Harness Packaging and Versioning.
