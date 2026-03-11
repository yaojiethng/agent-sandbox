# Story Roadmap — Obsidian Vault Onboarding

Tracks investigation, implementation, and validation for onboarding an Obsidian vault into agent-sandbox. Linked from `story_obsidian_vault.md`.

---

## Status

| Phase | Status |
|---|---|
| 1 — Investigation | Complete ✓ |
| 2 — Onboarding guide | Complete ✓ |
| 3 — Implementation | Complete ✓ |
| 4 — Agent-Sandbox Workflow Onboarding | Complete ✓ |
| 5 — Knowledge Store Modification Workflow | Not started |

---

## Phase 1 — Investigation *Complete.*

Confirmed that the standard agent-sandbox diff model works for vault use with one harness patch. LFS is the correct mechanism for binary attachment tracking; extension-based `.gitattributes` glob patterns with auto-classification handle vault file diversity without manual maintenance. The checkpoint system uses dated branches plus a `checkpoint/latest` force-tag as the rollback target. Obsidian Sync coexistence is resolved operationally via pause-apply-resume; no harness changes required. The `--binary -M` patch to `lib/diff.sh` is required for correct binary diff output.

---

## Phase 2 — Onboarding Guide *Complete.*

Produced `workflow/knowledge-vault/onboarding.md`. Covers Sync setup, tooling copy, init, checkpoint creation, agent-sandbox integration, migration workflow, backup file behavior, `.gitattributes` implementation notes, and plugin tracking as an optional configuration. Written for operators and agents.

---

## Phase 3 — Implementation *Complete.*

Tooling lives in `workflow/knowledge-vault/`. `.vault/` is a machine-local symlink rather than a committed copy, eliminating dual-maintenance. `vault-init.sh` rolls back `.git` on failure, leaving no partial state. `vault-prepare.sh` sequences init and baseline checkpoint as the operator-facing preparation step. `snapshot_copy_files` was hardened for filenames with spaces and leading dashes, and skips symlinks cleanly. The checkpoint scripts are project-agnostic (`--root` flag); `checkpoint-test.sh` validates all three against a scratch repo.

---

## Phase 4 — Agent-Sandbox Workflow Onboarding *Complete.*

`agent-sandbox onboard knowledge-vault --vault=<path>` is the single operator entry point for vault onboarding. `scripts/onboard.sh` dispatches by workflow name to `workflow/<n>/scripts/onboard.sh`, making the pattern extensible without modifying the dispatcher. The knowledge-vault onboard script validates the target, warns if Sync is active, enforces idempotency, places a machine-local `.vault` symlink, generates a pre-filled Makefile from `lib/_templates/Makefile.template` with vault-specific targets (`initialize`, `checkpoint`, `rollback`, `checkpoint-prune`), and places an `agents.md` brief starter. The apply/checkpoint workflow is confirmed as a manual operator step: create a checkpoint before each session, apply the diff after review, roll back to the previous checkpoint if rejected.

---

## Phase 5 — Knowledge Store Modification Workflow

This phase defines the framework for agent-assisted vault operations and validates the end-to-end workflow. The agent has standard project posture inside the container: read/write access to the sandbox copy of vault files. Checkpointing is an operator step performed outside the container before `make start`. The agent does not have access to `.vault/` tooling or checkpoint scripts from inside the container — the sandbox contains vault content only.

### Open design question

- **Agent provider** — OpenCode has significant limitations working with large volumes of markdown files. Claude Code is likely the correct provider for knowledge store work. This needs investigation before validation tasks can be completed. See user story: *Claude Code provider integration*.

### Validation tasks

- End-to-end sandbox validation — snapshot pipeline captures vault with LFS pointers and `.gitattributes` correctly
- `lib/diff.sh` `--binary -M` patch verified correct for agent run against vault
- `agent-sandbox apply` correctly handles vault diff on host

Proposed shape: controlled agent task against an initialised vault, verify diff, apply, verify vault state. Manual integration test initially.

### Deferred

- Whether to automate pre-session checkpoint creation (e.g. as part of `make start`) — revisit after manual workflow is validated.

---

## Potential User Stories

Each should become a scoped investigation or milestone task when ready.

- **Claude Code provider integration** — OpenCode is not well-suited to large markdown vaults. Investigate Claude Code as the agent provider for knowledge store work; determine harness changes required. Prerequisite for Phase 5 validation tasks.
- **Attachment format migration** — agent produces conversion script + link-update patch (e.g. webp conversion via `cwebp`/`ffmpeg`)
- **Remove unreferenced attachments** — agent builds link graph, produces reviewed deletion script
- **OCR screenshots to text notes** — requires `tesseract` in container; text output is standard patch
- **PDF / epub handling** — extract, summarize, convert to note format; no pipeline changes needed

---

## Deferred — Harness-level checkpoint tooling

The checkpoint scripts are project-agnostic by design (`--root` flag, no vault-specific logic). A decision to promote them from `workflow/knowledge-vault/scripts/` to the main harness `scripts/` directory is deferred to the agent-sandbox roadmap.
