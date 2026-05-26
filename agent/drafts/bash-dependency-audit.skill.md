# Skill — Bash Dependency and Path Resolution Audit

**Status:** Draft — developed during the path resolution convention design (session 20260526-04). Codifies the process for auditing how shell files resolve their dependencies and determine their runtime context.

## Purpose

Systematically catalogues how every shell file in a codebase resolves its own location and sources its dependencies. Identifies inconsistencies, standardisation opportunities, misplaced files, and control flow violations. Produces a migration spec ready for implementation.

## When to Use

- Before a file restructuring or reorganisation that involves moving shell files
- When establishing or enforcing a path resolution convention
- When investigating "file not found" or "command not found" errors that trace back to broken source paths
- When onboarding to a new codebase with organic shell script growth

---

## Audit Process

### Step 1 — Catalogue All Shell Files

List every shell file in scope. Group by directory:

```bash
# libs/
ls libs/*.sh

# scripts/
ls scripts/*.sh

# tests/
ls tests/test_*.sh tests/knowledge/*.sh

# Dockerfiles (COPY paths)
grep '^COPY.*\.sh' libs/*.Dockerfile providers/*/*.Dockerfile
```

### Step 2 — Find Every Source Statement

For each file, extract all `source` statements and classify the path resolution pattern:

```bash
# Per file: find all source statements
grep -n '^source' path/to/file.sh
```

Classify each hit by pattern:

| Pattern | Example | Context |
|---|---|---|
| **Hardcoded absolute** | `source /opt/sandbox/lib/session.sh` | Container-only — path baked into image |
| **Macro** | `source "$AGENT_SANDBOX_REPO/libs/containers.sh"` | Host installed CLI — macro set at install time |
| **Repo root variable** | `source "$REPO_ROOT/libs/session.sh"` | Host scripts running from checkout |
| **Self-resolution variable** | `source "$_PB_SCRIPT_DIR/session.sh"` | Cross-context — file computes own location |
| **Inline self-resolution** | `source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session.sh"` | Same as above but without cached variable |
| **Relative path** | `source "$SCRIPT_DIR/../libs/diff.sh"` | Test files — relative from test dir |
| **Inline exec** | `bash "$(cd ... && pwd)/../libs/foo.sh"` | Executable call (not source) with dynamic path |

### Step 3 — Map the Self-Resolution Variable Names

For every file that uses self-resolution (either variable or inline), extract the variable name:

```bash
# Find all self-resolution variable declarations
grep -E '^_[A-Z_]+_DIR="' libs/*.sh
# Find inline self-resolution (no variable cached)
grep -n '\$(cd.*\$(dirname.*\${BASH_SOURCE\[0\]})' libs/*.sh
```

Note inconsistencies:
- Which files cache the result in a variable vs recompute inline?
- What naming convention is used? (`_DIR`, `_SH_DIR`, `_SCRIPT_DIR`, `_LIB`?)
- Are there multiple names for the same pattern?

### Step 4 — Find Dockerfile COPY Paths

Dockerfiles copy source files from the host tree into the image. These paths will break when source files move:

```bash
grep '^COPY' libs/*.Dockerfile providers/*/*.Dockerfile
```

Mark each COPY line's source path and its target path in the container.

### Step 5 — Map the Control Flow Constraints

Verify the dependency graph follows directional rules:

```
scripts/  ──→ libs/shared/          host scripts source shared libs
scripts/  ──→ scripts/              may source other scripts if logically
                                      a library (e.g. checkpoint.sh)
libs/*    ──→ libs/shared/ only    libs never source scripts
tests/*   ──→ anything              tests can source everything
☐ nothing ──→ tests/               nothing sources tests
containers ──→ libs/shared/ only   entrypoints only source shared libs
```

Check for violations:

```bash
# libs sourcing scripts (forbidden)
for f in libs/*.sh; do
  targets=$(grep '^source.*scripts/' "$f" 2>/dev/null)
  if [[ -n "$targets" ]]; then echo "VIOLATION: $f sources scripts/"; fi
done

# scripts sourcing tests (forbidden)
for f in scripts/*.sh; do
  targets=$(grep '^source.*tests/' "$f" 2>/dev/null)
  if [[ -n "$targets" ]]; then echo "VIOLATION: $f sources tests/"; fi
done
```

Also flag **misplaced files** — files in the wrong directory given their role:

```bash
# Files in scripts/ that only define functions (libraries, not executables)
for f in scripts/*.sh; do
  # Has function definitions but no main() — likely a library
  has_fns=$(grep -c '^[a-zA-Z_][a-zA-Z_]*()' "$f" 2>/dev/null || echo 0)
  is_sourced=$(grep -l "^source.*$(basename $f)" scripts/*.sh libs/*.sh 2>/dev/null)
  if [[ "$has_fns" -gt 0 && -n "$is_sourced" ]]; then
    echo "MISPLACED: $f is a library (sourced by $is_sourced)"
  fi
done
```

### Step 6 — Build the Migration Table

For every source/COPY/exec path that will change, list:

| File | Old path | New path | Convention |
|---|---|---|---|
| `scripts/agent-sandbox.sh` | `$AGENT_SANDBOX_REPO/libs/containers.sh` | `$AGENT_SANDBOX_REPO/build/image.sh` | `$AGENT_SANDBOX_REPO` |
| `libs/diff.sh` | `$_DIFF_SH_DIR/session.sh` | `$_self_dir/session.sh` | Self-resolution |

This table is the implementation spec.

### Step 7 — Determine the Convention Per Layer

After cataloguing, decide the convention for each runtime context:

| Context | Convention | Variable/Pattern | Why |
|---|---|---|---|
| Container entrypoints | Hardcoded `/opt/sandbox/lib/` | Absolute path | Baked into image at build time |
| Cross-context (shared libs) | Self-resolution | `_self_dir` | Must work in host and container |
| Host installed CLI | Macro | `$AGENT_SANDBOX_REPO` | Must survive `make install` |
| Host repo scripts | Repo root | `$REPO_ROOT` | Always run from checkout |
| Host libs sourced by CLI | Macro (inherited) | `$AGENT_SANDBOX_REPO` | Only sourced by CLI |
| Test files | Repo root | `$REPO_ROOT` | Always run from checkout |

---

## Output

The audit produces two deliverables:

1. **Migration spec** — a table of every source/COPY/exec path with old → new mapping, ready for implementation
2. **Convention document** — a concise reference defining the layered convention, suitable for publishing as a project concept doc

Both should be reviewed before any file moves or path updates begin.
