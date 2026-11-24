#!/usr/bin/env bash
# agent-sandbox
# Installed by: make install (agent-sandbox repo)
# Host-side CLI tool for managing agent-sandbox sessions and exports.
# All subcommands run on the host  --  never inside a container.
# Inside the container, invoke lib scripts directly (see prompt templates).
#
# The dispatcher holds one catalog row per subcommand and derives every surface
# from it: the valid-subcommand list, the help index, the no-argument message,
# the help routing, the dispatch, and `help --json` (`cli_surface.md` R7, R8).
# A leaf owns its flags and answers `--help`; the catalog declares which of the
# dispatcher-parsed fields each leaf takes.

set -euo pipefail

# Self-locating dispatcher (ADR harness_versioning.md, host surface): the
# installed CLI is a symlink into the repo, so resolving $0 yields the repo
# itself -- the installed tool IS the working tree's copy and no independent
# host version exists by construction. Rollback is `git checkout <sha>`.
# An already-exported AGENT_SANDBOX_REPO wins (tests preset it before sourcing).
_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$(cd "$(dirname "$_SELF")/.." && pwd)}"

# Shared parsing and the resolver core are sourced once at module scope; the
# dispatcher is a thin route table over them. Identity flags become optional via
# resolve_identity, which delegates to the canonical resolver.
source "$AGENT_SANDBOX_REPO/src/libs/common.sh"
source "$AGENT_SANDBOX_REPO/src/libs/cli.sh"
source "$AGENT_SANDBOX_REPO/src/libs/env_resolve.sh"

# =============================================================================
# The subcommand catalog
# =============================================================================
# One row per subcommand, pipe-separated:
#   name | leaf | identity | leading args | resolver | summary
#
#   leaf      -- the script the subcommand runs, relative to the repo root.
#   identity  -- the dispatcher-parsed fields the leaf takes, from the field
#                vocabulary in CLI_FIELDS (`name project sandbox env`). The
#                dispatcher parses one spec for all four, so this column decides
#                what it forwards; the fields other than `env` also decide the
#                resolver's required set, and `env` requires the `identity`
#                resolver because that is what exports the normalized ENV_FILE.
#   args      -- a leading positional argument the leaf expects before its flags
#                (`start_agent.sh` takes its mode that way).
#   resolver  -- `identity` runs the resolver on the declared fields; `base`
#                requires all three without resolving, which is onboard's case
#                because it creates the `.env` the resolver would read.
#   summary   -- the index sentence `help --json` carries. It is the catalog's
#                own line, not a copy of anything a leaf prints.
#
# Order is the workflow's: onboard, then build and run, then the workflows,
# then the export. The printed list and the JSON keep that order.
# The field vocabulary, one row per field:
#   field | resolver mode | forwarded flag | value variable
#
# `project` is the resolver's selector and the leaf's --project, so the table
# carries no name translation. `env` is forward-only: the resolver always
# exports ENV_FILE and has no mode to request, so its resolver cell is empty.
CLI_FIELDS=(
  "name|name|--name|PROJECT_NAME"
  "project|project|--project|PROJECT_DIR"
  "sandbox|sandbox|--sandbox|SANDBOX_DIR"
  "env||--env|ENV_FILE"
)

CLI_CATALOG=(
  "onboard|scripts/onboard.sh|name project sandbox||base|Create the project's record from the operator's inputs"
  "build|scripts/build.sh|name project sandbox||identity|Build the provider image chain for the project"
  "start|scripts/start_agent.sh|name project sandbox env|standard|identity|Run an agent session in the sandbox"
  "dry-run|scripts/start_agent.sh|name project sandbox env|dry-run|identity|Exercise the whole pipeline, then tear it down"
  "resume|scripts/resume_agent.sh|name project sandbox env||identity|Reopen an earlier session in the sandbox"
  "stop|scripts/stop.sh|name project sandbox||identity|Stop the session's containers"
  "prune|scripts/prune.sh|name project sandbox||identity|Remove stale images and containers"
  "apply|scripts/workflows/apply.sh|project sandbox||identity|Apply the packaged diffs to the project"
  "draft|scripts/workflows/draft.sh|project sandbox||identity|Draft a commit series from the session's changes"
  "confirm|scripts/workflows/confirm.sh|project sandbox||identity|Confirm a drafted series"
  "reject|scripts/workflows/reject.sh|project sandbox||identity|Reject a drafted series"
  "package-branch|src/libs/package_branch.sh|sandbox||identity|Export the branch as numbered diffs for review"
)

