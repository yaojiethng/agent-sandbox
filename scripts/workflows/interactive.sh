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
#   CHANNEL=$(interactive_select_channel "draft" "$SANDBOX_DIR") || exit 1
#   BUNDLE=$(interactive_select_bundle "$SANDBOX_DIR" "$CHANNEL") || exit 1
#
# Functions:
#   interactive_confirm_or_abort   — print items + y/N prompt
#   interactive_select_channel     — pick a channel (draft or apply)
#   interactive_select_bundle     — pick a bundle entry within a channel

# No set -euo pipefail here — this file is always sourced, never executed directly.
# Safety settings are inherited from the parent script.

# Self-locate the repo root (mirrors draft.sh/apply.sh) so routing.sh can be
# sourced regardless of how interactive.sh is invoked. Callers may pre-set
# AGENT_SANDBOX_REPO (e.g. the dispatcher) to override the default.
: "${AGENT_SANDBOX_REPO:="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"}"
# Source routing.sh for dirs_resolve; common.sh for the shared picker page cap
# (INTERACTIVE_MAX_ENTRIES).
source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
source "$AGENT_SANDBOX_REPO/src/libs/common.sh"

# =============================================================================
# Internal helpers
# =============================================================================

# _resolve_channel_dir CHANNEL
#   Prints the base directory for the given channel name.
#   Sets OUTPUT_DIR and CHANGES_DIR via dirs_resolve first (caller must do it).
_resolve_channel_dir() {
  local CHANNEL="$1"
  resolve_channel_base_dir "$CHANNEL"
}

# =============================================================================
# interactive_pick — generic numbered picker
# =============================================================================

