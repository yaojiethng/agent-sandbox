# Story — &lt;&lt;TOOL&gt;&gt; as a UI Option for agent-sandbox

**Status:** &lt;&lt;Investigation pre-experiment | Investigation in progress | Investigation complete | Ready for resolution&gt;&gt;

> *Template note (delete on instantiation):* This template captures the tool-independent backbone of an editor/UI integration evaluation, plus structured placeholders for the tool-specific content. Copy this file, replace `<<TOOL>>` and other placeholders, fill in the tool-specific sections by working through the prompt in `prompt_evaluate_editor_integration.md`, and delete all template notes including this one before committing the story.
>
> *Section policy.* Sections marked **(stable)** are tool-independent and should be copied largely verbatim across evaluations. Sections marked **(structured, tool-specific)** have a fixed structure but tool-specific content. Sections marked **(open)** are entirely tool-specific.

---

## Context *(structured, tool-specific)*

The operator currently runs an agent-sandbox session across multiple windows: a host editor (VSCode) for reviewing changes in `PROJECT_DIR`, a terminal in `SANDBOX_DIR` for `make apply` / `make draft`, a terminal attached to the reasoning layer container for prompting the agent, a file explorer on `SANDBOX_DIR` for sandbox-side artefacts, and ad-hoc inspection of agent file changes via the same channels. The goal is to consolidate as many of these as possible into &lt;&lt;TOOL&gt;&gt; — ideally with each surface presented well, or at minimum collapsed into one window.

&lt;&lt;TOOL&gt;&gt; is being evaluated as &lt;&lt;the primary candidate | an alternative tooling option | a successor candidate&gt;&gt;. &lt;&lt;Position relative to other parallel evaluations: e.g. "Evaluated in parallel with the Zed and Warp stories; the comparison view is obtained by reading them side by side, not embedded in any one story." | "Standalone evaluation; no parallel candidates currently in scope."&gt;&gt;

### What drew us to &lt;&lt;TOOL&gt;&gt;

&lt;&lt;Two-to-three bullets naming the *specific* features or properties that motivated considering this tool. Be honest: distinguish marketing claims from confirmed behaviour. The Warp evaluation's first draft made two load-bearing claims that turned out to be wrong; flagging the source of each claim (documentation / marketing / screenshot / hands-on) at this stage prevents that failure mode.&gt;&gt;

- &lt;&lt;Claim 1, with source.&gt;&gt;
- &lt;&lt;Claim 2, with source.&gt;&gt;

### Framing axiom *(stable)*

agent-sandbox is an agentic tool that &lt;&lt;TOOL&gt;&gt; has access to. &lt;&lt;TOOL&gt;&gt; is not part of agent-sandbox. The harness exposes primitives; &lt;&lt;TOOL&gt;&gt; composes them. Any approach that requires the harness to know &lt;&lt;TOOL&gt;&gt; exists in a structural way is a departure from the framing and needs explicit justification. Findings that contradict this framing are themselves significant — they would mean the operator surface needs more than primitive composition can provide.

The natural analogue is Open WebUI sitting on top of `opencode serve`: Open WebUI works because the harness exposes a documented endpoint shape; the harness has no opinion on whether Open WebUI exists. &lt;&lt;TOOL&gt;&gt; integration aims for the same relationship.

### Approach to evaluation *(stable backbone, tool-specific scope)*

The integration shape has multiple independent axes (lifecycle, terminal panes, editor panes, multi-writer policy). Each axis offers several values. A working configuration is a *combination across axes*, not a single option from a flat list. The evaluation question is therefore: **what combination covers the most use cases under the constraints?** — not "which option is best?"

Within each axis, some values are mutually exclusive (one lifecycle command at a time). Across axes, values compose freely.

&lt;&lt;Tool-specific scope notes if applicable: e.g. "&lt;&lt;TOOL&gt;&gt; offers two distinguishable integration paths with very different cost profiles; they are evaluated separately." or "&lt;&lt;TOOL&gt;&gt; is a single-shape integration; the evaluation is desk-research rather than phased experiments." Omit this paragraph if there is nothing tool-specific to add.&gt;&gt;

---

## Pain Points *(stable)*

The operator's current workflow surfaces. (1)–(4) are existing pain; (5)–(6) are nice-to-haves not currently available without friction.

