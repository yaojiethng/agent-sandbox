#!/usr/bin/env bash
# tests/test_makefile_template.sh
# Contract tests for scripts/templates/Makefile.template. The template is
# text, not a built artifact: no `make` binary is required, so each test reads
# the template and asserts the argument surface and documentation it exposes.
#
# Covers:
#   every accepted variable is declared at the top with ?= or :=
#   the target-scoped misuse guards
#   every functional target is in .PHONY
#   every target's recipe carries its flag translators
#   the draft channel is conditional on FROM
#   the operator help names the INTERACTIVE and FORCE consumers
#   the refresh comment block appears once

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

TPL="$REPO_ROOT/scripts/templates/Makefile.template"

# target_block FILE TARGET  --  the recipe lines of TARGET, up to the next
# column-0 target line.
target_block() {
  awk -v t="$2" '
    $0 ~ "^" t ":" { inb = 1; print; next }
    inb && $0 ~ /^[A-Za-z][A-Za-z0-9_-]*:/ { exit }
    inb { print }
  ' "$1"
}

# Given: the shipped template
# When:  its declared variables and its recipe variable references are read
# Then:  every recipe reference is declared at the top, and ALL is gone
# Asserts: the accepted-variable set is visible in one place.
test_accepted_variables_are_declared() {
  local declared refs v
  declared="$(grep -oE '^[A-Z_][A-Z0-9_]*[[:space:]]*(\?=|:=)' "$TPL" | sed -E 's/[[:space:]]*(\?=|:=)$//' | sort -u)"
  refs="$(awk '/^\t/{print}' "$TPL" | grep -oE '\$\([A-Z_][A-Z0-9_]*\)' | sed -E 's/^\$\(//; s/\)$//' | sort -u)"

  while IFS= read -r v; do
    [[ -n "$v" ]] || continue
    case "$v" in *_FLAG) continue ;; esac
    if grep -qxF "$v" <<< "$declared"; then
      pass "recipe variable declared at the top: $v"
    else
      fail "recipe variable is not declared with ?= or :=: $v"
    fi
  done <<< "$refs"

  if grep -qE '^ALL[[:space:]]*\?=' "$TPL"; then
    fail "the unused ALL variable is still declared"
  else
    pass "the unused ALL variable is not declared"
  fi

  local accepted="PROVIDER SERVE REFRESH REBUILD FAST TARGET FROM INTERACTIVE"
  accepted+=" BRANCH DIFF TARGET_BRANCH NEW BUNDLE BUNDLE_SUMMARY BASELINE"
  accepted+=" BRANCH_FROM DIFFS BRANCH_SUMMARY NO_RENAMES PERMISSIVE FORCE LIST"
  accepted+=" PRUNE SESSION_ID SANDBOX_TYPE FLATTEN WORKTREE_DIR STALE AGE_DAYS DRY_RUN"
  local -a accepted_toks
  read -ra accepted_toks <<< "$accepted"
  for v in "${accepted_toks[@]}"; do
    if grep -qE "^${v}[[:space:]]*\?=" "$TPL"; then
      pass "accepted variable declared: $v"
    else
      fail "accepted variable missing a ?= declaration: $v"
    fi
  done
}

# Given: the shipped template
# When:  its target-scoped guards are read
# Then:  each known misuse is refused by name
# Asserts: a target-scoped variable used on the wrong target is loud, not ignored.
test_target_scoped_guards() {
  local body
  body="$(cat "$TPL")"
  assert_contains "$body" 'ifdef CHANNEL' "CHANNEL guard present"
  assert_contains "$body" 'ifdef STALE_ONLY' "STALE_ONLY guard present"
  assert_contains "$body" 'ifdef NEW_BRANCH' "NEW_BRANCH guard present"
  assert_contains "$body" 'DRY_RUN is not a dry-run variable' "dry-run/DRY_RUN guard names the target"
  assert_contains "$body" 'FAST is not a start variable' "start/FAST guard names the target"
  assert_contains "$body" 'INTERACTIVE is not a build variable' "build/INTERACTIVE guard names the target"
}

# Given: the shipped template
# When:  its .PHONY list and its target definitions are read
# Then:  every functional target and help are phony
# Asserts: a project file with a target's name cannot shadow the target.
test_every_target_is_phony() {
  local phony t
  phony="$(grep -m1 '^\.PHONY:' "$TPL")"
  for t in build start dry-run stop resume prune draft confirm reject apply package-branch refresh help; do
    if [[ " $phony " == *" $t "* ]]; then
      pass "$t is declared .PHONY"
    else
      fail "$t is missing from .PHONY"
    fi
  done
}

