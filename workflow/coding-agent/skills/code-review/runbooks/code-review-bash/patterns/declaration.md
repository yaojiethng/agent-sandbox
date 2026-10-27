# Declaration patterns

Open this when code declares a variable, builds a flag list, or defaults a value that may be empty.

## p-4 Declare, then assign

```bash
local FOO
FOO=$(failing_cmd)
```

`local` is a builtin, so it returns 0 whatever the command substitution did. Under `set -e` the failure disappears and the line looks like a success. Split the declaration from the assignment, which puts the status on the assignment where the shell can act on it.

Replaces: `local FOO=$(cmd)`, which returns 0 and swallows the command's failure.

## p-5 Behaviour as an argument

```bash
run_with_flags() {
  local -a ARGS=()
  [[ "${REFRESH:-false}" == "true" ]] && ARGS+=(--refresh)
  exec "${_self_dir}/run.sh" --name="$PROJECT" "${ARGS[@]}"
}
```

An exported value travels into every child process, teardown included, so a behaviour flag set once in an invocation decides what later stages do, and no reader of those stages can see where the decision came from. Pass the decision as an argument, and build it as an array so its expansion needs no exception to the quoting rule.

- Variant: configuration and identity values may be exported, because a child has to know them rather than decide from them. That is the `.env` configuration, the session id and its timestamp, and the head sha the run started from. The test is whether the value changes what the child does; when it does, it is behaviour and takes the argument path above.

Replaces: `export REFRESH=1`, which leaks into every child and into teardown, and a bare `$FLAGS`, which needs an exception to the quoting rule.

## p-6 Empty is not unset

```bash
# an unset variable takes the default; a deliberately empty one survives
BASE_COMMIT="${BRANCH_FROM_ARG-HEAD}"

# an empty value takes the default as well
BASE_COMMIT="${BRANCH_FROM_ARG:-HEAD}"
```

The colon form replaces an empty value as well as an unset one, and the bare form replaces only an unset one. So a setting the operator cleared to the empty string is silently replaced by `${VAR:-default}`, and the script runs with the default they thought they had overridden. Choose the form by what an empty value means. An explicit `[[ -n "$x" ]] || x=default` guard is the colon form written the long way, so it does not fix the case it looks like a fix for.

Replaces: `${BRANCH_FROM_ARG:-HEAD}` where an empty value is meaningful, and the two-line guard read as the fix for it.

## p-36 A `local` outside a function is a runtime error

```bash
# Wrong: local: can only be used in a function
local FOO=bar

# Right
FOO=bar
```

`local` exists only inside a function body. At top level bash prints "local: can only be used in a function" and exits, and `bash -n` accepts the same file, so a syntax check passes and the failure waits until the line runs. Declare locally only inside the function that owns the variable, and use a plain assignment in a script body.

Replaces: `local` at the top of a script, which fails only when that line runs.

## p-37 Declare an accumulator integer

```bash
declare -i total=0
total+=bytes
```

A variable is text until arithmetic touches it, so `total+=bytes` appends to a string and four counts become one very long number. The division that formats the total then fails with "value too great for base" once the concatenation starts with a zero, and a run that skipped three of four directories prints a plausible summary for the first. Declare the accumulator integer, or assign through `$(( ))`, and report the iteration count beside the total, because a total cannot show that the loop stopped early.

Replaces: `total+=bytes` on an undeclared variable, followed by a per-step summary line.

## p-38 Build a default value on its own line when it holds an apostrophe

```bash
DEFAULT_PROMPT="The working tree holds this iteration's work."
PROMPT="${EVAL_PROMPT:-$DEFAULT_PROMPT}"
```

Inside `${...}` a single quote opens a quoted string, so an apostrophe in a default value opens a quote that never closes and the file stops parsing. Bash reports the unmatched quote at the last line of the file, whatever line holds it, so the message points away from the fault and the line has to be found by counting quotes. Keep the default free of apostrophes, or assign it on its own line first as above. `grep -c "'"` over the file gives an odd count while one is loose.

Replaces: `PROMPT="${EVAL_PROMPT:-The working tree holds this iteration's work.}"`, and the search for it that reads backwards from the last line.

## p-44 Declare a library function's variables `local`

```bash
load_config() {
  local file="$1" key value
  ...
}
```

A variable assigned in a function without `local` is written into the caller's shell, so two functions that use the same name overwrite each other's value and the damage appears in whichever ran second. Declare every variable a function assigns as `local`, on one line at the top, before the first assignment.

Replaces: an assignment inside a function with no `local`, and a `local` declared after the value is first used.
