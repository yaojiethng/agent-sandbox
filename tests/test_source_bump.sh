#!/usr/bin/env bash
# tests/test_source_bump.sh
# The source-bump tracking store: one JSON file per source, the source and
# artifact schema, the rules the store refuses, and the canonical form that
# `format` writes and the gate compares against.
#
# Covers:
#   clean          -- a source with two artifacts passes
#   missing path   -- an artifact whose local path is gone fails
#   duplicate path -- one local path under two sources fails
#   bad fields     -- an unknown kind, a short base and an unknown status fail
#   empty source   -- an empty source needs a reason and carries no status
#   format         -- format canonicalises order, key order and indentation and
#                     changes no field value; a canonical file is left identical
#   agreement      -- the gate and check print one finding for one bad file
#   kinds          -- a runbook names its parent and a prompt is a file
#   diff           -- diff prints the base -> local change from a clone and
#                     leaves the store untouched
#   prepare        -- prepare creates base, ours and theirs from a clone and
#                     leaves the store untouched
#   help           -- the CLI exposes check, format, diff and prepare

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

CLI="$REPO_ROOT/scripts/source_bump.mjs"
A="62f43a18177be6ec82da242e59ffbc490a4c22ea"
C="cccccccccccccccccccccccccccccccccccccccc"

# make_fixture -- one source with two skill edges.
make_fixture() {
  local root="$FIXTURE_DIR/tree" store
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/skills/alpha" "$root/src/skills/beta" "$store"

  printf '%s\n' '---' 'name: alpha' 'description: The alpha skill.' '---' '' 'Alpha.' \
    >"$root/src/skills/alpha/SKILL.md"
  printf '%s\n' '---' 'name: beta' 'description: The beta skill.' '---' '' 'Beta.' \
    >"$root/src/skills/beta/SKILL.md"

  cat >"$store/test-source.json" <<EOF
{
  "schema": 1,
  "id": "test-source",
  "url": "https://example.test/source",
  "license": "MIT",
  "copyright": "Copyright Test",
  "artifacts": [
    {
      "local_path": "src/skills/alpha",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/alpha",
      "origin": "$A",
      "base": "$A"
    },
    {
      "local_path": "src/skills/beta",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/beta",
      "origin": "$A",
      "base": "$A"
    }
  ]
}
EOF
  printf '%s\n' "$root"
}

make_upstream() {
  local upstream="$FIXTURE_DIR/upstream"
  mkdir -p "$upstream/skills/alpha"
  git init -q "$upstream"
  printf 'Alpha A\n' >"$upstream/skills/alpha/SKILL.md"
  printf 'A-only\n' >"$upstream/skills/alpha/old.md"
  mkdir -p "$upstream/prompts"
  printf 'Prompt A\n' >"$upstream/prompts/auto.md"
  git -C "$upstream" add -A
  git -C "$upstream" -c user.name=Test -c user.email=test@example.test commit -qm A
  local a b
  a="$(git -C "$upstream" rev-parse HEAD)"
  printf 'Alpha B\n' >"$upstream/skills/alpha/SKILL.md"
  rm "$upstream/skills/alpha/old.md"
  printf 'B-only\n' >"$upstream/skills/alpha/new.md"
  printf 'Prompt B\n' >"$upstream/prompts/auto.md"
  git -C "$upstream" add -A
  git -C "$upstream" -c user.name=Test -c user.email=test@example.test commit -qm B
  b="$(git -C "$upstream" rev-parse HEAD)"
  printf '%s %s\n' "$a" "$b"
}

set_edge_commits() {
  local file="$1" local="$2" origin="$3" base="$4"
  node -e '
    const fs = require("fs");
    const [file, local, origin, base] = process.argv.slice(1);
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    const artifact = data.artifacts.find((item) => item.local_path === local);
    artifact.origin = origin;
    artifact.base = base;
    fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
  ' "$file" "$local" "$origin" "$base"
}

set_edge_upstream() {
  local file="$1" local="$2" upstream="$3"
  node -e '
    const fs = require("fs");
    const [file, local, upstream] = process.argv.slice(1);
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    const artifact = data.artifacts.find((item) => item.local_path === local);
    artifact.upstream_path = upstream;
    fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
  ' "$file" "$local" "$upstream"
}

