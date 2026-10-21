#!/usr/bin/env bash
# tests/test_linking.sh
# TEST_DEADLINE: 30
# Behavioural tests for scripts/lint/linking.mjs -- the link-target and
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
#   an image path, from a shipped file -- clean when the image path maps back to
#                                 a populated repository source
#   a repository path, from a shipped file -- flagged: the file runs in the image
#   a target that ships nowhere -- flagged, from an instruction root
#   a repository path, from a bundled document -- flagged: a bundled document
#                                 ships too, so its links resolve in the image
#   a link between two bundled documents -- clean: their destinations keep the
#                                 repository's shape, so the relative link
#                                 survives the move
#   the provider config root    -- its links resolve in the image too: the
#                                 repository-relative form fails, the image path
#                                 passes, so the root is a registered root
#   a link outside the cell reach -- flagged, even when the image carries it
#   a link to a reachable row     -- clean: the cell declares the path
#   a repository link under a reachable row -- clean: the cell reads it there
#   a repository path, from a bundled document -- clean: only the instruction
#                                 roots resolve in the image's path space
#   a shipped document naming an unseeded convention -- flagged: the name is
#                                 derived from the `initialize` corpus, so a
#                                 convention it does not seed cannot be read
#   a shipped document naming a seeded convention -- clean
#   a shipped document using the generic `<name>` form -- clean: it claims no
#                                 specific convention
#   a project-scoped document naming its own convention -- clean
#
# The image-space cases need a fixture that looks like the repository from the
# rule's point of view, because the rule keys on the file's repository-relative
# path. Each one builds a fake root, changes into it, and runs markdownlint from
# there, so `<!-- cwd -->/workflow/coding-agent/prompts/` is a shipped root.
#
# The rule's live whole-tree behaviour is the Markdown gate's job
# (`check_markdown.sh`), not a fixture unit test's: see
# testing-conventions.md Anti-Pattern 8.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

RULE="$REPO_ROOT/scripts/lint/linking.mjs"