| # | Surface | Currently | Notes |
|---|---|---|---|
| 1 | Reviewing changes on host | VSCode opened from `PROJECT_DIR` | Window switch from primary editor; separate from the rest of the workflow |
| 2 | Applying diffs from container | Terminal in `SANDBOX_DIR` running `make apply` / `make draft` | Separate terminal from the agent terminal; manual cd between folders |
| 3 | Sending prompts to the agent | Terminal attached to reasoning layer container | Confined to one terminal window; no editor context alongside |
| 4a | Running sandbox commands | Terminal in `SANDBOX_DIR` | Often shares a window with (2) |
| 4b | File explorer on `SANDBOX_DIR` | Second file explorer window | Browsing config, brief, provider config; distinct from (4a) by optimal UI |
| 5 | View into shared operator/sandbox channels (`workspace/input/`, `workspace/output/`, `workspace/session-diffs/`) | Done via the file explorer for (4b), tediously | Currently same window as (4b) but distinct use — these are communication surfaces, not configuration |
| 6 | View into agent's live file changes in `sandbox/` | Not currently available except by entering the container shell and running `git diff` / `cat` | Steering use case: see when the agent is going wrong without a port-out / review / amend / port-in loop |

Use case 5 is currently available but tedious; use case 6 is currently not really available at all. Both are nice-to-haves that &lt;&lt;TOOL&gt;&gt; could plausibly offer if the right axes line up.

claude.ai web chat (this conversation) is excluded — operator-side reasoning, not part of the sandbox loop.

---

## Constraints *(stable; constraint 6 may need tool-specific tweaking)*

These hold across any combination across the axes.

1. **Lifetime coupling.** When the operator uses agent-sandbox via &lt;&lt;TOOL&gt;&gt;, closing &lt;&lt;TOOL&gt;&gt; closes the session.
2. **Cold start.** agent-sandbox is not running when &lt;&lt;TOOL&gt;&gt; opens. The session starts inside &lt;&lt;TOOL&gt;&gt;.
3. **Operator restart authority.** Within a &lt;&lt;TOOL&gt;&gt; session, the operator can stop and restart the agent-sandbox container set freely.
4. **Security invariants preserved.** The four invariants in [`security.md`](../architecture/security.md) hold: agents in containers, output via diffs, human approval gate, depth ≤ 2 with no grandchildren. &lt;&lt;If any path under evaluation requires invariant rescoping, name it here: "Path X extends the invariant set with ...; the default path does not."&gt;&gt;
5. **Bare terminal still works.** `make start` and `make serve` are not changed in shape or behaviour by &lt;&lt;TOOL&gt;&gt; integration.
6. **Harness change is permitted but should be minimal.** &lt;&lt;Replace with the tool-specific harness change profile: "&lt;&lt;TOOL&gt;&gt; requires no harness change." | "&lt;&lt;TOOL&gt;&gt; requires an additive `.X.yml` compose overlay alongside `.serve.yml` and a `MODE=X` flag on the start path; bare-terminal flow unchanged." | "&lt;&lt;TOOL&gt;&gt; requires changes to ...; rationale: ...".&gt;&gt;

---

## Preliminary Context *(stable backbone; primitives table is stable, shapes/axes are tool-specific)*

What is known going into the experiments, before any hands-on testing — or, if no hands-on is planned, what is known from research. This is preliminary, not a finding — it is the material the experiments (or the evaluation) is built on top of.

### Existing primitives &lt;&lt;TOOL&gt;&gt; can hook into *(stable)*

Without any harness change, an operator with &lt;&lt;TOOL&gt;&gt; installed has access to:

