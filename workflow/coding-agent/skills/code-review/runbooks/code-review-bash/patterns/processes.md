# Process patterns

Open this when code looks for a running process, kills one, or cleans up after one.

## p-34 Match a process scan on the executable, and exclude the scanner

```bash
# Wrong: the pattern is in this shell's own argv, so the scan finds it
pgrep -f "$name" | while read -r pid; do kill "$pid"; done

# Right
pgrep -f 'node\ .*server\.mjs' | grep -vx "$$" | while read -r pid; do kill "$pid"; done
```

A scan by argument text matches the command line running the scan, because the pattern is in that command line as an argument. Feeding the resulting pids to `kill` signals the scanner, and the tool that ran it dies with 143. Match the executable as well as the argument, and drop the current pid from what comes back.

Replaces: `pgrep -f "$name"` piped into `kill`, which kills the shell that ran it.

## p-35 Verify the effect rather than a cleanup tool's exit code

```bash
# Wrong: pkill is absent from the image, so nothing is killed and nothing fails
pkill -f "node .*server.mjs"

# Right
ss -ltn "sport = :$PORT" | grep -q . && exit 1
```

A tool that is absent from the runtime exits non-zero and is read as "nothing to clean up", so a cleanup built on it removes nothing and reports success, and the port stays held. The damage does not stop at the cleanup: the next run's probe talks to the process that was never killed and reports that nothing was captured, so the next run carries a failure that belongs to this one. State the effect the cleanup exists to produce, and check that instead: a port that is closed, a file that is gone, a pid that no longer answers.

Replaces: `pkill -f ...` read as the cleanup, in an image that does not ship `pkill`.
