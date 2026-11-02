#!/usr/bin/env bash
# tests/test_source_bump.sh
# The source-bump tracking store: one JSON file per source, the source and
# artifact schema, the CLI writes, and the rules the store refuses.
#
# Covers:
#   clean          -- a source with two artifacts passes
#   missing path   -- an artifact whose local path is gone fails
#   duplicate path -- one local path under two sources fails
#   bad fields     -- an unknown kind, a short base and an unknown status fail
#   empty source   -- an empty source needs a reason and carries no status
#   add            -- add creates a source, appends an edge, sorts and creates an
#                     empty source; source facts are required only on creation
#   record         -- record moves base, preserves origin, and leaves the file
#                     untouched when the new base is invalid
#   kinds          -- a runbook names its parent and a prompt is a file
#   diff           -- diff prints the base -> local change from a clone and
#                     leaves the store untouched
#   prepare        -- prepare creates base, ours and theirs from a clone and
#                     leaves the store untouched
#   help           -- the CLI exposes check, add, diff, prepare and record

set -uo pipefail

# TEST_DEADLINE: 60

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

CLI="$REPO_ROOT/scripts/source_bump.mjs"
A="62f43a18177be6ec82da242e59ffbc490a4c22ea"
B="5beb35b040e3de97e54fa9e386d7e42d15c295c2"
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

test_a_duplicate_local_path_fails() {
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
  assert_rc 1 "$rc" "one local path under two sources fails"
  assert_contains "$out" "local_path src/skills/alpha is already used by source" "the duplicate is named"
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
    d.reason = "Not forked by this repository.";
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + "\n");
  ' "$store/empty-source.json"
  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "an empty source with a reason passes"
  assert_contains "$out" "clean across 2 source(s) and 2 artifact(s)" "the empty source is counted"
}

test_add_appends_and_sorts() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/skills/gamma"
  printf '%s\n' '---' 'name: gamma' 'description: The gamma skill.' '---' '' 'Gamma.' \
    >"$root/src/skills/gamma/SKILL.md"

  out="$(run_cli "$root" add --store "$store" --source test-source \
    --local src/skills/gamma --kind skill --upstream skills/gamma \
    --origin "$A" --base "$B")"; rc=$?
  assert_rc 0 "$rc" "add appends an edge"
  assert_contains "$out" "added src/skills/gamma to test-source" "the added edge is named"
  assert_eq "$(paths_in_store "$store/test-source.json")" \
    "src/skills/alpha,src/skills/beta,src/skills/gamma" "the edges are sorted by local path"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the store passes after add"
  assert_contains "$out" "clean across 1 source(s) and 3 artifact(s)" "the new edge is counted"
  assert_eq "$(source_field "$store/test-source.json" src/skills/gamma)" "$A $B" "the new edge keeps origin and base"
}

test_add_creates_a_source_file() {
  local root store out rc
  root="$FIXTURE_DIR/tree"
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/skills/solo"
  printf '%s\n' '---' 'name: solo' 'description: The solo skill.' '---' '' 'Solo.' \
    >"$root/src/skills/solo/SKILL.md"

  out="$(run_cli "$root" add --store "$store" --source solo-source \
    --url https://example.test/solo --license MIT --copyright "Copyright Solo" \
    --local src/skills/solo --kind skill --upstream skills/solo \
    --origin "$A" --base "$A")"; rc=$?
  assert_rc 0 "$rc" "add creates the source file when it is absent"
  assert_contains "$out" "added src/skills/solo to solo-source" "the created edge is named"
  assert_file_exists "$store/solo-source.json" "the source file exists"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the created store passes"
  assert_contains "$out" "clean across 1 source(s) and 1 artifact(s)" "the created source is counted"
}

