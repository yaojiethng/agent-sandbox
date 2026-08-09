#!/usr/bin/env bash
# tests/libs/session_fixtures.sh
# Session fixture helpers for workflow tests.

# make_session_fixture DIR [PATCHES] [UNCOMMITTED]
#   Creates a session fixture directory with standard session structure.
#   Replaces make_export_with_diffs, make_export_with_diffs_and_uncommitted,
#   make_diffs_session, make_changes_session, and create_fixture_session.
#
#   DIR         - Target directory (created if absent)
#   PATCHES     - Number of numbered .diff files to create in patches/ (default: 0)
#   UNCOMMITTED - "content" (non-empty), "empty" (empty file), or "none" (default: "none")
#
#   Patch files are valid git diffs adding file-N.txt.
#   uncommitted.diff (when not "none") diffs uncommitted.txt.
#   Also writes a minimal .export-status (consolidated metadata) for draft.sh.
make_session_fixture() {
  local DIR="$1"
  local PATCHES="${2:-0}"
  local UNCOMMITTED="${3:-none}"

  mkdir -p "$DIR"

  if [[ "$PATCHES" -gt 0 ]]; then
    mkdir -p "$DIR/patches"
    local i
    for i in $(seq 1 "$PATCHES"); do
      local PADDING
      PADDING=$(printf "%04d" "$i")
      cat > "$DIR/patches/${PADDING}-abc1234.diff" <<EOF
diff --git a/file-${i}.txt b/file-${i}.txt
new file mode 100644
--- /dev/null
+++ b/file-${i}.txt
@@ -0,0 +1 @@
+change ${i}
EOF
    done
  fi

  if [[ "$UNCOMMITTED" == "content" ]]; then
    cat > "$DIR/uncommitted.diff" <<'EOF'
diff --git a/uncommitted.txt b/uncommitted.txt
new file mode 100644
--- /dev/null
+++ b/uncommitted.txt
@@ -0,0 +1 @@
+uncommitted change
EOF
  elif [[ "$UNCOMMITTED" == "empty" ]]; then
    > "$DIR/uncommitted.diff"
  fi

  # Write consolidated .export-status for draft.sh consumption
  {
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=20260408-120000"
    echo "INIT_SHA=0000000000000000000000000000000000000000"
  } > "$DIR/.export-status"
}
