#!/usr/bin/env bash
# tests/test_shared_base_contract.sh  --  the shared runtime base is the single
# owner of the runtimes and lint gates every reasoning layer inherits.
#
# The drift this guards against: a provider base reinstalls Node, Python, uv,
# or a linter, and the copies pin different versions from the shared base. The
# copy is invisible in review because the provider base is a small file, and the
# result is that two containers stop having the same toolchain.
#
# Pins cite: docs/reference/tool_interface.md provider interface table;
# docs/adr/git_hooks.md ("the linter ships in every provider base").
#
# Run:
#   bash tests/test_shared_base_contract.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

SHARED_BASE="$REPO_ROOT/src/reasoning/base.dockerfile"
PROVIDER_DIR="$REPO_ROOT/src/reasoning/agent-runtime"

# Every Dockerfile under the reasoning layer. The scan is deliberately not the
# provider bases alone: the dispatch CLI may be installed in any tier, and a
# hand-list would drift from the tree.
_reasoning_dockerfiles() {
  find "$REPO_ROOT/src/reasoning" -type f \
    \( -name "*.dockerfile" -o -name "Dockerfile*" \) | sort
}

# Emit one record per shell command in a Dockerfile, as "<line><TAB><command>".
# A logical Dockerfile instruction is joined across its backslash continuation
# lines first, so the installer and the package token may sit on different
# physical lines. The joined text is then split on the shell separators ; && ||,
# so every command is matched on its own tokens and a flag binds only to the
# command that carries it. Comment-only lines are skipped, and an inline shell
# comment is dropped before the tokens are read. The record's line is the first
# physical line of the logical instruction.
_dockerfile_shell_commands() {
  awk '
    function strip_comment(s,   n, t, i, out) {
      n = split(s, t, /[[:space:]]+/)
      out = ""
      for (i = 1; i <= n; i++) {
        if (t[i] ~ /^#/) break
        out = (out == "" ? t[i] : out " " t[i])
      }
      return out
    }
    function emit(   n, i, cmd) {
      if (buf == "") return
      n = split(buf, parts, /[;]|&&|\|\|/)
      for (i = 1; i <= n; i++) {
        cmd = strip_comment(parts[i])
        sub(/^[[:space:]]+/, "", cmd)
        sub(/[[:space:]]+$/, "", cmd)
        if (cmd != "") print start_line "\t" cmd
      }
    }
    /^[[:space:]]*#/ { next }
    {
      line = $0
      cont = (line ~ /\\[[:space:]]*$/)
      sub(/\\[[:space:]]*$/, "", line)
      if (buf == "") start_line = NR
      buf = buf line
      if (cont) next
      emit(); buf = ""
    }
    END { emit() }
  ' "$1"
}

# Print "<line><TAB><command>" for every package-manager install command:
# npm install, npm i, pnpm add, yarn add and bun add. The command separators are
# resolved first (see _dockerfile_shell_commands), so a flag on one command
# never binds to a package installed by another.
_package_install_commands() {
  _dockerfile_shell_commands "$1" | awk -F'\t' '
    {
      n = split($2, t, /[[:space:]]+/)
      is_install = 0
      for (i = 1; i < n; i++) {
        if (t[i] == "npm" && (t[i+1] == "install" || t[i+1] == "i")) is_install = 1
        if ((t[i] == "pnpm" || t[i] == "yarn" || t[i] == "bun") && t[i+1] == "add") is_install = 1
      }
      if (is_install) print
    }
  '
}

# Print one token per pi-coding-agent install: only an install command is read,
# so a prose mention (such as a provider's own header) is not a match.
_pi_coding_agent_installs() {
  _package_install_commands "$1" | awk -F'\t' '
    {
      n = split($2, t, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (t[i] ~ /pi-coding-agent/) print t[i]
      }
    }
  '
}

# The shared base is the one file that owns the runtime set. If it is missing,
# no provider has a runtime, and the build fails with a clearer message here.
# Given: the repository source tree
# When:  the shared base file is read
# Then:  it exists and the former node.dockerfile is gone
# Asserts: the shared base is the single runtime owner
test_shared_base_exists_and_node_dockerfile_is_gone() {
  [[ -f "$SHARED_BASE" ]] || { fail "shared base missing: $SHARED_BASE"; return; }
  [[ ! -e "$REPO_ROOT/src/reasoning/node.dockerfile" ]] \
    || { fail "node.dockerfile still present; the shared base is base.dockerfile"; return; }
  pass "shared base present, node.dockerfile gone"
}

# The shared base names the whole runtime set, including the Python floor the
# operator set. A dropped install line would leave an image without the tool.
# Given: the shared base file
# When:  its content is grepped
# Then:  it installs Node (the FROM line), uv, Python 3.11, hadolint, and markdownlint-cli2
# Asserts: the shared base installs the full runtime set
test_shared_base_installs_the_full_runtime_set() {
  local content; content="$(cat "$SHARED_BASE")"
  local missing=""
  grep -q "^FROM node:" <<< "$content" || missing="$missing node"
  grep -q "^ARG UV_VERSION=" <<< "$content" || missing="$missing uv"
  grep -q "^ARG UV_SHA256=" <<< "$content" || missing="$missing uv-checksum"
  grep -q "uv python install 3.11" <<< "$content" || missing="$missing python"
  grep -q "hadolint" <<< "$content" || missing="$missing hadolint"
  grep -q "registry/markdownlint-cli2/" <<< "$content" || missing="$missing markdownlint-cli2"
  assert_eq "$missing" "" "shared base installs every runtime and lint gate"
}

# Every tier-2 image inherits the shared base by its canonical default: the shared
# agent-runtime tier, and any provider base that a source-built runtime adds. A
# tier-2 image that pins a different default builds a different image than the one
# the build orchestrator passes in, and the two drift silently.
# Given: each providers/<n>/base.dockerfile and runtimes.dockerfile
# When:  the file's BASE_IMAGE default is read
# Then:  it equals agent-base
# Asserts: the tier-2 images inherit the shared base
test_tier2_images_inherit_the_shared_base() {
  local out=""
  local df
  for df in "$PROVIDER_DIR"/*/base.dockerfile; do
    [[ -e "$df" ]] || continue
    grep -q "^ARG BASE_IMAGE=agent-base$" "$df" \
      || out="$out $(basename "$(dirname "$df")")"
  done
  grep -q "^ARG BASE_IMAGE=agent-base$" "$REPO_ROOT/src/reasoning/runtimes.dockerfile" \
    || out="$out agent-runtimes"
  assert_eq "$out" "" "every tier-2 image defaults BASE_IMAGE to agent-base"
}

# The single rule the consolidation exists to hold: a tier-2 image adds its
# agent-runtime install and nothing else. A language runtime or linter install
# reappearing here is the regression this file exists to catch.
# Given: each providers/<n>/base.dockerfile and runtimes.dockerfile
# When:  the file is grepped for language runtime and linter installs
# Then:  no match
# Asserts: the shared base is the only owner of the language runtime set
test_tier2_images_install_no_runtime_or_linter() {
  local out=""
  local df
  for df in "$PROVIDER_DIR"/*/base.dockerfile; do
    [[ -e "$df" ]] || continue
    local hits
    hits="$(grep -nE 'nodesource|astral\.sh/uv|install python3|hadolint|markdownlint-cli2' "$df" || true)"
    [[ -z "$hits" ]] || out="$out $(basename "$(dirname "$df")")"
  done
  local runtime_hits
  runtime_hits="$(grep -nE 'nodesource|astral\.sh/uv|install python3|hadolint|markdownlint-cli2' "$REPO_ROOT/src/reasoning/runtimes.dockerfile" || true)"
  [[ -z "$runtime_hits" ]] || out="$out agent-runtimes"
  assert_eq "$out" "" "no tier-2 image installs a language runtime or a linter"
}

# The dispatch CLI has one pin, and its home is the committed lockfile. A
# dependency range in the registry directory would resolve to whatever the
# registry serves at build time, so every dependency there names an exact
# version and the lockfile pins what that version resolved to.
# Given: every registry directory's package.json
# When:  each dependency spec is read
# Then:  every spec is an exact version
# Asserts: no unpinned registry dependency
test_registry_dependencies_are_exact() {
  local offenders=""
  local manifest
  for manifest in "$REPO_ROOT"/src/reasoning/registry/*/package.json; do
    [[ -e "$manifest" ]] || continue
    local out
    out="$(node -e '
      const pkg = require(process.argv[1]);
      const bad = Object.entries(pkg.dependencies || {})
        .filter(([, spec]) => !/^[0-9]+\.[0-9]+\.[0-9]+$/.test(spec))
        .map(([name, spec]) => name + "@" + spec);
      if (bad.length) console.log(bad.join(" "));
    ' "$manifest")"
    [[ -z "$out" ]] || offenders="$offenders $manifest:$out"
  done
  assert_empty "$offenders" "every registry dependency names an exact version"
}

# opencode ships one binary per platform and per C library, and its package
# names all of them as optional dependencies. An npm install of that package
# therefore lands four linux-x64 variants -- 730MB for one executable -- so the
# tier pins the single tarball instead and no npm install may name it again.
# Given: the shared agent-runtime tier
# When:  its install steps are read
# Then:  no package-manager install names opencode-ai, and the opencode step
#        fetches a versioned tarball, verifies its checksum and links one binary
# Asserts: the tier installs one verified executable rather than a platform matrix
test_opencode_is_one_verified_binary() {
  local offenders installs
  installs="$(_package_install_commands "$REPO_ROOT/src/reasoning/runtimes.dockerfile")"
  offenders="$(printf '%s\n' "$installs" | grep -c 'opencode-ai' || true)"
  assert_eq "$offenders" "0" "no npm install names opencode-ai"

  local run
  run="$(grep -A8 '^RUN curl -fsSL -o /tmp/opencode.tgz' "$REPO_ROOT/src/reasoning/runtimes.dockerfile" || true)"
  assert_contains "$run" 'opencode-linux-x64-$' "the fetch names the platform package"
  assert_contains "$run" 'sha256sum -c -' "the tarball is verified before it is unpacked"
  assert_contains "$run" 'install -D -m 0755' "one binary is installed"
  assert_contains "$run" 'ln -s /opt/opencode/opencode /usr/local/bin/opencode' "the binary is on PATH"
  assert_contains "$run" 'rm -rf /tmp/package /tmp/opencode.tgz' "the download leaves the layer"
}

# The shape's core rule: every agent-runtime package installs in exactly one
# place, and that place is its own registry directory. A second home is a
# finding, whatever tier it sits in, because a second lockfile is a second
# resolution of the same tree.
# Given: every registry directory
# When:  the agent-runtime package each one declares is read
# Then:  each has one home, and that home is its own directory
# Asserts: each agent-runtime package installs exactly once
test_each_agent_runtime_package_has_one_home() {
  local homes="" dir pkg
  local -a hits
  for dir in "$REPO_ROOT"/src/reasoning/registry/*/; do
    [[ -d "$dir" ]] || continue
    pkg="$(basename "$dir")"
    mapfile -t hits < <(grep -rl --include=package.json -e '"@earendil-works/pi-coding-agent"' "$REPO_ROOT/src/reasoning/registry/" 2>/dev/null | grep "/$pkg/")
    case "$pkg" in
      pi)
        (( ${#hits[@]} == 1 )) || homes="$homes $pkg:${#hits[@]}" ;;
      *)
        (( ${#hits[@]} == 0 )) || homes="$homes $pkg:${#hits[@]}" ;;
    esac
  done
  assert_empty "$homes" "each agent-runtime package has one registry home"
}

run_test test_shared_base_exists_and_node_dockerfile_is_gone
run_test test_shared_base_installs_the_full_runtime_set
run_test test_tier2_images_inherit_the_shared_base
run_test test_tier2_images_install_no_runtime_or_linter
run_test test_registry_dependencies_are_exact
run_test test_opencode_is_one_verified_binary
run_test test_each_agent_runtime_package_has_one_home

test_done
