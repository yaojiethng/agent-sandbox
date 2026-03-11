# Story Roadmap — Obsidian Vault Onboarding

Tracks investigation, implementation, and future work for onboarding an Obsidian vault into agent-sandbox. Linked from `story_obsidian_vault.md`.

Promote to a named milestone when investigation is complete and the onboarding guide is validated.

---

## Status

| Phase | Status |
|---|---|
| Investigation | Complete ✓ |
| Onboarding guide | Complete ✓ |
| LFS + checkpoint system | Complete ✓ |
| Future migration use cases | Deferred |

---

## Phase 1 — Investigation

Resolves open questions before the onboarding guide is written. Each item below must reach a decision before the guide is drafted.

### Binary file handling — Complete
- LFS pointer storage verified for all binary types (docx, jpeg, pdf)
- Text files including unknown extensions (.pine) correctly bypass LFS
- `git diff -M` rename detection works for both text moves and LFS pointer moves
- `--binary` flag with LFS produces pointer text not raw blobs — safe to add to harness
- `git apply --3way` succeeds on LFS-containing diff
- `git checkout` restores LFS binaries from local cache correctly
- **Harness patch complete:** `lib/diff.sh` `diff_generate` patched with `--binary -M` flags

### Git LFS design — Complete
- Extension-based tracking via `.gitattributes` glob patterns confirmed working
- Auto-classification approach validated: known binary list as fast path; unknown extensions probed via `git diff --numstat`; text extensions never LFS-tracked
- Known text extensions (`KNOWN_TEXT_EXTENSIONS`) needed to prevent false positives from binary probe on executables — add `.sh .py .rb .js .ts .css .html` at minimum
- `git checkout` old commit restores correct LFS attachment state from local cache — confirmed
- Sync behavior on non-LFS devices: document as operator-verified manual check in guide (cannot be automated)

### Checkpoint system design — Complete
- `checkpoint/<date>` branches confirmed as correct model
- `checkpoint/latest` as force-updated tag confirmed
- LFS objects covered by local cache; `git lfs fetch --all` before checkpoint creation is the pre-migration gate
- Checkpoint rollback restores attachment state — confirmed via Test 8

### `vault-lfs-test.sh` — Complete
- 30/30 tests passing against real vault content
- Auto-classification validated: known binary, known text, probed unknown all working correctly
- `-filter -diff -merge` override confirmed as correct syntax (not `!filter`) for known-text extensions
- LFS pointer detection must check `head -1` only — files containing the LFS version string in their own content cause false positives with full-content grep
- Init sequence ordering (`.gitattributes` committed before other files) not required — attribute resolution works correctly at `git add` time

### `.gitattributes` and `.gitignore` — Decided, templates to be written in Phase 2
- `.gitattributes`: auto-generated from vault scan on each run; known binary list + detected binary extras in separate annotated section
- `.gitignore`: see decisions above; templates produced as part of `vault-init.sh`
- Plugin binary tracking: off by default; operator opts in

### Obsidian Sync coexistence — Confirmed
- Exclude `.git/` from Sync settings: confirmed required
- Desktop-only git operations: confirmed
- Pause-apply-resume protocol: confirmed
- Sync behavior on non-LFS devices: document as operator-verified manual check

---

## Phase 2 — Onboarding Guide (`onboarding.md`) — Complete ✓

Deliverable: `workflow/knowledge-vault/onboarding.md`. Tooling lives in `workflow/knowledge-vault/` in agent-sandbox; operators copy it into `.vault/` at the vault root. Standalone doc; does not extend `sandbox-onboarding.md` (different audience and purpose).

- [x] Prerequisites — designated desktop machine, git and LFS install, Obsidian Sync exclude `.git/` step
- [x] Vault git init — `vault-init.sh` usage, `.gitignore` + `.gitattributes` templates, initial commit
- [x] Backup file handling — `app.backup.json` + `appearance.backup.json` seeding pattern
- [x] agent-sandbox integration — Makefile and `agent_context_brief.md` for the vault
- [x] Migration workflow — pause Sync → checkpoint → run agent → review diff → apply → resume Sync
- [x] Checkpoint system — create, rollback, prune
- [x] `.gitattributes` implementation notes and known quirks
- [x] Plugin tracking as optional configuration

---

## Phase 3 — Scripts — Complete ✓

Deliverables live in `workflow/knowledge-vault/` (lib, scripts, tests). Modularized: `vault-init.sh` and `vault-lfs-test.sh` both source shared logic from `lib/classify.sh` and `lib/gitattributes.sh`.

- [x] `lib/classify.sh` — extension discovery, binary probe, `classify_extensions`, `print_classification`
- [x] `lib/gitattributes.sh` — `generate_gitattributes`, `generate_gitignore`
- [x] `vault-init.sh` — idempotent; git init + LFS on first run; regenerates `.gitattributes` on every run; backup file seeding; baseline commit `init: <vault-name> YYYY-MM-DD`
- [x] `vault-lfs-test.sh` — sources lib; 30/30 tests passing; scratch-only, never modifies original vault
- [x] `checkpoint-create.sh` — `git lfs fetch --all`, create `checkpoint/YYYY-MM-DD[-label]` branch, force-update `checkpoint/latest` tag
- [x] `checkpoint-rollback.sh` — restore from named branch or `checkpoint/latest`; rollback commit, no history rewrite
- [x] `checkpoint-prune.sh --keep=<N>` — keep N most recent dated branches; prompt before delete; never touch `checkpoint/latest`

---

## Future Use Cases

Deferred. Each should become a user story or milestone task when ready.

### Attachment format migration (webp conversion)
Agent produces a conversion script (`cwebp` / `ffmpeg`) + text patch updating note links. LFS sees pointer changes for renamed/deleted objects and new pointers for `.webp` files. Requires checkpoint before running.

### Remove unreferenced attachments
Agent walks vault text corpus, builds link graph, diffs against attachment directory, produces a reviewed deletion script. Pure filesystem op. Requires checkpoint before running.

### OCR screenshots to text notes
Agent produces `.md` notes with extracted text per screenshot, plus optional image archival script. Requires `tesseract` in container. Text output is standard patch; image ops are filesystem script. Requires checkpoint; output volume may be large.

### PDF / epub handling
Future: extract text, summarize, convert to note format. No pipeline changes needed — extension list in `.gitattributes` already covers tracking. Agent task definition deferred.

### Generalized checkpoint/backup system
Current design is vault-local. Future: configurable backup target (local path, remote URL) via `.env` or Makefile var; prune policy via `-n` flag. Consider whether this generalizes to all agent-sandbox projects, not just vaults.
