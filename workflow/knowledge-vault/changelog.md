## Milestone Summary

| Milestone | Status |
|---|---|
| KV1 — Investigation | Complete |
| KV2 — Onboarding Guide | Complete |
| KV3 — Implementation | Complete |
| KV4 — Agent-Sandbox Workflow Onboarding | Complete |
| KV5 — Knowledge Store Modification Workflow | Promoted to [M2.1](../../docs/devlog/roadmap.md) |

---

## KV1 — Investigation

*The standard agent-sandbox diff model was confirmed to work for Obsidian vault use with minimal harness changes.*

LFS was established as the correct mechanism for binary attachment tracking, with extension-based `.gitattributes` glob patterns handling vault file diversity without manual maintenance. The checkpoint system design — dated branches plus a `checkpoint/latest` force-tag — was confirmed as the rollback target. Obsidian Sync coexistence is resolved operationally via pause-apply-resume, requiring no harness changes. One harness patch was identified as required: `--binary -M` flags on the diff pipeline for correct binary output.

---

## KV2 — Onboarding Guide

*Operators and agents have a complete reference for preparing and running a vault with agent-sandbox.*

`workflow/knowledge-vault/onboarding.md` was produced covering Sync setup, vault initialisation, checkpoint creation, agent-sandbox integration, and the migration workflow. Backup file handling for Obsidian config files and optional plugin version tracking are documented as operational patterns.

---

## KV3 — Implementation

*Vault tooling is live and validated: git + LFS initialisation, checkpoint lifecycle, and LFS classification are all scriptable and tested.*

Tooling lives in `workflow/knowledge-vault/`. The vault tooling directory (`.vault/`) is a machine-local symlink rather than a committed copy, eliminating dual-maintenance. `vault-init.sh` rolls back `.git` on failure during first-run initialisation, leaving no partial state. `vault-prepare.sh` sequences init and baseline checkpoint as the operator-facing preparation step. `snapshot_copy_files` was fixed to handle filenames with spaces and leading dashes, and to skip symlinks. The checkpoint scripts are project-agnostic (`--root` flag); `checkpoint-test.sh` validates all three against a scratch repo.

---

## KV4 — Agent-Sandbox Workflow Onboarding

*A vault can be fully onboarded into agent-sandbox with a single CLI command and made ready for agent sessions with `make initialize`.*

`agent-sandbox onboard knowledge-vault --vault=<path>` is the single entry point for vault onboarding. `scripts/onboard.sh` dispatches by workflow name to `workflow/<n>/scripts/onboard.sh`, making the pattern extensible without modifying the dispatcher. The onboard script validates the target, warns if Sync is active, enforces idempotency, places a machine-local `.vault` symlink, and generates a pre-filled Makefile from a shared template with vault-specific targets appended (`initialize`, `checkpoint`, `rollback`, `checkpoint-prune`). The snapshot pipeline captures vault files correctly; LFS pointer files enter the snapshot as text. The apply/checkpoint workflow is a confirmed manual operator step: create a fresh checkpoint before each session, apply the diff after review, roll back to the previous checkpoint if rejected.

---
