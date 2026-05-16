#!/usr/bin/env bash
# libs/interactive_session_select.sh
#
# Interactive session selection helpers for agent-sandbox apply and draft.
# All output (prompts, tables, errors) goes to stderr. Only the selected
# value (channel name, session name, or diff type) is printed to stdout.
#
# Dependencies:
#   libs/routing.sh — for dirs_resolve (path derivation)
#
# Usage:
#   source /path/to/interactive_session_select.sh
#   CHANNEL=$(interactive_select_channel "draft" "$SANDBOX_DIR" "session") || exit 1
#   SESSION=$(interactive_select_session "$SANDBOX_DIR" "$CHANNEL") || exit 1
#
# Functions:
#   interactive_confirm_or_abort   — print items + y/N prompt
#   interactive_select_channel     — pick a channel (draft or apply)
#   interactive_select_session     — pick a session entry within a channel
#   interactive_select_diff_type   — pick uncommitted.diff or all-changes.diff

set -euo pipefail

# Source routing.sh for dirs_resolve
_ISS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_ISS_SCRIPT_DIR/routing.sh"

# Max entries to display in session picker. Hardcoded — change here if needed.
INTERACTIVE_MAX_ENTRIES=10

# =============================================================================
# interactive_confirm_or_abort
# =============================================================================

# interactive_confirm_or_abort LABEL ITEMS...
#
# Prints a label and list of items to stderr, then prompts "Proceed? [y/N]".
# Reads from stdin. Warns to stderr if stdin is not a terminal.
# Returns 0 on y/Y, 1 on anything else.
#
# Args:
#   LABEL  — header text (empty string skips the label line)
#   ITEMS  — one or more strings to display (one per line)
#
# Output:
#   stderr — label, items, prompt, abort message
#   stdout — nothing (selected value is the return code)
#
# Example:
#   interactive_confirm_or_abort "Apply:" "/path/to/uncommitted.diff" || exit 1
interactive_confirm_or_abort() {
  local LABEL="$1"
  shift

  if [[ -n "$LABEL" ]]; then
    echo "$LABEL" >&2
  fi
  for item in "$@"; do
    echo "  $item" >&2
  done
  if [[ "$#" -gt 0 ]]; then
    echo "" >&2
  fi
  if ! test -t 0; then
    echo "Warning: stdin is not a terminal; interactive prompts may not display correctly." >&2
  fi
  read -r -p "Proceed? [y/N] " REPLY || true
  case "$REPLY" in
    y|Y) return 0 ;;
    *)
      echo "Aborted." >&2
      return 1
      ;;
  esac
}

# =============================================================================
# interactive_select_channel
# =============================================================================

