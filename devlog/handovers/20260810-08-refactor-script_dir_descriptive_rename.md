# Agent Handover

**Session date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (general CLI refactor track)
**Session type:** Implementation (commit type: refactor)
**Status:** Closed

## Objective
Session 2 of the 3-session refactor split (per operator). Repo-wide cleanup of
the `SCRIPT_DIR` variable with properly descriptive STE100 names, now that
Session 1 (`24d6ebc`) removed the `common.sh` injection mechanism. The rename
makes each variable name describe the directory it holds.

## Key finding (surfaced during scoping)
`SCRIPT_DIR` is NOT a single variable with one meaning. It is overloaded across
**four distinct directory concepts** in live code:

| Class | Files | What `SCRIPT_DIR` holds | Correct name |
|---|---|---|---|
| A | 7 host scripts (`start_agent.sh`, `run_agent.sh`, `onboard.sh`, `stop.sh`, `prune.sh`, `check_test_coverage.sh`, `run_tests.sh`) | `$REPO_ROOT/scripts` | Anchor on `REPO_ROOT` (intermediate collapsed per review) |
| B | ~18 non-knowledge tests | `$REPO_ROOT/tests` (set by `test_common.sh` `test_setup`) | `TEST_DIR` |
| C | 3 knowledge workflow tests (`workflow_draft_*`) | `$REPO_ROOT` (repo root) | `REPO_ROOT` |
| D | 6 other knowledge tests | their own `tests/knowledge/` dir | `TEST_DIR` / self-dir |

A single global rename is therefore impossible — the variable must be renamed
per class to the descriptive name that matches its actual semantic target.
This is the full extent of the "which scripts copy / which dir" ambiguity the
operator called out.

## Scope (to confirm with operator)
1. Rename `SCRIPT_DIR` per class as in the table above, in live agent-sandbox
   code: 7 host scripts, `test_common.sh`, all non-knowledge tests, all
   knowledge tests.
2. Update live docs that define the convention: `docs/concepts/context_resolution.md`,
   `docs/development/testing_policy.md`.
3. Update skills that document the variable: `src/reasoning/agent/drafts/bash-scripting-traps.skill.md`,
   `src/reasoning/agent/drafts/bash-dependency-audit.skill.md`.
4. Update `common.sh` docstring if it references `SCRIPT_DIR`.

**Not in scope:**
- Historical devlog handovers/discussions referencing `SCRIPT_DIR` — read-only
  records per `handover_policy.md`  Corrections to Closed Handovers (only
  factual-error corrections, not historical-referent updates). Zero stale-ref
  grep for the rename targets **live code/docs only**.
- `workflow/knowledge-vault/` — a separate self-contained subproject with its
  own `SCRIPT_DIR`/`SCRIPTS_DIR` conventions; not part of the agent-sandbox
  harness documented in `context_resolution.md`.

## Carried forward
| Item | From |
|---|---|
| Repo-wide descriptive rename of the script-dir variable | Session-1 split (operator), Session-1 handover `20260810-07` |
| `_self_dir` (ambiguous-context libs) is already canonical well-named — NOT part of this rename | `context_resolution.md` defines it as a distinct concept from host `SCRIPT_DIR` |

## Acceptance criteria
| # | Criterion | Status | Verifiable by |
|---|---|---|---|
| 1 | Zero `SCRIPT_DIR` in live agent-sandbox code (`scripts/`, `src/libs/common.sh`, `tests/`) | done | `grep -rln '\bSCRIPT_DIR\b' scripts/*.sh tests/*.sh tests/libs/*.sh src/libs/common.sh` → empty |
| 2 | Host scripts anchor on `REPO_ROOT` (no `REPO_SCRIPTS_DIR`), siblings via `$REPO_ROOT/scripts/`; tests use `TEST_DIR`; knowledge workflow tests use `REPO_ROOT`; knowledge tests use `TEST_KNOWLEDGE_DIR` | done | grep each; grep `REPO_SCRIPTS_DIR` → empty |
| 3 | `test_common.sh` `test_setup` sets `TEST_DIR` | done | read file |
| 4 | Live docs (`context_resolution.md`, `testing_policy.md`) free of stale `SCRIPT_DIR` | done | grep → empty (except line-119 historical note) |
| 5 | Full suite green, no regression vs pre-rename | done | `bash scripts/run_tests.sh` (439 passed, 0 failed, 6 skipped); knowledge lock-trace test identical pre/post (31/7) |
| 6 | Historical handovers, knowledge-vault subproject left untouched | done | git diff excludes them |