# add_edge FILE SOURCE LOCAL KIND PARENT UPSTREAM ORIGIN BASE -- append one edge
# and rewrite the file in canonical form, the way a hand edit is expected to.
add_edge() {
  node -e '
    const fs = require("fs");
    const [file, local, kind, parent, upstream, origin, base] = process.argv.slice(1);
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    data.artifacts.push({
      local_path: local,
      kind,
      parent: parent === "null" ? null : parent,
      upstream_path: upstream,
      origin,
      base,
    });
    data.artifacts.sort((left, right) => (left.local_path < right.local_path ? -1 : 1));
    const ordered = {
      schema: data.schema,
      id: data.id,
      url: data.url,
      license: data.license,
      copyright: data.copyright,
      artifacts: data.artifacts,
    };
    if (data.artifacts.length === 0) ordered.reason = data.reason;
    fs.writeFileSync(file, JSON.stringify(ordered, null, 2) + "\n");
  ' "$1" "$3" "$4" "$5" "$6" "$7" "$8"
}

run_cli() {
  local root="$1"
  shift
  SOURCE_BUMP_ROOT="$root" node "$CLI" "$@" 2>&1
}

source_field() {
  local file="$1" local="$2"
  node -e '
    const fs = require("fs");
    const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const a = d.artifacts.find((item) => item.local_path === process.argv[2]);
    console.log(`${a.origin} ${a.base}`);
  ' "$file" "$local"
}

paths_in_store() {
  local file="$1"
  node -e '
    const fs = require("fs");
    const d = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    console.log(d.artifacts.map((item) => item.local_path).join(","));
  ' "$file"
}

test_clean_fixture_passes() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "a source with two skill edges passes"
  assert_contains "$out" "clean across 1 source(s) and 2 artifact(s)" "the clean report counts both"
}

test_a_missing_local_path_fails() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  rm -rf "$root/src/skills/alpha"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "a missing local path fails"
  assert_contains "$out" "local_path src/skills/alpha does not exist" "the missing path is named"
}

test_a_bad_record_field_fails() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts[0].record = { kept: 5, mine: "a field nothing reads" };
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$store/test-source.json"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "a record field that is not a string fails"
  assert_contains "$out" "record.kept must be a non-empty string" "the bad value is named"
  assert_contains "$out" "unknown record field mine" "the unknown field is named"
}

test_an_artifact_in_two_sources_is_allowed() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  cat >"$store/other-source.json" <<EOF
{
  "schema": 1,
  "id": "other-source",
  "url": "https://example.test/other",
  "license": "MIT",
  "copyright": "Copyright Other",
  "artifacts": [
    {
      "local_path": "src/skills/alpha",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/alpha",
      "origin": "$A",
      "base": "$A"
    }
  ]
}
EOF
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "one artifact built from two sources passes"
  assert_contains "$out" "clean across 2 source(s) and 3 artifact(s)" "the report counts both edges"
}

test_a_duplicate_edge_in_one_source_fails() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts.push({ ...d.artifacts[0] });
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$store/test-source.json"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "the same edge twice in one source fails"
  assert_contains "$out" "is listed twice" "the duplicate edge is named"
}

test_invalid_kind_bad_base_and_unknown_status_fail() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.status = "active";
    d.artifacts[0].kind = "widget";
    d.artifacts[1].base = "short";
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$store/test-source.json"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "an invalid kind and a short base fail"
  assert_contains "$out" "kind must be one of skill, runbook, prompt" "the kind finding is named"
  assert_contains "$out" "base must be a 40-character commit" "the base finding is named"
  assert_contains "$out" "unknown field status" "a status field is refused"
}

test_an_empty_source_needs_a_reason() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  cat >"$store/empty-source.json" <<'EOF'
{
  "schema": 1,
  "id": "empty-source",
  "url": "https://example.test/empty",
  "license": "MIT",
  "copyright": "Copyright Empty",
  "artifacts": []
}
EOF
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "an empty source without a reason fails"
  assert_contains "$out" "an empty source requires a reason" "the reason is enforced"

  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    const ordered = {
      schema: d.schema,
      id: d.id,
      url: d.url,
      license: d.license,
      copyright: d.copyright,
      reason: "Not forked by this repository.",
      artifacts: d.artifacts,
    };
    fs.writeFileSync(p, JSON.stringify(ordered, null, 2) + "\n");
  ' "$store/empty-source.json"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "an empty source with a reason passes"
  assert_contains "$out" "clean across 2 source(s) and 2 artifact(s)" "the empty source is counted"
}

