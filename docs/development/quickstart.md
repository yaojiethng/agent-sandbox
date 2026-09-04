# Quickstart

Getting agent-sandbox running on a new machine for the first time. Covers install, onboarding, and verifying the setup. For day-to-day commands and troubleshooting, see the provider quickstart for your provider (e.g. `providers/opencode/quickstart.md`).

---

## Prerequisites

- Linux or WSL on Windows
- Docker installed and running
- Git installed
- agent-sandbox repository cloned locally

---

## 1. Install the CLI

From the agent-sandbox repository root:

```sh
make install
```

Installs `agent-sandbox` to `/usr/local/bin`. To install elsewhere:

```sh
make install PREFIX=~/.local/bin
```

---

## 2. Onboard a project

```sh
agent-sandbox onboard \
  --name=<project-name> \
  --project=/path/to/<project-dir> \
  --sandbox=/path/to/<project-dir>-sandbox
```

By convention the sandbox directory is named `<project-dir>-sandbox` and sits alongside the project repository. All paths must be Linux/WSL format — convert Windows paths with `wslpath 'C:\your\path'`.

After onboarding, `SANDBOX_DIR` contains:

```
<project-dir>-sandbox/
├── Makefile
├── .env
└── .workspace/
    ├── input/
    ├── output/
    └── session-diffs/
```

See [`project_onboarding_guide.md`](project_onboarding_guide.md) for the full procedure.

---

## 3. Complete the setup

**Edit `.env`** — set `SERVE_PORT` and any provider-specific variables flagged in the file comments. Path variables are derived automatically; do not edit them.

**Confirm prerequisites in `PROJECT_DIR`:**
- `.env` is covered by `.gitignore`
- Project has at least one git commit

---

## 4. Build images

```sh
make build
```

Builds the capability layer image and all provider images. To build a single provider:

```sh
make build TARGET=<provider>
```

---

## 5. Verify

```sh
make dry-run PROVIDER=<provider>
```

A passing dry-run confirms both containers start, `sandbox/` initialises, and the diff pipeline produces output. See [Dry-Run Guarantees](../architecture/tool_interface.md#dry-run-guarantees).

---

## Pre-run checklist

- [ ] `agent-sandbox` CLI installed (`which agent-sandbox`)
- [ ] `agent-sandbox onboard` run; sandbox directory exists
- [ ] `.env` complete — `SERVE_PORT` and provider variables set
- [ ] `.env` gitignored in `PROJECT_DIR`
- [ ] `PROJECT_DIR` is a git repo with at least one commit
- [ ] Docker running (`docker info`)
- [ ] `make dry-run PROVIDER=<provider>` passes

---

## Session persistence

The sandbox directory persists across `make start` / `make stop` cycles via a named Docker volume. All git state, uncommitted changes, and session artifacts are preserved.

- **New session:** `make start` always starts a NEW session with a fresh volume. `make start INTERACTIVE=1` opens the config wizard: pick a provider + build policy, confirm, then start (provider and .env values otherwise come from the Makefile/`.env`).
- **Resume a session:** `make resume SESSION_ID=<id>` resumes that session's git state and volume. `make resume LIST=1` lists resumable sessions in an enriched table (`SESSION_ID | PROVIDER | STARTED | BRANCH | LAST_USED`, relative times, newest first, capped at 10 rows), flagging staleness as the `[SANDBOX_STALE]` warning label (worktree identity); `make resume INTERACTIVE=1` picks + confirms (same marker); `PROVIDER=<n>` filters either by provider.
- **Rebuild and fresh start:** `make start REFRESH=1` or `REBUILD=1` rebuilds images before starting a new session with a fresh volume.
- **Stop without destroying:** `make stop` preserves the volume and prints the resume command (`make resume SESSION_ID=<id>`).
- **Prune stale/orphaned sessions:** `make prune` removes stale `.compose` records and now-orphaned resources (containers/volumes whose session has no record). Always a complete pass; `STALE=sandbox`/`PROVIDER`/`AGE_DAYS` narrow the stale-record selection, `DRY_RUN=1` simulates, `INTERACTIVE=1` confirms.

The session identity (SESSION_ID, SESSION_TS) is recorded in the per-run compose registry (`.compose/<session-id>.yml`) and reused across resumes. This ensures container labels, error logs, and export paths remain consistent.

---

## Recovery

If a session produces a bad diff that corrupts your repository after apply, recover using the checkpoint tag:

```bash
# Find the latest checkpoint tag
LATEST=$(git tag --list "agent-checkpoint/*" | sort | tail -n 1)

# Reset to pre-session state
git reset --hard "$LATEST"
```

Checkpoint tags are created automatically before each session and stored as `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS`. The worktree ID is a short hash of your project path, ensuring tags are namespaced per-worktree. The 5 most recent tags per worktree are kept; older tags are pruned.

To see all available checkpoint tags for your worktree:

```bash
git tag --list 'agent-checkpoint/*'
```

To recover to a specific checkpoint:

```bash
git reset --hard agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS
```

---

## References

| Document | Purpose |
|---|---|
| [`project_onboarding_guide.md`](project_onboarding_guide.md) | Full onboarding procedure |
| [`provider_onboarding_guide.md`](provider_onboarding_guide.md) | Adding a new provider |
| [`../architecture/tool_interface.md`](../architecture/tool_interface.md) | Command shapes, `.env` variables, mount guarantees |
