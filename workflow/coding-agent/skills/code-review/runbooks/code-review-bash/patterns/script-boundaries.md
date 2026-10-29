# Script-boundary patterns

Open this when a script is run or sourced, when it decides which mode it is running in, or when it hands off to another script.

## p-15 Guard a dual-use script's `main`

```bash
main() { ... }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

A file that both exports functions for sourcing and runs standalone needs this guard to separate the two modes, because the sourcing consumer must not execute the entry logic. Use `"$0"`, not `${0}`, and add no `||` array-length fallback: the test is exact.

Replaces: a dual-use file that calls `main` unconditionally, so every source of it runs the entry.

## p-16 Parse a selection once, pass it as an argument

```bash
# Entry: parse once, default at ingestion
DELIVERY="copy"
for ARG in "$@"; do
  case "$ARG" in
    --delivery=*) DELIVERY="${ARG#--delivery=}" ;;
  esac
done
exec "$REPO_ROOT/scripts/run_agent.sh" "$MODE" --delivery="$DELIVERY"

# Downstream: required argument, no default, no environment read
if [[ -z "$DELIVERY" ]]; then
  echo "Error: --delivery is required (copy|mount); the caller must state it" >&2
  exit 1
fi
```

A mode or model selection is a command input, not environment state. The entry parses it, or its default, exactly once, and every downstream consumer receives it as an explicit argument: no environment read, no re-applied `${VAR:-default}`, no export. A consumer resuming a persisted operation recovers the value from the record and rejects the record when the field is absent. A silently propagated default lets one mode impersonate another, which is the mount-resume-as-copy failure. A container-boundary value in a compose `environment:` literal is persisted config rather than bash state, and is unaffected.

Replaces: `${DELIVERY:-copy}` re-applied at a second site, and an exported `DELIVERY` read back out of the environment.

## p-17 Dispatch a subcommand through `exec`

```bash
build)
  parse_flags "$@"
  exec bash "$SCRIPTS/build.sh" --targets="$TARGETS"
  ;;
```

Each subcommand gets a clean process boundary: a dispatch branch is `exec`, or short validation followed by `exec`. A branch longer than five lines belongs in the subcommand script.

Replaces: sourcing the subcommand script, and calling it without `exec` so the caller traps the signals and holds the exit status.

## p-40 Give a child its own standard input

```bash
while IFS= read -r item; do
  opencode run "$item" < /dev/null
done < plan.txt
```

A child that reads standard input takes it from the loop's own file descriptor, so the loop reaches end of file after the first item, exits, and reports success. A caller that asked for every item in the file gets one, and no error says so. Redirect the child's input from `/dev/null`, which it can read and which ends immediately, so the loop keeps the stream it is walking.

Replaces: a loop over a redirected file that runs a child with no `< /dev/null`.

## p-61 Cross the process boundary at one named seam

```bash
# The seam, and the only place the dependency is named
run_external() { "$EXTERNAL_CMD" "$@"; }

# The test replaces the seam with the same name and signature
run_external() { printf 'capture: %s\n' "$*"; }
```

Every call that leaves the process goes through one function, and a test replaces that function rather than the dependency behind it. A test that reaches the dependency is testing the dependency: it fails when the network, the daemon or the tool version moves, and it proves nothing about the argument the code built. Replacing the seam turns the handoff into data, so the assertion is over the arguments the dependency would have received.

Replaces: a test that runs the real external command, and one that asserts the stub's own output rather than the arguments handed to it.
