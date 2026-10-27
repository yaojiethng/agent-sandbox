# Operator-facing text patterns

Open this when code decides what to print, to which stream, or whether it may tell the operator what to do next.

## p-30 Only the operator-facing script gives guidance

```bash
# Library
do_thing || { echo "ERROR: thing failed: $reason" >&2; return 1; }

# Orchestrator
echo "Done. Next: run make start"
```

A library reports what failed to stderr and returns non-zero. It does not say what to do next, because it does not know which caller it runs inside and the same function is reached from a test, a hook and two entry points. Guidance belongs to the script the operator ran, which is the only layer that knows what was asked for.

Replaces: a library printing "Done. Next: run make start", and a caller that has to read a library's prose to learn what happened.

## p-45 Send values to stdout and diagnostics to stderr

```bash
emit_paths() { printf '%s\n' "$@"; }
emit_paths "${FILES[@]}" > "$LIST"
warn() { printf 'Warning: %s\n' "$*" >&2; }
```

A caller captures standard output and prints standard error to the terminal, so the two streams carry different things: a value the caller will use, and a message a human reads. A diagnostic on stdout lands inside the captured value and corrupts it, and a value on stderr is lost to a variable assignment. Route each line by who reads it.

Replaces: `echo "Warning: ..."` inside a function whose output the caller captures.

## p-46 Name the function and the failed operation in an error

```bash
fetch_manifest() {
  curl -fsS "$url" -o "$dest" || {
    printf 'fetch_manifest: curl failed for %s\n' "$url" >&2
    return 1
  }
}
```

An error line is read in a log alongside every other line the run printed, so it has to say which function failed and what it was doing. Without that, the reader reconstructs the call path from the run's order, and two functions failing the same way produce two lines that cannot be told apart. Name the function and the operation, and leave the next step to the entry point, which is the only layer that knows the command the operator ran.

Replaces: `echo "Failed" >&2`, and an error line that says what the operator should do from inside a library.
