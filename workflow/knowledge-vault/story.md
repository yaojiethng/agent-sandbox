# User Story — Obsidian Vault Onboarding

> **SUPERSEDED.** This story is closed. KV1–KV4 are complete — see [`kv-changelog.md`](kv-changelog.md) for the completion record. KV5 (agent modification workflow) has been promoted to **M2.1** in the main agent-sandbox roadmap under the two-layer architecture. See [`docs/development/roadmap.md`](../../docs/development/roadmap.md) — M2.1, and [`docs/concepts/two_layer_model.md`](../../docs/concepts/two_layer_model.md) for the architectural context. For the current vault workflow entry point, see [`workflow/knowledge-vault/README.md`](README.md).

**Status:** Superseded — see above.

---

## Context

An Obsidian vault with no existing git repository. Goal is to onboard the vault into agent-sandbox to enable agent-assisted vault migrations and, eventually, ongoing agent-based vault management. Obsidian Sync is active on the vault.

---

## Pain Points

- Vault has no git repo — agent-sandbox requires at least one git commit to function
- Unclear how Obsidian Sync and git coexist without breaking sync state
- Writeback model for a vault is different from a code project — operator wants to review a diff before writing back into the vault, not apply a patch to a git branch
- Concurrency risk: Obsidian Sync may write files during the apply step

---

## Proposed Workflow

The standard agent-sandbox diff model works well for this use case with minimal changes:

1. Operator sets up git in the vault (see below)
2. Agent runs, works in sandbox, produces `staged.diff` on exit
3. Operator reviews diff
4. Operator pauses Obsidian Sync
5. Operator applies diff to vault
6. Operator resumes Obsidian Sync — picks up applied changes on next sync cycle

This keeps the review gate intact and treats Obsidian Sync as an external system that the operator coordinates manually. No harness code changes required for the basic workflow.

---

## Open Questions & Current Thinking

### Git setup for a vault with no repo

Prerequisite steps before onboarding:

```sh
cd /path/to/vault
git init
# Create .gitignore before first commit
git add .gitignore
git add -A
git commit -m "init"
```

`.gitignore` should cover machine-specific and sync-state Obsidian files:

```
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.obsidian/plugins/*/data.json   # plugin runtime state; review per plugin
.trash/
```

What to track vs. gitignore requires a judgment call per vault:
- `.obsidian/app.json`, `.obsidian/appearance.json`, `.obsidian/community-plugins.json` — generally safe to track; these are settings, not runtime state
- Plugin data files — varies; some are config, some are runtime state. Needs per-vault review.

This setup procedure should be documented as a vault onboarding guide, either as a section in `sandbox-onboarding.md` or as a standalone `vault-onboarding.md` in `docs/development/`.

### Obsidian Sync coexistence

Obsidian Sync and git can coexist if `.obsidian/` sync state files are gitignored. The risk is not during the agent run (agent works in sandbox, not the live vault) but during the apply step — if Obsidian Sync writes a file between `git apply` and Obsidian picking up the changes, there may be a conflict.

**Mitigation:** pause Obsidian Sync before applying the diff, resume after. This is an operational protocol, not a code change. Low friction — Obsidian Sync can be paused from the app settings.

### Concurrency

Not a complex concurrency problem — the vault is single-user, and the only concurrency risk is the Obsidian Sync process running in the background during apply. The pause-apply-resume protocol above resolves it. No locking or coordination mechanism needed in the harness.

### Writeback model

The operator stated preference: review diff, then write back into the vault. The current `staged.diff` output is sufficient for this — it shows exactly what the agent changed, and `git apply` writes those changes cleanly. The operator does not need branch management for this use case; applying directly to the working tree is appropriate.

If the M1.5 apply workflow redesign (format-patch + checkpoint branch) lands before this is implemented, evaluate whether it adds value for vault use or introduces unnecessary complexity. For a vault, the simpler `patch.diff` model may be preferable to a commit-replay approach.

### Potential code changes

The standard workflow likely works as-is. One possible gap: if the vault contains binary files (images, attachments), `git apply` behavior on binaries needs to be verified. The current harness uses `git apply --3way` which handles text files cleanly; binary handling depends on whether binary diffs are included in `staged.diff`.

---

## Constraints

- Obsidian Sync must not be disrupted by the git setup or the agent run
- Writeback must go through the diff review step — no direct agent writes to the live vault
- Vault may contain binary attachments; binary diff handling needs verification

---

## Outcomes

All investigation tasks resolved. Outputs in `workflow/knowledge-vault/`:

- `onboarding.md` — operator and agent-facing onboarding guide
- `libs/classify.sh`, `libs/gitattributes.sh` — shared classification and generation logic
- `scripts/vault-init.sh` — idempotent vault git + LFS init
- `scripts/checkpoint-create.sh`, `checkpoint-rollback.sh`, `checkpoint-prune.sh`
- `tests/vault-lfs-test.sh` — 30/30 passing against real vault content
- `libs/diff.sh` patch — `--binary -M` flags added to `diff_generate`

Decisions and implementation notes recorded in `story_obsidian_vault_roadmap.md`.

To promote to a named milestone: pull future use cases from the roadmap into tasks when a specific migration is ready to implement.
