# Design — Change B: Interactive Confirmation Flag

**Target milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline

**Status:** Design record — describes the interactive `--interactive` flag for `make apply` and `make draft`

**Supersedes:** The "Settled scope" section in `recovery-design-step-b.md` (now reconciled with current repo state)

**Related:**
- [`design_change_a_contract.md`](design_change_a_contract.md) — CLI contract, routers, channel model (prerequisite)
- [`design_diff_and_branch_packaging_workflow.md`](design_diff_and_branch_packaging_workflow.md) — core diff pipeline
- [`libs/routing.sh`](../../libs/routing.sh) — router functions
- [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) — dispatch entry point

---

## 1. Scope

Change B adds an `--interactive` flag to `agent-sandbox apply` and `agent-sandbox draft`. When set, the operator is guided through a numbered multi-step picker instead of needing to know session names or paths from directory listings. This is a convenience alternative — non-interactive mode behaviour is unchanged and remains the primary path.

**What Change B is:**
- An `--interactive` flag for both `apply` and `draft`
- Two-level picker for `draft`: step 1 selects channel, step 2 selects session entry
- Three-level picker for `apply`: step 1 selects channel, step 2 selects session entry, step 3 selects diff type (`uncommitted.diff` or `all-changes.diff`)
- Shared helpers in a new `libs/interactive_session_select.sh` for numbered prompts, channel/entry scanning, and availability indicators
- `INTERACTIVE=1` Makefile variable mapped to `--interactive`
- Renamed `FROM=` Makefile variable replacing `BUNDLE=` and `AUTOSAVE=` — value is the channel name directly (e.g. `bundles`, `autosave`, `diffs`, `session`)

**What Change B is not:**
- Not a redesign of the diff format, channel model, or router layer (settled in Change A)
- Not TTY auto-detection — interactive mode activates only when `--interactive` is explicitly set
- Not a redesign of `package_diff` or `package_branch`
- Not cross-write of `package_diff` output into `session-diffs/`

---

## 2. Drift Reconciliation

The recovery design document `recovery-design-step-b.md` was written during an earlier recovery cycle. Assumptions that have drifted:

| Assumption in recovery doc | Current state | Impact |
|---|---|---|
| `draft_run` signature unknown | `draft_run PROJECT_DIR SOURCE_DIR SESSION_NAME BRANCH_FROM DIFFS BRANCH_SUMMARY` | Interactive logic lives in dispatch layer, not in `draft_run` |
| `apply_run` takes 6 args | `apply_run PROJECT_DIR DIFF_FILE APPLY_BRANCH FORCE` (4 args) | Same — dispatch layer only |
| Router functions not finalised | `resolve_source_for_draft`, `resolve_diff_for_apply` in `libs/routing.sh` | Interactive selection feeds `SESSION_ARG` into router; router unchanged |
| `output/diffs/` path implicit | `$OUTPUT_DIR/diffs/` via `dirs_resolve` | Use `dirs_resolve` for paths |
| `resolve_session_dir` still used | Replaced by channel-specific routers | Interactive feeds into routers |
| Test framework mentioned as bats | Custom shell framework via `test_common.sh` | Custom `run_test`/`pass`/`fail` — no bats dependency |

---

## 3. Resolved Design Decisions

### 3.1. Interactive Flow — `draft --interactive`

**Two-step picker:**

```
Step 1 — Pick channel:
  Available channels:
    1: session     (3 entries, newest: 20260504-120000-feature-X)
    2: autosave    (1 entry,  newest: 20260503-090000-main)
    3: bundles     (0 entries)

  Selection [1-3, q to quit, Enter for default]:

  → picks channel number

Step 2 — Pick session entry:
  Available sessions (session):
    1: 20260504-120000-feature-X    patches: ✓  uncommitted: ✓
    2: 20260503-090000-main         patches: ✓  uncommitted: ✗

  Selection [1-2, q to quit, Enter for default]:

  → feeds SESSION_TS-BRANCH as --session to the channel resolver
```

