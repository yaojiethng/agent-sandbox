# Story — Warp as a UI Option for agent-sandbox

**Status:** Investigation complete — findings collected from research, no further experiments planned. Operator-side adoption decision deferred until the parallel Zed evaluation matures enough to compare.

---

## Context

The operator currently runs an agent-sandbox session across multiple windows: a host editor (VSCode) for reviewing changes in `PROJECT_DIR`, a terminal in `SANDBOX_DIR` for `make apply` / `make draft`, a terminal attached to the reasoning layer container for prompting the agent, a file explorer on `SANDBOX_DIR` for sandbox-side artefacts, and ad-hoc inspection of agent file changes via the same channels. The goal is to consolidate as many of these as possible into a single tool.

Warp is being evaluated as an **alternative tooling option** to Zed. The two evaluations run in parallel; this story covers Warp specifically. A comparison view is obtained by reading both stories side by side, not embedded in either one.

### What Warp turned out to be

The pre-investigation framing for considering Warp leaned on two claims, which research has corrected:

- *Original claim 1: Warp's terminal-first model lets it host both the terminal and the editor surfaces, similar to Zed.* **Partially correct, with a load-bearing caveat.** Warp's File Tree, File Editor, and git diff/history views (collectively "Interactive code review" in Warp's documentation) are **host-side only.** They do not function in remote sessions. An operator who Warpifies into a container gets terminal chrome inside the container — block structuring, command labels, working directory display, git status indicators, command timing — but does not get File Tree or editor features there. Project Explorer is on Warp's roadmap for remote sessions but not currently shipped.
- *Original claim 2: Warp's CMD+I "tag in the AI" feature provides an ACP-free path to first-class agent integration with pi.* **Incorrect.** CMD+I invokes the **Warp Agent** — Warp's own AI assistant — and is intended as "use Warp Agent to drive your other agents." Warp does not currently allow third-party agents (such as pi) to be plugged in as the agent CMD+I controls. CMD+I is therefore a separate paid AI offering that sits *alongside* pi, not an integration surface for it.

After these corrections, **Warp's remaining value proposition is a quality-of-life upgrade to the terminal experience**, with no editor-view-of-`sandbox/` coverage and no agent-integration first-class surface. Specifically, Warp delivers:

- PTY block structuring, command labels, and timing in any tab — including those Warpify'd into a running container via `docker exec`.
- Git status indicators in the prompt chrome inside the container.
- Saved Workflows for `make` command sequences (operator-config equivalent of `.zed/tasks.json`).
- Multiple folders / tabs in one window — `PROJECT_DIR` and `SANDBOX_DIR` can both be open as host workspaces, consolidating the host-side file explorer and terminal for a working folder into a single tab.

Warp does **not** deliver:

- Editor view of `sandbox/` (Project Explorer unavailable in remote sessions).
- ACP-free agent integration with pi (CMD+I is Warp Agent, not a wrapper for third-party agents).
- Any first-class differentiation from Zed on use case (6).

### Framing axiom

agent-sandbox is an agentic tool that Warp has access to. Warp is not part of agent-sandbox. The harness exposes primitives; Warp composes them. Any approach that requires the harness to know Warp exists in a structural way is a departure from the framing and needs explicit justification.

This is the same axiom as the Zed story. It applies symmetrically.

### Approach to evaluation

Given the corrected understanding of Warp's actual feature set, the evaluation question is narrow: **does Warp's terminal-side QoL upgrade justify adopting it as the primary operator surface in place of, or alongside, an existing terminal emulator?**

Investigation is desk-research and small hands-on confirmation rather than a phased experiment programme — the answer turns on understanding documented features, not on running multi-phase tests against the harness.

The integration shape has the standard axes (lifecycle, terminal panes, editor panes, multi-writer policy). The Warp-specific addition is one new lifecycle option (Axis A value A4) for the optional `.warp.yml` compose overlay that enables Warpify-over-`docker exec` ergonomics.

---

## Pain Points

The operator's current workflow surfaces. Same enumeration as the Zed story; reproduced here so this document stands alone.

| # | Surface | Currently | Notes |
|---|---|---|---|
| 1 | Reviewing changes on host | VSCode opened from `PROJECT_DIR` | Window switch from primary editor; separate from the rest of the workflow |
| 2 | Applying diffs from container | Terminal in `SANDBOX_DIR` running `make apply` / `make draft` | Separate terminal from the agent terminal; manual cd between folders |
| 3 | Sending prompts to the agent | Terminal attached to reasoning layer container | Confined to one terminal window; no editor context alongside |
| 4a | Running sandbox commands | Terminal in `SANDBOX_DIR` | Often shares a window with (2); folds into Warp's terminal naturally |
| 4b | File explorer on `SANDBOX_DIR` | Second file explorer window | Browsing config, brief, provider config; distinct from (4a) by optimal UI |
| 5 | View into shared operator/sandbox channels (`workspace/input/`, `workspace/output/`, `workspace/session-diffs/`) | Done via the file explorer for (4b), tediously | Currently same window as (4b) but distinct use — these are communication surfaces, not configuration |
| 6 | View into agent's live file changes in `sandbox/` | Not currently available except by entering the container shell and running `git diff` / `cat` | Steering use case: see when the agent is going wrong without a port-out / review / amend / port-in loop |

claude.ai web chat is excluded — operator-side reasoning, not part of the sandbox loop.

---

## Constraints

These hold across the Warp integration.

1. **Lifetime coupling.** When the operator uses agent-sandbox via Warp, closing Warp closes the session.
2. **Cold start.** agent-sandbox is not running when Warp opens. The session starts inside Warp.
3. **Operator restart authority.** Within a Warp session, the operator can stop and restart the agent-sandbox container set freely.
4. **Security invariants preserved.** The four invariants in [`security.md`](../architecture/security.md) hold: agents in containers, output via diffs, human approval gate, depth ≤ 2 with no grandchildren. **No invariant rescoping is required for the Warp integration as scoped.** sshd-in-container was considered and rejected (see Rejected approaches).
5. **Bare terminal still works.** `make start` and `make serve` are not changed in shape or behaviour by Warp integration. The Warp lifecycle option (A4) is an opt-in overlay alongside, not a replacement for, the default behaviour.
6. **Harness change is permitted but should be minimal.** A small additive change is required for A4: a `.warp.yml` compose overlay (mirroring the existing `.serve.yml` overlay pattern) and a `MODE=warp` flag on the start path that selects detached startup. No core flow is modified.

---

## Preliminary Context

What is known from research before any hands-on commitment. Subsequently corrected and confirmed during the investigation; recorded here as the baseline the integration design is built on.

### Existing primitives Warp can hook into

Without any harness change, an operator with Warp installed has access to:

| Primitive | Source | Use |
|---|---|---|
| `make start PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-start-provider-provider-rebuild1) | Foreground task; closing terminal pane signals teardown |
| `make serve PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-serve-provider-provider-rebuild1) | Background mode; agent on `127.0.0.1:SERVE_PORT` (provider-specific server interface) |
| `make stop` | [`tool_interface.md`](../architecture/tool_interface.md) | Explicit teardown |
| Deterministic container names | [`tool_interface.md`](../architecture/tool_interface.md#container-naming) | `sandbox-<project>` and `<provider>-agent-<project>` — known at workflow-write time |
| `docker attach <container>` | Docker | TTY connection to running container's PID 1 |
| `docker exec -it <container> <cmd>` | Docker | Fresh shell or process inside running container; **Warpifies** so the operator gets Warp's terminal chrome inside the container |
| `docker logs -f <container>` | Docker | Tail of stdout/stderr from PID 1 |
| Host-side workspace | [`tool_interface.md`](../architecture/tool_interface.md#mount-shape-guarantees) | `SANDBOX_DIR` and contents (`AGENTS.md`, `.workspace/`, provider config) editable directly |
| `agent-sandbox` CLI wrapper | `scripts/agent-sandbox.sh` | Host-installed command surface; preferred wrapper target |
| Warp Workflows (saved command sequences) | Warp | Operator-config-scoped saved CLI commands; can wrap any host command |
| Warp Blocks (PTY output structuring) | Warp | Each command's output is a navigable block; available for any process running in a Warp tab, host-side or Warpify'd-remote |
| Warp File Tree, File Editor, git diff/history views | Warp | **Host-side only.** Not available in remote/Warpify'd sessions. |
| Warp CMD+I (Warp Agent) | Warp | Paid Warp Agent feature for AI-assisted command authoring. **Not a third-party agent integration surface.** Out of scope as an integration option; see Q-W1 for the residual operator-adoption checklist if Warp is ever chosen. |
| Warp multi-folder window | Warp | Multiple folders open as tabs in one window; consolidates file-explorer-plus-terminal for each working folder into a single tab. |

**Wrappers vs custom integrations.** Warp Workflows that wrap host-installed commands (`make`, `agent-sandbox`, `docker`) are preferred — they keep the contract on the harness side, leave bare terminal usage unaffected, and don't require Warp-specific knowledge in the harness. Same principle as Zed tasks.

### Concrete Warp shapes

The shapes below are the integration surfaces actually available given the corrected feature set.

**Shape W1 — Plain Warp tab running `make start`:**

The operator opens a Warp tab in `SANDBOX_DIR` and runs `make start PROVIDER=pi`. Warp wraps the resulting PTY (the pi TUI). Blocks and Workflows are available against this tab. No configuration. Operationally equivalent to running `make start` in any terminal emulator.

`make start` today uses `docker compose run` under the hood, which means the foreground PTY belongs to the `compose run` process. Warpify-into-container does not apply to `compose run`-launched containers — see Shape W4 / Axis A4 for the alternative lifecycle that does support it.

**Shape W2 — Warp Workflow wrapping a `make` sequence:**

```yaml
# Warp Workflow — "Apply agent diff"
name: Apply agent diff
command: |
  cd "$SANDBOX_DIR"
  make draft
  make apply
```

Saved Workflow that runs the diff pipeline. Equivalent in operational profile to a `.zed/tasks.json` task in the Zed evaluation. Workflow files are stored in Warp's workflows directory and are operator-config, not project-config.

**Shape W3 — Warp tab running `docker attach <container>`:**

Direct attach to PID 1 of the reasoning layer (the agent TUI). Equivalent to Zed's B1 and inherits the same operational concerns: pre-attach scrollback, Ctrl-D coupling, and the wait-for-welcome discipline that the Zed Session 1 finding closed-by-workaround. Whether the same TUI rendering issue reproduces under Warp is not separately investigated; if it does, the same workaround applies.

**Shape W4 — Warp tab running `docker exec -it <container> bash` with Warpify (Axis A4):**

After containers are started detached (via `make start MODE=warp`, which applies the `.warp.yml` compose overlay so the reasoning layer comes up without foreground attach), the operator opens a Warp tab and runs `docker exec -it <container> bash`. Warp recognises the remote shell and Warpifies it: the prompt chrome inside the container shows user@host, working directory, git branch, git status (e.g. "2 files, +6 -1"), and command timing. Block structuring works on commands run inside the container.

This shape **does not** activate File Tree, File Editor, or git diff views inside the container — Project Explorer is unavailable in remote sessions.

**Shape W5 — Warp host-side workspace pointed at `SANDBOX_DIR`:**

Open `SANDBOX_DIR` as a host folder in Warp. File Tree, File Editor, and git diff views operate on the host filesystem. Equivalent in coverage to Zed's C1.

**Shape W6 — Warp host-side workspace pointed at `PROJECT_DIR`:**

Open `PROJECT_DIR` as a host folder in Warp. Equivalent to Zed's C0. Can be combined with W5 in the same Warp window via tabs/multi-folder.

### Axes of the integration design

Within an axis, values are mutually exclusive. Across axes, values compose freely. Axes are intentionally similar to the Zed story's so the two read in parallel; differences are noted inline.

#### Axis A — Lifecycle ownership (how does the session start?)

| Value | Description |
|---|---|
| A1 | Foreground tab: `make start` from a Warp tab (Shape W1). Closing the tab signals teardown. Default for bare-terminal-equivalent use. |
| A2 | Foreground tab: `make serve` from a Warp tab. Provider-specific server API. **Closed for pi** for the same reason as the Zed story — pi has no usable server API; ACP is not in scope. |
| A3 | New harness mode (`make warp` standalone wrapper). Wrapper that starts containers, opens Warp pre-configured, waits on Warp exit, runs `make stop`. **Departs from the framing axiom**; not pursued. |
| A4 | `make start MODE=warp`: applies the `.warp.yml` compose overlay so containers come up detached. Operator then attaches to the reasoning layer via Warpify-wrapped `docker exec` (Shape W4) or `docker attach` (Shape W3). Mirrors the existing `.serve.yml` overlay pattern. **Required for Warpify-into-container ergonomics**; opt-in alongside A1. |

#### Axis B — Terminal pane targets (where do Warp tabs point?)

Multiple values can be combined.

| Value | Description |
|---|---|
| B0 | Plain shell on host (in `SANDBOX_DIR` or `PROJECT_DIR`). Used for `make` commands, git, etc. |
| B1 | `docker attach` to reasoning layer (`<provider>-agent-<project>`) — Shape W3. TTY view of the live agent. |
| B2 | `docker exec` shell into reasoning layer — Shape W4 under A4. Inspection shell separate from the agent TUI; Warpify chrome active. |
| B3 | `docker exec` shell into capability layer (`sandbox-<project>`). Inspection shell on the volume-owning side; Warpify chrome active. |

#### Axis C — Editor workspace targets (where does Warp's File Tree / File Editor point?)

Multiple values can be combined for host-side.

| Value | Description |
|---|---|
| C0 | `PROJECT_DIR` as a host workspace (Shape W6). |
| C1 | `SANDBOX_DIR` as a host workspace (Shape W5). Covers `AGENTS.md`, `.workspace/`, provider config. |
| C3 | No editor workspace on container — container access is via terminal panes only (axis B). |

The Zed story has C2 (Dev Container remote-server providing editor view of `sandbox/`) and C4 (host bind-mount fallback). Neither has an analogue in the Warp integration as scoped: Warp's remote sessions do not provide File Tree or editor features (so no C2 analogue), and host bind-mount is rejected on the same security and prior-art grounds as the Zed story (see Rejected approaches).

#### Axis D — Operator/agent edit policy on `sandbox/`

| Value | Description |
|---|---|
| D1 | Single-writer. Operator does not edit `sandbox/` directly. Edits flow via `AGENTS.md`, `workspace/input/`, and the existing `!`-hook commit pattern inside the agent. |
| D2 | Multi-writer. Operator and agent both edit `sandbox/`. **Not currently usable** — would require an editor view of `sandbox/` to be a useful surface, which Warp does not provide. |
| D3 | Comment channel via `workspace/input/`. Additive to D1 — operator-authored comments and quoted sections written to `workspace/input/` for the agent to read on next turn. Uses an existing primitive without modification. |

### Rejected approaches (off the axes)

These were considered and ruled out. Recorded for traceability.

| Rejected | Reason | Would change if |
|---|---|---|
| **Host bind-mount of `sandbox/` for Warp local-mode editor view** | (1) Same reason the Zed story rejects C4: `sandbox/` is currently a Docker anonymous volume specifically because it should not appear on the host (see [`container_model.md`](../architecture/container_model.md)). (2) Independently rejected by the security invariant that the agent must not have direct read/write access to host git history; bind-mounting flips that invariant. (3) Operator has previously explored bind-mounting and decided to stick with the snapshot + baseline workflow; revisiting that decision is out of scope for this story. | The bind-mount direction is reopened as its own scoping decision. Out of scope here. |
| **sshd in the reasoning layer container, so Warp's SSH extension can attach** | The motivating use case — File Tree / editor view inside the container — does not exist regardless of transport: Project Explorer is unavailable in remote sessions whether the transport is SSH or `docker exec` Warpify. Every PTY-side feature SSH would deliver, `docker exec` Warpify already delivers without adding a network listener, host-key management, or auth surface to the container. **No additional features for the cost** — ruled out cleanly. | Warp ships Project Explorer for remote sessions *and* the `docker exec` Warpify path does not extend to it for some reason. Both conditions would need to hold; neither is a near-term expectation. |
| **CMD+I / Warp Agent as a third-party agent integration surface for pi** | Warp Agent is Warp's own AI; it is not a wrapper into which third-party agents (pi or any other) can be plugged. The "ACP-free agent integration" claim that originally motivated considering Warp does not hold. | Warp ships a third-party-agent integration mode for Warp Agent. Not on Warp's stated roadmap. |
| **Warp + agent ACP** | Same as Zed: pi does not have working ACP support; ACP implementation is feature-incomplete with no timeline. | Pi or another adopted provider ships sufficiently complete ACP support. |
| **Warp-as-MCP-server, agent connects out** | Same trust-boundary objection as in the Zed story — operator's editor becomes a service the agent calls into, creating an outbound channel from the agent to operator-side software on the host. | A use case appears that genuinely requires the agent to query the editor, *and* a model exists to bound the surface. |

### Use case coverage by axis value

How each axis value contributes to each use case. `✓` = covers; `partial` = partial fit; `—` = does not address.

| | (1) Review host | (2) Apply diffs | (3) Send prompts | (4a) Run sandbox cmds | (4b) Sandbox file explorer | (5) Shared channels | (6) Live agent edits |
|---|---|---|---|---|---|---|---|
| **A1** (`make start` foreground) | — | — | indirect (via terminal pane) | — | — | — | — |
| **A2** (`make serve`) | — | — | rejected for pi | — | — | — | — |
| **A4** (`MODE=warp` + overlay) | — | — | indirect (enables Warpify-attach for B1/B2) | — | — | — | — |
| **B0** (host shell) | — | ✓ via `make apply` / `make draft` | — | ✓ | — | — | — |
| **B1** (attach reasoning TUI) | — | — | ✓ subject to wait-for-welcome discipline | — | — | — | — |
| **B2** (Warpify'd exec into reasoning) | — | partial (via shell) | — | partial (sandbox-side commands via shell) | — | — | partial (`git diff` in shell, with Warpify chrome showing status) |
| **B3** (Warpify'd exec into capability) | — | partial (via shell) | — | partial | — | — | partial (`git diff` in shell) |
| **C0** (`PROJECT_DIR` host workspace) | ✓ | — | — | — | — | — | — |
| **C1** (`SANDBOX_DIR` host workspace) | — | ✓ via Workflows running `make apply` | — | ✓ via Workflows + file tree | ✓ | ✓ | — |
| **D1** | — | — | — | — | — | — | — |
| **D3** (comment channel) | — | — | partial — async channel into agent reasoning | — | — | partial | — |

**Reading the table.**

- The viable cluster is **A1 *or* A4 + B0 + B1 + (B2/B3 if A4) + C0 + C1 + Workflows**, with D1 and optional D3.
- This cluster covers (1), (2), (3), (4a), (4b), (5).
- Use case **(6) is not covered.** Warp has no editor view of `sandbox/`. The only on-axis option for (6) would be a hypothetical C2 analogue, which Warp does not currently support (Project Explorer unavailable in remote sessions).
- Choosing A4 over A1 buys: Warpify chrome (block structuring, command labels, git status indicators, command timing) inside the reasoning and capability layers when accessed via `docker exec`. It does not change which use cases are covered, only the polish of (3)/(4a)-via-shell.
- A2 is closed for pi (no server API; ACP rejected) — same outcome as the Zed story.

---

## Open Questions

What remains unresolved. The list is short because most candidate questions were either resolved by research or fell out of scope when the option space collapsed.

### Resolved during research

1. **Q-W1 — What does Warp's CMD+I do under the hood?** **Resolved: it invokes Warp Agent, Warp's own paid AI assistant.** It is not a third-party agent integration surface. CMD+I is therefore **out of scope as an agent-integration consideration** for this story. *Residual:* if the operator ever decides to subscribe to Warp Agent for operator-side command-authoring assistance, the standard checklist applies — characterise the data-flow profile (what is sent off-device, where, retention, opt-outs). Recorded here so it is not lost; not load-bearing for the adoption decision. Effectively a non-consideration for the Warp-vs-Zed evaluation.

2. **Q-W2 — Does `docker attach` to the reasoning layer (B1) render the agent TUI usefully under Warp?** **Resolved: expected to work.** Warp is a terminal wrapper; PTY behaviour is the standard PTY behaviour. The Zed Session 1 wait-for-welcome discipline is expected to apply identically if the rendering issue surfaces. Not separately investigated since no different outcome is anticipated.

3. **Q-W3 — Does Warp support multi-folder windows usefully for C0 + C1?** **Resolved: yes.** Two folders open as separate tabs in one Warp window. Consolidates file-explorer-plus-terminal per working folder into a single tab. The hidden-subfolder layout caveat noted in Zed Session 1 (when `SANDBOX_DIR` is at `<PROJECT_DIR>/.sandbox/<project>/`) applies equally to Warp — it is a general editor limitation, not Warp-specific.

4. **Q-W5 — Are Warp Workflows project-scoped?** **Resolved: no — operator-config-scoped.** Wrap-make-commands story still works; operator namespaces by hand if multiple projects are in play.

5. **Q-W7 / Q-W8 / Q-W9 / Q-W10 — sshd-in-container feasibility, threat model, image cost.** **Closed not-pursued.** The Path C / sshd direction was rejected when research confirmed `docker exec` Warpify delivers all the in-container PTY chrome that SSH would, and that File Tree / Project Explorer is unavailable in remote sessions regardless of transport. No additional features to chase for the security cost.

### Still open

6. **Q-W4 — Watch item: any finding that contradicts the framing axiom.** No contradictions found in research. The integration as scoped (A4 overlay, Workflows, host-side workspaces) is composition of existing primitives. Watch item remains open across any future hands-on use.

7. **Q-W11 — Warp's UX quirks at sustained-use intensity.** Brief operator hands-on flagged real-world friction not present in static feature analysis: tabs opening unexpectedly, terminal shortcuts not matching expectations from other terminal emulators. This is below the threshold of being a feature gap but above the threshold of being negligible. Ergonomics of sustained Warp use vs the operator's incumbent terminal is an open question, answered only by trying it for a real session if the operator chooses to. Not blocking the Warp-vs-Zed comparison, which can proceed on documented features alone, but worth noting before commitment.

---

## Experiments to Run

**No further experiments are planned for this story.** Warp is a terminal wrapper; its feature set is documented; the integration is composition of existing primitives plus an additive `.warp.yml` overlay. The questions that hand-rolling would have answered have been resolved by research (Q-W1, Q-W2, Q-W3, Q-W5, Q-W7–Q-W10) or are below the threshold of formal experimentation (Q-W11 — a sustained-use ergonomics question, answered only by adopting Warp for real work if that adoption is chosen).

If the operator chooses Warp following the Warp-vs-Zed comparison, the implementation work is straightforward:

- Add `.warp.yml` compose overlay alongside `.serve.yml`.
- Add `MODE=warp` flag to the start path that selects the overlay and detached startup.
- Author Workflows for `make` sequences in the operator's Warp config.
- Document the Warpify-attach pattern (`docker exec -it <container> bash` after detached start) in operator-facing docs.

This is not currently committed work; it sits behind the Warp-vs-Zed decision.

### Deferred follow-ups

Items recorded for visibility, not active commitments:

- **Q-W11 sustained-use ergonomics.** Only answered by real use. If Warp is ever piloted for a real session, the operator's notes from that session resolve or refine this.
- **Warp Agent data-flow checklist.** The residual from Q-W1 — characterise data flow profile, retention, opt-outs — applies only if Warp Agent is ever subscribed to. Useful to have on file then; not part of the current evaluation.
- **Comparison write-up: Warp vs Zed end state.** Operator-side analysis once the Zed evaluation matures; not part of either story directly.
- **Pi subagents / pi-headless under Warp.** Out of scope; recorded for visibility, same as the Zed story.

### Out of scope for this story

- Host bind-mount of the sandbox volume. Already rejected.
- sshd-in-container. Already rejected.
- ACP-based integrations. Already rejected.
- Warp-as-MCP-server. Already rejected.
- Warp Agent as a third-party agent integration surface. Already rejected.
- A2 (`make serve`) end-to-end test for pi. Closed: pi does not expose a server API (same as Zed story).

---

## Investigation Findings

### Research session — 2026-05-05

Single research-and-discussion session. No hands-on experiments; sources were Warp documentation, screenshots from operator's prior research, Warp-published feature lists, and a brief operator hands-on for Warp UX quirks.

#### Warp's feature set as it applies to agent-sandbox

Warp's terminal-side features (Blocks, command labels, prompt chrome, working-directory display, command timing, Workflows) work in any tab including those Warpify'd into a running container via `docker exec`. **Confirmed via screenshot** showing the Warpify chrome active inside a container at `agentuser@6633402912e1:~/sandbox` with git status `2 files, +6 -1` displayed in the prompt pill.

Warp's editor-side features (File Tree / Project Explorer, File Editor, git diff/history views) are **host-only**. **Confirmed via screenshot** showing "Project explorer unavailable — The Project Explorer requires access to your local workspace, which isn't supported in remote sessions." Project Explorer is on Warp's roadmap for remote sessions; no shipping date.

#### CMD+I is Warp Agent, not a third-party integration surface

CMD+I invokes Warp Agent — Warp's own paid AI assistant. The intended use is "use Warp Agent to drive your other agents" (e.g. ask Warp Agent to author and run commands that interact with pi running in another tab). It is not a hook for third-party agents (pi or otherwise) to plug into Warp's UI. The "ACP-free path to first-class agent integration" framing that originally motivated this story does not hold.

This is the load-bearing correction. With CMD+I removed from the option space, **Warp's remaining differentiation from a plain terminal emulator is terminal-side QoL** (Blocks, prompt chrome, Workflows, multi-folder window) and that's it. Editor-view-of-`sandbox/` is uncovered. ACP-free agent integration is uncovered.

#### `docker exec` Warpify subsumes the SSH-server direction

Initial research flagged Warp's "remote mode" via SSH as a path to in-container editor features. Subsequent research confirmed (a) Warpify works over `docker exec -it`, not only SSH, and (b) the editor features that motivated the SSH direction (Project Explorer in container) are unavailable in any remote session regardless of transport. The SSH direction therefore offers no additional features over `docker exec` Warpify, and it would add a network listener, host keys, and auth surface to the container for no gain. Rejected cleanly.

#### `docker compose run` is not Warpify-able; `docker exec` is

`make start` today uses `docker compose run`, which Warp does not Warpify. To get Warpify chrome inside the reasoning layer the harness needs to support a detached start mode followed by `docker exec`-based attach. Tractable via a `.warp.yml` compose overlay that mirrors the existing `.serve.yml` pattern, plus a `MODE=warp` flag on the start path. Modelled as Axis A value A4. Small additive change; no impact on bare-terminal flows or security invariants.

#### Multi-folder window works as expected

Two folders open as separate tabs in one Warp window. `PROJECT_DIR` and `SANDBOX_DIR` can both be present, consolidating the file-explorer-plus-terminal-per-working-folder pattern into a single Warp window. Same hidden-subfolder caveat as the Zed story (a general editor limitation when `SANDBOX_DIR` is at `<PROJECT_DIR>/.sandbox/<project>/`, not Warp-specific).

#### UX quirks flagged from brief operator hands-on

Operator noted: tabs opening when not expected; terminal shortcuts not behaving as in other emulators. Below the threshold of being a feature gap but above the threshold of being negligible. Recorded as Q-W11 for any future sustained-use evaluation.

#### Findings against open questions

| Question | Status | Notes |
|---|---|---|
| Q-W1 — What does CMD+I do? | **Resolved** | Warp Agent — Warp's own paid AI; not a third-party integration surface. Out of scope as an integration option. Residual data-flow checklist preserved for future operator adoption decisions. |
| Q-W2 — Does B1 render the agent TUI usefully? | **Expected yes** | Standard PTY behaviour; Zed wait-for-welcome discipline applies if needed. Not separately tested. |
| Q-W3 — Multi-folder window? | **Resolved: yes** | Tabs in one window. Hidden-subfolder caveat is general, not Warp-specific. |
| Q-W4 — Framing axiom watch | **No contradictions** | A4 overlay is additive composition; integration does not require harness to know Warp exists. |
| Q-W5 — Workflows project-scoped? | **Resolved: operator-scoped** | Wrap-make-commands works; operator namespaces by hand. |
| Q-W6 — CMD+I usefulness on agent TUI | **N/A** | Subordinate to Q-W1; CMD+I is not an agent-integration surface, so this question does not arise. |
| Q-W7 — Warpify SSH cost in container | **Closed not-pursued** | sshd direction rejected; question doesn't arise. |
| Q-W8 — Warp remote editor view live? | **Closed not-pursued** | No remote editor view exists; question doesn't arise. |
| Q-W9 — sshd threat model | **Closed not-pursued** | sshd direction rejected. |
| Q-W10 — sshd image cost | **Closed not-pursued** | sshd direction rejected. |
| Q-W11 — Warp UX quirks at intensity | **Open, deferred** | Only answered by sustained real use. |

---

## References

| Document | Purpose |
|---|---|
| [`tool_interface.md`](../architecture/tool_interface.md) | Existing harness primitives — commands, container names, mount guarantees |
| [`container_model.md`](../architecture/container_model.md) | Two-container lifecycle and volume ownership rationale |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot, work, diff pipeline phases |
| [`execution_model.md`](../architecture/execution_model.md) | Compose generation model — `.warp.yml` overlay sits in this model alongside `.serve.yml` |
| [`two_layer_model.md`](../concepts/two_layer_model.md) | Reasoning vs capability layer separation |
| [`security.md`](../architecture/security.md) | Security invariants this scope preserves; no rescoping required |
| [`story_zed_integration.md`](story_zed_integration.md) | Parallel evaluation of Zed as alternative tooling for the same use cases |
| [`story_policy.md`](../operations/story_policy.md) | Story format, lifecycle, and graduation |
| [`investigation_policy.md`](../operations/investigation_policy.md) | If candidate evaluation is split into sub-investigations |
| [`story_agent_git_surface.md`](story_agent_git_surface.md) | Adjacent surface — agent's relationship to git, tracked separately |