test_runbook_and_prompt_edges() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/skills/code-review/runbooks/review" "$root/prompts"
  printf '%s\n' '---' 'name: code-review' 'description: The review skill.' '---' '' 'Review.' \
    >"$root/src/skills/code-review/SKILL.md"
  printf '%s\n' '---' 'name: review' 'description: The review runbook.' '---' '' 'Runbook.' \
    >"$root/src/skills/code-review/runbooks/review/SKILL.md"
  printf '%s\n' '# Auto prompt' >"$root/prompts/auto.md"

  add_edge "$store/test-source.json" test-source src/skills/code-review skill null \
    skills/code-review "$A" "$A"
  add_edge "$store/test-source.json" test-source src/skills/code-review/runbooks/review \
    runbook src/skills/code-review skills/code-review/runbooks/review "$A" "$A"
  add_edge "$store/test-source.json" test-source prompts/auto.md prompt null \
    prompts/auto.md "$A" "$A"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the skill, runbook and prompt store passes"
  assert_contains "$out" "clean across 1 source(s) and 5 artifact(s)" "all three kinds are counted"

  add_edge "$store/test-source.json" test-source src/skills/code-review/runbooks/review \
    runbook null skills/code-review/runbooks/review "$A" "$A"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "a runbook without a parent is refused"
  assert_contains "$out" "a runbook must name its parent" "the missing parent is named"
}

test_unknown_fields_and_hashes_are_refused() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const d = JSON.parse(fs.readFileSync(p, "utf8"));
    d.artifacts[0].local_sha256 = "0".repeat(64);
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$store/test-source.json"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 1 "$rc" "a stored hash is refused"
  assert_contains "$out" "unknown artifact field local_sha256" "the hash field is named"
}

test_diff_prints_the_local_change_and_leaves_the_store_untouched() {
  local root store upstream up_a up_b before after out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  set_edge_commits "$store/test-source.json" src/skills/alpha "$up_a" "$up_a"
  before="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"

  out="$(run_cli "$root" diff --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream")"; rc=$?
  assert_rc 0 "$rc" "diff prints the local change"
  assert_contains "$out" "diff --git a/base/SKILL.md b/ours/SKILL.md" "the diff names the base and ours trees"
  assert_contains "$out" "-Alpha A" "the upstream base line is removed"
  assert_contains "$out" "+Alpha." "the local line is added"

  after="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"
  assert_eq "$after" "$before" "diff wrote no store change"
}

test_diff_reports_no_local_changes() {
  local root store upstream up_a up_b out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  set_edge_commits "$store/test-source.json" src/skills/alpha "$up_a" "$up_a"
  printf 'Alpha A\n' >"$root/src/skills/alpha/SKILL.md"
  printf 'A-only\n' >"$root/src/skills/alpha/old.md"

  out="$(run_cli "$root" diff --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream")"; rc=$?
  assert_rc 0 "$rc" "diff reports a clean local tree"
  assert_contains "$out" "no local changes" "the clean report is named"
}

test_prepare_builds_the_three_trees_and_leaves_the_store_untouched() {
  local root store upstream up_a up_b before after out rc ws
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  set_edge_commits "$store/test-source.json" src/skills/alpha "$up_a" "$up_a"
  before="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"

  out="$(run_cli "$root" prepare --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream" --revision "$up_b")"; rc=$?
  assert_rc 0 "$rc" "prepare creates the merge workspace"
  ws="$(printf '%s\n' "$out" | sed -n 's/^source-bump: prepared //p')"
  assert_file_exists "$ws/base/SKILL.md" "the base tree is present"
  assert_file_exists "$ws/ours/SKILL.md" "the ours tree is present"
  assert_file_exists "$ws/theirs/SKILL.md" "the theirs tree is present"
  assert_eq "$(cat "$ws/base/SKILL.md")" "Alpha A" "the base is the stored revision"
  assert_contains "$(cat "$ws/ours/SKILL.md")" "Alpha." "the ours tree is the local artifact"
  assert_eq "$(cat "$ws/theirs/SKILL.md")" "Alpha B" "the theirs tree is the new revision"
  assert_file_exists "$ws/base/old.md" "a base-only file is present"
  assert_file_exists "$ws/theirs/new.md" "a new upstream file is present"
  [[ ! -e "$ws/theirs/old.md" ]] && pass "a deleted upstream file is absent" \
    || fail "a deleted upstream file is absent"

  after="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"
  assert_eq "$after" "$before" "prepare wrote no store change"
  rm -rf "$ws"
}

