# Knowledge Vault — Development Roadmap

Tracks investigation, implementation, and validation for onboarding an Obsidian vault into agent-sandbox. Linked from the [agent-sandbox roadmap](../../docs/development/roadmap.md).

Maintenance rules follow [`docs/development/roadmap_policy.md`](../../docs/development/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| KV1 — Investigation | [Complete — see changelog](changelog.md) |
| KV2 — Onboarding Guide | [Complete — see changelog](changelog.md) |
| KV3 — Implementation | [Complete — see changelog](changelog.md) |
| KV4 — Agent-Sandbox Workflow Onboarding | [Complete — see changelog](changelog.md) |
| [KV5 — Knowledge Store Modification Workflow](#kv5--knowledge-store-modification-workflow) | Not started |

---

## Upcoming Milestones

### KV5 — Knowledge Store Modification Workflow

**Objective:** Define the framework for agent-assisted vault operations and validate the end-to-end workflow against a live vault.

The agent has standard project posture inside the container: read/write access to the sandbox copy of vault files. Checkpointing is an operator step performed outside the container before `make start`. The agent does not have access to `.vault/` tooling or checkpoint scripts from inside the container — the sandbox contains vault content only.

#### Open design question

- **Agent provider** — OpenCode has significant limitations working with large volumes of markdown files. Claude Code is likely the correct provider for knowledge store work. Investigation is required before validation tasks can be completed. See user story: *Claude Code provider integration*.

#### Validation tasks

- [ ] End-to-end sandbox validation — snapshot pipeline captures vault with LFS pointers and `.gitattributes` correctly
- [ ] `lib/diff.sh` `--binary -M` patch verified correct for agent run against vault
- [ ] `agent-sandbox apply` correctly handles vault diff on host

Proposed shape: controlled agent task against an initialised vault, verify diff, apply, verify vault state. Manual integration test initially.

#### Deferred

- Whether to automate pre-session checkpoint creation (e.g. as part of `make start`) — revisit after the manual workflow is validated.

---

## User Stories

Active investigations not yet promoted to milestones.

- **Claude Code provider integration** — OpenCode is not well-suited to large markdown vaults. Investigate Claude Code as the agent provider for knowledge store work; determine harness changes required. Prerequisite for KV5 validation tasks.
- **Attachment format migration** — agent produces conversion script + link-update patch (e.g. webp conversion via `cwebp`/`ffmpeg`)
- **Remove unreferenced attachments** — agent builds link graph, produces reviewed deletion script
- **OCR screenshots to text notes** — requires `tesseract` in container; text output is standard patch
- **PDF / epub handling** — extract, summarize, convert to note format; no pipeline changes needed

---

## Deferred Decisions

### Checkpoint tooling — promote to harness scripts/

The checkpoint scripts are project-agnostic by design (`--root` flag, no vault-specific logic). A decision to promote them from `workflow/knowledge-vault/scripts/` to the main harness `scripts/` directory is tracked in the agent-sandbox roadmap. Integration testing against at least one non-vault workflow is required before the scripts are treated as general infrastructure.
