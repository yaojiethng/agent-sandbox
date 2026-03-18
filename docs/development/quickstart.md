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

Run the onboard command from anywhere, passing the project name, project path, and the path where the sandbox directory should be created:

```sh
agent-sandbox onboard \
  --name=<project-name> \
  --project=/absolute/path/to/<project-dir> \
  --sandbox=/absolute/path/to/<project-dir>-sandbox
```

By convention the sandbox directory is named `<project-dir>-sandbox` and sits alongside the project repository. The command creates the sandbox directory if it does not exist, copies all template files, creates the `.workspace/` subdirectories, and writes `.env` with derived path variables.

After onboarding, the sandbox directory contains:

```
<project-dir>-sandbox/
├── Makefile              ← delegates to agent-sandbox CLI; reads PROJECT_DIR/SANDBOX_DIR from .env
├── .env                  ← written by onboard; machine-specific variables
├── Dockerfile.sandbox    ← capability layer Dockerfile; customise as needed
└── .workspace/
    ├── input/            ← place task briefs here before a run
    ├── output/           ← agent writes progress and data here
    └── changes/          ← staged.diff and autosave.diff written here
```

### Complete the setup

**1. Edit `.env`**

`onboard` writes `SERVE_PORT` and `OPENCODE_SERVER_PASSWORD` as stubs. Set them before the first run:

```sh
SERVE_PORT=46553
OPENCODE_SERVER_PASSWORD=<your-password>
```

All path variables (`PROJECT_DIR`, `SANDBOX_DIR`, `SNAPSHOT_DIR`, etc.) are derived and written automatically — do not edit them.

**2. Create `agents.md` in the project repo**

`onboard` writes a stub at `SANDBOX_DIR/agents.md`. Move or copy it into `PROJECT_DIR` and fill it in — it is passed to the agent at the start of every session:

```markdown
# agents.md — <project-name>

## Project
<what the project is, what it does, its current state>

## Constraints
<coding standards, conventions, files not to touch>

## Output
<what a correct output looks like>
```

**3. Ensure `.gitignore` covers secrets**

In the project repo, confirm `.env` is gitignored. If the sandbox directory sits inside the project tree, also add:

```
.workspace/
.snapshot/
```

**4. Ensure the project is a git repository**

The project must have at least one commit before agent-sandbox can run against it:

```sh
git init
git add -A
git commit -m "initial"
```

---

## 3. Build the images

From the sandbox directory:

```sh
# Build both capability and reasoning layer images
make build all

# Build only the capability layer (sandbox) image
make build sandbox

# Build only the reasoning layer (agent) image
make build agent
```

`make start`, `make serve`, and `make dry-run` call `docker build` automatically before starting containers. Docker's cache produces a hit in under 5 seconds when source files are unchanged. Explicit builds via `make build` are only needed before the first run, or after editing `Dockerfile.sandbox`.

---

## 4. Prepare inputs (optional)

Before a run, place task files, briefs, or additional context in the operator input channel:

```sh
cp my-task.md <sandbox-dir>/.workspace/input/
```

The agent reads these as read-only files alongside any brief. Clear or replace them between runs as needed.

---

## 5. Run the agent

All commands are run from the sandbox directory.

**Interactive mode** — agent runs in the terminal:

```sh
make start
```

**Serve mode** — agent runs as a web server, accessible in the browser:

```sh
make serve
```

**Liveness check** — confirms both containers start and the sandbox is healthy:

```sh
make dry-run
```

To force a rebuild before starting:

```sh
make rebuild start
make rebuild serve
```

---

## 6. Apply changes

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

## Recovery

If a bad diff has been applied and the project repo is in a broken state:

**1. Reset the branch**

```sh
# Discard all uncommitted changes
git -C <PROJECT_DIR> checkout -- .

# Or reset to a specific known-good commit
git -C <PROJECT_DIR> reset --hard <commit-sha>
```

**2. Clear the workspace**

```sh
rm -rf <SANDBOX_DIR>/.workspace/changes/
mkdir -p <SANDBOX_DIR>/.workspace/changes/
```

This discards any staged or autosave diffs from the bad run.

**3. Clear the snapshot**

```sh
rm -rf <SANDBOX_DIR>/.snapshot/
```

The snapshot is rebuilt fresh on the next `make start` or `make dry-run`.

**4. Verify**

```sh
make dry-run
```

A passing dry-run confirms the snapshot pipeline is clean and both containers start correctly.

---

**If tracked files are missing from disk** (causing `cp: cannot stat` errors during snapshot):

```sh
git rm --cached <file>
git commit -m "remove missing file from index"
```

---

## Pre-run checklist

Before running the agent for the first time:

- [ ] `agent-sandbox` CLI is installed (`which agent-sandbox`)
- [ ] `agent-sandbox onboard` has been run; sandbox directory exists alongside the project repo
- [ ] `agents.md` is present in the project repo and filled in
- [ ] `.env` is present in sandbox directory; `SERVE_PORT` and `OPENCODE_SERVER_PASSWORD` are set
- [ ] `.env` is gitignored in the project repo
- [ ] Project is a git repository with at least one commit
- [ ] Docker is running (`docker info`)
- [ ] Images are built (`make build all`)
