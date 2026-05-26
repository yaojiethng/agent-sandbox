# Story — VSCode as a UI Option for agent-sandbox

**Status:** Investigation pre-experiment

---

## Context

The operator currently runs an agent-sandbox session across multiple windows: a host editor (VSCode) for reviewing changes in `PROJECT_DIR`, a terminal in `SANDBOX_DIR` for `make apply` / `make draft`, a terminal attached to the reasoning layer container for prompting the agent, a file explorer on `SANDBOX_DIR` for sandbox-side artefacts, and ad-hoc inspection of agent file changes via the same channels. The goal is to consolidate as many of these as possible into VSCode — ideally with each surface presented well, or at minimum collapsed into one window.

VSCode is being evaluated as an alternative tooling option alongside Zed. Warp is most likely a rejected story; Zed is the current frontrunner but is blocked by a git locking bug that prevents standard terminal use, with workarounds being sought. VSCode is being evaluated as the parallel alternative. The comparison view is obtained by reading the VSCode and Zed stories side by side.

### What drew us to VSCode

- **Mature Dev Containers + "Attach to Running Container" support.** VSCode has had Dev Containers since 2019 and the attach-to-running-container path is documented, stable, and does not require the harness to know VSCode exists. (Source: documentation — [code.visualstudio.com/docs/devcontainers/attach-container](https://code.visualstudio.com/docs/devcontainers/attach-container))
- **True multi-root workspaces.** VSCode supports opening multiple independent host folders in a single window via `.code-workspace` files — `PROJECT_DIR` and `SANDBOX_DIR` simultaneously, each as a first-class root with its own file tree, tasks, and settings. (Source: documentation — [code.visualstudio.com/docs/editing/workspaces/multi-root-workspaces](https://code.visualstudio.com/docs/editing/workspaces/multi-root-workspaces))
- **Dominant, mature editor feature set — pre-AI.** VSCode's appeal is not AI-first. Its primary value is its editor: widely battle-tested, cross-platform (macOS, Linux, Windows+WSL2), extensive extension ecosystem. If the container attach and workspace integration work, the editor surface is already established. (Source: operator — hands-on.)

### Notes on first-class agent integrations

The pi-coding-agent VSCode extension is explicitly abandoned. No first-class agent integration surface exists for the target agent. If VSCode-native AI features (GitHub Copilot, Copilot Chat) work alongside the harness, they may be useful for operator-side editing but cannot serve as the agent integration path. This story does not evaluate any agent integration axis beyond the terminal attach that the harness already supports.

### Framing axiom

agent-sandbox is an agentic tool that VSCode has access to. VSCode is not part of agent-sandbox. The harness exposes primitives; VSCode composes them. Any approach that requires the harness to know VSCode exists in a structural way is a departure from the framing and needs explicit justification.

The natural analogue is Open WebUI sitting on top of `opencode serve`: Open WebUI works because the harness exposes a documented endpoint shape; the harness has no opinion on whether Open WebUI exists. VSCode integration aims for the same relationship.

### Approach to evaluation

The integration shape has multiple independent axes (lifecycle, terminal panes, editor panes, multi-writer policy). Each axis offers several values. A working configuration is a *combination across axes*, not a single option from a flat list. The evaluation question is: **what combination covers the most use cases under the constraints?**

VSCode offers two distinguishable integration paths with very different cost profiles:

1. **Host-only (no container attach):** Multi-root workspace on host, terminal panes via `docker attach` / `docker exec`, no editor features inside the container. Available immediately, no harness change, no container modification. Covers all pain points except (6).
2. **Container attach via Dev Containers:** VSCode attaches to a running harness container (capability or reasoning layer), opens `sandbox/` as workspace folder, delivers full editor features including file tree, git diff, and extensions inside the container. Covers (6). VS Code Server installation confirmed on both harness container images.

**Confirmed working model — two windows.** The full-coverage configuration is two VSCode windows running simultaneously. Host folders (`PROJECT_DIR`, `SANDBOX_DIR`) and a container workspace (`sandbox/`) cannot coexist in a single window's file explorer — a VSCode window connects to exactly one context (local or remote), and a single window cannot hold multiple `.code-workspace` files simultaneously (unresolved feature request, open since 2018). Two windows is the confirmed minimum; this is not a limitation to work around but the accepted design.

**Container window (primary):** attached to the harness container via Dev Containers, `workspaceFolder` = `sandbox/`. Provides: container file tree (use case 6 — live agent edits), container terminal panes (B1: `docker attach` agent TTY, B2: container inspection shell), local terminal tabs via `Terminal: New Local Terminal` (B0: `make apply`, `make draft`, `make stop` on the host). The container window is the operator's primary working surface during a session.

**Host window (secondary):** multi-root `.code-workspace` file with `PROJECT_DIR` and `SANDBOX_DIR` as roots. Provides: host file tree for `PROJECT_DIR` (use case 1 — review host changes, C0), host file tree for `SANDBOX_DIR` (use cases 4b/5 — sandbox file explorer + shared channels, C1). Used for reviewing diffs and reading harness artefacts; less active during a session than the container window.

**Session open flow:** `make start` is run from a terminal (inside the container window's local terminal tab, or from a standalone terminal before opening VSCode). Once containers are up, the container window is opened via `code --folder-uri` script **(unverified — community)**:

```bash
CONTAINER_NAME="sandbox-<project>"
FOLDER="/home/agentuser/sandbox"
HEX=$(printf '{"containerName":"/%s"}' "$CONTAINER_NAME" | od -A n -t x1 | tr -d '[\n\t ]')
code --folder-uri "vscode-remote://attached-container+${HEX}${FOLDER}"
```

This means the host window is not a required stepping stone to open the container window — both can be opened independently.

**Session-end disconnect behaviour.** When the harness stops (`make stop` or session ends), VS Code Server inside the container dies and the container window drops to a "Cannot reconnect" state. There is no auto-recovery. To reattach after a new `make start`: re-run the `code --folder-uri` script or use Command Palette → `Dev Containers: Attach to Running Container`. Because the harness uses deterministic container names (`sandbox-<project>`), the attached container config (extensions, `workspaceFolder`) persists across sessions keyed by container name — reattach is a one-step operation.

**Layout persistence across sessions.** VSCode's panel positions, sidebar layout, terminal panel location, and workbench chrome are stored in host-side user-level global storage (`~/.config/Code/User/` on Linux, `~/Library/Application Support/Code/User/` on macOS) — **not inside the container**. This means panel layout survives container restarts in principle, because it never lived in the container.

However, the attached container config (remembered `workspaceFolder`, extensions to install) is keyed by container name. If the container name changes each session (e.g. due to a `WORKTREE_ID` suffix or other per-session naming), VSCode treats each new container as a new remote context — no remembered config carries over. This means:

- **`workspaceFolder`** — not remembered. The `code --folder-uri` URI encodes the folder directly, so this is not a problem in practice; the right folder opens regardless.
- **Extensions** — reinstalled on each attach to a new container name. Pre-installing VS Code Server and extensions into the Dockerfile (Shape V9) eliminates this cost entirely.
- **Panel/workbench layout** — survives, because it lives in host global storage, not keyed by container name.

What resets on each session regardless of naming:

- **Open editors / open files list** — workspace-specific state tied to the container context. Resets intentionally; `sandbox/` has fresh content each session.
- **Window screen position and size** — VSCode does not persist window position per workspace or per remote context. Known unresolved limitation (GitHub issue #61838, marked out-of-scope). Each time the container window opens via `code --folder-uri`, it opens at a default or last-used screen position. No built-in fix exists.

The practical consequence: after each `agent-sandbox-open.sh`, the container window opens at an unpredictable screen position and extensions reinstall (unless pre-baked). The panel arrangement inside the window stays. One manual window snap after open, plus the extension reinstall delay, are the per-session friction.

Mitigations: (a) pre-install extensions and VS Code Server in the Dockerfile (Shape V9) to eliminate the reinstall delay; (b) use an OS window manager to snap the container window to a fixed position after open (Rectangle on macOS, PowerToys FancyZones on Windows, i3/sway on Linux).

**B2/B3 terminal as lightweight alternative to C2 for use case (6).** Before committing to the full container-attach path, a simpler in-terminal view of live agent changes is available from any terminal pane:

```bash
# Continuous diff view (updates every 1 second):
docker exec -it sandbox-<project> watch -n1 git -C /home/agentuser/sandbox diff

# Compact log view (shows recent commits as agent works):
docker exec -it sandbox-<project> git -C /home/agentuser/sandbox log --oneline
```

These run from a B0 or B3 terminal pane in either window and require no VS Code Server, no container attach, and no harness change. They provide read-only visibility into agent progress without the full editor surface. Useful as a fallback if C2 proves problematic, or as a quick steering check during a session.

---

## Pain Points

| # | Surface | Currently | Notes |
|---|---|---|---|
| 1 | Reviewing changes on host | VSCode opened from `PROJECT_DIR` | Window switch from primary editor; separate from the rest of the workflow |
| 2 | Applying diffs from container | Terminal in `SANDBOX_DIR` running `make apply` / `make draft` | Separate terminal from the agent terminal; manual cd between folders |
| 3 | Sending prompts to the agent | Terminal attached to reasoning layer container | Confined to one terminal window; no editor context alongside |
| 4a | Running sandbox commands | Terminal in `SANDBOX_DIR` | Often shares a window with (2) |
| 4b | File explorer on `SANDBOX_DIR` | Second file explorer window | Browsing config, brief, provider config; distinct from (4a) by optimal UI |
| 5 | View into shared operator/sandbox channels (`workspace/input/`, `workspace/output/`, `workspace/session-diffs/`) | Done via the file explorer for (4b), tediously | Currently same window as (4b) but distinct use — these are communication surfaces, not configuration |
| 6 | View into agent's live file changes in `sandbox/` | Not currently available except by entering the container shell and running `git diff` / `cat` | Steering use case: see when the agent is going wrong without a port-out / review / amend / port-in loop |

Use case 5 is currently available but tedious; use case 6 is currently not really available at all. Both are nice-to-haves that VSCode could plausibly offer if the right axes line up.

claude.ai web chat (this conversation) is excluded — operator-side reasoning, not part of the sandbox loop.

---

## Constraints

1. **Lifetime coupling.** When the operator uses agent-sandbox via VSCode, closing VSCode closes the session.
2. **Cold start.** agent-sandbox is not running when VSCode opens. The session starts inside VSCode.
3. **Operator restart authority.** Within a VSCode session, the operator can stop and restart the agent-sandbox container set freely.
4. **Security invariants preserved.** The four invariants in [`security.md`](../architecture/security.md) hold: agents in containers, output via diffs, human approval gate, depth ≤ 2 with no grandchildren. No path under this evaluation requires invariant rescoping.
5. **Bare terminal still works.** `make start` and `make serve` are not changed in shape or behaviour by VSCode integration.
6. **Harness change is permitted but should be minimal.** Host-only path requires no harness change. Container attach path requires no harness change for basic operation — VS Code Server installs on first attach and is confirmed to work in both harness container images. Optional: pre-install VS Code Server into the Dockerfile to eliminate the per-attach installation delay (see primitives table). No compose overlay is required — attachment is initiated from VSCode, not from a harness command.

---

## Preliminary Context

### Existing primitives VSCode can hook into

Without any harness change, an operator with VSCode installed has access to:

| Primitive | Source | Use |
|---|---|---|
| `make start PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-start-provider-provider-rebuild1) | Foreground task; closing terminal pane signals teardown |
| `make serve PROVIDER=<n>` | [`tool_interface.md`](../architecture/tool_interface.md#make-serve-provider-provider-rebuild1) | Background mode; agent on `127.0.0.1:SERVE_PORT` |
| `make stop` | [`tool_interface.md`](../architecture/tool_interface.md) | Explicit teardown |
| Deterministic container names | [`tool_interface.md`](../architecture/tool_interface.md#container-naming) | `sandbox-<project>` and `<provider>-agent-<project>` — known at workflow-write time |
| `docker attach <container>` | Docker | TTY connection to running container's PID 1 |
| `docker exec -it <container> <cmd>` | Docker | Fresh shell or process inside running container |
| `docker logs -f <container>` | Docker | Tail of stdout/stderr from PID 1 |
| Host-side workspace | [`tool_interface.md`](../architecture/tool_interface.md#mount-shape-guarantees) | `SANDBOX_DIR` and contents editable directly |
| `agent-sandbox` CLI wrapper | `scripts/agent-sandbox.sh` | Host-installed command surface; preferred wrapper target |
| VSCode `tasks.json` (shell type) | [VSCode tasks docs](https://code.visualstudio.com/docs/debugtest/tasks) | Named tasks wrapping arbitrary shell commands, runnable from Command Palette or keybinding. Per-folder in `.vscode/tasks.json`; also available at workspace level in `.code-workspace`. (Source: documentation) |
| VSCode integrated terminal | [VSCode docs](https://code.visualstudio.com/docs/terminal/basics) | Multiple panes per window, each spawned in a configurable working directory or shell profile. (Source: documentation) |
| VSCode multi-root workspace | [VSCode multi-root docs](https://code.visualstudio.com/docs/editing/workspaces/multi-root-workspaces) | Multiple host-side folders open as independent roots in a single window. Each root has its own file tree, tasks, and settings. Configured via `.code-workspace` file. (Source: documentation) |
| VSCode Dev Containers — Attach to Running Container | [VSCode attach docs](https://code.visualstudio.com/docs/devcontainers/attach-container) | Attaches to an already-running Docker container regardless of how it was started. Once attached: full VS Code editor features (file tree, diff, extensions, terminal) inside the container. Configured via per-image/name attached container config file (subset of `devcontainer.json`). (Source: documentation) |
| VS Code Server (auto-installed on attach) | [VSCode FAQ](https://code.visualstudio.com/docs/devcontainers/faq) | Downloaded locally and copied into the container on first attach. **Requires glibc ≥ 2.28 and libstdc++ ≥ 3.4.25 in the container** (enforced since VS Code 1.99, March 2025). Ubuntu 20.04+ satisfies this; Alpine does not. **Confirmed by operator: installs cleanly into both capability layer and reasoning layer containers.** |
| VS Code Server (pre-installed in image) | [VSCode pre-build docs](https://code.visualstudio.com/docs/devcontainers/containers#_prebuilding-dev-container-images) | VS Code Server can be baked into the container image at build time to eliminate the per-attach installation delay. The server binary lives at `~/.vscode-server/` inside the container; pre-populating this in the Dockerfile means the first attach connects immediately. The server version must match the VSCode client version, so this is only stable if the VSCode version is pinned or the Dockerfile is rebuilt on VSCode update. **(unverified — inferred from how VS Code Server works; Dockerfile approach needs hands-on confirmation)** |
| `code --folder-uri` CLI attach | [community gist](https://gist.github.com/awesomebytes/8494fb216c42bc4a2fcaef6b4937a07e) | Opens a container-attached VSCode window directly from the command line without requiring a host window as intermediary. Container name is hex-encoded into the URI: `code --folder-uri "vscode-remote://attached-container+<hex>/<folder>"`. Scriptable — can be fired after `make start` in a single session-open script. **(unverified — community; not in official docs. Needs hands-on confirmation with harness container names.)** |
| `Terminal: New Local Terminal` | [VSCode docs](https://code.visualstudio.com/docs/terminal/basics) | Available via Command Palette from a container-attached window. Opens a host shell tab in the same integrated terminal panel alongside container shell tabs. Allows `make` commands to run on the host from within the container window. (Source: documentation) |
| VSCode window constraint | [VSCode FAQ](https://code.visualstudio.com/docs/devcontainers/faq) | A single VS Code window can only connect to one remote context at a time. Host folders and container workspace cannot coexist in the same window's file explorer. Two windows is the minimum for the full-coverage configuration. Multiple `.code-workspace` files cannot be open in a single window simultaneously — this is a long-standing unresolved feature request. (Source: documentation + GitHub issue #43188, open since 2018) |

**Wrappers vs custom integrations.** VSCode tasks that wrap host-installed commands (`make`, `agent-sandbox`, `docker`) are preferred — they keep the contract on the harness side, leave bare terminal usage unaffected, and require no VSCode-specific knowledge in the harness.

### Platform notes

VSCode runs natively on macOS, Linux, and Windows. On Windows+WSL2 **with Docker Desktop**, the recommended path is to run VSCode on Windows with the Remote - WSL extension; Dev Containers and the attach path work from this configuration. (Source: documentation)

**Windows+WSL2 without Docker Desktop — resolved workaround.** When running Docker Engine directly inside WSL2 (no Docker Desktop), VSCode on the Windows side cannot reach the Docker socket and the Dev Containers attach path fails. The workaround is to launch VSCode from *inside* the WSL2 terminal:

```bash
# From your WSL2 distro terminal, in the project directory:
code .
```

This opens VSCode connected to WSL via the Remote - WSL extension. From that WSL-connected window, the Dev Containers extension sees Docker Engine's socket at `/var/run/docker.sock` inside WSL and the attach path works normally — identically to a native Linux host. The multi-root workspace, task wrappers, and container attach all behave the same from that point. (Source: community confirmation — GitHub devcontainers/discussions#99; inferred from Remote - WSL + Dev Containers extension interaction model — documentation)

**Constraint:** Project files (`SANDBOX_DIR`, `PROJECT_DIR`) must live in the WSL filesystem (e.g. `~/projects/`), not the Windows filesystem (`/mnt/c/...`). Cross-filesystem I/O via the 9P protocol is slow and causes known issues. This should already be the case for harness performance reasons. (Source: documentation — endjin.com 2025)

### Concrete VSCode shapes from research

The shapes below are the integration surfaces identified from documentation. None have been hands-on confirmed in the agent-sandbox context.

**Shape V1 — Multi-root host workspace:**

```json
// agent-sandbox.code-workspace
{
  "folders": [
    { "name": "project (host)", "path": "/path/to/PROJECT_DIR" },
    { "name": "sandbox-host (SANDBOX_DIR)", "path": "/path/to/SANDBOX_DIR" }
  ],
  "settings": {}
}
```

Opens `PROJECT_DIR` and `SANDBOX_DIR` as two independent roots in a single VSCode window. The operator gets two file trees side by side. No container integration, no harness change. (Source: documentation — hands-on confirmation pending for agent-sandbox paths specifically)

**Shape V2 — Task wrappers for harness commands:**

```json
// .vscode/tasks.json (in SANDBOX_DIR or at workspace level)
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "agent-sandbox: start",
      "type": "shell",
      "command": "make start PROVIDER=${input:provider}",
      "options": { "cwd": "${workspaceFolder:sandbox-host (SANDBOX_DIR)}" },
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "agent-sandbox: apply",
      "type": "shell",
      "command": "make apply",
      "options": { "cwd": "${workspaceFolder:sandbox-host (SANDBOX_DIR)}" }
    },
    {
      "label": "agent-sandbox: draft",
      "type": "shell",
      "command": "make draft",
      "options": { "cwd": "${workspaceFolder:sandbox-host (SANDBOX_DIR)}" }
    },
    {
      "label": "agent-sandbox: stop",
      "type": "shell",
      "command": "make stop",
      "options": { "cwd": "${workspaceFolder:sandbox-host (SANDBOX_DIR)}" }
    }
  ]
}
```

Task names appear in Command Palette (`Ctrl+Shift+P → Tasks: Run Task`). Each runs in a VSCode integrated terminal pane. `cwd` resolves to `SANDBOX_DIR` regardless of which file is focused. No harness change required. (Source: documentation — `${workspaceFolder:<name>}` variable scoping in multi-root workspaces is documented; hands-on confirmation of exact variable syntax pending)

**Shape V3 — Terminal panes for agent attach:**

Multiple integrated terminal panes, each started via Command Palette or split terminal:

```
Terminal 1 (SANDBOX_DIR, B0): make commands, git, general ops
Terminal 2 (docker attach <provider>-agent-<project>, B1): live agent TTY
Terminal 3 (docker exec -it <provider>-agent-<project> bash, B2): inspection shell
```

No harness change. VSCode supports multiple terminal panes per window. **(unverified — needs hands-on confirmation that `docker attach` TTY behaves correctly inside VSCode's integrated terminal — specifically that agent TUI input is well-behaved)**

**Shape V4 — Attach to capability layer container (C2 path):**

Once the harness containers are running, from VSCode Command Palette:

```
Dev Containers: Attach to Running Container...
→ select sandbox-<project>
→ workspaceFolder: /home/agentuser/sandbox
```

Or via attached container config (`~/.config/Code/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs/<container-name>.json`):

```json
{
  "workspaceFolder": "/home/agentuser/sandbox",
  "extensions": ["mhutchie.git-graph", "eamodio.gitlens"]
}
```

This opens a **second VSCode window** pointed at `sandbox/` inside the capability layer container. Full editor features: file tree, diff viewer, extensions, terminal. VS Code Server installs on first attach — **confirmed working by operator on both harness container images.**

**Shape V5 — Attach to reasoning layer container (alternative C2 path):**

Same as Shape V4 but targeting `<provider>-agent-<project>`. The reasoning layer also has `sandbox/` mounted via `--volumes-from`. The editor workspace would point to the same `sandbox/` path. VS Code Server installation **confirmed working** on the reasoning layer image as well.

Tradeoff vs V4: The capability layer owns `sandbox/` — attaching there puts VS Code Server dependencies in a provider-agnostic container that persists across provider changes. The reasoning layer changes per provider — VS Code Server would need to be reinstalled or pre-installed separately for each provider image. Architecturally, the capability layer is the cleaner C2 target. Decision deferred to Session 2.

**Shape V6 — Two-window confirmed configuration:**

The accepted full-coverage setup. Two VSCode windows open simultaneously:

- **Host window** — opens `agent-sandbox.code-workspace` (Shape V1). Contains: `PROJECT_DIR` file tree (C0), `SANDBOX_DIR` file tree (C1), task wrappers (Shape V2). Used for reviewing host diffs and harness artefacts.
- **Container window** — Dev Containers attached to `sandbox-<project>` or `<provider>-agent-<project>`, `workspaceFolder` = `/home/agentuser/sandbox`. Contains: `sandbox/` file tree + git diff (C2), agent TTY terminal tab (B1, `docker attach`), local terminal tab for host `make` commands (B0, `Terminal: New Local Terminal`).

The container window is primary (agent chat + live edits). The host window is secondary (diff review). Both opened at session start; container window disconnects at session end and is reattached via script.

**Shape V7 — Scriptable session-open:**

A shell script wrapping `make start` + `code --folder-uri` that opens both windows in one step. The `code --folder-uri` command uses a hex-encoded container name to open the container window directly without requiring any VSCode UI interaction.

Because container names may not be known in advance (e.g. when a `WORKTREE_ID` suffix is appended), the script looks up the current capability layer container by its harness label rather than constructing the name directly. The harness sets `agent-sandbox.project-dir` on the capability layer container at session start — this is the stable lookup key.

```bash
#!/usr/bin/env bash
# agent-sandbox-open.sh
# Usage: ./agent-sandbox-open.sh /path/to/PROJECT_DIR /path/to/SANDBOX_DIR [provider]
set -e

PROJECT_DIR="$1"
SANDBOX_DIR="$2"
PROVIDER="${3:-default}"

# Start harness (background; adjust to make serve if preferred)
cd "$SANDBOX_DIR"
make start PROVIDER="$PROVIDER" &

# Wait for capability layer healthcheck to pass
# Polls the harness label rather than assuming a fixed container name
echo "Waiting for capability layer..."
until docker ps \
  --filter "label=agent-sandbox.project-dir=${PROJECT_DIR}" \
  --filter "health=healthy" \
  --format '{{.Names}}' | grep -q .; do
  sleep 1
done

# Look up the actual container name (may include WORKTREE_ID suffix)
CONTAINER_NAME=$(docker ps \
  --filter "label=agent-sandbox.project-dir=${PROJECT_DIR}" \
  --format '{{.Names}}' | head -1)

echo "Attaching to: $CONTAINER_NAME"

# Open container window
FOLDER="/home/agentuser/sandbox"
HEX=$(printf '{"containerName":"/%s"}' "$CONTAINER_NAME" | od -A n -t x1 | tr -d '[\n\t ]')
code --folder-uri "vscode-remote://attached-container+${HEX}${FOLDER}"

# Open host window
code "${SANDBOX_DIR}/agent-sandbox.code-workspace"
```

**(unverified — `code --folder-uri` community-documented, not in official docs. Label-based lookup uses documented harness labels from `sandbox_host_correspondence_model.md`. Healthcheck poll assumes the capability layer has a Docker healthcheck configured — verify against actual harness setup. Needs hands-on confirmation in Session 1 phase 5.)**

**Shape V8 — Lightweight live-edit view without container attach:**

For use case (6) without the full Dev Containers attach, from any B0/B3 terminal pane:

```bash
# Continuous diff (updates every 1 second — shows unstaged changes as agent works):
docker exec -it sandbox-<project> watch -n1 git -C /home/agentuser/sandbox diff

# Recent commit log (shows commits as agent completes work blocks):
docker exec -it sandbox-<project> git -C /home/agentuser/sandbox log --oneline
```

No VS Code Server, no image change, no harness change. Available from any terminal in either window. Useful as a steering check during a session or as a fallback if C2 is unavailable. Does not provide file tree navigation or diff viewer — read-only terminal output only.

**Shape V9 — Pre-install VS Code Server into Dockerfile:**

Eliminates the per-attach VS Code Server download/copy step. The server binary is downloaded at image build time and placed at the path VSCode expects (`~/.vscode-server/bin/<commit-hash>/`). On attach, VSCode finds the binary already present and skips the install.

**Version coupling caveat:** The server binary is versioned by VSCode commit hash. The pre-installed version must match the connecting VSCode client exactly — a VSCode update that changes the commit hash will cause a fresh install anyway. This approach is most stable when the VSCode version used on the operator's machine is pinned or changes infrequently.

```dockerfile
# In the harness container Dockerfile (capability or reasoning layer)
# Replace <VSCODE_COMMIT> with output of: code --version | head -1 | awk '{print $2}'
# Replace <VSCODE_VERSION> with output of: code --version | head -1 | awk '{print $1}'

ARG VSCODE_COMMIT=<commit-hash>
ARG VSCODE_VERSION=<version>

RUN mkdir -p /home/agentuser/.vscode-server/bin/${VSCODE_COMMIT} \
    && curl -fsSL "https://update.code.visualstudio.com/commit:${VSCODE_COMMIT}/server-linux-x64/stable" \
       | tar -xz --strip-components=1 \
         -C /home/agentuser/.vscode-server/bin/${VSCODE_COMMIT} \
    && chown -R agentuser:agentuser /home/agentuser/.vscode-server
```

To get the current values on your machine:

```bash
code --version
# Example output:
# 1.99.0
# abc123def456...   ← this is VSCODE_COMMIT
# x64
```

**(unverified — community-documented pattern; download URL format confirmed from VSCode update infrastructure. Needs hands-on confirmation that the path and binary are picked up correctly on attach. Version coupling is a real maintenance cost — evaluate against actual attach latency before committing to this.)**

### Axes of the integration design

A working VSCode integration is a combination of choices across the following axes.

#### Axis A — Lifecycle ownership

| Value | Description |
|---|---|
| A1 | Foreground task: `make start` from a VSCode task (`tasks.json`). The task runs in a terminal pane; closing the window or killing the pane signals teardown. Satisfies constraint 1 (lifetime coupling). |
| A2 | Foreground task: `make serve` from a VSCode task. Constraint 1 may require extra wrapper work. **Provider-specific server API; closed for pi unless pi has a non-server-API integration mode.** |
| A3 | New harness mode (`make vscode` or similar). Wrapper that starts containers, opens VSCode pre-configured, waits on VSCode exit, runs `make stop`. **Departs from the framing axiom**; not pursued unless explicitly justified. |

No A4 is needed — VSCode does not require a detached startup or special lifecycle overlay comparable to Warp's `MODE=warp`. The attach step is initiated from VSCode after the containers are running, not from the harness.

#### Axis B — Terminal pane targets

VSCode supports multiple terminal panes per window. (Source: documentation)

| Value | Description |
|---|---|
| B0 | Plain shell on host (in `SANDBOX_DIR` or `PROJECT_DIR`). Used for `make` commands, git, etc. |
| B1 | `docker attach` to reasoning layer (`<provider>-agent-<project>`). TTY view of the live agent. |
| B2 | `docker exec` shell into reasoning layer. Inspection shell separate from the agent TUI. |
| B3 | `docker exec` shell into capability layer (`sandbox-<project>`). Inspection shell on the volume-owning side. |

#### Axis C — Editor workspace targets

VSCode supports multiple folders per window (multi-root) for host paths. For container paths, each attach opens a new window.

| Value | Description |
|---|---|
| C0 | `PROJECT_DIR` as a host workspace root. Operator's view of the host repo. Available in the multi-root `.code-workspace` file. |
| C1 | `SANDBOX_DIR` as a host workspace root. Operator's view of `AGENTS.md`, `.workspace/`, provider config. Available in the multi-root `.code-workspace` file alongside C0. |
| C2 | Container workspace via Dev Containers attach. A second VSCode window attached to the capability layer (Shape V4) or reasoning layer (Shape V5), with `sandbox/` as `workspaceFolder`. Full editor features: file tree, diff, git, extensions. VS Code Server installation confirmed on both harness container images. Target container (capability vs reasoning layer) is an open design decision (Q-V-8). |
| C3 | No editor workspace on container — container access is via terminal panes only (B1/B2/B3). Viable as a starting configuration before C2 is confirmed. |
| C4 | Sandbox volume bind-mounted to host so VSCode can open it as a workspace without entering the container. **Rejected** — see standing rejections. |

#### Axis D — Operator/agent edit policy on `sandbox/`

| Value | Description |
|---|---|
| D1 | Single-writer. Operator does not edit `sandbox/` directly. Edits flow via `AGENTS.md`, `workspace/input/`, and the existing `!`-hook commit pattern inside the agent. |
| D2 | Multi-writer. Operator and agent both edit `sandbox/`. Requires C2 to be a useful surface; not usable if C2 is unavailable. |
| D3 | Comment channel via `workspace/input/`. Additive to D1 or D2 — operator-authored comments written to `workspace/input/` for the agent to read on next turn. |

No Axis E is needed. VSCode has no first-class agent integration surface for pi-coding-agent (extension explicitly abandoned). GitHub Copilot / Copilot Chat exist as a vendor AI surface but are not the agent integration path and do not warrant a separate axis.

### Rejected approaches

**Standing rejections — apply to every tool unless the tool changes the underlying argument:**

| Rejected | Reason | Would change if |
|---|---|---|
| **Host bind-mount of `sandbox/`** | (1) `sandbox/` is a Docker anonymous volume specifically because it should not appear on the host. (2) Independently rejected by the security invariant that the agent must not have direct read/write access to host git history. (3) Operator has previously explored bind-mounting and decided to stick with the snapshot + baseline workflow. | The bind-mount direction is reopened as its own scoping decision. Out of scope here. |
| **VSCode + agent ACP** | ACP implementation is feature-incomplete with no timeline. Pi does not have working ACP support. | Pi or another adopted provider ships sufficiently complete ACP support with a stable surface. |
| **VSCode-as-MCP-server, agent connects out** | Crosses the trust boundary backwards — the operator's editor becomes a service the agent calls into. | A use case appears that genuinely requires the agent to query the editor, and a model exists to bound the surface. |
| **Capability layer MCP with both VSCode and agent as clients** | MCP capability layer is anticipated but not currently planned. Premature. | The MCP capability layer is adopted for unrelated reasons, at which point VSCode-as-second-client becomes a small add. |

**VSCode-specific rejections:**

| Rejected | Reason | Would change if |
|---|---|---|
| **Pi-coding-agent VSCode extension as integration surface** | Extension is explicitly abandoned. No maintained path. | Extension is revived or a replacement is published by the pi team. |
| **GitHub Copilot / Copilot Chat as agent integration surface** | Vendor-specific AI; cannot be replaced with pi-coding-agent. Useful for operator-side editing but not the agent integration path this story is evaluating. | Out of scope; not a reversal condition for this story. |
| **Single-window host + container workspace** | VSCode's constraint: a window can only connect to one remote context. Host folders and container workspace cannot coexist in the same window. | VSCode changes its remote connection model to support mixed local/remote roots in one window. |

### Use case coverage by axis value

| | (1) Review host | (2) Apply diffs | (3) Send prompts | (4a) Run sandbox cmds | (4b) Sandbox file explorer | (5) Shared channels | (6) Live agent edits |
|---|---|---|---|---|---|---|---|
| **A1** | — | — | — | — | — | — | — |
| **A2** | — | — | — | — | — | — | — |
| **A3** | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config | depends on bundled config |
| **B0** | — | ✓ via `make apply` / `make draft` task | — | ✓ | — | — | — |
| **B1** | — | — | ✓ | — | — | — | — |
| **B2** | — | partial (via shell) | — | partial | — | — | partial (`git diff` in shell) |
| **B3** | — | partial (via shell) | — | partial | — | — | partial (`git diff` in shell) |
| **C0** | ✓ | — | — | — | — | — | — |
| **C1** | — | ✓ via task wrappers + file tree | — | ✓ via task wrappers + file tree | ✓ | ✓ | — |
| **C2** | — | — | — | — | — | — | ✓ (confirmed working) |
| **C3** | — | — | — | — | — | — | — |
| **C4** | — | — | — | — | — | — | rejected |
| **D1** | — | — | — | — | — | — | — |
| **D2** | — | — | — | — | — | — | partial — viewing is C2; D2 is whether operator can also write |
| **D3** | — | — | partial — async channel into agent | — | — | partial | — |

**Reading the table.**

- The cheap cluster — A1 + B0 + B1 + C0 + C1 + D1 — covers use cases (1) through (5) without any harness change, purely via host-side multi-root workspace and terminal panes. This is achievable before any hands-on experimentation.
- Use case (6) — live agent edits — is covered by C2 (confirmed working) or partially by B2/B3 terminal commands (`watch git diff`, `git log --oneline`) as a lightweight fallback without container attach.
- The two-window design is the confirmed and accepted configuration. It is an improvement over the current state (multiple separate apps) and not a limitation to resolve further.
- A2 is closed for pi; A3 is closed by the framing axiom unless explicitly justified.

---

## Open Questions

### Resolved during research

**Q-V-1:** Does VSCode support attaching to an already-running Docker container without a `devcontainer.json` in the project?
→ **Resolved.** Yes. "Attach to Running Container" is a first-class path via Command Palette or Remote Explorer. No `devcontainer.json` required; per-container config is stored in a user-level settings file keyed by image or container name. (Source: documentation)

**Q-V-2:** Does VSCode support true multi-root workspaces with multiple independent host folders in one window?
→ **Resolved.** Yes. `.code-workspace` files support a `folders` array with arbitrary paths. Each folder is an independent root with its own file tree and task definitions. (Source: documentation)

**Q-V-3:** Does attaching to a container deliver full editor features (file tree, diff, extensions) or only terminal chrome?
→ **Resolved.** Full editor features. VS Code Server is installed into the container on first attach, and the connected window has the same capabilities as a local window. This is what distinguishes VSCode's attach from Warp's Warpify: the file tree, diff viewer, and extensions are all inside the container. (Source: documentation)

**Q-V-4:** Can a single VSCode window have both host folders and a container workspace?
→ **Resolved.** No — confirmed hard constraint. A VSCode window connects to exactly one context; host file explorer and container file explorer cannot coexist in the same window. However, `Terminal: New Local Terminal` from a container-attached window opens a host shell tab in the same integrated terminal panel, so host commands (`make`, `git`, `docker`) are available from within the container window without switching. The full-coverage configuration is two windows: host window (multi-root `.code-workspace` for `PROJECT_DIR` + `SANDBOX_DIR`) and container window (Dev Containers attach to `sandbox/`). Multiple `.code-workspace` files cannot be open in one window simultaneously — unresolved feature request open since 2018 (GitHub issue #43188). Two windows is the accepted design, not a workaround. (Source: documentation + GitHub issue)

**Q-V-5:** Does VSCode Dev Containers work on Windows+WSL2 without Docker Desktop?
→ **Resolved.** Docker Desktop is the supported path, but a working workaround exists for Docker Engine in WSL2 only: launch VSCode from inside the WSL2 terminal (`code .`), which connects via Remote - WSL. From that WSL-connected window the Dev Containers extension sees the Docker socket and the attach path works normally. Project files must be in the WSL filesystem. (Source: community confirmation — GitHub devcontainers/discussions#99)

**Q-V-6:** Does VS Code Server install successfully into the capability layer container image (`sandbox-<project>`)?
→ **Resolved by operator.** Installs cleanly into both capability layer and reasoning layer containers. Ubuntu base satisfies the glibc ≥ 2.28 requirement. No Dockerfile modification required for basic attach.

**Q-V-10:** On Windows+WSL2 without Docker Desktop, does the Dev Containers attach path work?
→ **Resolved.** Yes, via the Remote - WSL workaround described in Q-V-5. The operator's current setup (Docker Engine in WSL2, no Docker Desktop) is covered. No blocker. (Source: same as Q-V-5)

### Resolved by hand-rolling

*Empty — no sessions run yet.*

### Closed by workaround / shelved

*Empty.*

### Active

**Q-V-7:** Does `docker attach` to the reasoning layer agent container behave correctly inside VSCode's integrated terminal?
The reasoning layer runs pi-coding-agent, which may have a TUI. Whether the VSCode integrated terminal correctly handles the TTY modes required by the agent's interface is unknown. Maps to B1 coverage cell.

**Q-V-8:** Which container is the better C2 attach target — capability layer or reasoning layer?
The capability layer owns `sandbox/`; attaching there is architecturally cleaner (VS Code Server dependencies live in a provider-agnostic container). The reasoning layer has the agent process; attaching there may give a richer view but installs VS Code Server into a provider-specific image that changes per provider. Both confirmed to accept VS Code Server. Decision deferred to hands-on.

**Q-V-9:** Does the `${workspaceFolder:<name>}` variable syntax in `tasks.json` correctly resolve to the named root folder in a multi-root workspace for `cwd`?
Documentation confirms the multi-root variable syntax exists; exact behaviour for `cwd` resolution in tasks has not been confirmed hands-on. Maps to Shape V2.

**Q-V-11:** Can VS Code Server be pre-installed into the harness container Dockerfile to eliminate the first-attach installation delay?
The server binary lives at `~/.vscode-server/` inside the container. Pre-populating this at image build time would make first attach instant. The complication is version coupling: the pre-installed server version must match the connecting VSCode client version, so the image needs rebuilding when VSCode updates. Whether this is worth the maintenance cost relative to the one-time delay is an open tradeoff. Maps to the pre-install primitive row.

**Q-V-12:** Does the `code --folder-uri "vscode-remote://attached-container+<hex>/<folder>"` command work with harness container names?
Community-documented but not in official VSCode docs. Needs hands-on confirmation that the hex-encoded container name resolves correctly to `sandbox-<project>` and that the command fires without error from a WSL terminal or local shell. Maps to the session-open flow.

### Still open

*None currently.*

---

## Experiments to Run

### Session 1 — host-only baseline + session-open script

**Goal.** Confirm the cheap cluster (A1 + B0 + B1 + C0 + C1) works end-to-end with no harness change. Validate Shape V1 (multi-root workspace) and Shape V2 (task wrappers). Resolve Q-V-7 (agent TTY), Q-V-9 (task `cwd` variable), and Q-V-12 (`code --folder-uri` scriptable attach).

**Why this is the right next experiment.** The host-only path has no uncertain prerequisites. If it works, pain points (1)–(5) are covered immediately. The `code --folder-uri` test can piggyback on this session since it only requires running containers.

**Phased structure.**

1. Open `agent-sandbox.code-workspace` with `PROJECT_DIR` and `SANDBOX_DIR` as roots. Confirm both appear as independent file trees.
2. Add `tasks.json` with `make start`, `make apply`, `make draft`, `make stop` tasks. Run `make start` from Command Palette. Confirm it runs in a terminal pane in `SANDBOX_DIR`.
3. Open a second terminal pane. Run `docker attach <provider>-agent-<project>`. Confirm agent TUI renders correctly and accepts input.
4. Run `make apply` from the task while the agent terminal is running. Confirm both terminal panes coexist without interference.
5. With containers running, test `code --folder-uri "vscode-remote://attached-container+<hex>/home/agentuser/sandbox"`. Confirm a new window opens attached to the container.

**Pass criterion.** Phases 1–4 complete without issue. Agent TTY is usable in the integrated terminal. Task `cwd` resolves correctly. Phase 5: container window opens from script without requiring a host window as prerequisite.

### Session 2 — container attach detail (C2)

**Goal.** Resolve Q-V-8 (which container to target), confirm C2 coverage of use case (6) in the two-window configuration, and establish the full session-open workflow end-to-end.

**Why this is the right next experiment.** VS Code Server installation is confirmed. The remaining question is which container produces the better operator experience and whether the two-window setup is ergonomically workable in practice.

**Phased structure.**

1. Attach to `sandbox-<project>` (capability layer). Open file tree on `sandbox/`, confirm git diff accessible, run agent for a short task, observe live changes.
2. Try `Terminal: New Local Terminal` from the container window. Confirm a host shell opens in the same panel. Run `make draft` from it. Confirm it works.
3. Run `make stop`. Observe disconnect behaviour. Re-run `make start` + `code --folder-uri` script. Confirm reattach is a single step.
4. Optional: repeat attach targeting `<provider>-agent-<project>` (reasoning layer). Compare the two targets for operator experience.

**Pass criterion.** Live file changes visible in container file tree. Local terminal tab functional in container window. Reattach after session restart is one command. Q-V-8 resolved with a documented decision.

### Deferred follow-ups

- **VS Code Server pre-install (Q-V-11).** Baking the server binary into the Dockerfile for faster first-attach. Deferred until the attach workflow is stable and the version-coupling tradeoff is understood.
- **Windows+WSL2 parity.** Sessions above assume macOS or Linux host. Windows+WSL2 (`code .` from WSL terminal) should be confirmed in a follow-up session on a Windows machine.
- **Reasoning layer attach (Q-V-8 Option B).** If Session 2 settles on the capability layer, reasoning layer attach can be deferred. Revisit if a future provider benefits from it.

### Out of scope for this story

- GitHub Copilot / Copilot Chat as agent integration surface.
- Pi-coding-agent VSCode extension (abandoned).
- ACP or MCP client surface in VSCode.
- VS Code Server security analysis (VS Code Server runs inside the container; it does not open a network port to the host — communication is via Docker's IPC channel, not a bound port. This is within the existing container isolation model and does not require security rescoping).

### Output protocol

Findings get appended to **Investigation Findings** as a new "Hand-rolled session N — `<date>`" subsection. Resolved questions move to Resolved sub-lists; remaining questions stay open. New questions surfaced by a session are added to a "New questions surfaced by Session N" sub-list. When all questions are resolved, deferred, or shelved, the story is ready for Resolution.

---

## Investigation Findings

*Empty — no sessions run yet.*

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
| [`threat_model_stride.md`](../architecture/threat_model_stride.md) | Threat model |
| [`story_policy.md`](../operations/story_policy.md) | Story format, lifecycle, and graduation |
| [`story_zed_integration.md`](story_zed_integration.md) | Parallel evaluation of Zed for the same use cases |
| [VSCode Dev Containers docs](https://code.visualstudio.com/docs/devcontainers/containers) | Official documentation — primary source |
| [VSCode Attach to Running Container](https://code.visualstudio.com/docs/devcontainers/attach-container) | Attach path documentation |
| [VSCode Multi-root Workspaces](https://code.visualstudio.com/docs/editing/workspaces/multi-root-workspaces) | Multi-root workspace documentation |
| [VSCode Remote FAQ](https://code.visualstudio.com/docs/remote/faq) | glibc requirements, VS Code Server installation, window constraints |
| [VSCode Tasks](https://code.visualstudio.com/docs/debugtest/tasks) | `tasks.json` reference |
