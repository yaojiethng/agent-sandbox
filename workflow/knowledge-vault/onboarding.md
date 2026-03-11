# Knowledge Vault Onboarding

This document covers onboarding an Obsidian vault into git with LFS, setting up checkpoints, and integrating with agent-sandbox. Written for operators and agents.

---

## Obsidian Sync — Read First

Git operations run on the designated desktop machine only. Mobile devices are Sync targets only.

Before running any commands: in Obsidian, go to **Settings → Sync → Excluded files** and add `.git`. This prevents Sync from uploading the git object store to mobile devices.

During migrations: pause Sync before applying a diff, resume after committing.

---

## Setup

### 1. Copy tooling into vault

Copy `workflow/knowledge-vault/` from agent-sandbox into `.vault/` at the vault root:

```bash
cp -r workflow/knowledge-vault/ /path/to/vault/.vault/
```

The `.vault/` directory is vault tooling, not vault content. Add it to `.gitignore` if you do not want it tracked, or commit it if you want the tooling versioned with the vault.

### 2. Validate LFS behavior (recommended before first init)

Runs against a scratch copy — original vault is never modified. Confirms extension classification and diff pipeline are correct for this vault's file types.

```bash
bash .vault/tests/vault-lfs-test.sh --vault=/path/to/vault
```

If any extension is misclassified, correct it in `.vault/lib/classify.sh` (`KNOWN_BINARY_EXTENSIONS` or `KNOWN_TEXT_EXTENSIONS`) before proceeding.

### 3. Initialize the vault

```bash
bash .vault/scripts/vault-init.sh --vault=/path/to/vault
```

First run: classifies extensions, writes `.gitattributes`, runs `git init` and `git lfs install`, writes `.gitignore`, handles backup files (see [Backup Files](#backup-files)), creates baseline commit `init: <vault-name> YYYY-MM-DD`.

Subsequent runs: regenerates `.gitattributes` only and stages it for review. `.gitignore` is never modified after first run.

### 4. Create initial checkpoint

```bash
bash .vault/scripts/checkpoint-create.sh --vault=/path/to/vault
```

Creates `checkpoint/YYYY-MM-DD` branch and updates `checkpoint/latest` tag. Run this before any migration.

### 5. Integrate with agent-sandbox

Create `Makefile` and `agent_context_brief.md` at the vault root per `docs/operations/sandbox-onboarding.md`. The brief should describe vault structure, naming conventions, and current task scope.

---

## Checkpoint Reference

**Create**
```bash
bash .vault/scripts/checkpoint-create.sh --vault=<path> [--label=<suffix>]
```
Requires clean working tree. Fetches LFS objects locally before branching.

**Roll back**
```bash
bash .vault/scripts/checkpoint-rollback.sh --vault=<path> [--checkpoint=<ref>]
```
Defaults to `checkpoint/latest`. Creates a rollback commit — does not rewrite history.

**Prune**
```bash
bash .vault/scripts/checkpoint-prune.sh --vault=<path> --keep=<n>
```
Keeps N most recent checkpoint branches. Prompts before deleting. Never touches `checkpoint/latest`.

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

`vault-init.sh` manages `.obsidian/app.json` and `.obsidian/appearance.json`:

| Condition | Behavior |
|---|---|
| Live exists, backup missing | Creates backup from live — operator stages and commits |
| Live missing, backup exists | Seeds live from backup — included in init commit |
| Both exist | Skips |
| Neither exists | Skips |

Backup files (`*.backup.json`) are committed to git. Live files are gitignored — they diverge per device and are seeded from backups on new machines.

---

## .gitattributes — Implementation Notes

- Regenerated on every `vault-init.sh` run. Staged automatically; review and commit as part of normal workflow.
- Unknown extensions are probed with `git diff --numstat /dev/null <file>`. Binary result → LFS; text result → tracked normally.
- LFS pointer files are text internally. `--binary` in the diff pipeline produces pointer text, not raw binary blobs — this is correct behavior.
- Both lowercase and uppercase variants of each extension are emitted (e.g. `*.jpg` and `*.JPG`).
- Known text extensions receive an explicit `-filter` override. This takes precedence over any `filter=lfs` rule and prevents false LFS classification of executable scripts or files with unusual byte sequences.

---

## Optional Configuration

**Track plugin versions**

By default `.obsidian/plugins/` is gitignored. Plugin binaries are re-downloaded automatically by Obsidian. To lock a known-good plugin state before a migration, remove the `.obsidian/plugins/` line from `.gitignore` and commit. Revert after the migration if version locking is no longer needed.