# Dispatcher state, reset by main() on every invocation (tests call main twice).
PROJECT_NAME=""
PROJECT_DIR=""
SANDBOX_DIR=""
ENV_REL=""
PASSTHROUGH=()

# =============================================================================
# Catalog readers
# =============================================================================

# catalog_rows  --  one row per line, for a `while IFS='|' read` loop.
catalog_rows() { printf '%s\n' "${CLI_CATALOG[@]}"; }

# catalog_row SUB  --  the row that declares SUB, or nothing and status 1. The
# one lookup: the help route and the dispatch both call it.
catalog_row() {
  local row
  for row in "${CLI_CATALOG[@]}"; do
    if [[ "${row%%|*}" == "$1" ]]; then
      printf '%s\n' "$row"
      return 0
    fi
  done
  return 1
}

# catalog_field FIELD  --  the CLI_FIELDS row for FIELD, or nothing and status 1.
# A field the table does not declare never reaches a resolver mode or a flag.
catalog_field() {
  local row
  for row in "${CLI_FIELDS[@]}"; do
    if [[ "${row%%|*}" == "$1" ]]; then
      printf '%s\n' "$row"
      return 0
    fi
  done
  return 1
}

# catalog_validate  --  fail when a catalog row names a field outside the
# vocabulary. Runs before any help or dispatch surface derives from the table.
catalog_validate() {
  local row name leaf ident largs resolve summary field
  for row in "${CLI_CATALOG[@]}"; do
    IFS='|' read -r name leaf ident largs resolve summary <<< "$row"
    for field in $ident; do
      if ! catalog_field "$field" >/dev/null; then
        echo "Error: catalog row '$name' declares unknown identity field '$field'" >&2
        return 1
      fi
    done
  done
}

# subcommand_names SEP  --  the declared names, in catalog order, joined by SEP.
subcommand_names() {
  local sep="$1" row out=""
  for row in "${CLI_CATALOG[@]}"; do
    [[ -z "$out" ]] || out+="$sep"
    out+="${row%%|*}"
  done
  printf '%s\n' "$out"
}

# print_json  --  the catalog as JSON, for a programmatic reader (R8). Nothing
# is materialized: this printing is the rendering, so there is no file to drift.
print_json() {
  local name leaf ident largs resolve summary field field_row flag first=1
  local -a ident_words=() flags_words=() largs_words=()
  printf '{\n  "schema": 1,\n  "subcommands": [\n'
  while IFS='|' read -r name leaf ident largs resolve summary; do
    [[ $first -eq 1 ]] || printf ',\n'
    first=0
    printf '    {\n'
    printf '      "name": %s,\n' "$(json_string "$name")"
    printf '      "leaf": %s,\n' "$(json_string "$leaf")"
    ident_words=(); read -ra ident_words <<< "$ident"
    flags_words=()
    for field in "${ident_words[@]}"; do
      field_row="$(catalog_field "$field")" || {
        echo "Error: catalog row '$name' declares unknown identity field '$field'" >&2
        exit 1
      }
      IFS='|' read -r _ _ flag _ <<< "$field_row"
      flags_words+=("$flag")
    done
    largs_words=(); read -ra largs_words <<< "$largs"
    printf '      "identity": %s,\n' "$(json_array "${ident_words[@]}")"
    printf '      "flags": %s,\n' "$(json_array "${flags_words[@]}")"
    printf '      "args": %s,\n' "$(json_array "${largs_words[@]}")"
    printf '      "summary": %s\n' "$(json_string "$summary")"
    printf '    }'
  done < <(catalog_rows)
  printf '\n  ]\n}\n'
}

# =============================================================================
# Helpers (file scope)
# =============================================================================

# require_base_args  --  onboard's hard requirement (it creates the .env, so it
# cannot resolve identity from one).
require_base_args() {
  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --name, --project, and --sandbox are required"
    exit 1
  fi
}

# resolve_identity [name dir sandbox]  --  thin-interface seam over the
# canonical resolver.
resolve_identity() {
  env_resolve_identity "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR" "$ENV_REL" "$@" || exit 1
}

# print_subcommand_list  --  the declared set, for the messages that name it.
print_subcommand_list() {
  echo "Valid subcommands: $(subcommand_names ', ')"
}