# interactive_pick LABEL ENTRIES_VAR [DEFAULT] [PAGE_SIZE] [AUTO_SELECT]
#
# Generic numbered picker. Displays a list of entries, lets the user pick one.
# All display output goes to stderr. The selected entry value goes to stdout.
#
# Args:
#   LABEL        — header text (printed to stderr)
#   ENTRIES_VAR  — name of an array variable where each element is
#                  "value|display-line". The picker splits on the first |:
#                  value = text before | (printed to stdout on selection)
#                  display-line = text after | (shown to stderr, or the
#                  whole element if no | is present)
#   DEFAULT      — optional default value; empty Enter selects it
#   PAGE_SIZE    — max entries per page (default: 0 = no pagination)
#   AUTO_SELECT  — if "true" and only one entry, skip prompt (default: false)
#
# Output:
#   stdout — selected value
#   stderr — display table, prompt, errors
#
# Returns:
#   0 on selection, 1 on abort (q/Q or EOF)
interactive_pick() {
  local LABEL="$1"
  local ENTRIES_VAR="$2"
  local DEFAULT="${3:-}"
  local PAGE_SIZE="${4:-0}"
  local AUTO_SELECT="${5:-false}"

  local -n _PICK_ENTRIES="$ENTRIES_VAR"
  local TOTAL="${#_PICK_ENTRIES[@]}"

  # Auto-select when only one entry
  if [[ "$AUTO_SELECT" == "true" && "$TOTAL" -eq 1 ]]; then
    local single="${_PICK_ENTRIES[0]}"
    echo "${single%%|*}"
    return 0
  fi

  if [[ "$TOTAL" -eq 0 ]]; then
    echo "No items available." >&2
    return 1
  fi

  # Pagination setup
  local TOTAL_PAGES=1
  if [[ "$PAGE_SIZE" -gt 0 ]]; then
    TOTAL_PAGES=$(( (TOTAL + PAGE_SIZE - 1) / PAGE_SIZE ))
  else
    PAGE_SIZE="$TOTAL"
  fi
  local PAGE_OFFSET=0

  # Find absolute index of default
  local DEFAULT_INDEX=-1
  if [[ -n "$DEFAULT" ]]; then
    local idx
    for idx in "${!_PICK_ENTRIES[@]}"; do
      local val="${_PICK_ENTRIES[$idx]}"
      val="${val%%|*}"
      if [[ "$val" == "$DEFAULT" ]]; then
        DEFAULT_INDEX=$idx
        break
      fi
    done
  fi

  while true; do
    local DISPLAY_START=$((PAGE_OFFSET * PAGE_SIZE))
    local DISPLAY_END=$((DISPLAY_START + PAGE_SIZE))
    [[ "$DISPLAY_END" -gt "$TOTAL" ]] && DISPLAY_END="$TOTAL"
    local PAGE_COUNT=$((DISPLAY_END - DISPLAY_START))

    # Decide whether to inject default as option 0
    local INJECT_ZERO=false
    local INJECTED_VALUE=""
    if [[ -n "$DEFAULT" ]]; then
      if [[ "$DEFAULT_INDEX" -ge 0 ]]; then
        if [[ "$DEFAULT_INDEX" -lt "$DISPLAY_START" || "$DEFAULT_INDEX" -ge "$DISPLAY_END" ]]; then
          INJECT_ZERO=true
          INJECTED_VALUE="$DEFAULT"
        fi
      else
        INJECT_ZERO=true
        INJECTED_VALUE="$DEFAULT"
      fi
    fi

    # Header
    if [[ "$TOTAL_PAGES" -gt 1 ]]; then
      echo "$LABEL — page $((PAGE_OFFSET + 1)) of $TOTAL_PAGES:" >&2
    else
      echo "$LABEL" >&2
    fi

    # Option 0 (injected default)
    if [[ "$INJECT_ZERO" == true ]]; then
      printf "  0: %-50s (selected)\n" "$INJECTED_VALUE" >&2
    fi

    # Entries
    local rel=1
    local abs
    for ((abs=DISPLAY_START; abs<DISPLAY_END; abs++)); do
      local entry="${_PICK_ENTRIES[$abs]}"
      local display="${entry#*|}"
      [[ "$display" == "$entry" ]] && display="$entry"
      printf "  %d: %s\n" "$rel" "$display" >&2
      rel=$((rel + 1))
    done

    # Build prompt
    echo "" >&2
    local PROMPT="Selection ["
    [[ "$PAGE_OFFSET" -gt 0 ]] && PROMPT="${PROMPT}p=prev, "
    [[ "$PAGE_OFFSET" -lt "$((TOTAL_PAGES - 1))" ]] && PROMPT="${PROMPT}n=next, "
    [[ "$INJECT_ZERO" == true ]] && PROMPT="${PROMPT}0-"
    PROMPT="${PROMPT}1-${PAGE_COUNT}, q to quit"
    local SHOW_ENTER=false
    [[ "$INJECT_ZERO" == true ]] && SHOW_ENTER=true
    [[ "$DEFAULT_INDEX" -ge 0 ]] && SHOW_ENTER=true
    if [[ "$SHOW_ENTER" == true && -n "$DEFAULT" ]]; then
      PROMPT="${PROMPT}, Enter for ${DEFAULT}"
    fi
    PROMPT="${PROMPT}]: "
    read -r -p "$PROMPT" REPLY || true

    # Empty input with default
    if [[ -z "$REPLY" ]]; then
      if [[ "$INJECT_ZERO" == true ]]; then
        echo "$INJECTED_VALUE"
        return 0
      elif [[ "$DEFAULT_INDEX" -ge 0 ]]; then
        echo "$DEFAULT"
        return 0
      fi
      echo "Invalid selection. Try again." >&2
      continue
    fi

    # Page navigation
    if [[ "$REPLY" == [nN] ]]; then
      [[ "$PAGE_OFFSET" -lt "$((TOTAL_PAGES - 1))" ]] && PAGE_OFFSET=$((PAGE_OFFSET + 1))
      continue
    fi
    if [[ "$REPLY" == [pP] ]]; then
      [[ "$PAGE_OFFSET" -gt 0 ]] && PAGE_OFFSET=$((PAGE_OFFSET - 1))
      continue
    fi

    # Quit
    if [[ "$REPLY" == [qQ] ]]; then
      echo "Aborted." >&2
      return 1
    fi

    # Option 0 (injected default)
    if [[ "$REPLY" == "0" && "$INJECT_ZERO" == true ]]; then
      echo "$INJECTED_VALUE"
      return 0
    fi

    # Number selection (1-PAGE_COUNT)
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && [[ "$REPLY" -gt 0 ]]; then
      local rel_idx=$((REPLY - 1))
      local abs_idx=$((DISPLAY_START + rel_idx))
      if [[ "$abs_idx" -ge "$DISPLAY_START" && "$abs_idx" -lt "$DISPLAY_END" ]]; then
        local selected="${_PICK_ENTRIES[$abs_idx]}"
        echo "${selected%%|*}"
        return 0
      fi
    fi

    echo "Invalid selection. Try again." >&2
  done
}