test_prepare_refuses_a_misshapen_edge() {
  local root store upstream up_a up_b out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  set_edge_commits "$store/test-source.json" src/skills/alpha "$up_a" "$up_a"
  set_edge_upstream "$store/test-source.json" src/skills/alpha prompts/auto.md

  out="$(run_cli "$root" prepare --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream" --revision "$up_b")"; rc=$?
  assert_rc 1 "$rc" "a skill edge pointing at a blob is refused"
  assert_contains "$out" "is blob, expected tree" "the object type is named"
}

test_prepare_refuses_an_absent_upstream_path() {
  local root store upstream up_a up_b out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  set_edge_commits "$store/test-source.json" src/skills/alpha "$up_a" "$up_a"
  set_edge_upstream "$store/test-source.json" src/skills/alpha skills/missing

  out="$(run_cli "$root" prepare --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream" --revision "$up_b")"; rc=$?
  assert_rc 1 "$rc" "an absent upstream path is refused"
  assert_contains "$out" "has no skills/missing at base" "the absent path is named"
}

test_prepare_a_prompt_artifact() {
  local root store upstream up_a up_b before after out rc ws
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  mkdir -p "$root/prompts"
  printf 'Prompt.\n' >"$root/prompts/auto.md"
  add_edge "$store/test-source.json" test-source prompts/auto.md prompt null \
    prompts/auto.md "$up_a" "$up_a"
  before="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"

  out="$(run_cli "$root" prepare --store "$store" --source test-source \
    --local prompts/auto.md --clone "$upstream" --revision "$up_b")"; rc=$?
  assert_rc 0 "$rc" "prepare accepts a prompt artifact"
  ws="$(printf '%s\n' "$out" | sed -n 's/^source-bump: prepared //p')"
  assert_file_exists "$ws/base/auto.md" "the prompt base is present"
  assert_file_exists "$ws/ours/auto.md" "the prompt ours is present"
  assert_file_exists "$ws/theirs/auto.md" "the prompt theirs is present"
  assert_eq "$(cat "$ws/base/auto.md")" "Prompt A" "the prompt base is the stored revision"
  assert_eq "$(cat "$ws/ours/auto.md")" "Prompt." "the prompt ours is the local file"
  assert_eq "$(cat "$ws/theirs/auto.md")" "Prompt B" "the prompt theirs is the new revision"

  after="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"
  assert_eq "$after" "$before" "prepare wrote no store change for a prompt"
  rm -rf "$ws"
}

test_prepare_refuses_a_short_or_unknown_revision() {
  local root store upstream up_a up_b out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  read -r up_a up_b < <(make_upstream)
  upstream="$FIXTURE_DIR/upstream"
  set_edge_commits "$store/test-source.json" src/skills/alpha "$up_a" "$up_a"

  out="$(run_cli "$root" prepare --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream" --revision short)"; rc=$?
  assert_rc 2 "$rc" "a short revision is refused"
  assert_contains "$out" "--revision must be a 40-character commit" "the short revision is named"

  out="$(run_cli "$root" prepare --store "$store" --source test-source \
    --local src/skills/alpha --clone "$upstream" --revision "$C")"; rc=$?
  assert_rc 1 "$rc" "an unknown revision is refused"
  assert_contains "$out" "has no revision $C" "the missing revision is named"
}

test_help_lists_the_four_commands() {
  local out rc
  out="$(node "$CLI" --help 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the help exits cleanly"
  assert_contains "$out" "source-bump check" "check is listed"
  assert_contains "$out" "source-bump format" "format is listed"
  assert_contains "$out" "source-bump diff" "diff is listed"
  assert_contains "$out" "source-bump prepare" "prepare is listed"
  assert_not_contains "$out" "source-bump add" "add is gone"
  assert_not_contains "$out" "source-bump record" "record is gone"
}

