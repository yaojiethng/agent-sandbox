# Story — Zed as a UI Option for agent-sandbox

**Status:** Investigation in progress

---

## Context

The operator currently runs an agent-sandbox session across multiple windows: a host editor (VSCode) for reviewing changes in `PROJECT_DIR`, a terminal in `SANDBOX_DIR` for `make apply` / `make draft`, a terminal attached to the reasoning layer container for prompting the agent, a file explorer on `SANDBOX_DIR` for sandbox-side artefacts, and ad-hoc inspection of agent file changes via the same channels. The goal is to consolidate as many of these as possible into Zed — ideally with each surface presented well, or at minimum collapsed into one window.

Zed offers flexible workspace, terminal pane, project-task, and container-integration features. The question is which combination of these features and which agent-sandbox primitives compose into a configuration that covers the operator's use cases — and where the gaps are.

The natural analogue is Open WebUI sitting on top of `opencode serve`: Open WebUI works because the harness exposes a documented endpoint shape; the harness has no opinion on whether Open WebUI exists. Zed integration aims for the same relationship.

### Framing axiom

agent-sandbox is an agentic tool that Zed has access to. Zed is not part of agent-sandbox. The harness exposes primitives; Zed composes them. Any approach that requires the harness to know Zed exists in a structural way is a departure from the framing and needs explicit justification. Findings that contradict this framing are themselves significant — they would mean the operator surface needs more than primitive composition can provide.

### Approach to evaluation

The integration shape has multiple independent axes (lifecycle, terminal panes, editor panes, multi-writer policy). Each axis offers several values. A working configuration is a *combination across axes*, not a single option from a flat list. The evaluation question is therefore: **what combination covers the most use cases under the constraints?** — not "which option is best?"

Within each axis, some values are mutually exclusive (one lifecycle command at a time). Across axes, values compose freely (terminal pane choices and editor pane choices are independent).

---

## Pain Points

The operator's current workflow surfaces. (1)–(4) are existing pain; (5)–(6) are nice-to-haves not currently available without friction.

| # | Surface | Currently | Notes |
|---|---|---|---|
| 1 | Reviewing changes on host | VSCode opened from `PROJECT_DIR` | Window switch from primary editor; separate from the rest of the workflow |
| 2 | Applying diffs from container | Terminal in `SANDBOX_DIR` running `make apply` / `make draft` | Separate terminal from the agent terminal; manual cd between folders |
| 3 | Sending prompts to the agent | Terminal attached to reasoning layer container | Confined to one terminal window; no editor context alongside |
| 4a | Running sandbox commands | Terminal in `SANDBOX_DIR` | Often shares a window with (2); can be folded into Zed's terminal pane easily |
| 4b | File explorer on `SANDBOX_DIR` | Second file explorer window | Browsing config, brief, provider config; distinct from (4a) by optimal UI |
| 5 | View into shared operator/sandbox channels (`workspace/input/`, `workspace/output/`, `workspace/session-diffs/`) | Done via the file explorer for (4b), tediously | Currently same window as (4b) but distinct use — these are communication surfaces, not configuration |
| 6 | View into agent's live file changes in `sandbox/` | Not currently available except by entering the container shell and running `git diff` / `cat` | Steering use case: see when the agent is going wrong without a port-out / review / amend / port-in loop |

Use case 5 is currently available but tedious; use case 6 is currently not really available at all. Both are nice-to-haves that Zed could plausibly offer if the right axes line up.

claude.ai web chat (this conversation) is excluded — operator-side reasoning, not part of the sandbox loop.

---

## Constraints

These hold across any combination across the axes.

1. **Lifetime coupling.** When the operator uses agent-sandbox via Zed, closing Zed closes the session.
2. **Cold start.** agent-sandbox is not running when Zed opens. The session starts inside Zed.
3. **Operator restart authority.** Within a Zed session, the operator can stop and restart the agent-sandbox container set freely.
4. **Security invariants preserved.** The four invariants in [`security.md`](../architecture/security.md) hold: agents in containers, output via diffs, human approval gate, depth ≤ 2 with no grandchildren.
5. **Bare terminal still works.** `make start` and `make serve` are not changed in shape or behaviour by Zed integration.
6. **Harness change is permitted but should be minimal.** Changes are not avoided on principle, but the question is framed around reuse of existing primitives first.

---

## Preliminary Context

What is known going into the experiment, before any hands-on testing. This is preliminary, not a finding — it is the material the experiment is built on top of.

### Existing primitives Zed can hook into

Without any harness change, an operator with Zed installed has access to:

| Primitive | Source | Use |
|---|---|---|
| `make start PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-start-provider-provider-rebuild1) | Foreground task; closing terminal pane signals teardown |
| `make serve PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-serve-provider-provider-rebuild1) | Background mode; agent on `127.0.0.1:SERVE_PORT` (provider-specific server interface) |
| `make stop` | [`tool_interface.md`](../architecture/tool_interface.md) | Explicit teardown |
| Deterministic container names | [`tool_interface.md`](../architecture/tool_interface.md#container-naming) | `sandbox-<project>` and `<provider>-agent-<project>` — known at task-write time |
| `docker attach <container>` | Docker | TTY connection to running container's PID 1 |
| `docker exec -it <container> <cmd>` | Docker | Fresh shell or process inside running container |
| `docker logs -f <container>` | Docker | Tail of stdout/stderr from PID 1 |
| Host-side workspace | [`tool_interface.md`](../architecture/tool_interface.md#mount-shape-guarantees) | `SANDBOX_DIR` and contents (`AGENTS.md`, `.workspace/`, provider config) editable directly |
| `agent-sandbox` CLI wrapper | `scripts/agent-sandbox.sh` | Host-installed command surface; preferred wrapper target |
| Zed `.zed/tasks.json` | Zed | Project-scoped task definitions; can wrap any host command |
| Zed custom commands / slash commands | Zed | Editor-side commands; viable but less ideal than wrapping host-installed tools |
| Zed terminal pane | Zed | Plain terminal — agent-sandbox can be invoked here directly with no wrapping |
| Zed multi-workspace window | Zed | Multiple folders visible in one window; flexibility for split host/sandbox views |
| Zed Dev Container support | Zed | Inject Zed remote server into a container via `devcontainer.json` |
| Zed `docker exec` task targeting a running container by name | Zed + Docker | Open a terminal pane that runs a command inside an already-running container — does not require `devcontainer.json` |
| Zed editor on a folder | Zed | Open any host-readable directory as an editor workspace, including diff view |

**Wrappers vs custom commands.** Zed tasks that wrap host-installed commands (`make`, `agent-sandbox`, `docker`) are preferred — they keep the contract on the harness side, leave bare terminal usage unaffected, and don't require Zed-specific knowledge in the harness. Zed custom commands are viable for purely editor-side concerns (e.g. "send selection to agent input file") but should not be the primary surface for harness interaction.

### Concrete Zed shapes from research

The following shapes are documented in the operator's research transcript. Captured here so the axes below can refer to them concretely.

**Shape 1 — `.zed/tasks.json` task running `make start` in a new terminal:**

```jsonc
[
  {
    "label": "Start Sandbox",
    "command": "make start",
    "use_new_terminal": true,
    "allow_concurrent_runs": false
  }
]
```

Plain task definition — no Dev Container required. Closing the terminal pane sends signals to the make process. Foreground ownership is the make process, not Zed itself.

**Shape 2 — `.zed/tasks.json` task that opens a shell inside a running container:**

```jsonc
[
  {
    "label": "Attach to Agent Container",
    "command": "bash",
    "args": [
      "-c",
      "NAME=$(docker ps --filter 'name=<provider>-agent-<project>' --format '{{.Names}}'); docker exec -it $NAME bash"
    ],
    "use_new_terminal": true
  }
]
```

agent-sandbox container names are deterministic, so the discovery filter is straightforward. Whether to use `docker exec -it bash` (fresh shell) or `docker attach $NAME` (the agent TUI) depends on which surface the operator wants in that pane.

**Shape 3 — Compose-based Dev Container with `initializeCommand`:**

```jsonc
{
  "name": "Pi Agent Sandbox",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "agent-container",
  "initializeCommand": "make start",
  "overrideCommand": false,
  "workspaceFolder": "/workspace"
}
```

This shape has three blockers that make it impractical without substantial harness redesign:

- **Foreground-blocking.** `make start` foreground-attaches to the agent TUI. Zed expects `initializeCommand` to return so it can attach its remote server. The harness cannot return control to Zed without `make start` either backgrounding (breaking the TUI surface) or finishing (which means the session is over).
- **Static `service` name.** Compose-based devcontainers want a static service name. agent-sandbox names are deterministic so this is solvable per-project.
- **Compose file is generated, not authored.** agent-sandbox composes the runtime compose file by merging many partial fragments at session start ([`execution_model.md`](../architecture/execution_model.md)). The merged file is a tmpfile, not a stable on-disk artifact at a path Zed can name in `dockerComposeFile`. Adopting Shape 3 would require either pre-materialising the merged compose file at a stable path (a non-trivial change to the compose generation model) or designing around fragment-aware devcontainer config (which Zed does not support).

**Shape 4 — Dynamic service name via `${localEnv:...}`:**

```jsonc
{
  "service": "${localEnv:SERVICE_NAME}"
}
```

Pulls the service name from the host environment that launched Zed. The lookup itself is feasible — a small bash wrapper around `zed .` can resolve the service name from available host context (repo name, project name, cwd path, docker labels) and export `SERVICE_NAME` before invoking Zed. agent-sandbox already labels containers and has deterministic naming, so the lookup is well-supported. This is a building block for any future approach that needs host-resolved variables passed into Zed; it does not solve Shape 3's foreground-blocking or compose-generation issues on its own.

### Axes of the integration design

A working Zed integration is a combination of choices across the following four axes. Within an axis, values are mutually exclusive (you can only run one lifecycle command at a time). Across axes, values compose freely.

#### Axis A — Lifecycle ownership (how does the session start?)

| Value | Description |
|---|---|
| A1 | Foreground task: `make start` from a Zed task. Closing the tab signals teardown. |
| A2 | Foreground task: `make serve` from a Zed task. Containers run independently of Zed; constraint 1 (close-Zed-closes-session) requires extra wrapper work. Provider-specific server API; load-bearing assumption that pi exposes one usable to Zed. |
| A3 | New harness mode (`make zed` or similar). Wrapper that starts containers, opens Zed pre-configured, waits on Zed exit, runs `make stop`. Departs from the framing axiom. |

#### Axis B — Terminal pane targets (where do Zed terminal panes point?)

Multiple values can be combined — Zed supports multiple terminal panes per window.

| Value | Description |
|---|---|
| B0 | Plain shell on host (in `SANDBOX_DIR` or `PROJECT_DIR`). Used for `make` commands, git, etc. |
| B1 | `docker attach` to reasoning layer (`<provider>-agent-<project>`). TTY view of the live agent. |
| B2 | `docker exec` shell into reasoning layer. Inspection shell separate from the agent TUI. |
| B3 | `docker exec` shell into capability layer (`sandbox-<project>`). Inspection shell on the volume-owning side. |

#### Axis C — Editor workspace targets (where does Zed's editor point?)

Multiple values can be combined — Zed supports multiple workspaces per window.

| Value | Description |
|---|---|
| C0 | `PROJECT_DIR` as a host workspace. Operator's view of the host repo. |
| C1 | `SANDBOX_DIR` as a host workspace. Operator's view of `AGENTS.md`, `.workspace/`, provider config. |
| C2 | Container workspace via Dev Container remote-server. Zed injects its remote server into a container; full IDE features on the container's filesystem including `sandbox/`. Adds a long-running Zed process to the container — meaningful change to container runtime profile. |
| C3 | No editor workspace on container — container access is via terminal panes only (axis B). |
| C4 | Sandbox volume bind-mounted to host so Zed can open it as a workspace without entering the container. Requires harness change — `sandbox/` is currently a Docker anonymous volume specifically because it should not appear on the host. Breaks the rationale in [`container_model.md` — Why `--volumes-from` rather than a named volume](../architecture/container_model.md). |

#### Axis D — Operator/agent edit policy on `sandbox/`

| Value | Description |
|---|---|
| D1 | Single-writer. Operator does not edit `sandbox/` directly. Edits flow via `AGENTS.md`, `workspace/input/`, and the existing `!`-hook commit pattern inside the agent. |
| D2 | Multi-writer. Operator and agent both edit `sandbox/` (requires C2 or C4 to be a useful surface). |
| D3 | Comment channel via `workspace/input/`. Additive to D1 or D2 — operator-authored comments and quoted sections written to `workspace/input/` for the agent to read on next turn. Uses an existing primitive without modification. |

### Rejected approaches (off the axes)

These were considered and ruled out at this preliminary stage. Recorded for traceability.

| Rejected | Reason | Would change if |
|---|---|---|
| **Shape 3 — Compose-based devcontainer + `initializeCommand`** | Three compounding blockers (see Shape 3 detail): foreground-blocking on `make start`, static-`service`-name issue, and the harness's compose-file generation model has no stable on-disk path for `dockerComposeFile`. | The harness adopts a stable compose-file output and a non-foreground-blocking start mode; both substantial. |
| **Zed + agent ACP** (Zed as ACP client, agent as ACP server) | ACP implementation is feature-incomplete with no timeline. Pi (the primary provider) does not have working ACP support. | Pi or another adopted provider ships sufficiently complete ACP support with a stable surface. |
| **Zed-as-MCP-server, agent connects out** | Crosses the trust boundary backwards — the operator's editor becomes a service the agent calls into, creating an outbound channel from the agent to operator-side software on the host. | A use case appears that genuinely requires the agent to query the editor, *and* a model exists to bound the surface. |
| **Capability layer MCP with both Zed and agent as clients** | MCP capability layer is anticipated but not currently planned (see [`two_layer_model.md`](../concepts/two_layer_model.md#capability-layer-configurations)). Premature. | The MCP capability layer is adopted for unrelated reasons, at which point Zed-as-second-client becomes a small add. |

### Use case coverage by axis value

How each axis value contributes to each use case. `✓` = covers; `partial` = partial fit; `—` = does not address; `?` = pending experimental confirmation.

| | (1) Review host | (2) Apply diffs | (3) Send prompts | (4a) Run sandbox cmds | (4b) Sandbox file explorer | (5) Shared channels | (6) Live agent edits |
|---|---|---|---|---|---|---|---|
| **A1** (`make start`) | — | — | indirect (via terminal pane) | — | — | — | — |
| **A2** (`make serve`) | — | — | rejected for pi (no server API; ACP rejected) | — | — | — | — |
| **A3** (`make zed` mode) | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config |
| **B0** (host shell) | — | ✓ via `make apply` / `make draft` | — | ✓ | — | — | — |
| **B1** (attach reasoning TUI) | — | — | ✓ with discipline (wait for welcome message before attach) | — | — | — | — |
| **B2** (exec reasoning shell) | — | partial (via shell) | — | partial (sandbox-side commands via shell) | — | — | partial (`git diff` in shell) |
| **B3** (exec capability shell) | — | partial (via shell) | — | partial | — | — | partial (`git diff` in shell) |
| **C0** (`PROJECT_DIR` workspace) | ✓ † | — | — | — | — | — | — |
| **C1** (`SANDBOX_DIR` workspace) | — | ✓ † via tasks running `make apply` | — | ✓ via task wrappers + file tree | ✓ | ✓ | — |
| **C2** (container workspace) | — | — | — | — | — | — | ✓ editor or diff view on `sandbox/` |
| **C3** (no container editor) | — | — | — | — | — | — | — |
| **C4** (host bind `sandbox/`) | — | — | — | — | — | — | ? would cover (6) without C2 if harness change accepted |
| **D1** | — | — | — | — | — | — | — |
| **D2** | — | — | — | — | — | — | partial — viewing edits is C2/C4; D2 is whether operator can also write |
| **D3** (comment channel) | — | — | partial — async channel into agent reasoning | — | — | partial | — |

**Reading the table.** No single axis value covers all use cases — that's expected, since the axes are orthogonal. Combinations matter. Some informal observations from the table:

- Use cases (1), (2), (4a), (4b), (5) all line up under combinations of C0 + C1 + B0, with no harness change required. This is the cheapest-coverage cluster. **Confirmed working in Session 1.**
- Use case (3) is covered by B1 (`docker attach`) once the wait-for-welcome discipline is applied. **Resolved in Session 1.**
- Use case (6) — live view into agent file changes — was confirmed high-importance in Session 1 (Q4 resolved). The on-axis option is C2; **Session 3 is scoped to test it.** C4 is the documented fallback if Session 3 fails.
- A2 is closed for pi (no server API; ACP rejected). The row remains in the table for traceability but is not pursued.

**† Caveat — Zed git-pane lock contention.** Recent Zed versions hold `.git/index.lock` on every detected git repo in open workspaces whenever git features are enabled. This blocks host-side git mutation: any concurrent `make confirm` / `make draft` / `make apply` (or operator `git commit`) from a bare terminal will fail or block while Zed is open on `PROJECT_DIR`. Workaround: close the Zed workspace before running these commands. Use case (1) (review changes) is unaffected as long as no concurrent host-side git mutation is running. See Open Questions Q13 and Investigation Findings → Session 2 for details. Status: upstream-pending.

These are observations from the table updated against Sessions 1 and 2 findings.

---

## Open Questions

What remains unresolved given the preliminary context above. Numbered for cross-reference. Status updated as hand-rolled sessions produce findings.

### Resolved

1. **Does `docker attach` to the reasoning layer (B1) render the agent TUI usefully inside a Zed terminal pane?** **Resolved: yes (with discipline).** Wait for pi welcome message before attaching. See Session 1 findings.

2. **Does `docker exec` (Shape 2) to the reasoning layer produce a usable shell, and can the agent TUI be re-entered from it?** **Resolved: yes.** Exec works. See Session 1 findings.

3. **Does Zed's multi-workspace window cleanly hold `PROJECT_DIR` (C0) and `SANDBOX_DIR` (C1) at the same time?** **Resolved with caveat.** File tree and git pane work cleanly. Search pane likely needs an extension and is deferred. The hidden-subfolder layout (`PROJECT_DIR` opened alongside `SANDBOX_DIR` which is at `<PROJECT_DIR>/.sandbox/<project>/`) is a general editor limitation, not Zed-specific. See Session 1 findings.

4. **How important is use case (6) (live view into agent file changes) in practice?** **Resolved: high.** Two named motivations: cross-platform UI consistency, and live view into agent file changes to catch incomplete implementations before review. Promotes the C2 experiment into active scope. See Session 1 findings.

6. **Is `make serve` + Zed-on-host (A2 + C0/C1 cluster) viable for pi?** **Closed: no.** Pi does not currently expose a server API; the closest analog is ACP, which is rejected. Reopens if a non-pi provider with a server API enters scope.

### Closed by workaround / shelved

9. **Why does B1 TUI rendering fail intermittently?** **Closed by workaround.** Wait-for-welcome discipline resolves the issue; deeper investigation deferred indefinitely.

10. **Does multi-pane attach have practical use given Ctrl-D coupling and state divergence?** **Shelved.** Multi-attach has no current use; multi-exec needs harness work; one-agent-one-pane is good enough for now. Pi subagents (headless mode) noted as a future direction.

### Active — Session 3 scope

5. **Does C2 (devcontainer remote-server in the reasoning layer) work without disrupting the agent runtime?** Properly formulated in Experiments to Run → Session 3. Phased: prerequisite → non-disruption → live view → teardown.

### Still open

7. **What is the operator value of multi-writer (D2)?** Lower priority than Q5 given Session 1 findings. Run as opportunity arises.

8. **Watch item: any finding that contradicts the framing axiom.** No contradictions in Session 1 — the cheapest-coverage cluster works without harness modification, supporting the axiom. Watch item remains open across future sessions.

### New questions surfaced by Session 1

11. **What workflow-grouping primitives does Zed offer (sessions, threads, task collections), and are they tied to ACP / Agent Panel?** Multi-workspace + multi-pane works but each pane is currently managed individually from operator memory. If Zed offers a way to group panes and tasks into named workflow units that does not require ACP, this would consolidate operator overhead. Investigation not yet framed; needs research before a clean experiment can be designed.

12. **What does a parallel-sandbox workflow need from the harness?** Multi-workspace's intended use case (parallel pi sessions in distinct sandbox folders) is currently blocked by harness-side gaps: per-instance sandbox folders, multi-branch `persist_on_exit`, per-instance commit hygiene. **This is agent-sandbox work, not Zed work** — would belong in a separate story scoped to parallel-session support. Surfaced here so the dependency is visible.

### Upstream-pending

13. **Zed git-pane lock contention on the host repo's `.git/`.** Recent Zed holds `.git/index.lock` on every detected repo in open workspaces whenever git features are enabled, blocking external host-side git mutation (`make confirm` / `make draft` / `make apply`, plus operator `git commit`). Operator's chosen workaround: close Zed workspace before running affected commands. Watching for a Zed-side fix. Other workarounds (disable git features, route make through Zed tasks) considered and not pursued today. See Investigation Findings → Session 2.

---

## Experiments to Run

The open questions above are answerable by hand-rolling, not by further written analysis. This section records what experiments have been run, what is planned next, and what is deferred.

### Session 1 — completed

Status: **done.** See Investigation Findings → Hand-rolled session 1 for results.

Scope was the cheapest-coverage cluster (A1 + B0 + B1 + C0 + C1 + tasks) and diagnostic checks for B2, B3, multi-workspace, multi-exec, and `docker logs -f`. The `.zed/tasks.json` shape used during this session — start/stop/apply/draft/attach/exec — is the validated baseline going forward.

### Session 3 — C2 devcontainer remote-server experiment

**Status:** planned. Has not run.

**Goal.** Test whether Zed's Dev Container remote-server feature (C2) provides a usable editor view of `sandbox/` that satisfies use case (6) — live view into agent file changes — without disrupting the agent runtime.

**Why this is the right next experiment.** Use case (6) was confirmed high-importance in Session 1 (Q4 resolved). C2 is the only on-axis option for satisfying (6) without harness change. C4 (host bind-mount of the sandbox volume) requires harness change and is deliberately the second-line fallback if C2 fails.

**Phased structure.** Each phase is a precondition for the next; if a phase fails, downstream phases are not run, and the outcome routes to the C4 fallback question.

#### Phase 1 — Architectural prerequisite

Can Zed's remote-server feature inject into a container that was started outside `devcontainer.json` (i.e. one started by `make start`)?

The documented Zed devcontainer shapes assume Zed creates the container. The harness creates the container and then must hand it off. This is the load-bearing prerequisite: if Zed cannot attach its remote server to a container it did not create, C2 is dead and the experiment ends here.

What to try:
- Write a `.devcontainer/devcontainer.json` that names the running reasoning-layer container (`<provider>-agent-<project>`) without using `dockerComposeFile` (since Shape 3 is ruled out).
- Use the dynamic-name pattern from Shape 4 (`${localEnv:CONTAINER_NAME}` populated by a wrapper script) if Zed cannot resolve container names directly.
- If Zed insists on creating the container itself: phase 1 fails. Record the failure mode and move to the C4 question.

Pass criterion: Zed's remote server is running inside the container and Zed can list `sandbox/` in its file explorer.

#### Phase 2 — Non-disruption check

If phase 1 passes, does the injected remote server interfere with the running agent?

What to observe:
- **Resource cost.** CPU and memory footprint of the remote server inside the reasoning layer. Compare container resource usage with and without the Zed remote server attached.
- **Filesystem-watch contention.** The agent does file operations; Zed's remote server watches files. Are there conflicts (missed events, locks, slow file operations)?
- **TTY/process interactions.** The reasoning layer's PID 1 is the agent's TUI. Does the remote server's process tree interact with PID 1 in a way that affects `docker attach` behaviour or container lifecycle?
- **Existing flows still work.** With Zed remote-server attached, do `make start` / `make stop` / `make apply` / `make draft` / `docker attach` still behave identically to Session 1?

Pass criterion: agent runs to completion of a representative session without observable disruption.

#### Phase 3 — Live view actually works

If phase 2 passes, does the editor view stay live as the agent edits files in `sandbox/`?

What to observe:
- Make the agent edit a file; watch Zed's editor view of the file. Is the change reflected without manual refresh?
- Diff view: Zed's diff against `INIT_SHA` or the most recent commit — does it stay current?
- File creation, deletion, rename — does the file tree reflect them in real time?
- Latency: how delayed are updates? Acceptable threshold is "noticeable but not annoying"; precise measurement is unnecessary.

Pass criterion: the operator can see agent file changes happen live, well enough to catch incomplete implementations before the agent moves on.

#### Phase 4 — Teardown behaviour

If phase 3 passes, what happens at session end?

What to observe:
- Operator runs `make stop`, or closes the entrypoint terminal, or hits Ctrl-D in an attach pane. Container terminates.
- Does Zed's remote server disconnect cleanly? Is there orphaned state, dangling processes, or anything that requires manual cleanup?
- Does Zed's editor view clear, or does it hold stale file content?
- Subsequent `make start` — does Zed re-attach automatically, or does it need explicit re-config?

Pass criterion: teardown is clean enough that operator does not need an extra cleanup step.

#### What "success" means for Session 3

If all four phases pass: C2 is added to the recommended cluster (A1 + B0 + B1 + C0 + C1 + C2 + tasks). The story moves toward Resolution.

If phase 1 fails: route to the C4 fallback question. C4 requires harness change — specifically, exposing `sandbox/` to the host via a bind mount instead of (or alongside) the anonymous volume. This is a separate scoping decision that should be opened as its own story or investigation.

If phase 2 fails: C2 is operationally too costly. Same C4 fallback question.

If phase 3 or 4 fails: C2 is technically possible but has UX gaps. Investigation continues into whether the gaps can be configured away or whether C4 is the cleaner answer.

#### Setup additions for Session 3

Beyond Session 1's setup:

- A `.devcontainer/devcontainer.json` (and possibly a wrapper script for dynamic container name resolution) added to the project.
- A scripted way to compare container resource usage with and without the Zed remote server, even if it's just `docker stats` snapshots.

### Deferred follow-ups

Items that were surfaced during investigation but are not in the active experiment scope. Listed for traceability; some may grow into their own stories if pursued.

- **Tmux-in-entrypoint to fix `docker exec` lifecycle asymmetry.** Wrapping pi in tmux at the container entrypoint so the container's life is tied to "any tmux session exists" rather than "main pi process is alive." Solves the lifecycle limitation of exec'd terminals losing their container when the entrypoint terminal closes. Adds complexity (new layer, potentially different shortcuts, new failure modes). **Could be expanded into its own story** if exec-based workflows become load-bearing. Currently parked because one-agent-one-pane is good enough.
- **Workflow-grouping primitives in Zed (sessions / threads / task collections).** Multi-workspace + multi-pane works but each pane is managed individually from operator memory. Zed may have a way to group panes and tasks into named workflow units; investigation not yet framed. **Open concern:** workflow-grouping primitives in Zed may be tied to its Agent Panel / ACP path, in which case they would be unavailable for pi's TTY-based workflow. Needs research before a clean experiment can be designed.
- **Parallel sandbox folders for concurrent pi sessions.** Multi-workspace's intended use case. Blocked on harness-side work: per-instance sandbox folders, multi-branch `persist_on_exit` handling, per-instance commit hygiene. **This is agent-sandbox work, not Zed work** — would belong in a separate story scoped to parallel-session support in agent-sandbox.
- **Pi subagents / pi-headless.** Pi supports running pi sub-instances in headless mode. This is the operator's preferred future direction for "more than one agent active" once one-agent-one-pane is solid. **Out of scope for this story** but recorded for visibility.
- **Search pane in Zed.** Likely needs a Zed extension. Deferred — not blocking the current cluster.
- **D2 multi-writer trial.** Lower priority than Q5 / C2 given Session 1 findings. Run as opportunity arises in subsequent sessions.

### Out of scope for this story

- Shape 3 (compose-based devcontainer). Already ruled out at the preliminary-context level.
- Group of rejected protocol-level approaches (ACP, Zed-as-MCP-server, dual-client capability MCP). Already ruled out.
- A2 (`make serve`) end-to-end test for pi. Closed: pi does not expose a server API.
- Multi-writer race conditions and lockfile design. Downstream of D2 trial.

### Output protocol

Findings get appended to **Investigation Findings** as a new "Hand-rolled session N — `<date>`" subsection. Resolved questions move to the Resolved sub-list under Open Questions; remaining questions stay open. New questions surfaced by a session are added to a "New questions surfaced by Session N" sub-list. When all questions are resolved, deferred, or shelved, the story is ready for Resolution.

---

## Investigation Findings

### Hand-rolled session 1 — 2026-05-03

First exploratory session. Target provider pi. Tasks defined in `.zed/tasks.json` per the experiment setup. Operator hand-rolled the C0 + C1 + B0 + A1 + B1 cluster, checked diagnostic tasks, and probed multi-workspace and multi-exec.

#### Lifecycle and harness commands work as Zed tasks

`make start`, `make stop`, `make draft`, `make apply` all run cleanly as Zed terminal tasks. `docker exec` shells (B2, B3) work as expected. The full A1 + B0 + diff-pipeline task surface is operationally viable. No surprises against the framing axiom — every `make` and `docker` primitive that works in a bare terminal works in a Zed terminal pane without modification.

#### Multi-workspace window — file tree and git pane work

Zed cleanly opens two folders as workspaces in one window. The git pane handles two repositories without confusion — one pane per detected repo, scoped to its own folder. File-tree clarity is fine; folders are clearly distinguished.

The operator's *intended* layout — `PROJECT_DIR` as host repo plus multiple sandbox folders for parallel sessions — is currently constrained by agent-sandbox itself, not Zed. Specifically:

- The mount shape places `SANDBOX_DIR` at `<PROJECT_DIR>/.sandbox/<project>/` by default, so opening both as peer workspaces in Zed shows the sandbox both as a top-level workspace and as a hidden subfolder of `PROJECT_DIR`. There is no first-class editor convenience for elevating a hidden subfolder to peer-workspace level without showing it twice; this is a limitation of editors generally, not specifically Zed.
- The operator also tried a WSL-side `~/sandbox` location, which works individually as an alternative sandbox folder.
- Multiple sandbox folders running in parallel — the use case the multi-workspace layout was meant to support — is not currently feasible: `persist_on_exit` does not handle multiple branches, and sandbox folder per pi instance needs primitives the harness does not yet have. **This is harness-side work, not a Zed limitation.** Recorded as a parallel-sandboxes follow-up question (see Open Questions).

Search pane: not located in Zed's default UI. May require an extension. **Deferred** — not blocking the current cluster.

#### B1 (`docker attach`) — usable with a discipline

Headline finding: attach is reliable **if you wait for the container to finish starting up and pi to print its welcome message before attaching.** The intermittent input-corruption observed in early attempts (typed input echoing as a stack of separate lines instead of composing into the agent's input field) was traced to attaching too early. With the wait-for-welcome discipline, attach behaves identically to bare-terminal `make start`.

Known limitations:
- **No pre-attach scrollback.** Content from before the attach is not visible in the pane. Live content from the attach moment onward is fine.
- **Ctrl-D from any attach pane terminates the container.** Multiple attached panes share a control surface, not just a display.
- The intermittent-rendering and state-divergence anomalies observed earlier are no longer load-bearing now that the wait-for-welcome discipline resolves the rendering issue. **Operator does not intend to investigate the rendering bug further.** Recorded as a closed-by-workaround item.

#### B2 / multi-exec — works for shells, has gaps for parallel pi sessions

`docker exec` shells into both reasoning and capability layers work as advertised. The natural extension — running additional pi instances via `docker exec` to share `AGENT_HOME` — is partly viable but blocked by harness-side gaps:

- Pi appears to support multiple instances against the same `AGENT_HOME`. Session locking is unclear (possibly locked, possibly not); if locking is needed, pi extensions are a tractable place to add it.
- Pi has a `/tree` primitive for forking session state, which is functional with operator-care caveats.
- However: parallel pi instances on a single sandbox folder can overwrite each other. Manual deconfliction works but commit history hygiene is a problem; the agents may also become confused.
- Per-instance sandbox folders would need worktree-style scoping that the harness does not currently provide, and `persist_on_exit` does not handle multiple branches.
- Lifecycle asymmetry: the entrypoint terminal owns the container's lifecycle. Other exec'd terminals are functionally equivalent for input/output but cannot decide when the container ends. If the entrypoint terminal closes, exec'd panes lose their container.

The lifecycle asymmetry has a known shape of fix — wrapping pi in tmux at the entrypoint so the container's life is tied to "any tmux sessions exist" rather than "main pi process is alive." Adds a layer of complexity (new shortcuts, new failure modes); recorded as a deferred follow-up, not a current commitment.

#### `docker logs -f` — usable for visibility, not used in current workflow

`docker logs -f` mirrors the agent's stdout but on WSL2 + Docker the output is buffered; flush triggers on a keypress in the active window. With the window focused, output stays current. **Reframe from Session 1 first pass:** the lag isn't a Zed problem and the tool is usable for visibility purposes — but the current workflow does not need a separate visibility surface because B1 attach already provides it. Logs is **available, not currently needed.**

#### Cost: no Agent Panel

Zed's Agent Panel — the first-class agent-interaction UI element — requires ACP. Pi does not implement ACP. The Agent Panel is therefore not available with pi as the provider. The operator uses terminal-pane B1 attach as the substitute. This is the concrete UI element given up by the ACP rejection; recorded so the cost is named, not just inferred.

#### Findings against open questions

| Question | Status | Notes |
|---|---|---|
| Q1 — Does B1 render the agent TUI usefully in Zed's terminal pane? | **Resolved: yes (with discipline)** | Wait for pi welcome message before attaching. Rendering bug closed-by-workaround. |
| Q2 — Does B2 (`docker exec`) produce a usable shell? | **Resolved: yes** | Works. Not currently load-bearing in workflow. |
| Q3 — Does Zed's multi-workspace window cleanly hold C0 + C1? | **Resolved with caveat** | File tree and git pane work; search pane deferred (likely needs extension). Hidden-subfolder layout is a general editor limitation, not Zed-specific. |
| Q4 — Use case (6) importance? | **Resolved: high** | Two named motivations: cross-platform UI consistency, and live view into agent file changes to catch incomplete implementations before review. Promotes Q5 (C2 devcontainer experiment) into active scope. |
| Q5 — Does C2 work without disrupting the agent? | **Active — Session 3 scope** | Properly formulated below. |
| Q6 — `make serve` + pi viable? | **Closed: no, for pi** | Pi does not currently expose a server API; the closest analog is ACP, which is rejected. A2 row in coverage table updated. Reopens if a non-pi provider with a server API enters scope. |
| Q7 — D2 multi-writer value? | **Still open** | Not exercised yet. Lower priority than Q5 given the use case (6) finding. |
| Q8 — Framing axiom watch | **No contradictions in Session 1** | All findings handled by Zed config; no harness change required. Watch item remains open across future sessions. |
| Q9 — B1 intermittent rendering | **Closed by workaround** | Wait-for-welcome discipline resolves it. Operator does not intend deeper investigation. |
| Q10 — Multi-pane attach utility | **Shelved** | Multi-attach viable but no current use; multi-exec viable but needs harness changes. One-agent-one-pane is good enough. Subagents (pi-headless) noted as a future direction. |

### Session 2 — observed during normal use, 2026-05-03

Not a hand-rolled experiment. Operator was working a regular session on the cheapest-coverage cluster from Session 1 and hit a Zed-side bug.

#### Finding — Zed git-pane locks the host repo's `.git/`

Recent Zed holds a `.git/index.lock` (or equivalent) on every git repo it detects in open workspaces. The lock is held whenever git features are enabled — **not only when the git pane is active**. The git pane scans recursively through open folders for git repositories, so any open workspace in Zed with git features on is enough to trigger the lock contention; the offending pane does not need to be visible.

**Affected commands.** All host-side git mutation. Concretely: `make confirm`, `make draft`, `make apply`, plus any operator-side `git commit` / `git rebase` / `git stash` issued from a bare terminal in `PROJECT_DIR`. Anything that needs to take `.git/index.lock` will fail or block.

**Not affected.** Anything happening inside `sandbox/` — the agent's working tree, autosave commits, operator `!`-hook commits inside the agent session. These touch a different `.git/` (the sandbox's, not the host repo's), and Zed is not opening that one as a workspace.

#### Workarounds considered

1. **Close the Zed workspace before running host-side make commands.** Cleanest. Bare-terminal `make confirm` / `make draft` / `make apply` continue to work as designed. Cost: the operator loses the consolidated-window experience for the duration of those commands.
2. **Disable Zed's git features entirely on the workspace.** Eliminates the lock contention but loses the editor-grade git pane / diff view. Use case (1) (review changes on host) degrades to a plain editor without a git surface — workable but a real loss of the cluster's editor-grade win.
3. **Route `make` commands through Zed tasks.** Considered, not pursued. Speculative — depends on Zed sequencing the lock release for its own task subprocesses, which is unverified. Also weakens the spirit of constraint 5 ("bare terminal still works") since it would create a path where some operations are smoother through Zed than from a bare terminal. Closing the workspace is cleaner if a workaround is needed at all.
4. **Wait for Zed to fix it.** Recorded as a real option. The Zed team moves quickly; the bug may be addressed in a near-term release. Until then, workaround 1 is the operator's chosen path when host-side git mutation is needed.

#### Impact on cluster coverage

The Session 1 cheapest-coverage cluster (A1 + B0 + B1 + C0 + C1 + tasks) is not broken — every primitive still works. But the operator now has to close the Zed workspace before running `make confirm` / `make draft` / `make apply`, which is a real friction cost on use case (2) (apply diffs from container) and on any other host-side git mutation. Use case (1) is unaffected as long as no concurrent host-side git mutation is in progress — the editor and git pane work fine for review, just not for review-while-applying.

The cluster's coverage cells stay positive in the table but are footnoted to reflect this caveat.

#### Status

**Upstream-pending.** Watching for a Zed release that addresses the lock contention. If the bug persists materially, the operator may revisit workaround 2 (disable git features) or look for other approaches; no commitment to either today.

#### Findings against open questions

| Question | Status change |
|---|---|
| Constraint 5 (bare terminal still works) | **Still satisfied.** Bare terminal works as designed; the friction is specifically "Zed open while running host-side git mutation." Bare terminal usage with Zed closed is unchanged. |
| New Q13 — Zed git-pane lock contention | **Open, upstream-pending.** Tracked in Open Questions. |

---

## References

| Document | Purpose |
|---|---|
| [`tool_interface.md`](../architecture/tool_interface.md) | Existing harness primitives — commands, container names, mount guarantees |
| [`container_model.md`](../architecture/container_model.md) | Two-container lifecycle and volume ownership rationale |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot, work, diff pipeline phases |
| [`execution_model.md`](../architecture/execution_model.md) | Compose generation model |
| [`two_layer_model.md`](../concepts/two_layer_model.md) | Reasoning vs capability layer separation |
| [`security.md`](../architecture/security.md) | Security invariants this scope must preserve |
| [`story_policy.md`](../operations/story_policy.md) | Story format, lifecycle, and graduation |
| [`investigation_policy.md`](../operations/investigation_policy.md) | If candidate evaluation is split into sub-investigations |
| [`story_agent_git_surface.md`](story_agent_git_surface.md) | Adjacent surface — agent's relationship to git, tracked separately |
