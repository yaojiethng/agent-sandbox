#!/usr/bin/env bash
# tests/libs/session_fixtures.sh
# Session directory structure helpers for workflow tests.

# make_export_with_diffs EXPORT_DIR [NUM_DIFFS]
#   Creates a session directory with numbered .diff files in patches/.
#   Also creates EXPORT-TIME.txt and uncommitted.diff.
#   Patches are at the top level of EXPORT_DIR (not inside a session/ subdir).
#   This matches the contract for draft_run's SOURCE_DIR parameter.
make_export_with_diffs() {
  local EXPORT_DIR="$1"
  local NUM_DIFFS="${2:-2}"

  mkdir -p "$EXPORT_DIR/patches"

  echo "20260420-120000" > "$EXPORT_DIR/EXPORT-TIME.txt"
  > "$EXPORT_DIR/uncommitted.diff"

  for i in $(seq 1 "$NUM_DIFFS"); do
    local PADDING
    PADDING=$(printf "%04d" "$i")
    cat > "$EXPORT_DIR/patches/${PADDING}-abc1234.diff" <<EOF
diff --git a/file-${i}.txt b/file-${i}.txt
new file mode 100644
--- /dev/null
+++ b/file-${i}.txt
@@ -0,0 +1 @@
+change ${i}
EOF
  done
}

# make_export_with_diffs_and_uncommitted EXPORT_DIR [NUM_DIFFS]
#   Like make_export_with_diffs, but also creates a non-empty uncommitted.diff.
make_export_with_diffs_and_uncommitted() {
  local EXPORT_DIR="$1"
  local NUM_DIFFS="${2:-2}"

  make_export_with_diffs "$EXPORT_DIR" "$NUM_DIFFS"

  cat > "$EXPORT_DIR/uncommitted.diff" <<'EOF'
diff --git a/uncommitted.txt b/uncommitted.txt
new file mode 100644
--- /dev/null
+++ b/uncommitted.txt
@@ -0,0 +1 @@
+uncommitted change
EOF
}

# make_diffs_session SESSION_NAME DIFFS_DIR
#   Creates a session directory under DIFFS_DIR with a flat uncommitted.diff.
#   Used by apply tests that need a diff file under output/diffs/.
make_diffs_session() {
  local SESSION_NAME="$1"
  local DIFFS_DIR="$2"

  mkdir -p "$DIFFS_DIR/$SESSION_NAME"

  cat > "$DIFFS_DIR/$SESSION_NAME/uncommitted.diff" <<'EOF'
diff --git a/output-file.txt b/output-file.txt
new file mode 100644
--- /dev/null
+++ b/output-file.txt
@@ -0,0 +1 @@
+output change
EOF

  cat > "$DIFFS_DIR/$SESSION_NAME/migration-guide.md" <<'EOF'
# Migration Guide

This session adds output-file.txt.

Review before applying.
EOF
}

# make_changes_session SESSION_NAME CHANGES_DIR
#   Creates a session directory under CHANGES_DIR with session/uncommitted.diff.
make_changes_session() {
  local SESSION_NAME="$1"
  local CHANGES_DIR="$2"

  mkdir -p "$CHANGES_DIR/$SESSION_NAME/session"

  cat > "$CHANGES_DIR/$SESSION_NAME/session/uncommitted.diff" <<'EOF'
diff --git a/output-file.txt b/output-file.txt
new file mode 100644
--- /dev/null
+++ b/output-file.txt
@@ -0,0 +1 @@
+output change
EOF
}
