# Knowledge Vault Onboarding

This document covers preparing an Obsidian vault for use with agent-sandbox. There are two distinct phases: **onboarding** (file setup, run once via CLI) and **initialization** (git + LFS preparation, run via `make initialize`). Both must complete before using `make start`.

---

## Obsidian Sync — Read First

Git operations run on the designated desktop machine only. Mobile devices are Sync targets only.

Before running any commands: in Obsidian, go to **Settings → Sync → Excluded files** and add `.git`. This prevents Sync from uploading the git object store to mobile devices.

During migrations: pause Sync before applying a diff, resume after committing.

---

## Setup

### 1. Set git identity

Initialization creates a commit. If git identity is not configured, it will fail. Set it once globally if you haven't already:

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### 2. Onboard

Run once from any directory. Pass the vault root as `--vault`:

```bash
agent-sandbox onboard knowledge-vault --vault=/path/to/vault
```

This places three files at the vault root:
- `Makefile` — pre-filled with vault name and paths
- `agents.md` — agent brief starter template (fill this in before `make start`)
- `.vault` — symlink to the vault tooling in the agent-sandbox repo (machine-local, gitignored after initialization)

The command warns if Obsidian Sync appears active and exits without changes if onboarding has already run.

### 3. Fill in agents.md

Open `agents.md` at the vault root and fill in the vault description, constraints, and current task scope. `make start` will fail if this file is missing.

### 4. Initialize

```bash
cd /path/to/vault && make initialize
```

Initializes git + LFS, creates the baseline commit, and creates the first checkpoint. Re-run this if it fails — it rolls back any partial state on failure and is safe to retry.

If initialization fails and the cause is unclear, run the LFS test suite to diagnose file classification issues:

```bash
bash .vault/tests/vault-lfs-test.sh --vault=/path/to/vault
```

The vault is now `make start`-ready.

---

## Checkpoint Reference

Checkpoints are dated git branches used as rollback points. Create one before every agent session.

**Create**
```bash
bash .vault/scripts/checkpoint-create.sh --root=<path> [--label=<suffix>]
```
Requires a clean working tree.

**Roll back**
```bash
bash .vault/scripts/checkpoint-rollback.sh --root=<path> [--checkpoint=<ref>]
```
Defaults to `checkpoint/latest`. Creates a rollback commit — does not rewrite history.

**Prune**
```bash
bash .vault/scripts/checkpoint-prune.sh --root=<path> --keep=<n>
```
Keeps N most recent checkpoint branches. Prompts before deleting.

**List**
```bash
git -C /path/to/vault branch --list 'checkpoint/*'
```

---

## Migration Workflow

1. Ensure working tree is clean
2. `checkpoint-create.sh --label=pre-<name>`
3. Pause Obsidian Sync
4. `agent-sandbox apply`
5. Review result
6. Accepted: commit, resume Sync
7. Rejected: `checkpoint-rollback.sh`, resume Sync

Migration plans, agent briefs, and scripts go in `.vault/migrations/`.

---

## Backup Files

`make initialize` (via `vault-init.sh`) manages `.obsidian/app.json` and `.obsidian/appearance.json`:

| Condition | Behavior |
|---|---|
| Live exists, backup missing | Creates backup from live |
| Live missing, backup exists | Seeds live from backup — included in init commit |
| Both exist | Skips |
| Neither exists | Skips |

Backup files (`*.backup.json`) are committed to git. Live files are gitignored — they diverge per device and are seeded from backups on new machines.