**Default highlighting logic:**
- If `--channel=<X>` is provided → step 1 is skipped; channel is fixed to X
- If no `--channel` is provided → step 1 default is what auto-resolution would produce (`session`)
- If `--session=<name>` is provided → step 2 shows name as the default (highlighted, empty enter selects it)
- If no `--session` is provided → step 2 default is the auto-resolution result (newest entry under that channel)

### 3.2. Interactive Flow — `apply --interactive`

**Three-step picker:**

```
Step 1 — Pick channel:
  Available channels:
    1: diffs        (2 entries, newest: 20260504-120000-snapshot)
    2: autosave     (1 entry,  newest: 20260503-090000-main)
    3: session      (3 entries, newest: 20260504-120000-feature-X)

  Selection [1-3, q to quit, Enter for default]:

Step 2 — Pick session entry:
  Available sessions (diffs):
    1: 20260504-120000-snapshot    patches: ✓  uncommitted: ✓
    2: 20260503-090000-main         patches: ✗  uncommitted: ✓

  Selection [1-2, q to quit, Enter for default]:

Step 3 — Pick diff type:
  Select diff file:
    1: uncommitted.diff (default)
    2: all-changes.diff

  Selection [1-2, q to quit, Enter for default]:
```

**When `--diff=<path>` is supplied** — all three steps are skipped. Interactive mode shows the resolved path and a confirmation prompt:

```
Apply: /path/to/explicit.diff

Proceed? [y/N]
```

### 3.3. Interactive Flow — `draft` with explicit channel + session

When both `--channel` and `--session` are provided, both selection steps are skipped. Interactive mode shows the full patch list and prompts for confirmation:

```
Draft from: 20260504-120000-feature-X
  Patches:
    0001-abc1234.diff
    0002-def5678.diff
  Uncommitted: uncommitted.diff (non-empty)

Proceed? [y/N]
```

### 3.4. Table Layout

```
Available sessions (<channel>):
  1: <SESSION_TS>-<BRANCH>              patches: ✓  uncommitted: ✓
  2: <SESSION_TS>-<BRANCH>              patches: ✓  uncommitted: ✗
  ...

Selection [1-N, q to quit, Enter for default]:
```

- Session name: left-aligned, truncated at 50 characters with `...`
- Availability indicators: right-aligned, `patches: ✓/✗`, `uncommitted: ✓/✗`
- Default entry: shown at position 1 (newest), marked with `(default)` hint in the prompt line
- Max entries: capped at 10, hardcoded as `INTERACTIVE_MAX_ENTRIES=10` at top of script
- Overflow: when more than 10 entries, append "... and N more. Use SESSION=<name> to select older sessions directly."
- Zero entries: print "No sessions available." and exit non-zero
- `q` or empty input at any step: abort with exit 1
- Invalid number: re-prompt

### 3.5. Shared Functions

New file: `libs/interactive_session_select.sh`. Sources `libs/routing.sh` for path resolution.

Functions:

```bash
# interactive_confirm_or_abort LABEL ITEMS...
#   Prints LABEL, lists ITEMS (one per line to stderr), prompts "Proceed? [y/N]".
#   Reads from stdin. Warns to stderr if stdin is not a terminal (test -t 0).
#   Returns 0 on y/Y, 1 on anything else.
interactive_confirm_or_abort() { ... }

# interactive_select_channel SUBCOMMAND SANDBOX_DIR [DEFAULT_CHANNEL]
#   Scans eligible channels for SUBCOMMAND (apply or draft).
#   Prints numbered channel table with entry counts and newest timestamps.
#   Returns selected channel name on stdout.
#   If DEFAULT_CHANNEL is provided, highlights and uses as default on empty input.
#   Exits 1 on q or EOF.
interactive_select_channel() { ... }

# interactive_select_session SANDBOX_DIR CHANNEL [DEFAULT_SESSION]
#   Scans entries under the resolved channel directory.
#   Prints numbered session table with availability indicators.
#   Returns selected session basename on stdout.
#   If DEFAULT_SESSION is provided, highlights and uses as default on empty input.
#   Exits 1 on q or EOF.
interactive_select_session() { ... }

# interactive_select_diff_type SANDBOX_DIR SESSION_NAME CHANNEL
#   Shows available diff types for the resolved session.
#   Returns "uncommitted" or "all-changes".
#   Default: uncommitted.diff.
interactive_select_diff_type() { ... }
```