# make_cfg [IGNORED_ROOTS_CSV] -- a temp config enabling linking over the
# fixture dir. The CSV, when given, overrides the rule's default carve-outs.
make_cfg() {
  local cfg="$FIXTURE_DIR/mdlconfig-$RANDOM.mjs"
  {
    printf 'export default {\n'
    if [[ $# -gt 0 ]]; then
      printf '  config: { default: false, "linking": { recordTrees: ["%s"] } },\n' "$1"
    else
      printf '  config: { default: false, "linking": true },\n'
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
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a target that exists is clean'
}

test_directory_target_is_clean() {
  local dir cfg out
  dir="$(fixture_root dir_target)"
  mkdir -p "$dir/tree"
  printf '# Notes\n' > "$dir/doc.md"
  printf '[ok](tree)\n' >> "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a directory target is clean'
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
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a same-file fragment that resolves is clean'
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
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'external targets are skipped'
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
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a link in a fenced block is skipped'
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
  assert_eq_num 2 "$(grep -c 'linking' <<< "$out")" 'no recordTrees key exempts nothing'
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
  assert_eq_num 1 "$(grep -c 'linking' <<< "$out")" 'only the uncarved file is checked'
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

# shipped_root NAME -- a fixture root shaped like the repository, with one
# prompt in a shipped instruction root and one bundled policy document.
shipped_root() {
  local name="$1"
  local dir="$FIXTURE_DIR/$name"
  mkdir -p "$dir/workflow/coding-agent/prompts" "$dir/docs/policies"
  printf '# Policy\n' > "$dir/docs/policies/iteration_policy.md"
  printf '%s' "$dir"
}

test_image_path_from_a_shipped_file_is_clean() {
  local dir cfg out
  dir="$(shipped_root image_path)"
  printf '[policy](/opt/sandbox/docs/policies/iteration_policy.md)\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'an absolute image path that a COPY populates is clean'
}

test_image_path_missing_from_the_image_is_flagged() {
  local dir cfg out
  dir="$(shipped_root image_missing)"
  printf '[policy](/opt/sandbox/docs/policies/absent_policy.md)\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'does not exist in the image' 'an image path nothing populates is flagged'
}

test_repository_path_from_a_shipped_file_is_flagged() {
  local dir cfg out
  dir="$(shipped_root repo_form)"
  printf '[policy](../../../docs/policies/iteration_policy.md)\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  # The target exists in the repository, and the file never runs there: the old
  # form is the defect this rule now catches.
  assert_contains "$out" 'does not exist in the image' 'the repository-relative form is flagged from a shipped file'
}

test_repository_path_from_a_bundled_document_is_flagged() {
  local dir cfg out
  dir="$(shipped_root bundled_doc)"
  mkdir -p "$dir/docs/adr"
  printf '# Record\n' > "$dir/docs/adr/x.md"
  printf '[adr](../adr/x.md)\n' > "$dir/docs/policies/iteration_policy.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  # A bundled document ships as well, so its own tree's relative links face the
  # same test: the ADR is absent from the image, and the link is a finding.
  assert_contains "$out" 'does not exist in the image' 'a bundled document resolves its links in the image too'
}

test_link_between_two_bundled_documents_is_clean() {
  local dir cfg out
  dir="$(shipped_root bundled_pair)"
  mkdir -p "$dir/docs/reference"
  printf '# Reference\n' > "$dir/docs/reference/page.md"
  printf '[page](../reference/page.md)\n' > "$dir/docs/policies/iteration_policy.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  # The two destinations keep the repository's shape, so a relative link between
  # two bundled documents resolves in the image unchanged.
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a relative link between two bundled documents is clean'
}

test_sibling_instruction_root_link_is_clean() {
  local dir cfg out
  dir="$(shipped_root sibling_root)"
  mkdir -p "$dir/src/reasoning/agent/prompts" "$dir/src/reasoning/agent/skills/grill-me"
  printf '# Skill\n' > "$dir/src/reasoning/agent/skills/grill-me/SKILL.md"
  printf '[skill](../skills/grill-me/SKILL.md)\n' > "$dir/src/reasoning/agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  # The two prompt roots and the skill root meet in the image, so a link between
  # them resolves as a sibling link rather than by source-tree depth.
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a link between instruction roots resolves in the image'
}

test_provider_config_root_resolves_in_the_image() {
  local dir cfg out
  dir="$(shipped_root provider_root)"
  mkdir -p "$dir/src/reasoning/providers/pi/config/agent"
  local file="$dir/src/reasoning/providers/pi/config/agent/AGENTS.md"
  printf '# Layer\n' > "$file"

  printf '[policy](../../../../../../docs/policies/iteration_policy.md)\n' >> "$file"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'does not exist in the image' 'the repository form fails from the provider config root'

  printf '# Layer\n' > "$file"
  printf '[policy](/opt/sandbox/docs/policies/iteration_policy.md)\n' >> "$file"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'the image path passes from the provider config root'
}

# provision_root NAME -- a fixture root with a prompt in a shipped module root
# and a file in the provider config template. The template is a declared image
# destination that the module prompt's cell does not reach.
provision_root() {
  local name="$1"
  local dir="$FIXTURE_DIR/$name"
  mkdir -p "$dir/workflow/coding-agent/prompts" "$dir/src/reasoning/providers/pi/config/agent"
  printf '# Template file\n' > "$dir/src/reasoning/providers/pi/config/agent/template.md"
  printf '%s' "$dir"
}

test_link_outside_the_cell_reach_is_flagged() {
  local dir cfg out
  dir="$(provision_root outside_reach)"
  # The target exists in the image, and it names the provider config surface's
  # tree rather than any path the module prompt's cell reaches.
  printf '[tpl](/opt/workflow/agent/config/agent/template.md)\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'lands outside the instruction surface' 'a target outside the cell reach is flagged'
}

test_link_through_a_reachable_row_is_clean() {
  local dir cfg out
  dir="$(provision_root reachable_row)"
  # The same target, linked from the cell whose reachable rows name it.
  printf '[tpl](/opt/workflow/agent/config/agent/template.md)\n' > "$dir/src/reasoning/providers/pi/config/agent/AGENTS.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a reachable-row target is clean'
}

test_repository_link_under_a_reachable_row_is_clean() {
  local dir cfg out
  dir="$(shipped_root reachable_repo)"
  mkdir -p "$dir/devlog"
  printf '# Roadmap\n' > "$dir/devlog/roadmap.md"
  # The module prompt cell declares `devlog/` reachable, so a repository link
  # there is legal even though no image destination carries it.
  printf '[roadmap](../../../devlog/roadmap.md)\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a repository path under a reachable row is clean'
}

linking_skill_rules_cite_a_story() {
  local skill="$REPO_ROOT/.agents/skills/linking/SKILL.md"
  local sec missing=""
  for sec in "## What to link" "## Where the link is read" "## Where the handoff is" "## How to form one"; do
    awk -v h="$sec" '$0==h{f=1;next} /^## /{f=0} f' "$skill" | grep -qE 'S[0-9]' || missing="$missing [$sec]"
  done
  assert_empty "$missing" "every rule section cites a story"
}

linking_skill_stories_are_served() {
  local skill="$REPO_ROOT/.agents/skills/linking/SKILL.md"
  local ids cited id
  ids="$(grep -oE '^\| S[0-9]+ ' "$skill" | tr -d '| ' | sort -u)"
  assert_not_empty "$ids" "the story table has rows"
  cited="$(grep -oE 'S[0-9]+' "$skill" | sort | uniq -c | awk '$1 > 1 { print $2 }')"
  for id in $ids; do
    assert_contains "$cited" "$id" "story $id is served by at least one rule"
  done
}

run_test linking_skill_rules_cite_a_story
run_test linking_skill_stories_are_served

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
run_test test_image_path_from_a_shipped_file_is_clean
run_test test_image_path_missing_from_the_image_is_flagged
run_test test_repository_path_from_a_shipped_file_is_flagged
run_test test_repository_path_from_a_bundled_document_is_flagged
run_test test_link_between_two_bundled_documents_is_clean
run_test test_sibling_instruction_root_link_is_clean
run_test test_provider_config_root_resolves_in_the_image
run_test test_link_outside_the_cell_reach_is_flagged
run_test test_link_through_a_reachable_row_is_clean
run_test test_repository_link_under_a_reachable_row_is_clean

# The seeded-convention cases. The names are read from the repository's own
# `initialize` corpus, so `work-log` is seeded and `numbering` is not. The
# fixture supplies only the document and its shipped-ness; the corpus is the
# real one the rule reads.

test_shipped_document_naming_an_unseeded_convention_is_flagged() {
  local dir cfg out
  dir="$(shipped_root unseeded_convention)"
  printf 'See `.agents/skills/numbering/SKILL.md` for the scheme.\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_contains "$out" 'shipped document names a convention the seeded corpus lacks: .agents/skills/numbering/SKILL.md' 'an unseeded convention is flagged'
}

test_shipped_document_naming_a_seeded_convention_is_clean() {
  local dir cfg out
  dir="$(shipped_root seeded_convention)"
  printf 'Read `.agents/skills/work-log/SKILL.md` for the vocabulary.\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a seeded convention is clean'
}

test_shipped_document_with_the_generic_form_is_clean() {
  local dir cfg out
  dir="$(shipped_root generic_convention)"
  printf 'Read each convention at `.agents/skills/<name>/SKILL.md`.\n' > "$dir/workflow/coding-agent/prompts/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'the generic <name> form claims no convention and is clean'
}

test_project_scoped_document_naming_an_unseeded_convention_is_clean() {
  local dir cfg out
  dir="$(fixture_root project_convention)"
  printf 'See `.agents/skills/numbering/SKILL.md` for the scheme.\n' > "$dir/doc.md"
  cfg="$(make_cfg)"
  out="$(mdl_run "$dir" "$cfg")"
  assert_eq_num 0 "$(grep -c 'linking' <<< "$out")" 'a project-scoped document may name its own convention'
}

run_test test_shipped_document_naming_an_unseeded_convention_is_flagged
run_test test_shipped_document_naming_a_seeded_convention_is_clean
run_test test_shipped_document_with_the_generic_form_is_clean
run_test test_project_scoped_document_naming_an_unseeded_convention_is_clean

test_done