# =============================================================================
# interactive_confirm_or_abort
# =============================================================================

# interactive_confirm_or_abort LABEL ITEMS...
#
# Prints a label and list of items to stderr, then prompts "Proceed? [y/N]".
# Reads from stdin. Warns to stderr if stdin is not a terminal.
# Returns 0 on y/Y, 1 on anything else.
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
    draft) CHANNELS=("session" "autosave" "bundles") ;;
    *)
      echo "Error: unknown subcommand: $SUBCOMMAND" >&2
      return 1
      ;;
  esac

  # Build display entries: "name|name (N entries, newest: TS)"
  local -a ENTRIES=()
  local ch
  for ch in "${CHANNELS[@]}"; do
    local BASE_DIR
    BASE_DIR=$(_resolve_channel_dir "$ch") || return 1

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

    if [[ "$COUNT" -gt 0 && -n "$NEWEST" ]]; then
      ENTRIES+=("${ch}|${ch} (${COUNT} entries, newest: ${NEWEST})")
    else
      ENTRIES+=("${ch}|${ch} (0 entries)")
    fi
  done

  interactive_pick "Available channels:" ENTRIES "$DEFAULT_CHANNEL"
}

# =============================================================================
# interactive_select_bundle
# =============================================================================
# interactive_select_bundle SANDBOX_DIR CHANNEL [DEFAULT_BUNDLE]
#
# Scans bundle entries under the resolved channel directory and presents
# a numbered list with availability indicators (patches, uncommitted.diff).
#
# Args:
#   SANDBOX_DIR      — path to sandbox directory (for dirs_resolve)
#   CHANNEL          — channel name (diffs, session, autosave, bundles)
#   DEFAULT_BUNDLE   — optional bundle name to highlight as default
#
# Output:
#   stdout — selected bundle basename (e.g. "20260504-120000-feature-X")
#
# Returns:
#   0 on selection, 1 on abort or no bundles
interactive_select_bundle() {
  local SANDBOX_DIR="$1"
  local CHANNEL="$2"
  local DEFAULT_BUNDLE="${3:-}"

  dirs_resolve "$SANDBOX_DIR"

  local BASE_DIR
  BASE_DIR=$(_resolve_channel_dir "$CHANNEL") || return 1

  if [[ ! -d "$BASE_DIR" ]]; then
    echo "No bundles available in channel '$CHANNEL'." >&2
    return 1
  fi

  # Collect entries, sorted newest-first
  local -a BUNDLE_DIRS=()
  while IFS= read -r dir; do
    [[ -z "$dir" ]] && continue
    BUNDLE_DIRS+=("$(basename "$dir")")
  done < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)

  if [[ "${#BUNDLE_DIRS[@]}" -eq 0 ]]; then
    echo "No bundles available in channel '$CHANNEL'." >&2
    return 1
  fi

  # Build display entries: "name|name  patches: ✓  uncommitted: ✓"
  local -a ENTRIES=()
  local bname
  for bname in "${BUNDLE_DIRS[@]}"; do
    local ENTRY_DIR="${BASE_DIR}/${bname}"

    # Show the patch count rather than a binary presence indicator — the
    # number of .diff files is far more informative for judging a bundle.
    local PATCH_COUNT=0
    if [[ -d "$ENTRY_DIR/patches" ]]; then
      PATCH_COUNT=$(find "$ENTRY_DIR/patches" -maxdepth 1 -name '*.diff' 2>/dev/null | wc -l | tr -d ' ')
      PATCH_COUNT=$((10#$PATCH_COUNT))
    fi
    local HAS_UNCOMMITTED="✗"
    if [[ -f "$ENTRY_DIR/uncommitted.diff" && -s "$ENTRY_DIR/uncommitted.diff" ]]; then
      HAS_UNCOMMITTED="✓"
    fi

    # Truncate long names
    local DISPLAY_NAME="$bname"
    if [[ ${#DISPLAY_NAME} -gt 50 ]]; then
      DISPLAY_NAME="${DISPLAY_NAME:0:47}..."
    fi

    ENTRIES+=("${bname}|${DISPLAY_NAME}  patches: ${PATCH_COUNT}  uncommitted: ${HAS_UNCOMMITTED}")
  done

  interactive_pick "Available bundles (${CHANNEL}):" ENTRIES "$DEFAULT_BUNDLE" "$INTERACTIVE_MAX_ENTRIES"
}