**Stdio contract:** All output (prompts, tables, errors) goes to stderr. Only the selected value is printed to stdout. Stdin is read directly (no `/dev/tty` accommodation). When stdin is not a terminal, a warning is printed to stderr but reading proceeds — this enables tests to pipe input.

### 3.6. CLI Wiring in `agent-sandbox.sh`

**Flag parsing:**
```bash
--interactive) INTERACTIVE=true ;;
```

**`apply` dispatch — interactive mode:**
```bash
if [[ "$INTERACTIVE" == true ]]; then
  source "$AGENT_SANDBOX_REPO/libs/interactive_session_select.sh"

  if [[ -n "$DIFF_ARG" ]]; then
    # --diff=path given: skip all selection steps, just confirm
    interactive_confirm_or_abort "Apply:" "$DIFF_ARG" || exit 1
    # fall through to apply_run with DIFF_ARG as-is
  else
    # Step 1: pick channel
    local CHANNEL
    CHANNEL=$(interactive_select_channel "apply" "$SANDBOX_DIR" "${CHANNEL_ARG:-}") || exit 1
    # Step 2: pick session
    local SESSION
    SESSION=$(interactive_select_session "$SANDBOX_DIR" "$CHANNEL" "${SESSION_ARG:-}") || exit 1
    # Step 3: pick diff type
    local DIFF_TYPE
    DIFF_TYPE=$(interactive_select_diff_type "$SANDBOX_DIR" "$SESSION" "$CHANNEL") || exit 1
    # Set SESSION_ARG and fall through to normal resolution
    SESSION_ARG="$SESSION"
    # The router resolves the diff path from channel + session; we override the resolved
    # file with the selected type
  fi
fi
```

**`draft` dispatch — interactive mode:**
```bash
if [[ "$INTERACTIVE" == true ]]; then
  source "$AGENT_SANDBOX_REPO/libs/interactive_session_select.sh"

  if [[ -n "$CHANNEL_ARG" && -n "$SESSION_ARG" ]]; then
    # Both channel and session given: skip selection, show patch list and confirm
    local ROUTER_RESULT
    ROUTER_RESULT=$(resolve_source_for_draft "$SANDBOX_DIR" "$CHANNEL_ARG" "$SESSION_ARG") || exit 1
    local SOURCE_DIR SESSION_NAME
    SOURCE_DIR=$(echo "$ROUTER_RESULT" | cut -f1)
    SESSION_NAME=$(echo "$ROUTER_RESULT" | cut -f2)
    # Build patch list
    local -a PATCH_ITEMS=("Draft from: $SESSION_NAME")
    for f in "$SOURCE_DIR/patches/"*.diff; do
      PATCH_ITEMS+=("  $(basename "$f")")
    done
    if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
      PATCH_ITEMS+=("  uncommitted.diff (non-empty)")
    fi
    interactive_confirm_or_abort "" "${PATCH_ITEMS[@]}" || exit 1
    # fall through to normal draft_run
  else
    # Step 1: pick channel
    local CHANNEL
    CHANNEL=$(interactive_select_channel "draft" "$SANDBOX_DIR" "${CHANNEL_ARG:-}") || exit 1
    # Step 2: pick session
    local SESSION
    SESSION=$(interactive_select_session "$SANDBOX_DIR" "$CHANNEL" "${SESSION_ARG:-}") || exit 1
    SESSION_ARG="$SESSION"
    # fall through to normal resolution
  fi
fi
```

### 3.7. Makefile Integration

Changes to `libs/_templates/Makefile.template`:

| Change | Detail |
|---|---|
| Replace `AUTOSAVE ?=` and `BUNDLE ?=` | With `FROM ?=` — value is channel name directly |
| Add `INTERACTIVE ?=` | New variable |
| Update `DRAFT_CHANNEL` | `$(if $(FROM),$(FROM),session)` — replaces BUNDLE/AUTOSAVE logic |
| Update `APPLY_CHANNEL` | `$(if $(FROM),$(FROM),diffs)` — replaces AUTOSAVE logic |
| Add `$(if $(INTERACTIVE),--interactive,)` | To both `draft` and `apply` targets |
| Update help text | Remove BUNDLE/AUTOSAVE docs, add FROM= and INTERACTIVE=1 |

Example target:
```makefile
FROM ?=
INTERACTIVE ?=

DRAFT_CHANNEL := $(if $(FROM),$(FROM),session)

draft:
	agent-sandbox draft \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --channel=$(DRAFT_CHANNEL) \
	  $(if $(SESSION),--session=$(SESSION),) \
	  $(if $(INTERACTIVE),--interactive,) \
	  $(if $(BRANCH_FROM),--branch-from=$(BRANCH_FROM),) \
	  $(if $(DIFFS),--diffs=$(DIFFS),) \
	  $(if $(BRANCH_SUMMARY),--branch-summary=$(BRANCH_SUMMARY),)
```

**Operator migration:** `BUNDLE=1` → `FROM=bundles`, `AUTOSAVE=1` → `FROM=autosave`. One variable, explicit channel names, no implicit mapping.

### 3.8. Session Table Deduplication

Within a single channel, each session appears at most once (one directory per session name per channel). The per-row indicators show:
- `patches: ✓` — `patches/` subdirectory exists within the entry
- `uncommitted: ✓` — `uncommitted.diff` exists and is non-empty within the entry

---

## 4. Resolved Open Questions

| Question | Resolution |
|---|---|
| **Q-B-1** — Should `draft --interactive` show `output/diffs/` entries? | **No.** Draft only shows draft-eligible channels. |
| **Q-B-2** — Where does the scanner live? | **New file `libs/interactive_session_select.sh`.** Avoids coupling `session.sh` to routing. |
| **Q-B-3** — Behaviour when zero entries? | **Print "No sessions available." and exit non-zero.** |
| **Q-B-4** — Max entries? | **Cap at 10.** Hardcoded as `INTERACTIVE_MAX_ENTRIES=10` at script top. Overflow shows hint. |
| **Q-B-5** — `--interactive` + `--session=<name>`? | **Pre-fill and highlight.** Empty enter selects the default. |
| **Q-B-6** — `apply --interactive` table or path? | **Three-step flow**: channel → session → diff type pick. Only `--diff=<path>` bypasses all three. |
| **Q-B-7** — Table column format? | Session name left-aligned (truncate at 50 chars), indicators right-aligned. Default at position 1. |
| **Q-B-8** — Stdio for tests? | **Read stdin directly.** Warn on `test -t 0` false but proceed. Tests pipe input. |
| **Makefile rename** | `BUNDLE=` and `AUTOSAVE=` → `FROM=<channel-name>`. |

---

## 5. Implementation Units

### Unit 1 — `libs/interactive_session_select.sh`

- `interactive_confirm_or_abort`
- `interactive_select_channel`
- `interactive_select_session`
- `interactive_select_diff_type`
- Interaction helpers (prompt loop, numbered input parsing)

### Unit 2 — `apply --interactive` wiring in `agent-sandbox.sh`

- Source `interactive_session_select.sh` in the `apply` dispatch block
- Three paths: `--diff=` (one-step confirm), full channel→session→diff-type picker, or skip if all args provided

### Unit 3 — `draft --interactive` wiring in `agent-sandbox.sh`

- Source `interactive_session_select.sh` in the `draft` dispatch block
- Two paths: both `--channel` and `--session` given (show patch list + confirm), or channel→session picker

### Unit 4 — Makefile template update

- Replace `BUNDLE ?=` / `AUTOSAVE ?=` with `FROM ?=`
- Add `INTERACTIVE ?=`
- Update `DRAFT_CHANNEL` / `APPLY_CHANNEL` derivation
- Wire `--interactive` into both targets
- Update help text

