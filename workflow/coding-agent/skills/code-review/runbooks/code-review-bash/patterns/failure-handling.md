# Failure-handling patterns

Open this when code runs a command whose failure it must survive, tolerates a non-zero return, or decides what a status means.

## p-9 Scope `|| true` to one command

```bash
docker compose up -d 2>&1 | (grep -v "^Container " || true)
```

Under `set -o pipefail`, `|| true` on the whole pipeline absorbs every command's failure, so a broken `docker compose up` reports success. A subshell scopes the absorption to the command that needs it.

Replaces: `cmd | grep ... || true`, which catches the writer's failure too.

## p-10 Tolerate a failure without claiming success

```bash
if docker rm "${CONTAINER_IDS[@]}"; then
  echo "Containers removed."
else
  echo "Containers not removed; another process may be tearing them down."
fi
```

Tolerating a non-zero return keeps the script running. It does not justify a completion message. That message reaches the operator's terminal and every log that reads it, and it asserts work the command did not do.

The status can go missing in another shape as well. `a && b` runs `b` only when `a` succeeds, and when `a` fails the chain carries `a`'s status, but nothing reads it: the script continues, the next command overwrites the status, and the run ends looking complete. When the guarded command's failure has to be visible, end the chain with `|| { echo ...; exit 1; }` instead.

Replaces: `docker rm ... || true` followed by "Containers stopped and removed.", and a `a && b` guard where `a`'s failure is the one that matters.

## p-11 Collect the list, then test it

```bash
files="$(find "$dir" -name '*.md')"
grep -q pattern <<< "$files"
```

Under `pipefail`, a reader that stops at its first match sends `SIGPIPE` to the writer, and the pipeline reports the writer's 141 even though the reader succeeded. A producer cut short exits 141 the same way, so `--files-with-matches` piped into `grep -q .` fails too. Nothing prints, and the branch that should pass takes the failure path, so the cause looks like broken input rather than a broken pipeline.

Replaces: `find ... | grep -q pattern`, and any consumer that exits early on a pipeline it did not need.

## p-12 Count matches without failing

```bash
COUNT=$(grep -c "pattern" file || true)
COUNT=${COUNT:-0}
```

`grep -c` exits 1 on zero matches and still prints `0`, so `|| true` absorbs the exit code and `${COUNT:-0}` covers the paths where nothing was printed at all.

Replaces: `COUNT=$(grep -c ... || echo 0)`, which captures two zeros because grep already printed one, and an unguarded `grep -c` under `set -e`.

## p-13 Library functions return, never exit

```bash
check_base_flags() {
  if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: --name is required" >&2
    return 1
  fi
}
```

Functions in sourced libraries must `return 1`, not `exit 1`: every entrypoint caller runs under `set -euo pipefail`, so a non-zero return triggers script exit identically, while a bare `exit` is a latent bug when the function is called from a test harness, a subshell or an interactive context. Entrypoint scripts and standalone `main()` blocks may use `exit` legitimately.

Replaces: `exit 1` in `src/libs/` or `src/build/`.

## p-14 An exit code is a verdict, not a magnitude

An exit code answers one question, whether the operation succeeded. Use `0` for success and `1` for failure, never a count, a severity or a tool-missing condition. A missing tool is a finding: print it and exit `1`. A count belongs in the output, where a reader sees it, not in a code that wraps at 256.

A function that cannot determine its answer must not return the same status as one that determined a negative answer: give the undeterminable case its own status and make every caller handle it explicitly, because two states sharing one status make a broken input indistinguishable from a benign one.

The rule is about the boundary a caller sees. At a process exit, only a verdict. An in-process function may carry a distinguishing status when one helper owns its dispatch. A caller that would otherwise switch on several codes is better served by that helper than by a repeated `case`.

One standing exemption: a test harness may exit with its failure count, because the count is the point of the report, every consumer reads zero against non-zero, and a suite reaching 256 failures has a problem the exit code cannot express.

## p-23 Disarm an EXIT trap on success

```bash
CREATED=0
trap 'if [[ $CREATED -eq 1 ]]; then rm -rf "$DIR"; fi' EXIT
mkdir "$DIR"; CREATED=1
# ... work ...
CREATED=0  # disarm on success
```

`set -euo pipefail` stops on error but does not undo state already written, so a failure halfway through leaves the directory behind. The trap fires on every exit; the flag decides whether there is anything to undo. Disarm it on the success path. That line is easy to forget and is the only one the trap depends on.

