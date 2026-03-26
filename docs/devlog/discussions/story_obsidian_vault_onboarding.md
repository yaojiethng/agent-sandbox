# User Story — Obsidian Vault Onboarding

**Status:** Superseded — made obsolete by the two-layer architecture decision. See Resolution section.

> **Superseded.** The single-container model described in this story's open questions is no longer the target architecture. The agent modification workflow (KV5) now proceeds under the two-layer model (reasoning layer / capability layer) as **M2.1** in the main roadmap. See [`docs/concepts/two_layer_model.md`](../concepts/two_layer_model.md) and [`docs/development/roadmap.md`](../development/roadmap.md) — M2.1. For the current vault workflow entry point, see [`workflow/knowledge-vault/README.md`](../../workflow/knowledge-vault/README.md).

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

## Outcomes (KV1–KV4)

All investigation tasks resolved. Outputs in `workflow/knowledge-vault/`:

- `onboarding.md` — operator and agent-facing onboarding guide
- `libs/classify.sh`, `libs/gitattributes.sh` — shared classification and generation logic
- `scripts/vault-init.sh` — idempotent vault git + LFS init
- `scripts/checkpoint-create.sh`, `checkpoint-rollback.sh`, `checkpoint-prune.sh`
- `tests/vault-lfs-test.sh` — 30/30 passing against real vault content
- `libs/diff.sh` — `--binary -M` flags added to `diff_generate` (correctness fix; identified as required in KV1)

Full completion record in [`workflow/knowledge-vault/changelog.md`](../../workflow/knowledge-vault/changelog.md).

---

## Resolution

**Status at closure:** Superseded by the two-layer architecture decision.

### What was decided

The investigation through KV1–KV4 validated that the standard agent-sandbox diff model works for vault use with correctness patches (`--binary -M`, `snapshot_copy_files` space/symlink handling). The core workflow — operator checkpoints before a session, agent modifies vault content in sandbox, operator reviews diff, applies, resumes Sync — is sound and continues to operate.

KV5 (agent modification workflow at scale) was blocked on the OpenCode file navigation problem. The investigation initially framed this as a provider selection question. The broader MCP server investigation revealed it is an architectural question: the right fix is to give any agent a better tool interface via a capability layer, not to find a better agent.

The two-layer architecture (reasoning layer / capability layer) was adopted as the target architecture. Under this model:
- Vault access is mediated by a Dockerized MCP server with vault-specific tools
- The agent calls tools rather than reading files directly
- Any MCP-compatible reasoning layer works — provider selection is decoupled from the vault tool interface
- The OpenCode file navigation problem is dissolved architecturally

### Where the work went

| Thread | Destination |
|---|---|
| KV5 — agent modification workflow | Promoted to **M2.1** in the main roadmap (capability layer prototype: vault) |
| Provider selection question | Reframed as reasoning layer candidate evaluation; continues as M2 prerequisite work in `investigation_claude_code.md` and peer investigation docs |
| Operator input channel | Implemented in M1.5 directory restructuring as `SANDBOX_DIR/input/` |
| Checkpoint branch pattern | Validated through KV4; formalisation deferred to M2.4 (apply workflow redesign) |
| Vault-specific future use cases (attachment migration, OCR, etc.) | Retained as pending use cases in this story; not yet scoped into milestones |

### Pending use cases (not yet milestones)

The following vault workflows were identified during the investigation but are not yet scoped for implementation. They require M2.1 (capability layer) to be complete before they can be designed:

- **Attachment format migration** — agent produces conversion script + link-update patch (e.g. webp via `cwebp`/`ffmpeg`)
- **Remove unreferenced attachments** — agent builds link graph, produces reviewed deletion script
- **OCR screenshots to text notes** — requires `tesseract` in capability layer container; output is a standard patch
- **PDF / epub handling** — extract, summarise, convert to note format

When any of these is ready to implement, pull the relevant tasks into a milestone from here.