# interactive_select_channel SUBCOMMAND SANDBOX_DIR [DEFAULT_CHANNEL]
#
# Scans eligible channels for the given subcommand and presents a numbered
# picker. Each channel shows entry count and newest session timestamp.
#
# Args:
#   SUBCOMMAND      — "apply" or "draft" (determines which channels are shown)
#   SANDBOX_DIR     — path to sandbox directory (for dirs_resolve)
#   DEFAULT_CHANNEL — optional; highlighted as default, empty enter selects it
#
# Output:
#   stdout — selected channel name (e.g. "session", "autosave", "bundles", "diffs")
#
# Returns:
#   0 on selection, 1 on abort (q/Q or EOF)
interactive_select_channel() {
  local SUBCOMMAND="$1"
  local SANDBOX_DIR="$2"
  local DEFAULT_CHANNEL="${3:-}"

  dirs_resolve "$SANDBOX_DIR"

  # Define eligible channels per subcommand
  local -a CHANNELS=()
  case "$SUBCOMMAND" in
    apply) CHANNELS=("diffs" "autosave" "session") ;;
    draft) CHANNELS=("session" "autosave" "bundles") ;;
    *)
      echo "Error: unknown subcommand: $SUBCOMMAND" >&2
      return 1
      ;;
  esac

  # Resolve base directory for each channel and count entries
  local -a CH_NAMES=()
  local -a CH_COUNTS=()
  local -a CH_NEWEST=()
  local CH_DEFAULT_INDEX=0

  for ch in "${CHANNELS[@]}"; do
    local BASE_DIR=""
    case "$ch" in
      diffs)    BASE_DIR="${OUTPUT_DIR}/diffs" ;;
      autosave) BASE_DIR="${CHANGES_DIR}/autosave" ;;
      session)  BASE_DIR="${CHANGES_DIR}/session" ;;
      bundles)  BASE_DIR="${OUTPUT_DIR}/bundles" ;;
    esac

    local COUNT=0
    local NEWEST=""
    if [[ -d "$BASE_DIR" ]]; then
      local DIR_LIST
      DIR_LIST=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
      if [[ -n "$DIR_LIST" ]]; then
        COUNT=$(echo "$DIR_LIST" | wc -l)
        NEWEST=$(echo "$DIR_LIST" | head -1 | xargs basename 2>/dev/null || true)
      fi
    fi
    CH_NAMES+=("$ch")
    CH_COUNTS+=("$COUNT")
    CH_NEWEST+=("$NEWEST")
  done

  # Find default index
  if [[ -n "$DEFAULT_CHANNEL" ]]; then
    for idx in "${!CH_NAMES[@]}"; do
      if [[ "${CH_NAMES[$idx]}" == "$DEFAULT_CHANNEL" ]]; then
        CH_DEFAULT_INDEX=$idx
        break
      fi
    done
  fi

  # Print table
  echo "Available channels:" >&2
  for idx in "${!CH_NAMES[@]}"; do
    local NUM=$((idx + 1))
    local CH_NAME="${CH_NAMES[$idx]}"
    local COUNT="${CH_COUNTS[$idx]}"
    local NEWEST_TS="${CH_NEWEST[$idx]}"
    if [[ "$COUNT" -gt 0 && -n "$NEWEST_TS" ]]; then
      printf "  %d: %-12s (%d entries, newest: %s)\n" "$NUM" "$CH_NAME" "$COUNT" "$NEWEST_TS" >&2
    else
      printf "  %d: %-12s (0 entries)\n" "$NUM" "$CH_NAME" >&2
    fi
  done

  # Prompt loop
  local TOTAL="${#CH_NAMES[@]}"
  while true; do
    echo "" >&2
    local PROMPT="Selection [1-${TOTAL}, q to quit"
    if [[ -n "$DEFAULT_CHANNEL" ]]; then
      PROMPT="${PROMPT}, Enter for ${DEFAULT_CHANNEL}"
    fi
    PROMPT="${PROMPT}]: "
    read -r -p "$PROMPT" REPLY || true

    # Empty input with default
    if [[ -z "$REPLY" && -n "$DEFAULT_CHANNEL" ]]; then
      echo "$DEFAULT_CHANNEL"
      return 0
    fi

    # Quit
    if [[ "$REPLY" == "q" || "$REPLY" == "Q" ]]; then
      echo "Aborted." >&2
      return 1
    fi

    # Number selection
    if [[ "$REPLY" =~ ^[0-9]+$ ]]; then
      local IDX=$((REPLY - 1))
      if [[ "$IDX" -ge 0 && "$IDX" -lt "$TOTAL" ]]; then
        echo "${CH_NAMES[$IDX]}"
        return 0
      fi
    fi

    echo "Invalid selection. Try again." >&2
  done
}

# =============================================================================
# interactive_select_session
# =============================================================================

