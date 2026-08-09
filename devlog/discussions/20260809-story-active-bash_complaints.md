# Agent-maintained — bash technical complaints and friction log

This file is maintained by the coding agent to record technical complaints,
sharp edges, and frustrations encountered while implementing the project in bash.
It is a reasoning record, not a task list, not architecture.

Each entry describes the problem, where it was encountered, and a scope note
for whether it could be addressed.

**Status:** Ongoing (not a completion-tracked document)

---

## Context

agent-sandbox is implemented primarily in bash — build infrastructure, container
orchestration, diff pipelines, test suites, draft branch workflows. Bash is a
deliberate choice (zero-dependency, cross-platform, container-friendly) but it
exposes sharp edges that cause real bugs and wasted diagnostic time.

This file records them so future agents and operators understand the landscape.

---

## Complaints

### 1. Empty string bypasses `${VAR:-default}`

`${VAR:-default}` expands to `default` only when `VAR` is **unset** — not when it
is an empty string. An empty `VAR=""` is a set value, so the fallback is silently
skipped.

**Where it hit:** `draft_run()` in `scripts/workflows/draft.sh` — `main()` passes
`BRANCH_FROM=""` (empty, from `--branch-from=` not being provided), then
`BASE_COMMIT="${BRANCH_FROM_ARG:-HEAD}"` resolves to `""` instead of `HEAD`.
`git rev-parse ""` → `fatal: Failed to resolve '' as a valid ref`.

**Fix pattern:** Explicit emptiness check before the default:
```bash
local BASE_COMMIT="$BRANCH_FROM_ARG"
[[ -n "$BASE_COMMIT" ]] || BASE_COMMIT="HEAD"
```

**Scope:** Could be linted. A shellcheck rule exists for this (`SC2086` adjacent)
but the empty-vs-unset distinction is a language design issue, not a linting one.

---

### 2. `git rev-parse --verify 0000...` succeeds

Git treats the all-zero SHA (`0000000000000000000000000000000000000000`) as a
valid reference to the empty tree object. `rev-parse --verify` returns 0. No
warning, no error.

**Where it hit:** `draft_run()` validation — after reading `INIT_SHA=0000...`
from a test fixture's dummy `.export-status`, the validation check passed and a
draft branch was created pointing at the empty tree. Diffs then failed to apply
silently during the apply loop.

**Fix pattern:** If there's a risk of dummy SHAs from test fixtures, validate
against a known commit set. But the real fix is ensuring test fixtures don't
leak dummy values into validation paths.

**Scope:** Upstream git behavior — not fixable in this project. Defensive coding
only.

---

### 3. `local FOO=$(cmd)` swallows exit codes under `set -e`

`local` is a builtin that always returns 0, regardless of the exit code of any
command substitution in its value. Under `set -e`, `local FOO=$(failing_cmd)`
never triggers errexit — the failure is silently absorbed.

**Where it hit:** Common pattern throughout the codebase. Split assignment avoids
it: `local FOO; FOO=$(failing_cmd)`.

**Scope:** Shellcheck warns on this (`SC2155`). Could enable as a lint rule.

---

### 4. `|| true` required for failure-tolerant checks under `set -e`

Any command that is expected to sometimes fail — `ls missing*`, `grep -c` on
absent patterns, `diff --quiet` on dirty trees — must be suffixed with `|| true`
to prevent `set -e` from aborting the script.

**Where it hit:** Everywhere. Test helpers, preflight checks, optional grep
operations. The `|| true` pattern is pervasive but easy to forget on new checks,
causing scripts to exit early with no error message.

**Fix pattern:** `command || true` — but this also silences the exit code. Better
pattern for grep counting:
```bash
local COUNT
COUNT=$(grep -c 'pattern' file 2>/dev/null) || true
```

**Scope:** Language design limitation. The subshell-scoped `|| true` pattern
(from session `20260805-01`) is the best available mitigation.

---

### 5. No test fixture lifecycle — manual `rm -rf` everywhere

Bash test files have no `setup`/`teardown` framework. Every test manually creates
temp dirs with `mktemp -d` and cleans up with `rm -rf`. Tests that fail midway
leak temp directories.

