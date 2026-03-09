# Quickstart

This guide walks through setting up agent-sandbox on a new machine and onboarding
a project for the first time.

For OpenCode-specific commands, container inspection, and troubleshooting, see
[`providers/opencode/quickstart.md`](../../providers/opencode/quickstart.md).

---

## Prerequisites

- Linux (or WSL on Windows)
- Docker installed and running
- Git installed
- The agent-sandbox repository cloned locally

---

## 1. Install the CLI

From the agent-sandbox repository root:

```sh
make install
```

This installs the `agent-sandbox` command to `/usr/local/bin`. To install elsewhere:

```sh
make install PREFIX=~/.local/bin
```

Verify the installation:

```sh
which agent-sandbox
```

---

## 2. Onboard a project

For each project you want to run under agent-sandbox, you need three things in
the project repository:

### `Makefile`

Copy `Makefile.template` from the agent-sandbox repo into the project root and
set the three variables at the top:

```makefile
PROJECT_NAME := <project-name>
PROJECT_ROOT := $(CURDIR)
AGENT_BRIEF  := agent_context_brief.md
ENV_FILE     := .env
```

`PROJECT_ROOT` is always `$(CURDIR)` — do not change it.

### `agent_context_brief.md`

Create this file at the project root. It is passed to the agent at the start of
every session. It should describe the project, its conventions, and what good
output looks like. It does not need to describe how the sandbox works — the agent
already knows that.

```markdown
# Agent Context Brief — <project-name>

## Project
<what the project is, what it does, its current state>

## Constraints
<coding standards, conventions, files not to touch>

## Output
<what a correct output looks like>
```

### `.env`

Create this file at the project root. It holds machine-specific variables and
is never committed.

```sh
SERVE_PORT=46553
OPENCODE_SERVER_PASSWORD=<your-password>
```

### `.gitignore`

Ensure the following are gitignored in the project repo:

```
.env
.workspace/
.bootstrap/
```

### Git requirement

The project must be a git repository with at least one commit before agent-sandbox
can run against it:

```sh
git init
git add -A
git commit -m "initial"
```

---

## 3. Build the image

From the project root:

```sh
make build
```

This builds the Docker image for the project. Only needed once, or after updating
the agent-sandbox Dockerfile.

---

## 4. Run the agent

**Interactive mode** — agent runs in the terminal:

```sh
make start
```

**Serve mode** — agent runs as a web server, accessible in the browser:

```sh
make serve
```

**Liveness check** — confirms the container starts and the sandbox is healthy:

```sh
make dry-run
```

To force a rebuild before starting:

```sh
make start -- --rebuild
make serve -- --rebuild
```

---

## 5. Apply changes

After the agent completes its run, review and apply the diff:

```sh
# Apply to current branch
make apply

# Apply to a named branch (created if it does not exist)
make apply BRANCH=my-branch
```

Always review the diff before committing:

```sh
cat .workspace/changes/staged.diff
```

---

## Pre-flight checklist

Before running the agent for the first time:

- [ ] `agent-sandbox` CLI is installed (`which agent-sandbox`)
- [ ] `Makefile` is present at project root with correct `PROJECT_NAME`
- [ ] `agent_context_brief.md` is present at project root
- [ ] `.env` is present and gitignored
- [ ] `.workspace/` and `.bootstrap/` are gitignored
- [ ] Project is a git repository with at least one commit
- [ ] Docker is running (`docker info`)
- [ ] Image is built (`make build`)