Replaces: `rm -rf "$DIR"` at the end of the happy path, which never runs when the script aborts.

## p-24 Bound every external blocking call

| Call | Bound |
|---|---|
| `docker stop` | `--time <seconds>` |
| `docker compose stop` and `down` | `--timeout <seconds>` |
| a call with no native bound | `timeout <seconds> <command>` |

An external call that can wait on a peer carries an explicit bound, and the bound is a stated duration rather than a default inherited from the tool. A tool default is not a bound: `docker stop` spends its default grace per container, so a teardown of three containers can wait thirty seconds before the first slow end is visible anywhere.

The bound is written where the call is made, not held in a variable three files away. A caller that must wait longer than its bound says why in a comment on the command. A timeout is a distinct outcome: `timeout` returns 124, so the caller reports "did not return" rather than reporting success.

Replaces: a bare `docker stop` in a teardown loop, and a derived wait whose duration is stated in a comment instead of on the command.

## p-29 A check fails closed and names its key

A check reads an external capability, a tool, a daemon, a repository or an environment, and returns a verdict: pass or fail. A run where the capability could not produce the answer is not a third state, it is a fail whose distinguishing key the caller can read ("docker could not run", "no such image", "cannot derive the cutoff"). The family rests on one obligation: a silent failure must never be readable as a success.

- Fail closed. When a check cannot determine its answer, refuse and stop, and the refusal names the failing check on stderr.
- Never absorb a check's status with a bare `|| true`, which discards the distinction the check exists to make. Where proceeding is safe, a named opt-in override prints a warning naming what it bypassed.
- Never presume a predecessor succeeded. `cmd1 | cmd2` and `if cmd; then` are not proof that the earlier stage ran: read `PIPESTATUS[0]`, or split the pipeline and validate the stage that matters, because a collection fed by one failed stage writes a trustworthy-looking partial result.
- Never alias "the capability could not run" to "nothing to report": empty output answers only when the empty means there is no such thing.

Bash's `$( )` captures stdout only, so a probe returning both a value and a status falls back to treating empty output as the sentinel. That is why these defects cluster at a few substitution and pipe boundaries rather than everywhere, and why a `|| true` over a status that does not matter stays fine. A check that can read a silent failure as a success owes a test for its failed path, and for its cannot-run path where the capability can be absent.

Replaces: `foo || true` over a check, `if cmd; then : > out; fi` read as proof, and an empty result reported as "none found".

## p-41 Key a retry to one named transient condition

```bash
# Wrong: every non-zero exit is retried, including the one that will not change
until out=$(run_with_cap); do :; done

# Right
if ! out=$(run_with_cap); then
  grep -q 'usage limit' <<< "$out" && out=$(run_with_cap)
fi
```

"Repeat while the status is non-zero" retries every failure, including the ones that will fail the same way: a timeout spends its whole cap on each attempt, and three attempts cost three caps before the caller learns anything. Name the transient condition the retry is for, test the output for it, and stop on anything else, so a permanent failure reaches the caller once rather than three times.

Replaces: `until cmd; do :; done`, and a retry that reads any non-zero exit as transient.

## p-43 A condition true by construction decides nothing

```bash
# Wrong: both operands are non-empty strings, so the test is true
[[ -n "$x" && false ]]
[[ -z "$x" && -n /dev/null ]]

# Right
if false; then
```

Inside `[[ ]]` an operand is a string test unless it is an operator, so a literal such as `false` or a path is true whenever it is non-empty, and `&& false` disarms nothing. A guard no input can fail reports the branch it was meant to protect as taken, which is how an unchanged guard reads as a survivor. Remove the condition with a form that aborts, and run the removed branch once to see it fail.

Replaces: `&& false`, `-n /dev/null` and any other literal operand used to disable a condition.

## p-48 Test in `[[ ]]`, not `[ ]`

```bash
if [[ -n "$name" && -f "$path" ]]; then
  ...
fi
```

Inside `[ ]` the operands are re-split and pathname-expanded like any other command's arguments, so an unquoted value can become several arguments and `-a` and `-o` are parsed by the test itself with a precedence that surprises. `[[ ]]` is a bash keyword: it keeps one operand as one operand, takes `&&` and `||`, and does not run the expansion. Shellcheck's SC2006 makes the same argument for `$( )` over backticks, and this entry does not repeat it.

Replaces: `[ -n $name -a -f $path ]`, and `[ ]` where a value may hold a space.
