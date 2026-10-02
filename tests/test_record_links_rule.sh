#!/usr/bin/env bash
# tests/test_record_links_rule.sh
# Behavioural tests for scripts/lint/record-links.mjs -- the link-target and
# heading-fragment custom markdownlint rule. The real markdownlint-cli2 runs
# against fixture files with a temp config that imports the repo rule; the
# repo's own .markdownlint-cli2.mjs is never discovered because the fixture dir
# sits outside the repo tree.
#
# Covers:
#   a target that exists        --  clean
#   a directory target         --  clean (several documents point at a tree)
#   a same-file fragment        --  clean when the heading yields it
#   a missing target            --  flagged, naming the target
#   an unknown fragment         --  flagged, naming the target
#   a heading suffix            --  the suffix is part of the fragment
#   external targets            --  skipped (http, mailto)
#   a link in a fenced block    --  skipped
#   no recordTrees key         --  nothing is exempt; the rule holds no list
#   a configured carve-out      --  the named trees are exempt
#   an unreadable target        --  flagged as a missing target, never a pass
#
# The rule's live whole-tree behaviour is the Markdown gate's job
# (`check_markdown.sh`), not a fixture unit test's: see
# testing-conventions.md Anti-Pattern 8.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RULE="$REPO_ROOT/scripts/lint/record-links.mjs"

# make_cfg [IGNORED_ROOTS_CSV] -- a temp config enabling record-links over the
# fixture dir. The CSV, when given, overrides the rule's default carve-outs.
make_cfg() {
  local cfg="$FIXTURE_DIR/mdlconfig-$RANDOM.mjs"
  {
    printf 'export default {\n'
    if [[ $# -gt 0 ]]; then
      printf '  config: { default: false, "record-links": { recordTrees: ["%s"] } },\n' "$1"
    else
      printf '  config: { default: false, "record-links": true },\n'
    fi
    printf '  customRules: ["%s"],\n' "$RULE"
    printf '  globs: ["**/*.md"],\n'
    printf '};\n'
  } > "$cfg"
  printf '%s' "$cfg"
}

# mdl_run DIR CFG -- run markdownlint-cli2 over the fixture dir.
mdl_run() {
  local dir="$1" cfg="$2"
  (cd "$dir" && markdownlint-cli2 --config "$cfg" 2>&1)
}

# fixture_root NAME -- an empty fixture dir with a target document whose only
# heading is given by the caller.
fixture_root() {
  local name="$1"
  local dir="$FIXTURE_DIR/$name"
  mkdir -p "$dir"
  printf '%s' "$dir"
}

test_existing_target_is_clean() {
  local dir cfg out
  dir="$(fixture_root exists)"
  printf '# Notes\n' > "$dir/target.md"
  printf '[ok](target.md)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'record-links' <<< "$out")" 'a target that exists is clean'
}

test_directory_target_is_clean() {
  local dir cfg out
  dir="$(fixture_root dir_target)"
  mkdir -p "$dir/tree"
  printf '# Notes\n' > "$dir/doc.md"
  printf '[ok](tree)\n' >> "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'record-links' <<< "$out")" 'a directory target is clean'
}

test_same_file_fragment_resolves() {
  local dir cfg out
  dir="$(fixture_root same_file)"
  {
    printf '## M3 - Manual Dispatch\n\n'
    printf '[ok](#m3---manual-dispatch)\n'
  } > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'record-links' <<< "$out")" 'a same-file fragment that resolves is clean'
}

test_missing_target_is_flagged() {
  local dir cfg out
  dir="$(fixture_root missing)"
  printf '[gone](nope.md)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'link target does not exist: nope.md' 'a missing target is flagged'
}

test_unknown_fragment_is_flagged() {
  local dir cfg out
  dir="$(fixture_root frag)"
  printf '# Notes\n' > "$dir/target.md"
  printf '[bad](target.md#nope)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'link fragment names no heading' 'an unknown fragment is flagged'
}

test_heading_suffix_is_part_of_the_fragment() {
  local dir cfg out
  dir="$(fixture_root suffix)"
  printf '# M1.4 - Image Staleness Detection [SUPERSEDED/REMOVED in M2.1]\n' > "$dir/target.md"
  # The suffix belongs to the fragment, so the short form must be flagged.
  printf '[bad](target.md#m14---image-staleness-detection)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'link fragment names no heading' 'a heading suffix breaks the short fragment'
}

test_external_targets_are_skipped() {
  local dir cfg out
  dir="$(fixture_root external)"
  printf '[a](https://example.invalid/p) [b](mailto:a@b.invalid)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'record-links' <<< "$out")" 'external targets are skipped'
}

test_link_in_a_fenced_block_is_skipped() {
  local dir cfg out
  dir="$(fixture_root fenced)"
  {
    printf '```markdown\n'
    printf '[example](nope.md)\n'
    printf '```\n'
  } > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'record-links' <<< "$out")" 'a link in a fenced block is skipped'
}

test_no_carve_out_exempts_nothing() {
  local dir cfg out
  dir="$(fixture_root nocfg)"
  mkdir -p "$dir/devlog/handovers"
  printf '[gone](nope.md)\n' > "$dir/devlog/handovers/h.md"
  printf '[live](nope.md)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  # The rule carries no list: without recordTrees every file is checked, which
  # is what makes the repository's carve-out visible in the config file.
  assert_eq_num 2 "$(grep -c 'record-links' <<< "$out")" 'no recordTrees key exempts nothing'
}

test_configured_carve_out_exempts_the_named_trees() {
  local dir cfg out
  dir="$(fixture_root carveout)"
  mkdir -p "$dir/devlog/handovers" "$dir/devlog/discussions"
  printf '[gone](nope.md)\n' > "$dir/devlog/handovers/h.md"
  printf '[gone](nope.md)\n' > "$dir/devlog/discussions/d.md"
  printf '[live](nope.md)\n' > "$dir/doc.md"
  cfg="$(make_cfg 'devlog/handovers/", "devlog/discussions/')"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 1 "$(grep -c 'record-links' <<< "$out")" 'only the uncarved file is checked'
}

test_unreadable_target_is_flagged() {
  local dir cfg out
  dir="$(fixture_root unreadable)"
  mkdir -p "$dir/target.md"
  printf '[dir](target.md#frag)\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  # A directory exists, so the fragment check runs against a file that has no
  # headings: the fragment is reported rather than passed.
  assert_contains "$out" 'link fragment names no heading' 'a fragment into a headingless target is flagged'
}

run_test test_existing_target_is_clean
run_test test_directory_target_is_clean
run_test test_same_file_fragment_resolves
run_test test_missing_target_is_flagged
run_test test_unknown_fragment_is_flagged
run_test test_heading_suffix_is_part_of_the_fragment
run_test test_external_targets_are_skipped
run_test test_link_in_a_fenced_block_is_skipped
run_test test_no_carve_out_exempts_nothing
run_test test_configured_carve_out_exempts_the_named_trees
run_test test_unreadable_target_is_flagged

test_done