# route_help SUB  --  '<sub> --help', 'help <sub>' and 'help --json' route to
# the child's own help (or the index, or the JSON rendering). Exec's so the
# child prints its own usage  --  the dispatcher only locates it.
route_help() {
  local sub="${1:-help}" row name leaf rest
  if [[ "$sub" == "--json" ]]; then
    print_json
    exit 0
  fi
  if [[ "$sub" == "help" ]]; then
    echo "Usage: agent-sandbox <subcommand> [flags]"
    echo ""
    print_subcommand_list
    echo ""
    echo "Run 'agent-sandbox help <subcommand>' for detailed usage."
    echo "Run 'agent-sandbox help --json' for the same set as JSON."
    exit 0
  fi
  if row="$(catalog_row "$sub")"; then
    IFS='|' read -r name leaf rest <<< "$row"
    exec bash "$AGENT_SANDBOX_REPO/$leaf" --help
  fi
  echo "Unknown subcommand: $sub" >&2
  exit 1
}

# dispatch SUB  --  run the subcommand's row: resolve what the leaf requires,
# forward the fields and the leading argument it declares, and hand over the
# passthrough args. exec keeps the leaf's exit status the caller's own.
dispatch() {
  local sub="$1" row name leaf ident largs resolve summary field field_row mode flag value_var
  local -a forwarded=() modes=() lead=()
  if ! row="$(catalog_row "$sub")"; then
    echo "Unknown subcommand: $sub"
    print_subcommand_list
    exit 1
  fi
  IFS='|' read -r name leaf ident largs resolve summary <<< "$row"
  # The resolver mode and forwarded flag a field implies come from CLI_FIELDS;
  # a new field is a row there, not a second list beside it.
  for field in $ident; do
    field_row="$(catalog_field "$field")" || {
      echo "Error: catalog row '$name' declares unknown identity field '$field'" >&2
      exit 1
    }
    IFS='|' read -r _ mode _ _ <<< "$field_row"
    [[ -z "$mode" ]] || modes+=("$mode")
  done
  [[ -z "$largs" ]] || lead=("$largs")

  if [[ "$resolve" == "base" ]]; then
    require_base_args
  else
    resolve_identity "${modes[@]}"
  fi

  # The flags are built after resolution: a resolved value is what the leaf
  # receives, and reading it before the resolver runs forwards an empty flag.
  # The record path is the resolver's normalized absolute ENV_FILE, so the leaf
  # opens the same file the resolver read rather than resolving --env again.
  for field in $ident; do
    field_row="$(catalog_field "$field")" || {
      echo "Error: catalog row '$name' declares unknown identity field '$field'" >&2
      exit 1
    }
    IFS='|' read -r _ _ flag value_var <<< "$field_row"
    forwarded+=("$flag=${!value_var}")
  done
  exec bash "$AGENT_SANDBOX_REPO/$leaf" "${lead[@]}" "${forwarded[@]}" "${PASSTHROUGH[@]}"
}

# =============================================================================
# CLI entry point
# =============================================================================
# When sourced (for tests), only functions are defined  --  dispatch is not run.
# When executed directly, main() parses flags and dispatches to subcommands.

main() {
  local SUBCOMMAND="${1:-}"
  shift || true

  catalog_validate || exit 1

  if [[ -z "$SUBCOMMAND" ]]; then
    echo "Usage: agent-sandbox <$(subcommand_names '|')> <flags>"
    exit 1
  fi

  PROJECT_NAME=""
  PROJECT_DIR=""
  SANDBOX_DIR=""
  ENV_REL=""
  PASSTHROUGH=()

  # Identity and --env parse through the canonical cli.sh spec; every other
  # argument is collected in order and forwarded to the leaf unchanged.
  parse_args_collect PASSTHROUGH --env=ENV_REL \
      --name=PROJECT_NAME --project=PROJECT_DIR --sandbox=SANDBOX_DIR \
      -- "$@"

  # --help/-h delegates to the child's own help before any required-arg check,
  # which is the leaf's promise too (`cli_surface.md` R10). This makes
  # `agent-sandbox <sub> --help` uniform for every subcommand, and
  # `agent-sandbox help --help` show help's own page (the subcommand list).
  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) route_help "$SUBCOMMAND" ;;
    esac
  done

  # `help` is its own subcommand and has no catalog row: its page is the index.
  # A help request is a subcommand in its own right (R10, R11): bare `--help`
  # and `-h` reach the index rather than the unknown-subcommand path.
  case "$SUBCOMMAND" in
    help)  route_help "${1:-help}" ;;
    --help|-h) route_help help ;;
  esac

  dispatch "$SUBCOMMAND"
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