## Decisions made this session
| # | Proposed decision | Status |
|---|---|---|
| 1 | Per-class rename, not a single global replace | done — `SCRIPT_DIR` had 4 meanings; renamed per semantic target |
| 2 | Class A → host scripts anchor on `REPO_ROOT` (deleted the `REPO_SCRIPTS_DIR` intermediate); Class B → `TEST_DIR`; Class C → `REPO_ROOT`; Class D → `TEST_KNOWLEDGE_DIR` | done — thermo-nuclear review finding 2 collapsed `REPO_SCRIPTS_DIR` (was 7x-duplicated, always `$REPO_ROOT/scripts`) into direct `REPO_ROOT` anchoring |
| 3 | knowledge-vault subproject out of scope | done — not renamed |
| 4 | historical handovers/discussions out of scope | done — read-only records |
| 5 | Skills NOT renamed (assessment) | done — `bash-scripting-traps` uses generic idiom + knowledge-vault example (out of scope); `bash-dependency-audit` references historical/audit-category names (`_PB_SCRIPT_DIR`) — renaming would misattribute project names onto generic examples |

## Completed this session

### Class A — host scripts: `SCRIPT_DIR` → `REPO_ROOT`-anchored
scripts/start_agent.sh, scripts/run_agent.sh, scripts/onboard.sh, scripts/stop.sh, scripts/prune.sh, scripts/check_test_coverage.sh, scripts/run_tests.sh
Siblings via `$REPO_ROOT/scripts/...`; `common.sh` via `$REPO_ROOT/src/libs`; `TEST_DIR` inlined where the script only needed the tests dir.

### Class B — non-knowledge tests: `SCRIPT_DIR` → `TEST_DIR`
tests/libs/test_common.sh (test_setup now sets TEST_DIR) + 17 test files

### Class C — knowledge workflow tests: `SCRIPT_DIR` → `REPO_ROOT`
tests/knowledge/workflow_draft_then_confirm.sh, workflow_draft_then_reject.sh, workflow_draft_confirm_after_rebase.sh

### Class D — knowledge tests: `SCRIPT_DIR` → `TEST_KNOWLEDGE_DIR`
tests/knowledge/knowledge_binary_diff_apply.sh, knowledge_diff_export_container.sh, knowledge_draft_confirm_lock_trace.sh, knowledge_pi_config_cycle.sh, knowledge_session_diffs_path_resolution.sh, knowledge_trailing_whitespace_context_mismatch.sh

### Docs
- src/libs/common.sh docstring — `REPO_ROOT` in the "does NOT set" example
- docs/concepts/context_resolution.md — Repo scripts + Test files blocks updated to `REPO_ROOT`/`TEST_DIR`; historical naming-convention note (line 119) left intact
- docs/development/testing_policy.md — doc examples updated to `$REPO_ROOT/tests/...` / `$TEST_DIR/...`

### Thermo-nuclear review resolutions (operator-directed)
- **Finding 1 (doc defect, fixed):** the self-contained `# tests/test_example.sh` example referenced an undefined `$REPO_ROOT`; corrected to the canonical `$TEST_DIR/libs/...` pattern.
- **Finding 2 (design, applied):** collapsed `REPO_SCRIPTS_DIR` out entirely — it was a 7x-duplicated intermediate always equal to `$REPO_ROOT/scripts`. Host scripts now anchor directly on `REPO_ROOT` (`REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`), siblings via `$REPO_ROOT/scripts/...`, and `_common_dir` transient dropped for `$REPO_ROOT/src/libs`. Net −10 lines vs the `REPO_SCRIPTS_DIR` variant.
- **Finding 3 (minor, folded into 2):** `_common_dir` in stop.sh/prune.sh inlined to `source "$REPO_ROOT/src/libs/common.sh"`.

### Not renamed (justified)
- devlog/handovers + discussions — read-only historical records (handover_policy)
- workflow/knowledge-vault/ — separate subproject, own conventions
- Skills — generic/historical/out-of-scope examples (Decision 5)
- context_resolution.md line 119 — historical pre-standardisation names (`_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, etc.)

## Verification
- Full suite green: 439 passed, 0 failed, 6 skipped
- Renamed tests run green at runtime (test_trace_start=9, test_start_agent=28, test_diff_workflow=14, knowledge_binary_diff_apply=19)
- knowledge_draft_confirm_lock_trace.sh: 31 passed / 7 failed = **identical** to original (pre-existing git-lock environment failures, unrelated to rename, behavior-preserving)
- Zero `SCRIPT_DIR` in live agent-sandbox code/docs