| Primitive | Source | Use |
|---|---|---|
| `make start PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-start-provider-provider-rebuild1) | Foreground task; closing terminal pane signals teardown |
| `make serve PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-serve-provider-provider-rebuild1) | Background mode; agent on `127.0.0.1:SERVE_PORT` (provider-specific server interface) |
| `make stop` | [`tool_interface.md`](../architecture/tool_interface.md) | Explicit teardown |
| Deterministic container names | [`tool_interface.md`](../architecture/tool_interface.md#container-naming) | `sandbox-<project>` and `<provider>-agent-<project>` — known at workflow-write time |
| `docker attach <container>` | Docker | TTY connection to running container's PID 1 |
| `docker exec -it <container> <cmd>` | Docker | Fresh shell or process inside running container |
| `docker logs -f <container>` | Docker | Tail of stdout/stderr from PID 1 |
| Host-side workspace | [`tool_interface.md`](../architecture/tool_interface.md#mount-shape-guarantees) | `SANDBOX_DIR` and contents (`AGENTS.md`, `.workspace/`, provider config) editable directly |
| `agent-sandbox` CLI wrapper | `scripts/agent-sandbox.sh` | Host-installed command surface; preferred wrapper target |

&lt;&lt;TOOL-SPECIFIC ROWS BELOW&gt;&gt;
&lt;&lt;Add &lt;&lt;TOOL&gt;&gt;'s primitives here. For each, name the feature, point to source documentation, and describe the use. Mark unverified claims with "**(unverified — needs hands-on confirmation)**" so they are visible.&gt;&gt;

| `<<TOOL>>` task / workflow primitive | &lt;&lt;TOOL&gt;&gt; docs | &lt;&lt;Description and use&gt;&gt; |
| `<<TOOL>>` terminal pane | &lt;&lt;TOOL&gt;&gt; docs | &lt;&lt;Description and use&gt;&gt; |
| `<<TOOL>>` editor / file tree | &lt;&lt;TOOL&gt;&gt; docs | &lt;&lt;Description and use; explicitly note any host-only-vs-remote behaviour&gt;&gt; |
| `<<TOOL>>` multi-folder / multi-workspace | &lt;&lt;TOOL&gt;&gt; docs | &lt;&lt;Description and use&gt;&gt; |
| `<<TOOL>>` container integration (e.g. Dev Container, SSH remote, exec attach) | &lt;&lt;TOOL&gt;&gt; docs | &lt;&lt;Description; flag what the integration does and does not deliver — terminal chrome only? editor features? agent panel?&gt;&gt; |
| &lt;&lt;Other tool-specific primitives&gt;&gt; | | |

**Wrappers vs custom integrations.** &lt;&lt;TOOL&gt;&gt; tasks/workflows that wrap host-installed commands (`make`, `agent-sandbox`, `docker`) are preferred — they keep the contract on the harness side, leave bare terminal usage unaffected, and don't require &lt;&lt;TOOL&gt;&gt;-specific knowledge in the harness. Custom &lt;&lt;TOOL&gt;&gt; commands are viable for purely editor-side concerns but should not be the primary surface for harness interaction.

### Concrete &lt;&lt;TOOL&gt;&gt; shapes from research *(structured, tool-specific)*

The shapes below are the integration surfaces identified from research / documentation. &lt;&lt;Note for each shape whether it has been hands-on confirmed or is documentation-only.&gt;&gt;

**Shape &lt;ID-1&gt; — &lt;short description&gt;:**

&lt;&lt;Code block, config snippet, or prose describing the shape. Be concrete enough that a reader can recreate the shape.&gt;&gt;

&lt;&lt;Operational notes: what this shape does, what its limitations are, whether it requires harness change.&gt;&gt;

&lt;&lt;Repeat for each shape. The Zed story used 4 shapes; the Warp story used 6. Number per the tool's complexity.&gt;&gt;

### Axes of the integration design *(structured, tool-specific values)*

A working &lt;&lt;TOOL&gt;&gt; integration is a combination of choices across the following axes. Within an axis, values are mutually exclusive (you can only run one lifecycle command at a time). Across axes, values compose freely.

#### Axis A — Lifecycle ownership (how does the session start?)

| Value | Description |
|---|---|
| A1 | Foreground task: `make start` from a &lt;&lt;TOOL&gt;&gt; task. Closing the tab signals teardown. |
| A2 | Foreground task: `make serve` from a &lt;&lt;TOOL&gt;&gt; task. Constraint 1 may require extra wrapper work. **Provider-specific server API; closed for pi** unless &lt;&lt;TOOL&gt;&gt; has a non-server-API integration mode. |
| A3 | New harness mode (`make <<tool>>` or similar). Wrapper that starts containers, opens &lt;&lt;TOOL&gt;&gt; pre-configured, waits on &lt;&lt;TOOL&gt;&gt; exit, runs `make stop`. **Departs from the framing axiom**; not pursued unless explicitly justified. |
| &lt;&lt;A4...&gt;&gt; | &lt;&lt;Add tool-specific lifecycle values here. Examples from prior evaluations: Warp's A4 = `MODE=warp` overlay for detached startup + Warpify-attach. If &lt;&lt;TOOL&gt;&gt; needs a tool-specific lifecycle shape, it goes here.&gt;&gt; |

#### Axis B — Terminal pane targets (where do &lt;&lt;TOOL&gt;&gt; terminal panes point?)

Multiple values can be combined — &lt;&lt;TOOL&gt;&gt; supports multiple terminal panes per window &lt;&lt;CONFIRM and qualify if not&gt;&gt;.

| Value | Description |
|---|---|
| B0 | Plain shell on host (in `SANDBOX_DIR` or `PROJECT_DIR`). Used for `make` commands, git, etc. |
| B1 | `docker attach` to reasoning layer (`<provider>-agent-<project>`). TTY view of the live agent. |
| B2 | `docker exec` shell into reasoning layer. Inspection shell separate from the agent TUI. |
| B3 | `docker exec` shell into capability layer (`sandbox-<project>`). Inspection shell on the volume-owning side. |

#### Axis C — Editor workspace targets (where does &lt;&lt;TOOL&gt;&gt;'s editor point?)

Multiple values can be combined — &lt;&lt;TOOL&gt;&gt; supports multiple workspaces per window &lt;&lt;CONFIRM and qualify if not&gt;&gt;.

| Value | Description |
|---|---|
| C0 | `PROJECT_DIR` as a host workspace. Operator's view of the host repo. |
| C1 | `SANDBOX_DIR` as a host workspace. Operator's view of `AGENTS.md`, `.workspace/`, provider config. |
| C2 | Container workspace via &lt;&lt;TOOL&gt;&gt;'s container integration mechanism (Dev Container remote-server, SSH remote, etc.). Editor features on the container's filesystem including `sandbox/`. &lt;&lt;Mark as N/A if &lt;&lt;TOOL&gt;&gt; does not support editor features in remote/container sessions; cite the source.&gt;&gt; |
| C3 | No editor workspace on container — container access is via terminal panes only (axis B). |
| C4 | Sandbox volume bind-mounted to host so &lt;&lt;TOOL&gt;&gt; can open it as a workspace without entering the container. **Likely rejected** for the same reasons as the standing rejected approaches (see below); document explicitly in rejected approaches and remove from this axis if rejected. |

#### Axis D — Operator/agent edit policy on `sandbox/`

| Value | Description |
|---|---|
| D1 | Single-writer. Operator does not edit `sandbox/` directly. Edits flow via `AGENTS.md`, `workspace/input/`, and the existing `!`-hook commit pattern inside the agent. |
| D2 | Multi-writer. Operator and agent both edit `sandbox/` (requires C2 or C4 to be a useful surface; therefore not currently usable if both are unavailable). |
| D3 | Comment channel via `workspace/input/`. Additive to D1 or D2 — operator-authored comments and quoted sections written to `workspace/input/` for the agent to read on next turn. Uses an existing primitive without modification. |

#### &lt;&lt;Axis E and beyond — tool-specific axes if needed&gt;&gt;

&lt;&lt;Add tool-specific axes only when the standard axes A–D do not capture a real integration choice the tool offers. Example: an agent-integration mode axis if the tool offers a first-class agent surface (ACP, MCP, custom protocol). If no such axis is needed, delete this section.&gt;&gt;

### Rejected approaches (off the axes) *(stable backbone, tool-specific entries)*

These were considered and ruled out at this preliminary stage. Recorded for traceability.

**Standing rejections — apply to every tool unless the tool changes the underlying argument:**

| Rejected | Reason | Would change if |
|---|---|---|
| **Host bind-mount of `sandbox/`** | (1) `sandbox/` is currently a Docker anonymous volume specifically because it should not appear on the host (see [`container_model.md`](../architecture/container_model.md)). (2) Independently rejected by the security invariant that the agent must not have direct read/write access to host git history. (3) Operator has previously explored bind-mounting and decided to stick with the snapshot + baseline workflow. | The bind-mount direction is reopened as its own scoping decision. Out of scope here. |
| **&lt;&lt;TOOL&gt;&gt; + agent ACP** | ACP implementation is feature-incomplete with no timeline. Pi (the primary provider) does not have working ACP support. | Pi or another adopted provider ships sufficiently complete ACP support with a stable surface. |
| **&lt;&lt;TOOL&gt;&gt;-as-MCP-server, agent connects out** | Crosses the trust boundary backwards — the operator's editor becomes a service the agent calls into, creating an outbound channel from the agent to operator-side software on the host. | A use case appears that genuinely requires the agent to query the editor, *and* a model exists to bound the surface. |
| **Capability layer MCP with both &lt;&lt;TOOL&gt;&gt; and agent as clients** | MCP capability layer is anticipated but not currently planned (see [`two_layer_model.md`](../concepts/two_layer_model.md#capability-layer-configurations)). Premature. | The MCP capability layer is adopted for unrelated reasons, at which point &lt;&lt;TOOL&gt;&gt;-as-second-client becomes a small add. |

**Tool-specific rejections — add as research surfaces them:**

| Rejected | Reason | Would change if |
|---|---|---|
| &lt;&lt;e.g. "sshd in reasoning layer container" — describe the rejection reason specific to this tool, e.g. "no additional features over the standard `docker exec` integration; would add a network listener for no gain"&gt;&gt; | | |
| &lt;&lt;e.g. "&lt;&lt;TOOL&gt;&gt;'s native AI feature as a third-party agent integration surface" — describe why the tool's AI feature does not provide what was hoped&gt;&gt; | | |

### Use case coverage by axis value *(structured, tool-specific cells)*

How each axis value contributes to each use case. `✓` = covers; `partial` = partial fit; `—` = does not address; `?` = pending experimental confirmation.

| | (1) Review host | (2) Apply diffs | (3) Send prompts | (4a) Run sandbox cmds | (4b) Sandbox file explorer | (5) Shared channels | (6) Live agent edits |
|---|---|---|---|---|---|---|---|
| **A1** | | | | | | | |
| **A2** | | | | | | | |
| **A3** | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config |
| &lt;&lt;A4...&gt;&gt; | | | | | | | |
| **B0** | — | ✓ via `make apply` / `make draft` | — | ✓ | — | — | — |
| **B1** | — | — | &lt;&lt;✓ or ?&gt;&gt; | — | — | — | — |
| **B2** | — | partial (via shell) | — | partial | — | — | partial (`git diff` in shell) |
| **B3** | — | partial (via shell) | — | partial | — | — | partial (`git diff` in shell) |
| **C0** | ✓ | — | — | — | — | — | — |
| **C1** | — | ✓ via tasks running `make apply` | — | ✓ via task wrappers + file tree | ✓ | ✓ | — |
| **C2** | — | — | — | — | — | — | &lt;&lt;✓ if available; otherwise N/A&gt;&gt; |
| **C3** | — | — | — | — | — | — | — |
| **C4** | — | — | — | — | — | — | rejected (see standing rejections) |
| **D1** | — | — | — | — | — | — | — |
| **D2** | — | — | — | — | — | — | partial — viewing edits is C2/C4; D2 is whether operator can also write |
| **D3** | — | — | partial — async channel into agent reasoning | — | — | partial | — |
| &lt;&lt;Tool-specific axis values&gt;&gt; | | | | | | | |

**Reading the table.** &lt;&lt;Two to four bullets summarising what the table says: which cluster covers the cheap use cases without harness change; which use cases are uncovered; which axis values are closed for this tool. Mirror the prose in the Zed and Warp stories.&gt;&gt;

---

## Open Questions *(structured, tool-specific)*

What remains unresolved given the preliminary context above. Numbered for cross-reference; use a tool-specific prefix (e.g. `Q-Z` for Zed, `Q-W` for Warp, `Q-V` for VSCode) so questions across stories don't collide.

### Resolved during research

&lt;&lt;Questions answered by documentation review or research, before any hands-on. The Warp story landed most of its questions here because Warp turned out to be desk-research-shaped.&gt;&gt;

### Resolved by hand-rolling

&lt;&lt;Questions answered by hand-rolled experiments. The Zed story landed most of its questions here.&gt;&gt;

### Closed by workaround / shelved

&lt;&lt;Questions where a workaround makes deeper investigation unnecessary, or where the question lost relevance.&gt;&gt;

### Active

&lt;&lt;Questions currently being investigated. Each should have a corresponding entry in Experiments to Run.&gt;&gt;

### Still open

&lt;&lt;Questions that are unresolved but not currently active — recorded for visibility, deferred for now.&gt;&gt;

### New questions surfaced by Session N

&lt;&lt;After each hand-rolled session, new questions get added under their session header. Helps trace which questions came from which findings.&gt;&gt;

---

## Experiments to Run *(structured, tool-specific)*

The open questions above are answerable by hand-rolling, not by further written analysis &lt;&lt;or: "by desk research, not by hand-rolling — see Investigation Findings below"&gt;&gt;. This section records what experiments have been run, what is planned next, and what is deferred.

### Session N — &lt;&lt;short description&gt;&gt;

**Goal.** &lt;&lt;What this session is meant to resolve.&gt;&gt;

**Why this is the right next experiment.** &lt;&lt;Justification — usually "answers the load-bearing question for the cheapest cluster" or "tests the highest-value uncertain feature."&gt;&gt;

**Phased structure (if applicable).** &lt;&lt;If the session is phased — each phase precondition for the next, failure routing — describe the phases. Otherwise omit.&gt;&gt;

**Setup additions.** &lt;&lt;Anything that needs to be in place before the session beyond what's already documented.&gt;&gt;

**Pass criterion.** &lt;&lt;What "session succeeds" means.&gt;&gt;

### Deferred follow-ups *(structured, tool-specific)*

Items surfaced during investigation but not in active experiment scope. Listed for traceability; some may grow into their own stories.

- &lt;&lt;Item — what it is, why it's deferred, what would unparked it.&gt;&gt;
- &lt;&lt;Item.&gt;&gt;

### Out of scope for this story *(structured, tool-specific)*

- &lt;&lt;Things explicitly not addressed by this story, with brief reason.&gt;&gt;

### Output protocol *(stable)*

Findings get appended to **Investigation Findings** as a new "Hand-rolled session N — `<date>`" subsection (or "Research session — `<date>`" for desk-research sessions). Resolved questions move to a Resolved sub-list under Open Questions; remaining questions stay open. New questions surfaced by a session are added to a "New questions surfaced by Session N" sub-list. When all questions are resolved, deferred, or shelved, the story is ready for Resolution.

---

## Investigation Findings *(open)*

&lt;&lt;Empty until the first session runs. Each session's findings get appended as a dated subsection. Use the format from the Zed and Warp stories: short prose paragraphs grouped by finding, ending with a "Findings against open questions" table.&gt;&gt;

&lt;&lt;Example structure for a session entry:&gt;&gt;

### Session N — &lt;&lt;descriptor&gt;&gt; — &lt;date&gt;

&lt;&lt;Brief framing of what was attempted and the high-level outcome.&gt;&gt;

#### &lt;&lt;Finding heading 1&gt;&gt;

&lt;&lt;Prose, 2–4 sentences. Concrete observation, not interpretation. Cite confirmed-by-screenshot or hands-on if applicable.&gt;&gt;

#### &lt;&lt;Finding heading 2&gt;&gt;

&lt;&lt;...&gt;&gt;

#### Findings against open questions

| Question | Status | Notes |
|---|---|---|
| &lt;&lt;Q-X-N&gt;&gt; | &lt;&lt;Resolved | Closed by workaround | Active | Still open | N/A&gt;&gt; | &lt;&lt;Brief notes&gt;&gt; |

---

## References *(stable backbone, tool-specific cross-link rows)*

| Document | Purpose |
|---|---|
| [`tool_interface.md`](../architecture/tool_interface.md) | Existing harness primitives — commands, container names, mount guarantees |
| [`container_model.md`](../architecture/container_model.md) | Two-container lifecycle and volume ownership rationale |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot, work, diff pipeline phases |
| [`execution_model.md`](../architecture/execution_model.md) | Compose generation model |
| [`two_layer_model.md`](../concepts/two_layer_model.md) | Reasoning vs capability layer separation |
| [`security.md`](../architecture/security.md) | Security invariants this scope must preserve |
| [`threat_model_stride.md`](../architecture/threat_model_stride.md) | Threat model — referenced if any path under evaluation requires invariant rescoping |
| [`story_policy.md`](../operations/story_policy.md) | Story format, lifecycle, and graduation |
| [`investigation_policy.md`](../operations/investigation_policy.md) | If candidate evaluation is split into sub-investigations |
| [`story_agent_git_surface.md`](story_agent_git_surface.md) | Adjacent surface — agent's relationship to git, tracked separately |
| &lt;&lt;Cross-link to parallel editor evaluations&gt;&gt; | &lt;&lt;e.g. [`story_zed_integration.md`] | Parallel evaluation of Zed for the same use cases&gt;&gt; |
| &lt;&lt;Tool-specific references — vendor docs, threat model deltas, etc.&gt;&gt; | |
