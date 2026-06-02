# Design: Dispatch Cleanup and Help System

**Date:** 2026-05-30
**Status:** Approved — ready for implementation

## 1. Help System

### 1.1 Command interface

- `agent-sandbox help` — prints list of valid subcommands (hardcoded list)
- `agent-sandbox help <subcommand>` — prints usage for that subcommand
- `<subcommand> --help` also triggers usage output (works when subcommand scripts are called directly)

### 1.2 Implementation

Each subcommand script defines a `usage()` function that prints its help text to stdout and exits 0. This includes `build.sh`, `onboard.sh`, `stop.sh`, `start_agent.sh`, and all workflow scripts under `scripts/workflows/`.

The dispatcher's `help)` case:

```bash
help)
  if [[ -z "${1:-}" ]]; then
    echo "Usage: agent-sandbox <subcommand> [flags]"
    echo "Valid subcommands: onboard, build, start, serve, dry-run, stop, apply, draft, confirm, reject, package-diff, package-branch"
    exit 0
  fi
  exec bash "$SCRIPTS/$1.sh" --help 2>/dev/null \
    || exec bash "$SCRIPTS/workflows/$1.sh" --help 2>/dev/null \
    || { echo "Unknown subcommand: $1" >&2; exit 1; }
  ;;
```

When `--help` is passed to a subcommand script, its `main()` detects it as the first argument, calls `usage()`, and exits 0 before any validation runs.

### 1.3 Usage string format

```
Usage: agent-sandbox apply --project=<path> --sandbox=<path> [options]

Applies a diff file to the project working tree. Does not commit.

Required:
  --project=<path>    Path to the git repository
  --sandbox=<path>    Path to the sandbox directory

Options:
  --diff=<path>       Apply a specific diff file (default: auto-resolve)
  --branch=<name>     Check out or create a branch before applying
  --channel=<name>    Resolution channel: diffs, session, autosave (default: diffs)
  --session=<name>    Named session to resolve from (default: newest)
  --force             Apply with --reject for conflicts
  --interactive       Interactive picker mode
```

### 1.4 Error-to-help flow

When invalid flags are passed, the subcommand script's `main()` detects this in its `*)` case, calls `usage()` to stderr, and exits 1. The usage string serves as the error message.

### 1.5 Future improvement — automatic discovery

The valid subcommand list is currently hardcoded. A future improvement is to scan `$SCRIPTS/workflows/` and discover subcommand scripts automatically. Deferred — see roadmap.

---

## 2. Flag Group Taxonomy

### 2.1 Principles

- Flag groups are a **documentation concept**, not a code enforcement mechanism.
- A flag with a given name always has the same value type wherever it appears.
- Shared flag parsing logic lives in `libs/` files called by multiple subcommand scripts.
- Single-use flag parsing lives in the subcommand's `main()`.
- The taxonomy catalogs which flags are shared and where their canonical parsing lives.

### 2.2 Decision rule: shared lib vs subcommand-specific

A flag's parsing goes into a shared lib when both conditions hold:
1. The flag name and value type are identical across two or more subcommands
2. The parsing logic is non-trivial (beyond a simple `${ARG#--flag=}` assignment)

Otherwise, parsing stays in the subcommand's `main()`.

### 2.3 Catalogue

