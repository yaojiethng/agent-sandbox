#!/usr/bin/env bash
# tests/test_skill_sources.sh
# The source-keyed maintenance catalog: the source fields, the generated skill
# set, the local file hashes and the empty-source rule. Also probes pi's loader
# for the nested-skill rule the ADR relies on.
#
# Covers:
#   clean          -- a source with two records and matching hashes passes
#   drift          -- a changed local file fails the hash check
#   missing record -- a skill without MAINTENANCE.md fails --check and is dropped
#                     by --write
#   empty source   -- a source with no skills needs a reason and a null import
#                     commit; without a reason it is refused
#   empty recorded -- an empty source with a reason passes
#   real catalog   -- the repository catalog is clean and holds three sources
#                     and four skills
#   nested skill   -- pi does not discover a nested SKILL.md under a parent that
#                     already has one

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCANNER="$REPO_ROOT/scripts/lint/skill_sources.mjs"
LOADER="$REPO_ROOT/tests/skill_source_loader.mjs"

# make_fixture -- a source with two skills and matching hashes.
make_fixture() {
  local root="$FIXTURE_DIR/tree" ah bh
  mkdir -p "$root/src/reasoning/agent/skills/alpha" \
    "$root/src/reasoning/agent/skills/beta"

  cat >"$root/src/reasoning/agent/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: The alpha skill.
---

Alpha.
EOF
  cat >"$root/src/reasoning/agent/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: The beta skill.
---

Beta.
EOF
  cat >"$root/src/reasoning/agent/skills/alpha/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Source: `test-source`; see [`source-catalog.json`](../source-catalog.json).

## Adapted

Kept.

## Name

alpha
EOF
  cat >"$root/src/reasoning/agent/skills/beta/MAINTENANCE.md" <<'EOF'
# Maintenance record

## Source

Source: `test-source`; see [`source-catalog.json`](../source-catalog.json).

## Adapted

Kept.

## Name

beta
EOF

  ah="$(sha256sum "$root/src/reasoning/agent/skills/alpha/SKILL.md" | cut -d' ' -f1)"
  bh="$(sha256sum "$root/src/reasoning/agent/skills/beta/SKILL.md" | cut -d' ' -f1)"

  cat >"$root/src/reasoning/agent/skills/source-catalog.json" <<EOF
{
  "sources": [
    {
      "id": "test-source",
      "url": "https://example.test/source",
      "revision": "62f43a18177be6ec82da242e59ffbc490a4c22ea",
      "revision_date": "2026-04-28",
      "license": "MIT",
      "copyright": "Copyright Test",
      "import_commit": "440577fe149cf2315f432630667d991cb3e6b2ef",
      "skills": [
        {
          "name": "alpha",
          "upstream_path": "skills/alpha",
          "local_path": "src/reasoning/agent/skills/alpha",
          "files": [
            { "path": "SKILL.md", "upstream_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "local_sha256": "$ah" }
          ]
        },
        {
          "name": "beta",
          "upstream_path": "skills/beta",
          "local_path": "src/reasoning/agent/skills/beta",
          "files": [
            { "path": "SKILL.md", "upstream_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "local_sha256": "$bh" }
          ]
        }
      ]
    }
  ]
}
EOF
  printf '%s\n' "$root"
}

run_catalog() {
  local root="$1"; shift
  SKILL_SOURCE_ROOT="$root" node "$SCANNER" "$@" 2>&1
}

test_clean_fixture_passes() {
  local root out rc
  root="$(make_fixture)"
  out="$(run_catalog "$root" --check)"; rc=$?
  assert_rc "$rc" 0 "a source with matching hashes passes"
  assert_contains "$out" "clean across 1 source(s) and 2 skill(s)" "the clean report counts the source and skills"
}

test_a_changed_hash_fails() {
  local root out rc
  root="$(make_fixture)"
  printf '\nChanged.\n' >>"$root/src/reasoning/agent/skills/alpha/SKILL.md"
  out="$(run_catalog "$root" --check)"; rc=$?
  assert_rc "$rc" 1 "a changed local file fails the hash check"
  assert_contains "$out" "alpha SKILL.md hash mismatch" "the finding names the skill and the file"
}

test_a_missing_record_fails_check_and_is_dropped_by_write() {
  local root out rc
  root="$(make_fixture)"
  rm "$root/src/reasoning/agent/skills/beta/MAINTENANCE.md"
  out="$(run_catalog "$root" --check)"; rc=$?
  assert_rc "$rc" 1 "a skill without a record fails the check"
  assert_contains "$out" "skill beta has no MAINTENANCE.md record" "the finding names the missing record"

  out="$(run_catalog "$root" --write)"; rc=$?
  assert_rc "$rc" 0 "the write mode regenerates the skill set"
  assert_contains "$out" "wrote 1 source(s) and 1 skill(s)" "the write report drops the skill without a record"

  out="$(run_catalog "$root" --check)"; rc=$?
  assert_rc "$rc" 0 "the regenerated catalog passes"
}

test_an_empty_source_without_a_reason_is_refused() {
  local root out rc
  root="$(make_fixture)"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.sources.push({
      id: "empty-source",
      url: "https://example.test/empty",
      revision: "62f43a18177be6ec82da242e59ffbc490a4c22ea",
      revision_date: "2026-04-28",
      license: "MIT",
      copyright: "Copyright Test",
      import_commit: "440577fe149cf2315f432630667d991cb3e6b2ef",
      skills: []
    });
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$root/src/reasoning/agent/skills/source-catalog.json"
  out="$(run_catalog "$root" --check)"; rc=$?
  assert_rc "$rc" 1 "an empty source without a reason is refused"
  assert_contains "$out" "an empty source requires a reason" "the reason is enforced"
}

test_an_empty_source_with_a_reason_is_recorded() {
  local root out rc
  root="$(make_fixture)"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.sources.push({
      id: "empty-recorded",
      url: "https://example.test/empty",
      revision: "62f43a18177be6ec82da242e59ffbc490a4c22ea",
      revision_date: "2026-04-28",
      license: "MIT",
      copyright: "Copyright Test",
      import_commit: null,
      reason: "Not forked by this repository.",
      skills: []
    });
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$root/src/reasoning/agent/skills/source-catalog.json"
  out="$(run_catalog "$root" --check)"; rc=$?
  assert_rc "$rc" 0 "an empty source with a reason passes"
  assert_contains "$out" "clean across 2 source(s) and 2 skill(s)" "the empty source is counted"
}

test_the_repository_catalog_is_clean() {
  local out rc
  out="$(node "$SCANNER" 2>&1)"; rc=$?
  assert_rc "$rc" 0 "the repository catalog passes"
  assert_contains "$out" "clean across 3 source(s) and 4 skill(s)" "the repository holds three sources and four skills"
}

test_a_nested_skill_is_not_discovered() {
  local root out rc
  root="$FIXTURE_DIR/loader"
  mkdir -p "$root/code-review/improve-codebase-architecture"
  printf '%s\n' '---' 'name: code-review' 'description: The parent skill.' '---' '' 'Parent.' \
    >"$root/code-review/SKILL.md"
  printf '%s\n' '---' 'name: improve-codebase-architecture' 'description: The nested child.' '---' '' 'Child.' \
    >"$root/code-review/improve-codebase-architecture/SKILL.md"
  out="$(node "$LOADER" "$root" 2>&1)"; rc=$?
  assert_rc "$rc" 0 "the loader probe runs"
  assert_contains "$out" "code-review" "the parent skill is discovered"
  assert_not_contains "$out" "improve-codebase-architecture" "a nested SKILL.md is not discovered under a skill root"
}

run_test test_clean_fixture_passes
run_test test_a_changed_hash_fails
run_test test_a_missing_record_fails_check_and_is_dropped_by_write
run_test test_an_empty_source_without_a_reason_is_refused
run_test test_an_empty_source_with_a_reason_is_recorded
run_test test_the_repository_catalog_is_clean
run_test test_a_nested_skill_is_not_discovered

test_done