# values_only FILE -- every field value, with key order and artifact order
# normalised away, so a form change compares equal.
values_only() {
  node -e '
    const fs = require("fs");
    const sortKeys = (value) => {
      if (Array.isArray(value)) return value.map(sortKeys);
      if (value === null || typeof value !== "object") return value;
      return Object.keys(value).sort().reduce((out, key) => {
        out[key] = sortKeys(value[key]);
        return out;
      }, {});
    };
    const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    data.artifacts.sort((left, right) => (left.local_path < right.local_path ? -1 : 1));
    console.log(JSON.stringify(sortKeys(data)));
  ' "$1"
}

test_format_canonicalises_without_changing_a_value() {
  local root store before after out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"

  # A hand-written file: reversed key order, four-space indent, unsorted edges.
  cat >"$store/test-source.json" <<EOF
{
    "copyright": "Copyright Test",
    "license": "MIT",
    "url": "https://example.test/source",
    "id": "test-source",
    "schema": 1,
    "artifacts": [
        {
            "origin": "$A",
            "base": "$A",
            "upstream_path": "skills/beta",
            "parent": null,
            "kind": "skill",
            "local_path": "src/skills/beta"
        },
        {
            "origin": "$A",
            "base": "$A",
            "upstream_path": "skills/alpha",
            "parent": null,
            "kind": "skill",
            "local_path": "src/skills/alpha"
        }
    ]
}
EOF
  before="$(values_only "$store/test-source.json")"

  out="$(run_cli "$root" format --store "$store")"; rc=$?
  assert_rc 0 "$rc" "format writes a hand-written file"
  assert_contains "$out" "formatted 1 source file(s)" "the written file is counted"
  assert_eq "$(paths_in_store "$store/test-source.json")" "src/skills/alpha,src/skills/beta" \
    "the edges are sorted"
  after="$(values_only "$store/test-source.json")"
  assert_eq "$after" "$before" "no field value changed"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the canonicalised store passes the check"
}

test_format_leaves_a_canonical_file_identical() {
  local root store before after out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  before="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"

  out="$(run_cli "$root" format --store "$store")"; rc=$?
  assert_rc 0 "$rc" "format accepts a canonical file"
  assert_contains "$out" "formatted 0 source file(s)" "nothing is rewritten"

  after="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"
  assert_eq "$after" "$before" "the file is byte-identical"
}

test_format_refuses_an_invalid_store() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  rm -rf "$root/src/skills/beta"

  out="$(run_cli "$root" format --store "$store")"; rc=$?
  assert_rc 1 "$rc" "format refuses a store the validator rejects"
  assert_contains "$out" "local_path src/skills/beta does not exist" "the invalid edge is named"
}

test_the_gate_and_check_agree() {
  local root store check_out gate_out
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  rm -rf "$root/src/skills/beta"

  check_out="$(run_cli "$root" check --store "$store")"
  gate_out="$(SKILL_SOURCE_ROOT="$root" SKILL_SOURCE_STORE="$store" \
    node "$REPO_ROOT/scripts/lint/skill_sources.mjs" 2>&1)"

  assert_contains "$check_out" "local_path src/skills/beta does not exist" "check names the missing path"
  assert_contains "$gate_out" "local_path src/skills/beta does not exist" "the gate names the same finding"
}

run_test test_clean_fixture_passes
run_test test_a_missing_local_path_fails
run_test test_a_bad_record_field_fails
run_test test_an_artifact_in_two_sources_is_allowed
run_test test_a_duplicate_edge_in_one_source_fails
run_test test_invalid_kind_bad_base_and_unknown_status_fail
run_test test_an_empty_source_needs_a_reason
run_test test_format_canonicalises_without_changing_a_value
run_test test_format_leaves_a_canonical_file_identical
run_test test_format_refuses_an_invalid_store
run_test test_the_gate_and_check_agree
run_test test_runbook_and_prompt_edges
run_test test_unknown_fields_and_hashes_are_refused
run_test test_diff_prints_the_local_change_and_leaves_the_store_untouched
run_test test_diff_reports_no_local_changes
run_test test_prepare_builds_the_three_trees_and_leaves_the_store_untouched
run_test test_prepare_refuses_a_misshapen_edge
run_test test_prepare_refuses_an_absent_upstream_path
run_test test_prepare_a_prompt_artifact
run_test test_prepare_refuses_a_short_or_unknown_revision
run_test test_help_lists_the_four_commands

test_done
