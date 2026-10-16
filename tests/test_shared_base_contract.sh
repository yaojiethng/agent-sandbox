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
PROVIDER_DIR="$REPO_ROOT/src/reasoning/providers"

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
_opencode_ai_install_commands() {
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

# Print one token per opencode-ai install: "opencode-ai@<spec>" when a version
# is given, bare "opencode-ai" when it is not. Only an install command is read,
# so a prose mention (such as opencode/provider.dockerfile's own header) is not
# a match.
_opencode_ai_installs() {
  _opencode_ai_install_commands "$1" | awk -F'\t' '
    {
      n = split($2, t, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (t[i] == "opencode-ai") print "opencode-ai"
        else if (t[i] ~ /^opencode-ai@/) print t[i]
      }
    }
  '
}

# Print the line number of every install command that names opencode-ai and
# also carries --ignore-scripts. Such an install skips the postinstall that
# writes the platform binary the bin entry points at, so the CLI lands on PATH
# with nothing to run.
_opencode_ai_installs_skipping_postinstall() {
  _opencode_ai_install_commands "$1" | awk -F'\t' '
    {
      n = split($2, t, /[[:space:]]+/)
      has_pkg = 0; has_flag = 0
      for (i = 1; i <= n; i++) {
        if (t[i] == "opencode-ai" || t[i] ~ /^opencode-ai@/) has_pkg = 1
        if (t[i] == "--ignore-scripts") has_flag = 1
      }
      if (has_pkg && has_flag) print $1
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
  grep -q "astral.sh/uv/install.sh" <<< "$content" || missing="$missing uv"
  grep -q "uv python install 3.11" <<< "$content" || missing="$missing python"
  grep -q "hadolint" <<< "$content" || missing="$missing hadolint"
  grep -q "markdownlint-cli2" <<< "$content" || missing="$missing markdownlint-cli2"
  assert_eq "$missing" "" "shared base installs every runtime and lint gate"
}

# Every provider base inherits the shared base by its canonical default. A
# provider that pins a different default builds a different image than the one
# the build orchestrator passes in, and the two drift silently.
# Given: each providers/<n>/base.dockerfile
# When:  the file's BASE_IMAGE default is read
# Then:  it equals agent-base
# Asserts: the provider bases inherit the shared base
test_provider_bases_inherit_the_shared_base() {
  local out=""
  local df
  for df in "$PROVIDER_DIR"/*/base.dockerfile; do
    [[ -e "$df" ]] || continue
    grep -q "^ARG BASE_IMAGE=agent-base$" "$df" \
      || out="$out $(basename "$(dirname "$df")")"
  done
  assert_eq "$out" "" "every provider base defaults BASE_IMAGE to agent-base"
}

# The single rule the consolidation exists to hold: a provider base adds the
# agent and nothing else. A runtime or linter install reappearing here is the
# regression this file exists to catch.
# Given: each providers/<n>/base.dockerfile
# When:  the file is grepped for runtime and linter installs
# Then:  no match
# Asserts: the shared base is the only owner of the runtime set
test_provider_bases_install_no_runtime_or_linter() {
  local out=""
  local df
  for df in "$PROVIDER_DIR"/*/base.dockerfile; do
    [[ -e "$df" ]] || continue
    local hits
    hits="$(grep -nE 'nodesource|astral\.sh/uv|install python3|hadolint|markdownlint-cli2' "$df" || true)"
    [[ -z "$hits" ]] || out="$out $(basename "$(dirname "$df")"):$(wc -l <<< "$hits")"
  done
  assert_eq "$out" "" "no provider base installs a runtime or a linter"
}

# The dispatch CLI has one pin, wherever it is installed. A Dockerfile that
# installs opencode-ai without an exact version makes the image build
# unreproducible: the package resolves to whatever latest is at build time.
# Given: every Dockerfile under src/reasoning
# When:  each install of opencode-ai is read
# Then:  every install names an exact version
# Asserts: no unpinned opencode-ai install
test_opencode_ai_installs_are_pinned() {
  local df token version offenders=""
  while IFS= read -r df; do
    [[ -e "$df" ]] || continue
    while IFS= read -r token; do
      [[ -n "$token" ]] || continue
      version="${token#*@}"
      if [[ "$token" == "opencode-ai" ]] || [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        offenders="$offenders ${df#$REPO_ROOT/}:$token"
      fi
    done < <(_opencode_ai_installs "$df")
  done < <(_reasoning_dockerfiles)

  assert_empty "$offenders" "every opencode-ai install pins an exact version"
}

# opencode-ai's bin is inert until its postinstall writes the platform binary.
# An opencode-ai install that carries --ignore-scripts skips that step, so the
# CLI lands on PATH with nothing to run. The flag is inert for the
# pi-coding-agent install, whose package declares no postinstall; an
# opencode-ai install must not carry it.
# Given: every Dockerfile under src/reasoning
# When:  each install of opencode-ai is read for --ignore-scripts
# Then:  no install that names opencode-ai carries the flag
# Asserts: every opencode-ai install can produce a working binary
test_opencode_ai_installs_produce_a_working_binary() {
  local df lineno offenders=""
  while IFS= read -r df; do
    [[ -e "$df" ]] || continue
    while IFS= read -r lineno; do
      [[ -n "$lineno" ]] || continue
      offenders="$offenders ${df#$REPO_ROOT/}:$lineno"
    done < <(_opencode_ai_installs_skipping_postinstall "$df")
  done < <(_reasoning_dockerfiles)

  assert_empty "$offenders" "every opencode-ai install runs the postinstall that writes its binary"
}

# One dispatch CLI version across every image that installs it; two pins
# disagree and the two images run different CLIs. The test compares the pin
# values, not the count of installing Dockerfiles: the install's home among the
# tiers is undecided, so one file or several is not a failure.
# Given: every Dockerfile under src/reasoning
# When:  each exact opencode-ai pin is collected
# Then:  at most one distinct version appears
# Asserts: all opencode-ai pins agree
test_opencode_ai_pins_agree() {
  local df token version
  local -a pins=()
  while IFS= read -r df; do
    [[ -e "$df" ]] || continue
    while IFS= read -r token; do
      [[ "$token" == opencode-ai@* ]] || continue
      version="${token#*@}"
      [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
      pins+=("$version")
    done < <(_opencode_ai_installs "$df")
  done < <(_reasoning_dockerfiles)

  local -A distinct=()
  local pin
  for pin in "${pins[@]}"; do distinct[$pin]=1; done
  if (( ${#distinct[@]} <= 1 )); then
    pass "all opencode-ai pins agree (${#distinct[@]} distinct version(s))"
  else
    fail "opencode-ai pins disagree: ${!distinct[*]}"
  fi
}

run_test test_shared_base_exists_and_node_dockerfile_is_gone
run_test test_shared_base_installs_the_full_runtime_set
run_test test_provider_bases_inherit_the_shared_base
run_test test_provider_bases_install_no_runtime_or_linter
run_test test_opencode_ai_installs_are_pinned
run_test test_opencode_ai_pins_agree
run_test test_opencode_ai_installs_produce_a_working_binary

test_done