| Flag | Type | Shared by | Canonical parser |
|---|---|---|---|
| `--sandbox=<path>` | string | All subcommands | `parse_flags` in `agent-sandbox.sh` |
| `--project=<path>` | string | build, apply, draft, confirm, reject, start, serve, dry-run | `parse_flags` in `agent-sandbox.sh` |
| `--name=<name>` | string | build, start, serve, dry-run, stop | `parse_flags` in `agent-sandbox.sh` |
| `--channel=<name>` | string | apply, draft | `resolve_channel_base_dir` in `routing.sh` |
| `--session=<name>` | string | apply, draft | Each subcommand's `main()` |
| `--branch=<name>` | string | apply | `apply.sh`'s `main()` |
| `--branch-from=<sha>` | string | draft | `draft.sh`'s `main()` |
| `--diff=<path>` | string | apply | `apply.sh`'s `main()` |
| `--diffs=<range>` | string | draft | `draft.sh`'s `main()` |
| `--branch-summary=<slug>` | string | draft | `draft.sh`'s `main()` |
| `--target=<branch>` | string | confirm, build (legacy) | `confirm.sh`'s `main()`; `build.sh` normalises to `--targets` |
| `--targets=<list>` | string | build | `build.sh`'s `main()` |
| `--force` | boolean | apply | `apply.sh`'s `main()` |
| `--permissive` | boolean | apply | `apply.sh`'s `main()` |
| `--interactive` | boolean | apply, draft | Each subcommand's `main()` |
| `--provider=<name>` | string | start, serve, dry-run | Passed through via `PASSTHROUGH`; parsed by `start_agent.sh` |
| `--refresh` | boolean | start, serve, dry-run | Passed through via `PASSTHROUGH`; parsed by `start_agent.sh` |
| `--rebuild` | boolean | start, serve, dry-run, build | Passed through via `PASSTHROUGH`; parsed by `build.sh` or `start_agent.sh` |
| `--to=<path>` | string | package-diff, package-branch | Package scripts' own `main()` |
| `--session-summary=<text>` | string | package-diff, package-branch | Package scripts' own `main()` |
| `--all` | boolean | package-diff | `package_diff.sh`'s `main()` |
| `--baseline=<sha>` | string | package-diff, package-branch | Package scripts' own `main()` |

---

## 3. Streamlined Dispatch Architecture

### 3.1 What `parse_flags` extracts

`parse_flags` extracts exactly 3 flags:
- `--name`, `--project`, `--sandbox` — the universal flags

Everything else goes to `PASSTHROUGH` unmodified. No `rebuild_flags()` or `require_provider_args()` at the dispatch level.

### 3.2 What the dispatch layer validates

`require_base_args()` checks `--name`, `--project`, `--sandbox` are present. Called by every dispatch case that uses them.

No other validation at the dispatch layer. Each subcommand script validates its own required flags in its `main()`.

### 3.3 Standard dispatch case pattern

```bash
build)
  require_base_args
  exec bash "$SCRIPTS/build.sh" \
    --name="$PROJECT_NAME" \
    --project="$PROJECT_DIR" \
    --sandbox="$SANDBOX_DIR" \
    "${PASSTHROUGH[@]}"
  ;;
```

The three universal flags are re-appended explicitly. Everything the user typed beyond those three is forwarded as-is in `PASSTHROUGH`. The subcommand script receives all its flags in `$@`.

The `build` case is the sole exception to the passthrough rule: it normalises the legacy `--target` flag to `--targets` via a simple pre-loop before `parse_flags`.

### 3.4 `PASSTHROUGH` guarantees

- Every flag not recognised by `parse_flags` appears in `PASSTHROUGH` in the order it was given.
- `PASSTHROUGH` is an array, not a string — handles flags with spaces correctly.
- The subcommand's `$@` receives universal flags first, then the passthrough flags in original order.

---

## 4. Implementation Phases

### Phase 1 — Help system (no behaviour change)

- Add `usage()` to each subcommand script
- Add `help)` case to `agent-sandbox.sh` dispatch
- Add `--help` handling to each subcommand's `main()` (calls `usage()` before validation)
- Update `*)` error case in each subcommand to call `usage()` instead of ad-hoc error text

### Phase 2 — Streamlined dispatch (behaviour change)

- Reduce `parse_flags` to 3 universal flags
- Remove `rebuild_flags()`, `require_provider_args()` from dispatcher
- Remove unused local variable declarations from `main()` scope
- Update each dispatch case to use `"${PASSTHROUGH[@]}"` pattern
- Remove redundant flag parsing from subcommand scripts (they parse from `$@` instead of pre-parsed variables — but many already do this since the dispatch refactor)

### Phase 3 — Cleanup

- Update `tests/test_dispatch.sh` to reflect new flag flow
- Verify full test suite passes
