# Knowledge Vault Workflow

Entry point for the Obsidian vault workflow in agent-sandbox. Read this first.

---

> **Hot task — M2.1 in progress.**
> The KV workflow is affected by an active architecture change. The two-layer model (reasoning layer / capability layer) changes how agent access to the vault works — vault files will be accessed via MCP tools rather than a direct sandbox copy. The operator workflow (checkpoint, run, review, apply) is unchanged, but the harness internals change significantly.
>
> - [`docs/development/roadmap.md`](../../docs/development/roadmap.md) — M2.1 for the full task list
> - [`docs/concepts/two_layer_model.md`](../../docs/concepts/two_layer_model.md) for the architectural rationale
>
> Until M2.1 is complete, the current workflow (KV1–KV4) operates as documented in [`onboarding.md`](onboarding.md).

---

## What this workflow does

Enables agent-assisted management of an Obsidian vault: migrations, content operations, attachment handling, and ongoing maintenance — all via the agent-sandbox diff-and-review model. The operator always reviews agent-proposed changes before they reach the live vault.

**KV1–KV4 are complete.** The vault can be onboarded into agent-sandbox, initialised with git + LFS, checkpointed, and used for read-only or minimal agent sessions today. See [`changelog.md`](changelog.md) for the completion record and milestone summary.

---

## Document map

### To onboard a vault now

| Document | Purpose |
|---|---|
| [`onboarding.md`](onboarding.md) | Step-by-step: Sync setup, git init, LFS, checkpoint, `make start` |

This is the primary operator reference. Start here.

### Architecture and context

| Document | Purpose |
|---|---|
| [`docs/development/roadmap.md`](../../docs/development/roadmap.md) | Main harness roadmap — M2.1 is the next milestone affecting this workflow |
| [`docs/concepts/two_layer_model.md`](../../docs/concepts/two_layer_model.md) | Why M2.1 looks the way it does — reasoning vs capability layer separation |
| [`docs/development/investigation_mcp_server.md`](../../docs/development/investigation_mcp_server.md) | MCP server investigation: architecture, candidates, two-workspace model |

### Historical record (completed work)

| Document | Purpose |
|---|---|
| [`changelog.md`](changelog.md) | KV1–KV4 completion record and milestone summary |
| [`docs/discussions/story_obsidian_vault_onboarding.md`](../../docs/discussions/story_obsidian_vault_onboarding.md) | Original investigation story — reasoning record. Superseded; kept for reference. |

---

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