test_add_requires_source_facts_when_creating() {
  local root store out rc
  root="$FIXTURE_DIR/tree"
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/skills/solo"
  printf '%s\n' '---' 'name: solo' 'description: The solo skill.' '---' '' 'Solo.' \
    >"$root/src/skills/solo/SKILL.md"

  out="$(run_cli "$root" add --store "$store" --source solo-source \
    --local src/skills/solo --kind skill --upstream skills/solo \
    --origin "$A" --base "$A")"; rc=$?
  assert_rc 2 "$rc" "a new source without its facts is refused"
  assert_contains "$out" "--url is required" "the missing source fact is named"
  [[ ! -e "$store/solo-source.json" ]] && pass "the refused add wrote no file" \
    || fail "the refused add wrote no file"
}

test_add_empty_source() {
  local root store out rc
  root="$FIXTURE_DIR/tree"
  store="$root/.agents/registry/sources"

  out="$(run_cli "$root" add --store "$store" --source empty-source \
    --url https://example.test/empty --license MIT --copyright "Copyright Empty" \
    --empty)"; rc=$?
  assert_rc 2 "$rc" "an empty source without a reason is refused"
  assert_contains "$out" "--empty requires --reason" "the missing reason is named"

  out="$(run_cli "$root" add --store "$store" --source empty-source \
    --url https://example.test/empty --license MIT --copyright "Copyright Empty" \
    --empty --reason "Not forked by this repository.")"; rc=$?
  assert_rc 0 "$rc" "an empty source with a reason is written"
  assert_contains "$out" "created empty source empty-source" "the created source is named"
  assert_not_contains "$(cat "$store/empty-source.json")" '"status"' "an empty source has no status field"
  assert_contains "$(cat "$store/empty-source.json")" '"artifacts": []' "an empty source holds an empty artifact list"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the empty source passes the check"
  assert_contains "$out" "clean across 1 source(s) and 0 artifact(s)" "the empty source is counted"
}

test_add_to_an_empty_source_clears_the_reason() {
  local root store out rc
  root="$FIXTURE_DIR/tree"
  store="$root/.agents/registry/sources"
  mkdir -p "$root/src/skills/late"
  printf '%s\n' '---' 'name: late' 'description: The late skill.' '---' '' 'Late.' \
    >"$root/src/skills/late/SKILL.md"

  run_cli "$root" add --store "$store" --source late-source \
    --url https://example.test/late --license MIT --copyright "Copyright Late" \
    --empty --reason "The first edge has not landed." >/dev/null
  out="$(run_cli "$root" add --store "$store" --source late-source \
    --local src/skills/late --kind skill --upstream skills/late \
    --origin "$A" --base "$A")"; rc=$?
  assert_rc 0 "$rc" "an edge can be added to an empty source"
  assert_not_contains "$(cat "$store/late-source.json")" '"reason"' "the reason leaves when the source is no longer empty"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the source passes after its first edge"
  assert_contains "$out" "clean across 1 source(s) and 1 artifact(s)" "the first edge is counted"
}

test_add_refusal_leaves_the_file_unchanged() {
  local root store before after out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  before="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"

  out="$(run_cli "$root" add --store "$store" --source test-source \
    --local src/skills/alpha --kind skill --upstream skills/alpha \
    --origin "$A" --base "$A")"; rc=$?
  assert_rc 1 "$rc" "a duplicate local path is refused"
  assert_contains "$out" "src/skills/alpha is listed twice" "the duplicate edge is named"

  after="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"
  assert_eq "$after" "$before" "the refused add wrote nothing"
}

test_record_moves_base_and_preserves_origin() {
  local root store out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"

  out="$(run_cli "$root" record --store "$store" --source test-source \
    --local src/skills/alpha --base "$C")"; rc=$?
  assert_rc 0 "$rc" "record moves one edge's base"
  assert_contains "$out" "moved src/skills/alpha base to $C in test-source" "the moved edge is named"
  assert_eq "$(source_field "$store/test-source.json" src/skills/alpha)" "$A $C" "origin is preserved and base moved"
  assert_eq "$(source_field "$store/test-source.json" src/skills/beta)" "$A $A" "the other edge is untouched"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the store passes after record"
}

