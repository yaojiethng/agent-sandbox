# Knowledge Vault Workflow

Entry point for the Obsidian vault workflow in agent-sandbox. Read this first.

## What this workflow does

Enables agent-assisted management of an Obsidian vault: migrations, content operations, attachment handling, and ongoing maintenance -- all via the agent-sandbox diff-and-review model. The operator always reviews agent-proposed changes before they reach the live vault.

**KV1-KV4 are complete.** The vault can be onboarded into agent-sandbox, initialised with git + LFS, checkpointed, and used for read-only or minimal agent sessions today. See [`changelog.md`](changelog.md) for the completion record and milestone summary.

## Document map

### To onboard a vault now

| Document | Purpose |
|---|---|
| [`onboarding.md`](onboarding.md) | Step-by-step: Sync setup, git init, LFS, checkpoint, `make start` |

This is the primary operator reference. Start here.

### Architecture and context

| Document | Purpose |
|---|---|
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | Main harness roadmap -- M2.1 is the next milestone affecting this workflow |
| [`docs/reference/two_layer_model.md`](../../docs/reference/two_layer_model.md) | Why M2.1 looks the way it does -- reasoning vs capability layer separation |
| [`docs/development/20260312-study-settled-mcp_server.md`](../../devlog/discussions/archive/20260312-study-settled-mcp_server.md) | MCP server investigation: architecture, candidates, two-workspace model |

### Historical record (completed work)

| Document | Purpose |
|---|---|
| [`changelog.md`](changelog.md) | KV1-KV4 completion record and milestone summary |
| [`docs/discussions/archive/20260311-story-superseded-obsidian_vault_onboarding.md`](../../devlog/discussions/archive/20260311-story-superseded-obsidian_vault_onboarding.md) | Original investigation story -- reasoning record. Superseded; kept for reference. |

## Quick start (vault already onboarded)

If the vault has been onboarded and initialised (KV4 complete):

```bash
# Before each session
bash .vault/scripts/checkpoint-create.sh --root=<vault-path>

# Run agent
cd <sandbox-dir> && make start

# After session: review diff, then apply
agent-sandbox apply
```

If the vault has not been onboarded yet, start with [`onboarding.md`](onboarding.md).