# Given: the shipped template
# When:  each target's recipe is read
# Then:  the target carries the flag translators it documents
# Asserts: deleting a translator from a target breaks its unit.
test_targets_expand_their_flags() {
  local -a spec=(
    'build|$(TARGET_FLAG) $(REBUILD_FLAG) --env=$(ENV_FILE)'
    'start|$(PROVIDER_FLAG) $(SERVE_FLAG) $(REFRESH_FLAG) $(REBUILD_FLAG) $(INTERACTIVE_FLAG) $(DELIVERY_FLAG) $(FLATTEN_FLAG) --env=$(ENV_FILE)'
    'dry-run|$(PROVIDER_FLAG) --fast $(DELIVERY_FLAG) $(FLATTEN_FLAG) --env=$(ENV_FILE)'
    'stop|--env=$(ENV_FILE) $(SESSION_ID_FLAG) $(PRUNE_FLAG)'
    'resume|--env=$(ENV_FILE) $(RESUME_LIST_FLAG) $(RESUME_INTERACTIVE_FLAG) $(RESUME_PROVIDER_FLAG) $(SESSION_ID_FLAG)'
    'prune|--env=$(ENV_FILE) $(STALE_FLAG) $(AGE_DAYS_FLAG) $(PROVIDER_FLAG) $(DRY_RUN_FLAG)'
    'draft|--env=$(ENV_FILE) --channel=$(FROM) --bundle=$(BUNDLE) --interactive --branch-from=$(BRANCH_FROM) --diffs=$(DIFFS) --branch-summary=$(BRANCH_SUMMARY) --force --permissive'
    'confirm|--env=$(ENV_FILE) --target=$(TARGET_BRANCH) --new'
    'reject|--env=$(ENV_FILE)'
    'apply|--env=$(ENV_FILE) --diff=$(DIFF) --branch=$(BRANCH) --interactive --force'
    'package-branch|--env=$(ENV_FILE) --bundle-summary=$(BUNDLE_SUMMARY) --baseline=$(BASELINE) --no-renames'
    'refresh|--refresh --name=$(PROJECT_NAME) --project=$(PROJECT_DIR) --sandbox=$(SANDBOX_DIR)'
  )
  local entry target flags block f
  local -a toks
  for entry in "${spec[@]}"; do
    target="${entry%%|*}"
    flags="${entry#*|}"
    block="$(target_block "$TPL" "$target")"
    assert_not_empty "$block" "$target recipe extracted"
    read -ra toks <<< "$flags"
    for f in "${toks[@]}"; do
      if [[ "$block" == *"$f"* ]]; then
        pass "$target carries $f"
      else
        fail "$target recipe is missing $f"
      fi
    done
  done
}

# Given: the shipped template
# When:  the draft recipe and its default are read
# Then:  --channel is passed only when FROM is set, and no Make-level default exists
# Asserts: draft.sh owns the channel default; the Make layer does not shadow it.
test_draft_channel_is_conditional() {
  local block
  block="$(target_block "$TPL" "draft")"
  assert_contains "$block" '--channel=$(FROM)' "draft passes --channel from FROM"
  assert_not_contains "$block" '--channel=session' "draft does not force a channel default"
  if grep -q 'DRAFT_CHANNEL' "$TPL"; then
    fail "the Make layer still defines DRAFT_CHANNEL"
  else
    pass "the Make layer defines no DRAFT_CHANNEL default"
  fi
}

# Given: the shipped template
# When:  the help target is read
# Then:  the INTERACTIVE and FORCE lines name every consumer
# Asserts: the operator help states each meaning, not one consumer's meaning for all.
test_help_names_each_consumer() {
  local help_block iline fline t
  help_block="$(target_block "$TPL" "help")"
  iline="$(printf '%s\n' "$help_block" | grep 'INTERACTIVE=1     --' | head -1)"
  fline="$(printf '%s\n' "$help_block" | grep 'FORCE=1' | head -1)"
  for t in start resume prune draft apply; do
    assert_contains "$iline" "$t" "INTERACTIVE help names $t"
  done
  assert_contains "$fline" "draft" "FORCE help names draft"
  assert_contains "$fline" "apply" "FORCE help names apply"
}

# Given: the shipped template
# When:  the refresh comment text is counted
# Then:  it appears once, above the refresh target
# Asserts: a duplicated maintenance comment cannot drift between two copies.
test_refresh_comment_appears_once() {
  local n
  n="$(grep -c 'refresh: update stale template files' "$TPL" || true)"
  assert_eq_num "$n" 1 "the refresh comment block appears once"
}

# Given: the shipped template
# When:  the flag translator definitions and the .env path are read
# Then:  each definition still maps its variable to its flag
# Asserts: a translator cannot be emptied while its recipe reference remains.
test_flag_translators_are_defined() {
  local -a defs=(
    '^REFRESH_FLAG[[:space:]]*= \$\(if \$\(REFRESH\),--refresh,\)'
    '^REBUILD_FLAG[[:space:]]*= \$\(if \$\(REBUILD\),--rebuild,\)'
    '^INTERACTIVE_FLAG[[:space:]]*= \$\(if \$\(INTERACTIVE\),--interactive,\)'
    '^SERVE_FLAG[[:space:]]*= \$\(if \$\(SERVE\),--serve,\)'
    '^PROVIDER_FLAG[[:space:]]*= \$\(if \$\(PROVIDER\),--provider=\$\(PROVIDER\),\)'
    '^SESSION_ID_FLAG[[:space:]]*= \$\(if \$\(SESSION_ID\),--session-id=\$\(SESSION_ID\),\)'
    '^STALE_FLAG[[:space:]]*= \$\(if \$\(STALE\),--stale=\$\(STALE\),\)'
    '^DRY_RUN_FLAG[[:space:]]*= \$\(if \$\(DRY_RUN\),--dry-run,\)'
    '^DELIVERY_FLAG[[:space:]]*= \$\(if \$\(SANDBOX_TYPE\),--delivery=\$\(SANDBOX_TYPE\),\)'
    '^ENV_FILE[[:space:]]*:=[[:space:]]*\$\(CURDIR\)/\.env'
  )
  local d
  for d in "${defs[@]}"; do
    if grep -qE "$d" "$TPL"; then
      pass "translator definition present: $d"
    else
      fail "translator definition missing: $d"
    fi
  done
}

run_test test_accepted_variables_are_declared
run_test test_flag_translators_are_defined
run_test test_target_scoped_guards
run_test test_every_target_is_phony
run_test test_targets_expand_their_flags
run_test test_draft_channel_is_conditional
run_test test_help_names_each_consumer
run_test test_refresh_comment_appears_once

test_done "test_makefile_template"
