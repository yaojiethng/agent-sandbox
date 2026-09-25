#!/usr/bin/env bash
# R3 done right (2-space indent), then the probes that failed for the wrong reason.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/run_agent.sh
ORIG=/tmp/ra.orig
STUB="$PWD/tests/stubs"
ROOT=/tmp/probe_ra2; rm -rf "$ROOT"; mkdir -p "$ROOT"

R3_OLD='if [[ -z "$DELIVERY" ]]; then
  echo "Error: --delivery is required'
R3_NEW='if false; then
  echo "Error: --delivery is required'

fix() { # fix <name> <provider>
  local d="$ROOT/$1" p="$2"
  rm -rf "$d"; mkdir -p "$d/sandbox" "$d/project"
  export PROJECT_NAME="test-project" PROVIDER_NAME="$p"
  export SANDBOX_DIR="$d/sandbox" SERVE_PORT="46553" HOST_UID="1000" HOST_GID="1000"
  export SESSION_TS="20260730-000000" HOST_HEAD_SHA="abc123" SESSION_ID="test01"
  export SANITIZED_HOST_BRANCH="master"
  export SANDBOX_CONTAINER_NAME="sandbox-test-project-test01"
  export AGENT_CONTAINER_NAME="$p-test-project-test01"
  printf 'SANDBOX_DIR=%s\nPROJECT_DIR=%s\n' "$SANDBOX_DIR" "$d/project" > "$SANDBOX_DIR/.env"
  export DOCKER_TRACE_LOG="$d/trace.log"; :> "$DOCKER_TRACE_LOG"
  D="$d"
}
run() { # run <out> <mode> <args...>
  local out="$1" mode="$2"; shift 2
  ( export PATH="$STUB:$PATH"
    bash "$SRC" "$mode" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" \
      --env="$SANDBOX_DIR/.env" --provider="$PROVIDER_NAME" "$@" < /dev/null ) > "$out" 2>&1
  echo $?
}
mut() { cp "$ORIG" "$SRC"; OLD="$1" NEW="$2" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"; }
res() { cp "$ORIG" "$SRC"; }

echo "############ R3c bite: the required-delivery guard disabled ############"
mut "$R3_OLD" "$R3_NEW"
diff "$ORIG" "$SRC" | head -4 | sed 's/^/  /'
timeout 900 bash scripts/run_tests.sh > /tmp/bite_ra_R3c.log 2>&1
if grep -q '^FAIL ' /tmp/bite_ra_R3c.log; then
  echo "  R3c PROVEN: $(grep '^FAIL ' /tmp/bite_ra_R3c.log | sed 's/^FAIL //' | tr '\n' ' ')"
else echo "  R3c SURVIVED: $(tail -1 /tmp/bite_ra_R3c.log)"; fi

echo
echo "############ P2: what does a missing --delivery do? ############"
for tag in pristine mutant; do
  [[ $tag == mutant ]] && mut "$R3_OLD" "$R3_NEW" || res
  fix p2 opencode
  rc=$(run "$D/out.txt" standard)
  echo "--- $tag rc=$rc"
  echo "    overlays: $(grep -o '\-f [^ ]*' "$D/trace.log" | sed 's|.*/||' | sort -u | tr '\n' ' ')"
  echo "    stdout:  $(head -2 "$D/out.txt" | tr '\n' ' | ')"
done
res

echo
echo "############ P3/P4: provider dir + seeder -T (opencode has no setup hook) ############"
for tag in pristine mutant; do
  if [[ $tag == mutant ]]; then
    mut 'mkdir -p "$SANDBOX_DIR/.$PROVIDER_NAME"' ':'
    mut 'run --rm -T seeder < /dev/null' 'run --rm seeder < /dev/null'
  else res; fi
  fix p3 opencode
  export RESET_VOLUME=true
  rc=$(run "$D/out.txt" standard --delivery=copy --reset-volume)
  unset RESET_VOLUME
  echo "--- $tag rc=$rc"
  echo "    .opencode created by run_agent: $( [[ -e "$SANDBOX_DIR/.opencode" ]] && echo yes || echo no )"
  echo "    seeder invocation: $(grep -o 'run .*seeder' "$D/trace.log" | head -1)"
  echo "    output: $(grep -i 'seed' "$D/out.txt" | head -1)"
done
res

echo
echo "############ P5: seeder timeout attribution ############"
for tag in pristine mutant; do
  [[ $tag == mutant ]] && mut 'if (( rc == 124 )); then' 'if (( rc == 123 )); then' || res
  fix p5 opencode
  export RESET_VOLUME=true SEED_TIMEOUT=0.001
  rc=$(run "$D/out.txt" standard --delivery=copy --reset-volume)
  unset RESET_VOLUME SEED_TIMEOUT
  echo "--- $tag rc=$rc : $(grep -i 'timed out\|seeder failed' "$D/out.txt" | head -1)"
done
res

echo
echo "############ P10: FLATTEN - export visible to the compose file? ############"
for tag in pristine mutant; do
  [[ $tag == mutant ]] && mut 'export FLATTEN' '# export FLATTEN' || res
  fix p10 opencode
  rc=$(run "$D/out.txt" standard --delivery=mount --flatten)
  echo "--- $tag rc=$rc"
  echo "    yml FLATTEN lines: $(grep -c 'FLATTEN' "$SANDBOX_DIR/.compose/test01.yml" 2>/dev/null)"
  grep -n 'FLATTEN' "$SANDBOX_DIR/.compose/test01.yml" 2>/dev/null | sed 's/^/      /'
done
res
cmp -s "$ORIG" "$SRC" && echo "source byte-identical"
