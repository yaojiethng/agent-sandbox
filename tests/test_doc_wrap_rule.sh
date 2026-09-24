#!/usr/bin/env bash
# tests/test_doc_wrap_rule.sh
# Behavioural tests for scripts/lint/doc-wrap.mjs -- the one-paragraph-per-
# physical-line custom markdownlint rule (documentation_policy.md ### Line
# wrapping). The real markdownlint-cli2 runs against fixture files with a
# temp config that imports the repo rule; the repo's own .markdownlint-cli2.mjs
# is never discovered because the fixture dir sits outside the repo tree.
#
# Covers:
#   wrapped paragraph     --  flagged, naming the first line
#   single-line paragraph --  clean, however long the line
#   fenced code / table   --  exempt (matches the policy exemption)
#   frontmatter           --  not parsed as prose; clean
#   wrapped list item     --  flagged
#   wrapped blockquote    --  flagged
#   legacyFiles seam      --  a file named in the rule config is exempt, and
#                             only that file
#   real tree guard        --  the whole repository carries zero findings with
#                             the rule on and no exemptions
#
# Run:   bash tests/test_doc_wrap_rule.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RULE="$REPO_ROOT/scripts/lint/doc-wrap.mjs"
# make_cfg [legacyFiles...]  --  a temp config enabling doc-wrap over the
# fixture dir, with an optional legacyFiles exemption list.
make_cfg() {
  local cfg="$FIXTURE_DIR/mdlconfig.mjs"
  {
    printf "export default {\n"
    printf "  config: { default: false, \"doc-wrap\": { legacyFiles: ["
    local first=1
    for f in "$@"; do
      if (( first )); then first=0; else printf ", "; fi
      printf '"%s"' "$f"
    done
    printf "] } },\n"
    printf '  customRules: ["%s"],\n' "$RULE"
    printf '  globs: ["**/*.md"],\n'
    printf '};\n'
  } > "$cfg"
  echo "$cfg"
}
# mdl_run DIR CFG  --  run markdownlint-cli2 over the fixture dir; echoes output.
mdl_run() {
  local dir="$1" cfg="$2"
  (cd "$dir" && markdownlint-cli2 --config "$cfg" 2>&1)
}

test_wrapped_paragraph_flagged() {
  local dir="$FIXTURE_DIR/wp" cfg
  mkdir -p "$dir"
  printf 'This paragraph is broken across two physical lines\nat a sentence boundary.\n' > "$dir/a.md"
  cfg="$(make_cfg)"
  local out rc=0
  out="$(mdl_run "$dir" "$cfg")" || rc=$?
  assert_eq "1" "$rc" "wrapped paragraph fails the rule (rc 1)"
  assert_contains "$out" "a.md:1 error doc-wrap" "finding names the first wrapped line"
  assert_contains "$out" "one paragraph per physical line" "finding quotes the policy"
}
test_single_line_paragraph_clean() {
  local dir="$FIXTURE_DIR/sl" cfg
  mkdir -p "$dir"
  printf 'One paragraph, one physical line, however long it gets before the editor soft-wraps.\n\n## Heading\n\nShort.\n' > "$dir/a.md"
  cfg="$(make_cfg)"
  local out rc=0
  out="$(mdl_run "$dir" "$cfg")" || rc=$?
  assert_eq "0" "$rc" "single-line paragraphs pass (rc 0)"
}
test_fence_and_table_exempt() {
  local dir="$FIXTURE_DIR/ft" cfg
  mkdir -p "$dir"
  printf 'Prose before.\n\n```sh\ncode line one\ncode line two\n```\n\n| a | b |\n|---|---|\n| x | y |\n' > "$dir/a.md"
  cfg="$(make_cfg)"
  local out rc=0
  out="$(mdl_run "$dir" "$cfg")" || rc=$?
  assert_eq "0" "$rc" "fenced code and table rows are exempt (rc 0)"
}
test_frontmatter_exempt() {
  local dir="$FIXTURE_DIR/fm" cfg
  mkdir -p "$dir"
  printf -- '---\ntitle: a long\n  title: continued\n---\n\nProse.\n' > "$dir/a.md"
  cfg="$(make_cfg)"
  local out rc=0
  out="$(mdl_run "$dir" "$cfg")" || rc=$?
  assert_eq "0" "$rc" "frontmatter is not prose (rc 0)"
}
test_wrapped_list_item_and_quote_flagged() {
  local dir="$FIXTURE_DIR/lq" cfg
  mkdir -p "$dir"
  printf -- '- this list item wraps onto a\n  continuation line\n' > "$dir/a.md"
  printf '> quoted prose broken\n> across two physical lines\n' > "$dir/b.md"
  cfg="$(make_cfg)"
  local out rc=0
  out="$(mdl_run "$dir" "$cfg")" || rc=$?
  assert_eq "1" "$rc" "wrapped list item and quote fail the rule (rc 1)"
  assert_contains "$out" "a.md:1 error doc-wrap" "wrapped list item flagged"
  assert_contains "$out" "b.md:1 error doc-wrap" "wrapped quote flagged"
}
test_legacy_exemption_seam() {
  local dir="$FIXTURE_DIR/leg" cfg
  mkdir -p "$dir"
  printf 'Wrapped prose\nacross lines.\n' > "$dir/a.md"
  printf 'Wrapped prose\nacross lines.\n' > "$dir/b.md"
  cfg="$(make_cfg "a.md")"
  local out rc=0
  out="$(mdl_run "$dir" "$cfg")" || rc=$?
  assert_eq "1" "$rc" "exempting one file still fails on the other (rc 1)"
  assert_contains "$out" "b.md:1 error doc-wrap" "non-exempt file still flagged"
  assert_not_contains "$out" "a.md:1 error doc-wrap" "exempt file not flagged"
}

test_real_tree_zero_findings() {
  local cfg="$FIXTURE_DIR/treecfg.mjs"
  cat > "$cfg" <<EOF
export default {
  config: { default: false, "doc-wrap": true },
  customRules: ["$RULE"],
  globs: ["$REPO_ROOT/**/*.md"],
  ignores: ["$REPO_ROOT/**/node_modules/**"],
};
EOF
  local out rc=0
  out="$(cd "$FIXTURE_DIR" && markdownlint-cli2 --config "$cfg" 2>&1)" || rc=$?
  assert_eq "0" "$rc" "the real tree carries zero doc-wrap findings (rule on, no exemptions)"
}

run_test test_wrapped_paragraph_flagged
run_test test_single_line_paragraph_clean
run_test test_fence_and_table_exempt
run_test test_frontmatter_exempt
run_test test_wrapped_list_item_and_quote_flagged
run_test test_legacy_exemption_seam
run_test test_real_tree_zero_findings

test_done