### Unit 5 — Tests

File: `tests/test_interactive_session_select.sh`

**Unit tests for `interactive_confirm_or_abort`:**
- Feed `y\n` → returns 0
- Feed `n\n` → returns 1 (and any non-y input)
- Feed empty → returns 1
- Multiple items printed correctly to stderr
- Nothing printed to stdout

**Unit tests for `interactive_select_channel`:**
- Creates fixture directories for draft channels (session, autosave, bundles)
- Feed `1\n` → returns "session"
- Feed `2\n` → returns "autosave"
- Default channel highlighted: empty enter returns default
- Zero entries per channel → shows empty counts, channel still selectable
- Invalid input → re-prompts

**Unit tests for `interactive_select_session`:**
- Create fixture entries with patches and uncommitted.diff
- Feed `1\n` → returns correct session name
- Empty entries directory → prints "No sessions available." and exits non-zero
- Default session highlighted: empty enter returns default
- Cap at 10: 11+ entries show hint, only first 10 listed

**Unit tests for `interactive_select_diff_type`:**
- Feed `1\n` → returns "uncommitted"
- Feed `2\n` → returns "all-changes"
- `uncommitted.diff` missing but `all-changes.diff` present → defaults to all-changes
- Both missing → error

**Integration tests (in `test_diff_workflow.sh` and `test_draft_workflow.sh`):**
- `apply --interactive` with piped `y` → applies diff, file created
- `apply --interactive` with piped `n` → aborts, no file created
- `draft --interactive` with piped selection → creates draft branch
- `draft --interactive` with piped `q` → aborts, no branch created

---

## 6. Dependency Ordering

```
Unit 1 (interactive_session_select.sh)
  │
  ├──► Unit 2 (apply wiring — depends on Unit 1)
  │
  ├──► Unit 3 (draft wiring — depends on Unit 1)
  │
  ├──► Unit 4 (Makefile — independent, can run in parallel with 2/3)
  │
  └──► Unit 5 (tests — depends on Units 1-4)
```

---

## 7. Acceptance Criteria (Provisional)

1. `echo y | agent-sandbox apply --project=<path> --sandbox=<path> --interactive` applies the resolved diff
2. `echo n | agent-sandbox apply --project=<path> --sandbox=<path> --interactive` aborts without applying
3. `echo 1 | echo 1 | agent-sandbox draft --project=<path> --sandbox=<path> --interactive` creates a draft branch (picks channel 1, then session 1)
4. `echo q | agent-sandbox draft --project=<path> --sandbox=<path> --interactive` aborts at channel prompt
5. `make apply INTERACTIVE=1` passes `--interactive` through to `agent-sandbox apply`
6. `make draft INTERACTIVE=1 FROM=bundles` passes `--interactive --channel=bundles` through
7. Non-interactive mode behaviour is unchanged — full test suite passes
8. `draft --interactive` with zero sessions prints "No sessions available." and exits non-zero
9. `apply --interactive --diff=<path>` shows the path and prompts once (no channel/session steps)
10. `draft --interactive --channel=autosave --session=foo` shows patch list and confirms once (no picker steps)
11. Architecture documents in scope describe the system as built

---

## 8. Remaining Design Questions

No open questions remain. All Q-B entries resolved. Design is ready for Gate 2 (acceptance criteria confirmation) and implementation.

---

## 9. References

| Document | Purpose |
|---|---|
| `recovery-design-step-b.md` (input file) | Source design surface |
| `design_change_a_contract.md` | Precedent design doc format, CLI contract, channel model |
| `design_diff_and_branch_packaging_workflow.md` | Core diff pipeline |
| `libs/routing.sh` | Router functions |
| `libs/dirs.sh` | Path derivation |
| `scripts/agent-sandbox.sh` | Dispatch entry point |
| `libs/_templates/Makefile.template` | Makefile template |
| `tests/libs/git_fixtures.sh` | Git repo setup helpers |
| `tests/libs/session_fixtures.sh` | Session directory structure helpers |
| `tests/libs/test_common.sh` | Test framework |
