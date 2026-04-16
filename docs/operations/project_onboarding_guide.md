# Project Onboarding Guide

How to onboard a new project into agent-sandbox. Onboarding creates `SANDBOX_DIR` and populates it with the files the harness needs to run against the project.

For Obsidian vault projects, follow `workflow/knowledge-vault/onboarding.md` instead.

---

## Prerequisites

- `agent-sandbox` CLI installed on the host (`make install` in the agent-sandbox repo)
- `PROJECT_DIR` is a git repository with at least one commit
- All paths are WSL/Linux format (`/mnt/c/...` or `/home/...`). Convert Windows paths with `wslpath 'C:\your\path'`

---

## Step 1 — Create `SANDBOX_DIR`

Create the sandbox directory alongside the project. By convention it is named `<project-dir-name>-sandbox` and lives as a sibling of `PROJECT_DIR`, but any absolute path is valid.

```sh
mkdir /path/to/<project>-sandbox
```

After onboarding, the layout will be:

```
WORKDIR/
├── <project-dir>/              ← PROJECT_DIR (git repo, untouched by harness)
└── <project-dir>-sandbox/      ← SANDBOX_DIR (harness workspace)
    ├── Makefile
    ├── .env                    ← machine-specific vars; never committed
    ├── AGENTS.md               ← agent context brief; operator-written
    └── .workspace/             ← created at run time by harness
```

---

## Step 2 — Run onboard

```sh
agent-sandbox onboard --name=<project> --project=<PROJECT_DIR> --sandbox=<SANDBOX_DIR>
```

This produces:

| File | Source | Operator action required |
|---|---|---|
| `Makefile` | Copied from `libs/_templates/Makefile.template` | None — paths set automatically |
| `.env` | Written by harness; path variables derived from `--project` and `--sandbox` | Fill in `SERVE_PORT` and any provider-specific variables (see `.env` comments) |
| `AGENTS.md` | Stub written by harness | Fill in — see Step 3 |

Provider-specific `.env` stubs are appended automatically from each `providers/<n>/.env.example` present in the repo at onboard time.

---

## Step 3 — Write `AGENTS.md`

`AGENTS.md` is the agent context brief. The harness places it in the reasoning layer image at build time — the agent reads it at the start of every session. It must be complete enough for a fresh agent to orient itself and begin work without further instruction.

```markdown
# Agent Context Brief — <project-name>

## Project
<one paragraph: what the project is, what it does, its current state>

## Constraints
<project-specific constraints: coding standards, conventions, files not to touch>

## Output
<what good output looks like: expected file changes, patterns to follow>
```

---

## Step 4 — Review `.env`

Open `SANDBOX_DIR/.env` and set:

- `SERVE_PORT` — host port for serve mode
- Any provider-specific variables flagged in the file comments (e.g. `OPENCODE_SERVER_PASSWORD`)

Machine-specific variables are never committed. Confirm `.env` is covered by `.gitignore` in `PROJECT_DIR`.

---

## Step 5 — Build images and verify

Build all images:

```sh
make build
```

Verify the harness infrastructure is functional:

```sh
make dry-run PROVIDER=<n>
```

See [Dry-Run Guarantees](../architecture/tool_interface.md#dry-run-guarantees) for what a passing dry-run proves.

---

## Verification checklist

- [ ] `SANDBOX_DIR` is not inside `PROJECT_DIR` — they must be siblings, not nested
- [ ] `PROJECT_DIR` is a git repository with at least one commit
- [ ] `AGENTS.md` contains enough context for a fresh agent to begin work
- [ ] `.env` has `SERVE_PORT` and all provider-specific variables filled in
- [ ] `.env` is gitignored in `PROJECT_DIR`
- [ ] `make dry-run PROVIDER=<n>` passes

---

## References

| Document | Purpose |
|---|---|
| [`../architecture/tool_interface.md`](../architecture/tool_interface.md) | Command shapes, mount guarantees, `.env` variable reference |
| [`provider_onboarding_guide.md`](provider_onboarding_guide.md) | Adding a new reasoning layer provider |
| [`../concepts/agent_workflow.md`](../concepts/agent_workflow.md) | Operator workflow — before, during, and after a run |