test_record_failure_leaves_the_file_unchanged() {
  local root store before after out rc
  root="$(make_fixture)"
  store="$root/.agents/registry/sources"
  before="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"

  out="$(run_cli "$root" record --store "$store" --source test-source \
    --local src/skills/alpha --base short)"; rc=$?
  assert_rc 1 "$rc" "an invalid base is refused"
  assert_contains "$out" "base must be a 40-character commit" "the invalid base is named"

  after="$(sha256sum "$store/test-source.json" | cut -d' ' -f1)"
  assert_eq "$after" "$before" "the refused record wrote nothing"
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

  run_cli "$root" add --store "$store" --source test-source \
    --local src/skills/code-review --kind skill --upstream skills/code-review \
    --origin "$A" --base "$A" >/dev/null
  run_cli "$root" add --store "$store" --source test-source \
    --local src/skills/code-review/runbooks/review --kind runbook \
    --parent src/skills/code-review --upstream skills/code-review/runbooks/review \
    --origin "$A" --base "$A" >/dev/null
  out="$(run_cli "$root" add --store "$store" --source test-source \
    --local prompts/auto.md --kind prompt --upstream prompts/auto.md \
    --origin "$A" --base "$A")"; rc=$?
  assert_rc 0 "$rc" "a prompt edge is accepted"

  out="$(run_cli "$root" check --store "$store")"; rc=$?
  assert_rc 0 "$rc" "the skill, runbook and prompt store passes"
  assert_contains "$out" "clean across 1 source(s) and 5 artifact(s)" "all three kinds are counted"

  out="$(run_cli "$root" add --store "$store" --source test-source \
    --local src/skills/code-review/runbooks/review --kind runbook \
    --upstream skills/code-review/runbooks/review \
    --origin "$A" --base "$A")"; rc=$?
  assert_rc 2 "$rc" "a runbook without a parent is refused"
  assert_contains "$out" "a runbook requires --parent" "the missing parent is named"
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
  run_cli "$root" add --store "$store" --source test-source \
    --local prompts/auto.md --kind prompt --upstream prompts/auto.md \
    --origin "$up_a" --base "$up_a" >/dev/null
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

test_help_lists_the_five_commands() {
  local out rc
  out="$(node "$CLI" --help 2>&1)"; rc=$?
  assert_rc 0 "$rc" "the help exits cleanly"
  assert_contains "$out" "source-bump check" "check is listed"
  assert_contains "$out" "source-bump add" "add is listed"
  assert_contains "$out" "source-bump diff" "diff is listed"
  assert_contains "$out" "source-bump prepare" "prepare is listed"
  assert_contains "$out" "source-bump record" "record is listed"
}

run_test test_clean_fixture_passes
run_test test_a_missing_local_path_fails
run_test test_a_duplicate_local_path_fails
run_test test_invalid_kind_bad_base_and_unknown_status_fail
run_test test_an_empty_source_needs_a_reason
run_test test_add_appends_and_sorts
run_test test_add_creates_a_source_file
run_test test_add_requires_source_facts_when_creating
run_test test_add_empty_source
run_test test_add_to_an_empty_source_clears_the_reason
run_test test_add_refusal_leaves_the_file_unchanged
run_test test_record_moves_base_and_preserves_origin
run_test test_record_failure_leaves_the_file_unchanged
run_test test_runbook_and_prompt_edges
run_test test_unknown_fields_and_hashes_are_refused
run_test test_diff_prints_the_local_change_and_leaves_the_store_untouched
run_test test_diff_reports_no_local_changes
run_test test_prepare_builds_the_three_trees_and_leaves_the_store_untouched
run_test test_prepare_refuses_a_misshapen_edge
run_test test_prepare_refuses_an_absent_upstream_path
run_test test_prepare_a_prompt_artifact
run_test test_prepare_refuses_a_short_or_unknown_revision
run_test test_help_lists_the_five_commands

test_done