# interactive_select_session SANDBOX_DIR CHANNEL [DEFAULT_SESSION]
#
# Scans session entries under the resolved channel directory and presents
# a numbered list with availability indicators (patches, uncommitted.diff).
#
# Args:
#   SANDBOX_DIR      — path to sandbox directory (for dirs_resolve)
#   CHANNEL          — channel name (diffs, session, autosave, bundles)
#   DEFAULT_SESSION  — optional session name to highlight as default
#
# Output:
#   stdout — selected session basename (e.g. "20260504-120000-feature-X")
#
# Returns:
#   0 on selection, 1 on abort or no sessions
interactive_select_session() {
  local SANDBOX_DIR="$1"
  local CHANNEL="$2"
  local DEFAULT_SESSION="${3:-}"

  dirs_resolve "$SANDBOX_DIR"

  # Resolve base directory
  local BASE_DIR=""
  case "$CHANNEL" in
    diffs)    BASE_DIR="${OUTPUT_DIR}/diffs" ;;
    autosave) BASE_DIR="${CHANGES_DIR}/autosave" ;;
    session)  BASE_DIR="${CHANGES_DIR}/session" ;;
    bundles)  BASE_DIR="${OUTPUT_DIR}/bundles" ;;
    *)
      echo "Error: unknown channel: $CHANNEL" >&2
      return 1
      ;;
  esac

  if [[ ! -d "$BASE_DIR" ]]; then
    echo "No sessions available in channel '$CHANNEL'." >&2
    return 1
  fi

  # Collect entries, sorted newest-first (SESSION_TS prefix)
  local -a ENTRIES=()
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    ENTRIES+=("$(basename "$dir")")
  done < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)

  if [[ "${#ENTRIES[@]}" -eq 0 ]]; then
    echo "No sessions available in channel '$CHANNEL'." >&2
    return 1
  fi

  # Determine display count (cap at MAX_ENTRIES)
  local TOTAL_COUNT="${#ENTRIES[@]}"
  local DISPLAY_COUNT="$TOTAL_COUNT"
  if [[ "$DISPLAY_COUNT" -gt "$INTERACTIVE_MAX_ENTRIES" ]]; then
    DISPLAY_COUNT="$INTERACTIVE_MAX_ENTRIES"
  fi

  # Find default index
  local DEFAULT_INDEX=-1
  if [[ -n "$DEFAULT_SESSION" ]]; then
    for idx in "${!ENTRIES[@]}"; do
      if [[ "${ENTRIES[$idx]}" == "$DEFAULT_SESSION" ]]; then
        DEFAULT_INDEX=$idx
        break
      fi
    done
  fi

  # Print table
  echo "Available sessions (${CHANNEL}):" >&2
  for ((idx=0; idx<DISPLAY_COUNT; idx++)); do
    local BNAME="${ENTRIES[$idx]}"
    local NUM=$((idx + 1))

    # Check availability
    local HAS_PATCHES="✗"
    local HAS_UNCOMMITTED="✗"
    local ENTRY_DIR="${BASE_DIR}/${BNAME}"
    if [[ -d "$ENTRY_DIR/patches" ]] && find "$ENTRY_DIR/patches" -maxdepth 1 -name '*.diff' -print -quit | grep -q . 2>/dev/null; then
      HAS_PATCHES="✓"
    fi
    if [[ -f "$ENTRY_DIR/uncommitted.diff" && -s "$ENTRY_DIR/uncommitted.diff" ]]; then
      HAS_UNCOMMITTED="✓"
    fi

    # Truncate long names
    local DISPLAY_NAME="$BNAME"
    if [[ ${#DISPLAY_NAME} -gt 50 ]]; then
      DISPLAY_NAME="${DISPLAY_NAME:0:47}..."
    fi

    printf "  %d: %-50s patches: %s  uncommitted: %s\n" "$NUM" "$DISPLAY_NAME" "$HAS_PATCHES" "$HAS_UNCOMMITTED" >&2
  done

  # Overflow hint
  if [[ "$TOTAL_COUNT" -gt "$INTERACTIVE_MAX_ENTRIES" ]]; then
    local REMAINING=$((TOTAL_COUNT - INTERACTIVE_MAX_ENTRIES))
    echo "  ... and $REMAINING more. Use SESSION=<name> to select older sessions directly." >&2
  fi

  # Prompt loop
  while true; do
    echo "" >&2
    local PROMPT="Selection [1-${DISPLAY_COUNT}, q to quit"
    if [[ "$DEFAULT_INDEX" -ge 0 ]]; then
      PROMPT="${PROMPT}, Enter for ${DEFAULT_SESSION}"
    fi
    PROMPT="${PROMPT}]: "
    read -r -p "$PROMPT" REPLY || true

    # Empty input with default
    if [[ -z "$REPLY" && "$DEFAULT_INDEX" -ge 0 ]]; then
      echo "$DEFAULT_SESSION"
      return 0
    fi

    # Quit
    if [[ "$REPLY" == "q" || "$REPLY" == "Q" ]]; then
      echo "Aborted." >&2
      return 1
    fi

    # Number selection
    if [[ "$REPLY" =~ ^[0-9]+$ ]]; then
      local IDX=$((REPLY - 1))
      if [[ "$IDX" -ge 0 && "$IDX" -lt "$DISPLAY_COUNT" ]]; then
        echo "${ENTRIES[$IDX]}"
        return 0
      fi
    fi

    echo "Invalid selection. Try again." >&2
  done
}

# =============================================================================
# interactive_select_diff_type
# =============================================================================

# interactive_select_diff_type SANDBOX_DIR SESSION_NAME CHANNEL
#
# Presents a picker for diff file type (uncommitted.diff or all-changes.diff).
# If only one type is available, skips the prompt and returns it directly.
#
# Args:
#   SANDBOX_DIR   — path to sandbox directory (for dirs_resolve)
#   SESSION_NAME  — session basename
#   CHANNEL       — channel name (diffs, session, autosave, bundles)
#
# Output:
#   stdout — "uncommitted" or "all-changes"
#
# Returns:
#   0 on selection, 1 on abort or no diff files found
interactive_select_diff_type() {
  local SANDBOX_DIR="$1"
  local SESSION_NAME="$2"
  local CHANNEL="$3"

  _resolve_paths "$SANDBOX_DIR"

  local BASE_DIR=""
  case "$CHANNEL" in
    diffs)    BASE_DIR="${OUTPUT_DIR}/diffs" ;;
    autosave) BASE_DIR="${CHANGES_DIR}/autosave" ;;
    session)  BASE_DIR="${CHANGES_DIR}/session" ;;
    bundles)  BASE_DIR="${OUTPUT_DIR}/bundles" ;;
    *)
      echo "Error: unknown channel: $CHANNEL" >&2
      return 1
      ;;
  esac

  local SESSION_DIR="${BASE_DIR}/${SESSION_NAME}"
  local HAS_UNCOMMITTED=false
  local HAS_ALL_CHANGES=false

  if [[ -f "$SESSION_DIR/uncommitted.diff" && -s "$SESSION_DIR/uncommitted.diff" ]]; then
    HAS_UNCOMMITTED=true
  fi
  if [[ -f "$SESSION_DIR/all-changes.diff" && -s "$SESSION_DIR/all-changes.diff" ]]; then
    HAS_ALL_CHANGES=true
  fi

  # Auto-select if only one type available
  if [[ "$HAS_UNCOMMITTED" == true && "$HAS_ALL_CHANGES" == false ]]; then
    echo "uncommitted"
    return 0
  fi
  if [[ "$HAS_UNCOMMITTED" == false && "$HAS_ALL_CHANGES" == true ]]; then
    echo "all-changes"
    return 0
  fi
  if [[ "$HAS_UNCOMMITTED" == false && "$HAS_ALL_CHANGES" == false ]]; then
    echo "Error: no diff files found in $SESSION_DIR" >&2
    return 1
  fi

  # Both available — prompt
  echo "Select diff file:" >&2
  echo "  1: uncommitted.diff (default)" >&2
  echo "  2: all-changes.diff" >&2
  echo "" >&2

  while true; do
    read -r -p "Selection [1-2, q to quit, Enter for uncommitted.diff]: " REPLY || true

    if [[ -z "$REPLY" ]]; then
      echo "uncommitted"
      return 0
    fi
    if [[ "$REPLY" == "q" || "$REPLY" == "Q" ]]; then
      echo "Aborted." >&2
      return 1
    fi
    if [[ "$REPLY" == "1" ]]; then
      echo "uncommitted"
      return 0
    fi
    if [[ "$REPLY" == "2" ]]; then
      echo "all-changes"
      return 0
    fi

    echo "Invalid selection. Try again." >&2
  done
}