**Where it hit:** Every test file. The `test_setup` helper creates `$FIXTURE_DIR`
with a shared `trap ... EXIT` cleanup, but individual tests often create
additional temp dirs that aren't trapped.

**Fix pattern:** Use `$FIXTURE_DIR` subdirectories instead of `mktemp -d` where
possible. For supplemental dirs, add a `trap 'rm -rf "$_tmpdir"' RETURN`.

**Scope:** Could standardize a `test_teardown` helper. Not urgent — leaked temp
dirs in CI are ephemeral.

---

### 6. Undefined variable errors under `set -u` are opaque

`set -u` (or `-o nounset`) causes any reference to an undefined variable to abort
with an unhelpful error like `AUTHOR: unbound variable`. No line number, no
context — just the variable name.

**Where it hit:** `draft_run()` — when refactoring removed a `local AUTHOR`
declaration but left a downstream `$AUTHOR` usage. Test hung because the script
exited silently in a subshell context.

**Fix pattern:** Always declare `local` before use. Shellcheck catches this
(`SC2154`).

**Scope:** Bash limitation. Could add `|| true` guards on critical paths, but
that defeats the purpose of `-u`.

---

### 7. `grep -c` returns exit 1 on zero matches

`grep -c 'pattern' file` returns 0 if matches found, 1 if no matches. Under
`set -e`, this causes the script to abort even when zero matches is the expected
and correct result.

**Where it hit:** Test assertions that count matches. Every `grep -c` in a test
that might legitimately get 0 matches.

**Fix pattern:** `grep -c 'pattern' file || true` — always. Or `grep -c
'pattern' file 2>/dev/null; local _rc=$?` and check `_rc` manually.

**Scope:** Language design. Could adopt a `_count_matches()` wrapper.

---

### 8. Circular sourcing between `diff_export.sh` and `package_branch.sh`

`diff_export.sh` sources `package_branch.sh` to call it. When `package_branch.sh`
needed `_write_export_status`, it couldn't source `diff_export.sh` back without
creating a cycle.

**Resolution:** Extracted `_write_export_status` to a shared `export_status.sh`
lib sourced by both. But the discovery was trial-and-error — no static analysis
tool caught the cycle.

**Scope:** Architecture decision recorded in ADR (not yet written). Pattern to
follow for future lib dependencies: shared functions should live in leaf
libraries, never in orchestrators.

---

## Cross-reference: `bash-scripting-traps.skill.md` coverage

Each complaint checked against the skill file (16 traps) to determine whether
a mitigation already exists.

| # | Complaint | Trap coverage | Assessment |
|---|---|---|---|
| 1 | Empty string bypasses `${VAR:-default}` | None | No mitigation exists. Should be added as a new trap. |
| 2 | `git rev-parse --verify 0000...` succeeds | None | Upstream git behavior — not fixable. Defensive coding only. No trap to add. |
| 3 | `local FOO=$(cmd)` swallows exit codes | Trap 15 (top-level `local`) | Trap 15 covers top-level scope only. The function-scope exit-code-swallowing pattern is distinct and unaddressed. Should be added as a new trap or merged into Trap 15. |
| 4 | `|| true` required on individual commands | Trap 16 (pipeline `|| true`) | Trap 16 covers pipeline-level swallowing only. Individual command patterns (`grep -c`, `ls missing*`, `diff --quiet`) are not addressed. Trap 16 scope should be broadened or a companion trap added. |
| 5 | No test fixture lifecycle | None | No mitigation exists. Could add a `test_teardown` trap pattern. |
| 6 | `set -u` errors are opaque | None | Bash limitation — `set -u` has no built-in context reporting. No trap to add. |
| 7 | `grep -c` returns exit 1 on zero matches | None (Trap 9 is unrelated) | No mitigation exists. Could be paired with complaint #4 as a general "expected-failure commands under `set -e`" trap. |
| 8 | Circular sourcing between libs | None | No mitigation exists. Should be added as an architecture trap: shared functions live in leaf libraries, not orchestrators. |

**Summary:** 8 complaints, 5 with no skill coverage at all, 1 partially covered
(complaint #4 by Trap 16), 2 not applicable for trapping (upstream bash/git
behavior). Six new traps or trap expansions are warranted. Deferred to a future
skill-maintenance session.
