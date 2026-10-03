# Bash and Harness Lesson Plan

This document is a lesson plan for the project operator who has read the shell scripts and the tests but has not internalised the mechanics behind them. It teaches from the real code in this repository: every claim about behaviour is anchored to a file and a line, and every quoted snippet is copied from that file. Generic bash tutorials are deliberately absent; the point is to make the repository's own idioms legible.

The plan covers four learning areas, then a traps section drawn from the repository's own record, three graded exercises, and a self-check. Work through the areas in order; each one assumes the previous one.

No suite run is required to read this plan. The exercises at the end are the only place where a reader runs commands.

## Area 1 - Bash conditional semantics

### Learning targets

- You can say which conditional form this repository uses, and name two operators that `[[ ]]` accepts and `[ ]` does not.
- You can explain why `[[ "$x" && false ]]` and `[[ -z "$x" && -n /dev/null ]]` always evaluate true, and why neither changes a guard's behaviour.
- You can predict the result of `-n` and `-z` for an unset variable with and without `set -u` in effect.
- You can tell an unset variable from a variable set to the empty string, and choose between `${V-d}`, `${V:-d}`, `${V:=d}`, and `${V:?msg}`.
- You can choose `[[ ]]` or `(( ))` for a comparison and state the exit status the test returns and who reads it.

### Knowledge dump

`[ ]` is the POSIX `test` command; `[[ ]]` is a bash reserved word. The repository uses `[[ ]]` for string and file tests and `(( ))` for arithmetic. Inside `[[ ]]` the operands are not word-split and not glob-expanded, so an empty expansion stays an operand and `[[ $a == $b ]]` is a string comparison; inside `[ ]` an unquoted empty expansion disappears and can produce a syntax error. `[[ ]]` also accepts `&&`, `||`, and the regular-expression operator `=~`; `[ ]` treats `&&` as the shell list separator, not as a test operator.

A bare word inside `[[ ]]` is tested as a non-empty string. That is why `false` and `/dev/null` are not what they look like: `[[ -n /dev/null ]]` is true, and `[[ "$x" && false ]]` reduces to `[[ -n "$x" ]] && [[ -n false ]]`, which is true whenever `$x` is non-empty. Appending `&& false` to a guard, or wrapping a guard's condition in `[[ ... && -n /dev/null ]]`, therefore leaves the branch unchanged. Contrast the `||` at `src/libs/common.sh:45`, which sits outside the conditional expression and is a shell list operator:

```bash
  [[ -n "$dir" ]] || { echo "sandbox_dir_canon: SANDBOX_DIR is empty" >&2; return 1; }
```

Here the left operand is a `[[ ]]` test and the right operand is a brace group, so the group runs when the test fails. That is a real mutation point. An `&&` inside the brackets is not.

`-n` means "length is non-zero" and `-z` means "length is zero". For a variable set to the empty string, `-z` is true and `-n` is false. For an unset variable the answer depends on `set -u`: without `-u` the expansion yields the empty string, so `-z` is true; with `-u` the expansion is an unbound-variable error and the test never evaluates. That is why pure libraries, which never set options (`docs/development/bash-coding-conventions.md` rule 1.17), read a caller-owned variable directly at `src/libs/common.sh:85`:

```bash
  if [[ "$SANDBOX_DIR" == "/" ]]; then
```

and why scripts that carry `-u` write `${VAR:-}` in the same position, as at `src/libs/env_resolve.sh:55-56`:

```bash
  if [[ -n "$explicit" ]]; then printf '%s' "$explicit"; return 0; fi
  if [[ -n "${!envvar:-}" ]]; then printf '%s' "${!envvar}"; return 0; fi
```

The `${!envvar:-}` form is indirect expansion with a default: it reads the variable whose name is in `envvar` and supplies an empty string when that variable is unset, so the `-u` rule cannot fire.

An unset variable and a variable set to the empty string are two states, not three. `${V-d}` supplies `d` only when `V` is unset; `${V:-d}` supplies `d` when `V` is unset or empty. The assignment forms write back into the variable: `${V:=d}` sets `V` to `d` in either case, and the repository uses it where later readers need the value, at `src/libs/common.sh:32`:

```bash
: "${INTERACTIVE_MAX_ENTRIES:=10}"
```

The `:-` form at `src/libs/env_resolve.sh:38` does not write back, which is correct for a positional parameter:

```bash
  local raw="${1:-}" sandbox_dir="$2"
```

The hard-error form `${V:?msg}` turns an absent value into a loud failure. `src/libs/session_save_policy.sh:57` uses it to make a missing argument a programming error rather than an empty string:

```bash
  local _sandbox_dir="${1:?save_decision requires a sandbox dir}" _export_dir="${2:-}" _label="${3:-save}" _rc=0
```

`[[ ]]` and `(( ))` are not interchangeable. `(( ))` evaluates integer arithmetic: a variable name reads as its numeric value (unset reads as 0), `==` is numeric equality, and the status is inverted relative to the value - the command returns 0 when the arithmetic value is non-zero and 1 when it is zero. `src/libs/session_save_policy.sh:176` uses that status directly:

```bash
  if (( rc != 0 )); then
```

Inside `[[ ]]`, integer comparison uses the named operators `-eq`, `-ne`, `-gt`, `-lt`, `-ge`, `-le`, and `==` remains string equality. `src/libs/env_resolve.sh:80` counts an array with the integer operator inside brackets, and `scripts/dry_run_reasoning.sh:152` compares a command's numeric output the same way:

```bash
  if [[ ${#fields[@]} -eq 0 ]]; then fields=(name dir sandbox); fi
```

```bash
warn_check "running as non-root" bash -c '[[ "$(id -u)" -ne 0 ]]'
```

The exit status of a `[[ ]]` test is 0 when the expression is true and 1 when it is false; a syntax error returns a value greater than 1. `if` reads the status and takes the true branch on 0. `&&` runs its right operand only when the left returned 0, and `||` runs its right operand only when the left returned non-zero. `set -e` does not exit for a command whose status is being tested: a test used as the condition of `if`, `while`, or `until`, as an operand of `!`, or as either side of `&&`/`||`. The whole body of a function invoked in one of those positions is exempt too (Area 2). The last command of a function determines its return status, and `src/libs/guards.sh:42-48` ends on a test for exactly that reason:

```bash
require_clean_working_tree() {
  local dir="$1" out
  if ! out=$(git -C "$dir" status --porcelain 2>/dev/null); then
    return 2
  fi
  [[ -z "$out" ]]
}
```

The final `[[ -z "$out" ]]` makes a clean tree return 0 and a dirty tree return 1, and the earlier `return 2` marks the third outcome, "git cannot read the tree". The function's caller distinguishes the three with a `case` or an `if`/`elif`, never by printing inside the function; the docstring states that the verdict is the return status and the caller owns the message.

A function's return status also flows through a `||` list, which is how `parse_help_flag` reports "help was requested" without exiting, at `src/libs/common.sh:56-63`:

```bash
parse_help_flag() {
  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) usage; return 0 ;;
    esac
  done
  return 1
}
```

The caller tests it with `if parse_help_flag "$@"; then ... fi`, the shape used at `scripts/start_agent.sh:217`. A `0` means help was requested; the caller turns that into its own exit so the library can stay return-only.

### Worked example - the three statuses of `require_clean_working_tree`

Run this from the repository root. The function is a pure library, so sourcing it does not set shell options, and the commands below carry the status into `$?` before anything else overwrites it.

```bash
source scripts/guards.sh

d=$(mktemp -d)
git -C "$d" init -q
git -C "$d" -c user.email=a@b -c user.name=a commit -q --allow-empty -m init

require_clean_working_tree "$d"; echo "clean: $?"        # 0
touch "$d/new-file"
require_clean_working_tree "$d"; echo "dirty: $?"        # 1
require_clean_working_tree /nonexistent; echo "unreadable: $?"   # 2
```

The first call finds an empty `git status --porcelain`, so the final `[[ -z "$out" ]]` is true and the function returns 0. The second call finds output, so the test is false and returns 1. The third call's `git` fails, so `if ! out=$(...)` takes the true branch and the function returns 2 before reaching the test. Now mutate the last line to `[[ -z "$out" && false ]]` and rerun. All three calls return 0: the "unreadable" and "dirty" cases are now indistinguishable from clean. That mutation looks like a disablement and is not one, which is Trap 1 below.

## Area 2 - `set -euo pipefail` and subshell exit status

### Learning targets

- You can state the effect of `-e`, `-u`, and `-o pipefail`, and name one thing each does not do.
- You can explain why `set -e` is suspended for the whole body of a function invoked in a tested context.
- You can explain why a function in a sourced library must `return` rather than `exit`.
- You can explain how `$( ... )` can mask a failure and how to keep the status visible.
- You can explain why `set -o pipefail` with an early-exiting `grep -q` can produce a non-zero pipeline status after a match, and why the dry-run probes omit `-e` and `-u`.

### Knowledge dump

`set -e` exits the shell when a simple command fails. It does not fire when the failing command is being tested - as the condition of `if`, `while`, or `until`, as an operand of `!`, or on either side of `&&`/`||` - and it does not fire on a failure in the middle of a pipeline unless `pipefail` is also set. The exemption extends to an entire function when the function call itself is in a tested position. `docs/development/testing_policy.md` states the rule: "Bash suppresses `set -e` for a command in a `||` list, and that suppression covers the whole test function body - nested function calls and any background subshell the body starts are also exempt." Production code relies on the same rule at `src/libs/session_save_policy.sh:166`, where the call sits in a `||` list so that the deliberate non-zero return is a value and not an abort:

```bash
  save_decision "$sandbox_dir" "$as_dir" "autosave" || return 2
```

`set -u` reports an error when an unset variable or positional parameter is expanded. It does not fire for `$@`, `$*`, `$#`, `$?`, `$$`, or `!`, and it does not fire for a variable that is set to the empty string. The escape hatches are the default forms from Area 1. `src/libs/env_resolve.sh:29` shows the pattern at its narrowest, supplying an empty default to an indirect expansion:

```bash
  ( unset "$key"; env_load "$file" >/dev/null 2>&1 || true; printf '%s' "${!key:-}" )
```

`set -o pipefail` changes the pipeline's status: instead of the last command's status, the pipeline returns the status of the last command that failed, or 0 when all succeeded. This is what makes a consumer that exits early dangerous. A producer writing into `grep -q` can receive SIGPIPE when `grep` exits on its first match; the producer then exits about 141, and `pipefail` reports the pipeline as failed even though the pattern was found. The live site is the membership test in the liveness gate, `scripts/check_test_liveness.sh:47` (the `DANGLING` loop at line 55 is the same shape):

```bash
    if ! printf '%s\n' "${REGISTERED[@]:-}" | grep -qxF "$fn"; then
```

When SIGPIPE fires, the pipeline status is non-zero, `!` inverts it to success, the `if` takes the true branch, and the gate prints an `UNREGISTERED` finding for a function whose registration is present. The failure is load-sensitive: it needs the timing window where the producer is still writing when the consumer exits, so it appears under load and disappears on an idle tree. A pipeline-free membership test removes the hazard: write the list to a variable first, then test it with a here-string, `grep -qxF "$fn" <<< "$list"`, or use a `case` statement. The repository has not yet converted this site, which is why Trap 5 exists.

The option regimes are chosen by file class, and `docs/development/bash-coding-conventions.md` rule 1.17 names them. Orchestrator entry points use `set -euo pipefail`; pure libraries set nothing; observe-and-report files use `set -uo pipefail` with no `-e`, because the first failure must not abort the report. The test runner is in the last class, `scripts/run_tests.sh:5`:

```bash
set -uo pipefail
```

so is the lint umbrella, `scripts/lint.sh:15`, and so are the two dry-run probes. `scripts/dry_run_capability.sh:22-24` states the reason inline, and `scripts/dry_run_reasoning.sh:19-21` repeats it:

```bash
# Intentionally no set -e: all checks must run even when some fail.
# Intentionally no set -u: env vars are checked explicitly with guards.
set -o pipefail
```

Without `-e`, a failing check records a failure and the probe continues to the remaining checks; without `-u`, the probe can read an optional environment variable like `${CHANGES_DIR:-}` without an unbound-variable abort. The trade is that the probe must guard every variable itself, which is why `-uo pipefail` without `-e` is permitted only with the inline rationale comment.

A sourced-library function must `return`, never `exit`. A sourced file runs in the caller's process, so `exit` ends the caller, not just the function. Rule 3.1 of `docs/development/bash-coding-conventions.md` states the rule, and `scripts/check_lib_contract.sh` enforces it mechanically over `src/libs/` and `src/build/`. `src/libs/common.sh` follows it at lines 78-88: `check_base_flags` returns 1 on each invalid input and lets the entrypoint decide to exit. `src/libs/session_save_policy.sh` uses the full status vocabulary this allows: `session_save_needed` returns 0 for save, 1 for skip, and 2 for undeterminable, with the reason in the header comment. The test file that sources `common.sh`, `tests/test_common_lib.sh:116-122`, additionally isolates each call in a subshell, so a library that accidentally exited would not take the test process with it:

```bash
test_check_base_flags_missing_name() {
  if ( PROJECT_NAME="" SANDBOX_DIR="/tmp/valid" check_base_flags 2>/dev/null ); then
    fail "check_base_flags should fail with missing --name"
  else
    pass "check_base_flags fails when --name= is empty"
  fi
}
```

A subshell is a copy of the shell; its variable changes do not escape, and its exit status is the status of its last command. Command substitution `$( ... )` runs in a subshell, so the status of the substitution is the status of the last command inside it, and any earlier failure is invisible unless it was captured. `src/libs/env_resolve.sh:27-30` uses that deliberately:

```bash
_env_value() {
  local file="$1" key="$2"
  ( unset "$key"; env_load "$file" >/dev/null 2>&1 || true; printf '%s' "${!key:-}" )
}
```

The `|| true` absorbs `env_load`'s status, and the function's caller tests the produced value rather than the status, at lines 58-59:

```bash
    value="$(_env_value "$env_file" "$key")"
    if [[ -n "$value" ]]; then printf '%s' "$value"; return 0; fi
```

That is the correct pattern when the value is the product: test the value. When the status is the product, keep the substitution's status by making the assignment itself the tested command, as `src/libs/guards.sh:44` and `src/libs/session_save_policy.sh:36` both do:

```bash
  if ! _dirty=$(git -C "$_sandbox_dir" status --porcelain 2>/dev/null); then
```

The related trap is `local FOO=$(cmd)`, documented as rule 4.1 of `docs/development/bash-coding-conventions.md`: `local` is a builtin that always returns 0, so it swallows the substitution's status. Both repository sites declare first and assign second, at `src/libs/guards.sh:43` and `src/libs/session_save_policy.sh:34`:

```bash
  local _dirty _head
```

The per-file deadline is a separate status channel. `scripts/run_tests.sh:64-83` implements it in pure bash: it backgrounds the test file, polls `kill -0` every 0.1 seconds, and on expiry kills and reaps it before returning 124.

```bash
run_with_deadline() {
  local deadline_ticks=$(( ${1#-} * 10 ))
  local out="$2"; shift 2
  local pid ticks=0
  bash "$@" < /dev/null > "$out" 2>&1 &
  pid=$!
  while (( ticks < deadline_ticks )); do
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    return 124
  fi
  wait "$pid"
  return $?
}
```

The deadline is per file and defaults to 5 seconds at line 21 (`TEST_TIMEOUT="${TEST_TIMEOUT:-5}"`). The kill targets the file's own process, and the `wait` reaps it. Descendants that the file started are not in the kill's target set unless the runner kills the process group; Trap 4 covers the consequence.

Finally, the test harness disables errexit inside each test on purpose, at `tests/libs/test_common.sh:156`:

```bash
  out="$( set +e
```

The comment above it explains why: a test must be able to write `out=$(cmd); rc=$?` where `cmd` fails, and a sourced script that ran `set -e` (or the policy-level suppression described above) must not abort the capture. The verdict is `pass()` or `fail()`, never the shell's errexit.

### Worked example - `pipefail` and the early-exiting consumer

This probe demonstrates the mechanism without touching the repository. The first form is the fragile one; the second is the pipeline-free replacement.

```bash
set -uo pipefail

# Fragile: a writer feeding an early-exiting consumer.
found=0
if printf '%s\n' alpha beta gamma | grep -qxF alpha; then found=1; fi
echo "pipeline form, match present: found=$found"   # usually 1, but the pipeline may return 141 under load

# Pipeline-free: materialize the list, then test it with a here-string.
lines=$(printf '%s\n' alpha beta gamma)
found=0
if grep -qxF alpha <<< "$lines"; then found=1; fi
echo "here-string form, match present: found=$found"  # deterministically 1
```

In the first form, the status that `if` reads is the pipeline's. When `grep -q` exits on the match, `printf` can receive SIGPIPE, return 141, and `pipefail` makes 141 the pipeline status; `if` then reads failure and leaves `found` at 0. In the second form there is no pipe, so only `grep`'s status matters. Run the first form in a loop under load to see it flip; the second form stays at 1.

## Area 3 - The unit contract

### Learning targets

- You can define a test unit, register it with `run_test`, and end the file with `test_done`.
- You can explain what each count in the `UNIT:` report line means and why the runner trusts only that line.
- You can explain per-test subshell isolation, the fixture allocator, and fail-fast.
- You can explain the per-file deadline, the 124 return, and what happens to a killed file's descendants.
- You can state what a non-zero file exit with no `FAIL:` marker means.

### Knowledge dump

A test unit is one `test_*()` function registered with `run_test`. `docs/development/testing-conventions.md` fixes the file shape: source `tests/libs/test_common.sh`, call `test_setup` at file scope, define one function per unit, register every function, and end with a single `test_done`. A file has one registration block and one `test_done`; nothing follows it. `docs/development/test_harness_mechanism.md` describes the same contract from the runner side - discovery, parallel dispatch, the result protocol, and the gates - and states the invariant the harness guarantees: a trustworthy green or red signal, with every unit counted exactly once and a failure that never looks green.

`tests/libs/test_common.sh:138-140` is the whole public entry point:

```bash
run_test() {
  _run_one "$1"
}
```

`_run_one` at line 153 runs the function in a fresh subshell, and the subshell's first job is to allocate a fixture root and arm a cleanup trap at lines 156-164:

```bash
  out="$( set +e
    _alloc_log="$(mktemp /tmp/tc_alloc_XXXXXX)"
    : > "$_alloc_log"
    trap '_trap_rc=$?; _cleanup_alloc; exit "$_trap_rc"' EXIT
    FIXTURE_DIR="$(get_fixture_dir)"
    _IN_TEST=1
```

The subshell is what makes the suite order-independent: the test's environment, working directory, globals, and traps cannot leak into a sibling. The trap preserves the subshell's would-be exit status before cleaning, because a trap whose last command is a cleanup would otherwise overwrite a `fail()` exit 1 with exit 0 and flip the unit to PASS.

The unit outcome is decided at lines 166-176. A non-zero subshell exit is one failure; a subshell that exits 0 with no assertion is also a failure:

```bash
    if (( _ANY == 0 )); then
      echo "  not ok: $name completed without an assertion"
      exit 1
    fi
```

The `_ANY` flag is set by `pass()` and by `skip()` and, inside a test, `fail()` exits the subshell immediately at line 79 (`exit 1`). That is fail-fast: the first failing assertion ends the unit. Outside a test, `fail()` accumulates rather than exiting, so a stray top-level assertion cannot kill the file mid-way.

The assertion helpers live after `test_done` in the file and each one calls `pass()` or `fail()` itself: `assert_eq` at line 263, `assert_ne` at 272, `assert_rc` at 281, `assert_contains` at 290, `assert_matches` at 300, `assert_empty` at 310, `assert_not_empty` at 316, `assert_file_exists` at 322, `assert_dir_exists` at 328, `assert_not_contains` at 334, `assert_eq_num` at 344, and `assert_run` at 361. Because the helper asserts, a test body can be one or two lines and can never be assertion-less by accident. `assert_run` is the capture-and-assert form: it runs the command in a subshell, keeps the combined output in `RUN_OUT`, and on a mismatch names the captured output, so a failing test is never blind.

The file's authoritative counts are produced once, by `test_done` at `tests/libs/test_common.sh:237-249`:

```bash
test_done() {
  local NAME="${1:-}"
  if [[ -n "$NAME" ]]; then
    echo "=== $NAME ==="
    echo
  fi
  echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
  printf 'UNIT: pass=%d fail=%d skip=%d\n' "$PASS" "$FAIL" "$SKIP"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo "Failed:"
    for f in "${FAILURES[@]}"; do echo "  - $f"; done
  fi
  exit "$FAIL"
}
```

The `Results:` line and the per-unit `PASS:`/`FAIL:` markers are presentation for a human. The `UNIT:` line is the machine-readable contract, and the runner reads only it. `scripts/run_tests.sh:93-94` states the reason: "Counts come from the test file's own UNIT: report ... not from re-parsing presentation markers, so a format drift cannot silently zero the result." The worker extracts the last `UNIT:` line at line 109, validates it against an anchored shape at line 117, and treats four other outcomes as failures: a timeout at 112-113, no report at 115-116, a report with zero units at 119-121, and a malformed report at 125-126.

```bash
  UNIT="$(grep '^UNIT: pass=' "$TMPFILE" 2>/dev/null | tail -1)"
  FILE_PASS=0; FILE_FAIL=0; FILE_SKIP=0
  special=""
  if [[ "$RC" -eq 124 ]]; then
    special="TIMEOUT $BASENAME (exceeded ${TEST_TIMEOUT}s deadline)"
  elif [[ -z "$UNIT" ]]; then
    FILE_FAIL=1
    special="FAIL $BASENAME (file exited $RC with no UNIT: report -- crash or missing test_done)"
  elif [[ "$UNIT" =~ ^UNIT:[[:space:]]pass=([0-9]+)[[:space:]]fail=([0-9]+)[[:space:]]skip=([0-9]+)$ ]]; then
```

The reason the counts can be trusted is that a drift is loud by construction: the failure verdict rides the file's real exit status, which cannot be misparsed, and the pass and skip counts ride a self-describing line the file must emit or the run fails. A test file cannot silently report fewer units than it ran by accident of presentation.

The per-test fixture allocator is `get_fixture_dir`, `tests/libs/test_common.sh:41-47`:

```bash
get_fixture_dir() {
  local _d
  _d="$(mktemp -d /tmp/XXXXXX)"
  printf '%s\n' "$_d" >> "$_alloc_log" 2>/dev/null || true
  printf '%s\n' "$_d"
}
```

It journals each allocated directory to a file rather than a shell array, because it is normally called inside command substitution where an array append would be written to a lost sub-subshell copy. `_cleanup_alloc` at lines 51-58 reads the journal and removes everything the test allocated. `test_setup` at lines 203-213 sets `TEST_DIR`, `REPO_ROOT`, and a file-scope `FIXTURE_ROOT`, and arms a trap to remove the root. A test must allocate extras through `get_fixture_dir` (alias `get_test_dir`) and never with a bare `mktemp -d`; a bare directory is not journaled and leaks.

The registration contract is enforced before dispatch by `scripts/check_test_liveness.sh`. It computes two sets per file at lines 41-43:

```bash
  mapfile -t DEFINED < <(grep -oE '^test_[A-Za-z0-9_]+\(\)' "$F" | sed 's/()$//; s/^test_//' | sort -u)
  # Registered targets: run_test <name> at line start.
  mapfile -t REGISTERED < <(grep -oE '^\s*run_test\s+test_[A-Za-z0-9_]+' "$F" | awk '{print $2}' | sed 's/^test_//' | sort -u)
```

It then flags three defects: a defined function with no registration (`UNREGISTERED`, line 47-50), a registration with no definition (`DANGLING`, lines 54-58), and a registration after `test_done` (`DEAD-REGISTRATION`, lines 60-72). A defined-but-unregistered test never executes and never fails, so the suite stays green while the test rots; the gate is what makes that loud. The runner calls the gate before any file runs, at `scripts/run_tests.sh:204-208`, and aborts the whole run when it finds anything.

A file-level non-zero exit with no `FAIL:` marker is the crash case. The runner distinguishes it at `scripts/run_tests.sh:146`:

```bash
          echo "  - file exited $RC with no FAIL: marker (crash or uncaught non-zero command)"
```

This means the file's shell exited non-zero without any `fail()` being reached. The usual cause is an uncaught non-zero command at file scope, or a crash before the first assertion. The worker records it as a failure. This is also the case when the file produced a valid `UNIT:` line with `fail=0` but the shell still exited non-zero: the aggregate in `main()` treats a non-zero recorded `rc` as a failure independently of the fail count, so a green `UNIT:` line does not by itself make the run green.

### Worked example - trace one real unit to its report line

Take the unit `test_check_base_flags_missing_name` from `tests/test_common_lib.sh:116-122`. It runs `check_base_flags` in a subshell with `PROJECT_NAME=""` and `SANDBOX_DIR="/tmp/valid"`. The library returns 1, the subshell exits 1, the `if` takes the false branch, and `pass()` records one assertion. The trace is:

```text
[ test_check_base_flags_missing_name ]
  ok: check_base_flags fails when --name= is empty
  PASS: test_check_base_flags_missing_name
```

The unit marker at the end comes from `run_test`, not from the test body. When the file reaches `test_done`, the file-level counts are printed in the same `UNIT:` shape. This file registers sixteen units, so the three counts always sum to sixteen: when every unit passes the line reads `UNIT: pass=16 fail=0 skip=0`, and a mutation that breaks the two missing-flag units would produce `UNIT: pass=14 fail=2 skip=0` with `exit 2`. The pass count appears only because the units were registered; an unregistered function would not appear here at all, which is the defect the liveness gate catches statically. A test that ends without an assertion appears as a `FAIL` unit, and the fail count rides the exit status.

## Area 4 - The two gates

### Learning targets

- You can state which staged file classes the pre-commit gate checks, with which tool and severity, and how to bypass it.
- You can state what the standalone lint gate adds over the commit-time hook.
- You can list the suite gate's stages, from the prerequisite check to the aggregate exit.
- You can list the three defect classes the liveness gate flags.
- You can state plainly what a green pre-commit run and a green suite run do and do not prove.

### Knowledge dump

The two gates are different in kind. The pre-commit hook is a static check over staged files at commit time. The suite gate runs the unit tests and gates the registration contract. A green result from either one is evidence about one axis, never a blanket "the change is correct".

The commit-time gate is `src/capability/git-hooks/pre-commit.sh`. Its header names the bypass, at lines 10 and 77: `git commit --no-verify` skips it. It checks two staged file classes with an `--diff-filter=ACMR` list, so additions, copies, modifications, and renames are checked and deletions are not. Staged Markdown at line 31:

```bash
done < <(git diff --cached --name-only --diff-filter=ACMR -z -- '*.md')
```

```bash
  if [[ -n "${MDL:-}" ]] && ! "$MDL" --no-globs "${STAGED_MD[@]}"; then
```

and staged shell at line 56 checked by ShellCheck at warning severity, at line 60:

```bash
    if ! SH_OUTPUT=$(shellcheck -S warning "${STAGED_SH[@]}" 2>&1); then
```

A finding in either class sets `HAD_FINDINGS=1`, and the hook exits 1 at lines 75-78:

```bash
if (( HAD_FINDINGS )); then
  echo "" >&2
  echo "pre-commit: fix the findings, or commit with: git commit --no-verify" >&2
  exit 1
fi
```

Three properties matter. First, the tools read the working-tree file, not the index copy (header lines 12-16), so a partially staged Markdown file is checked as it exists on disk; the check can pass on content that is not what the commit will contain. Second, a missing tool is a skip with a warning, not a failure (lines 38-39 for markdownlint, lines 70-71 for shellcheck), so the hook can exit 0 without having checked anything. Third, the header states the hook is installed for copy delivery only and that mount delivery installs no hook, so the gate is not a host-wide guarantee.

The standalone counterpart is `scripts/lint.sh`. It runs three gates over the whole tree, not just staged files, and it names them at line 21:

```bash
GATES=(check_shell.sh check_lib_contract.sh check_markdown.sh)
```

`check_shell.sh` runs ShellCheck over every `.sh` file under `src/`, `scripts/`, and `tests/`; `check_lib_contract.sh` enforces the sourced-library `return`-not-`exit` rule and the guarded-read rule; `check_markdown.sh` runs markdownlint over `**/*.md`. The umbrella runs all three concurrently, captures each output, prints them on completion, and exits 1 when any gate failed, at lines 37-49:

```bash
for (( j = 0; j < ${#pids[@]}; j++ )); do
  if ! wait "${pids[$j]}"; then
    rc=1
  fi
  cat "$OUT_DIR/g.$j"
done
```

On success it prints `Lint: clean in <seconds>s across 3 gates` (line 45). `check_markdown.sh` fails closed when it linted no file, at lines 47-50, so an empty glob cannot print "Clean" over an empty set:

```bash
LINTED="$(printf '%s' "$OUTPUT" | sed -n 's/^Linting: \([0-9][0-9]*\) file.*$/\1/p' | head -1)"
if [[ "${LINTED:-0}" -eq 0 && "$STATUS" -eq 0 ]]; then
  echo "Markdown gate: no Markdown files were linted; cannot run the gate." >&2
  exit 1
fi
```

The suite gate is `scripts/run_tests.sh`. It has four stages before any test runs or reports: the prerequisite check, discovery, the liveness gate, and dispatch under a deadline. The prerequisite check at lines 34-41 verifies that `tests/stubs/docker` exists and is executable, and reports it once by name, because a broken stub would otherwise fail dozens of tests with unrelated 126 or 127 errors. Discovery globs `tests/test_*.sh`, sorts the names, and fails when it finds none. The liveness gate runs at lines 204-208 and is skipped when `RUN_TESTS_DIR` is set, because the runner self-test points discovery at synthetic fixtures:

```bash
  if [[ -z "${RUN_TESTS_DIR:-}" ]]; then
    if ! bash "$REAL_TESTS_DIR/../scripts/check_test_liveness.sh"; then
      echo "ERROR: test liveness gate failed -- fix the findings above before running the suite." >&2
      exit 1
    fi
  fi
```

Dispatch runs every file through a child copy of the runner in parallel, at line 223:

```bash
    | xargs -P"$TEST_PARALLEL" -I{} bash "$0" --worker "{}"
```

Each worker applies the per-file deadline (5 seconds by default), reads the file's `UNIT:` line, writes a key-value record, and always exits 0 so `xargs` schedules every file regardless of any single failure. The parent reads the records, validates each against the same strict shape, sums the counts, prints one aggregate line, and exits 1 when any unit failed, any file timed out, or any record was missing or malformed. A skip is reported as a warning and does not fail the run.

The liveness gate is the part of the suite gate that is static. `scripts/check_test_liveness.sh` flags three defect classes, plus prerequisite and orphan checks for the stub libraries:

| Defect | Meaning | Consequence if unreported |
|---|---|---|
| `UNREGISTERED` | a `test_*()` function with no `run_test` | the test never executes and never fails |
| `DANGLING` | a `run_test` target with no definition | a runtime failure with an unrelated error |
| `DEAD-REGISTRATION` | a `run_test` after `test_done` | `test_done` already exited, so the test never runs |

Now the honest limits. The pre-commit gate proves that the staged working-tree `.md` and `.sh` files passed markdownlint and ShellCheck at the moment of the commit. It does not prove that the tests pass, that the index matches the working tree, that other file classes are sound, or that the tool ran at all - a missing tool skips, and `--no-verify` skips everything. The suite gate proves that every discovered file ran to a report, that each unit asserted at least once, that no unit failed, that no file exceeded the deadline, and that the registration contract held for `tests/test_*.sh`. It does not prove that the assertions check the right behaviour: a vacuous assertion that is always true passes, and the record contains an entry for exactly that defect class. It does not prove that a mutation would be caught; that requires the mutation exercise below. It does not prove that no descendant process leaked, because the deadline kills one process and not its group. And it does not prove that the registration gate ran at all when `RUN_TESTS_DIR` is set. A green run is evidence of these specific properties and nothing more.

### Worked example - read a lint run and a suite run

Run the static gate from the repository root:

```bash
bash scripts/lint.sh
```

The success line is `Lint: clean in <seconds>s across 3 gates`. If a gate fails, the umbrella still runs all three and prints each gate's output before exiting 1, so one failure never hides the others. A `Lint: clean` run means the whole tree passed ShellCheck, the sourced-library contract, and markdownlint. It means nothing about test behaviour.

Run the suite:

```bash
bash scripts/run_tests.sh
```

The tail is one aggregate line, for example:

```text
722 tests across 48 files, 722 passed, 0 failed, 0 skipped (12s)
```

Read it as a conjunction of narrow claims: 48 files were discovered and each produced a record; their `UNIT:` lines summed to 722 units; every unit asserted at least once; no unit failed; no file hit the 5-second deadline; no skip. `-v` adds a per-file `PASS`/`FAIL` line and `-vv` prints the raw test output. A non-zero exit means at least one of those claims is false, and the stderr lines name which file and which cause.

## Traps observed in this repository

These five failure families are recorded in `devlog/AGENT_FEEDBACK.md` and in the harness design records. Each row names the family and the rule that avoids it. The rules are mechanical, not a matter of care.

### Trap 1 - A mutation that cannot change behaviour is not a mutation

Inside `[[ ]]`, the right-hand operand of `&&` or `||` is a conditional expression, and a bare word is tested as a non-empty string. `false` and `/dev/null` are non-empty strings. So `[[ "$x" && false ]]` is true when `$x` is non-empty, and `[[ -z "$x" && -n /dev/null ]]` is true when `$x` is empty. Appending either to a guard changes nothing, the suite stays green, and the green run is misread as a surviving mutation. The same shape appeared in a delivery guard, two resume guards, and a provider-recovery check.

The rule: before running any mutation, compare the mutant with its backup; if they do not differ, there is no mutation. To disable a guard, replace its condition with `if false; then`, which has no operand to be misread. Prefer a change that alters a value or removes a line over one that adds a test operand.

### Trap 2 - perl `\Q...\E` does not stop interpolation and does stop `\n`

`\Q...\E` quotes the pattern's metacharacters, but perl still interpolates `$VAR` inside the quoted region before the pattern is compiled. A substitution whose search text contains a shell variable and is passed on the command line therefore interpolates that variable in the perl process, and if it is unset the pattern becomes a no-match. Separately, `\Q...\E` also stops `\n` from being a newline: a search literal written as `'---\n### '` matches the two characters backslash and n, not a line break.

The rule: pass the literal through the environment and read it as `$ENV{OLD}`, so no interpolation happens in perl:

```bash
OLD='FILES_CHANGED=$(grep -c ...)' perl -0777 -pi -e 's/\Q$ENV{OLD}\E/.../' "$file"
```

For a multi-line literal, put a real newline in the variable with `$'line one\nline two'`, or use the `edit` tool, whose `oldText` carries the newline directly. Keep the match-count and the backup comparison in probe scripts as well as in bite scripts, because the environment idiom removes the interpolation hazard but not the escape hazard.

### Trap 3 - A false PROVEN verdict from a non-assertion abort

A mutation run whose exit status is non-zero looks like "the mutant was caught", but the non-zero status can come from something other than the failing unit: a gate abort, a missing prerequisite, or an unrelated crash. A bite script that reads only the exit status can record PROVEN for a mutation that in fact survived, because the liveness gate aborted the run before any test executed.

The rule: a PROVEN verdict requires the name of the failing test file and the failing unit, plus a re-run that reproduces it. "The suite exited non-zero" is not evidence that the intended assertion fired. Treat the failing unit's name as the evidence and the exit code as a hint.

### Trap 4 - A test process killed but not reaped reports a false result

The runner's deadline kills the test file's process and reaps it with `wait`, but the kill targets one process. Descendants the file started - background loops, pickers, watchers - survive, reparent to init, and carry load into later runs. That leaked load is what makes the load-sensitive failures reproducible and inflates later measurements. A killed child that is not reaped also lingers as a zombie, which `kill -0` still reports as present, so a poll that treats `kill -0` as the liveness test can keep seeing a process that is no longer running and report a timeout for a file that already finished.

The rule: after a `kill`, always `wait` for the direct child so it is reaped, and kill the process group rather than the single pid so descendants stop with it. Do not use `kill -0` alone as a liveness test; it answers "the pid exists", not "the process is running". When a timeout appears for a file that normally finishes well inside the deadline, check for leaked descendants before trusting the timeout.

### Trap 5 - A load-sensitive gate produces phantom findings

The membership test in the liveness gate is `printf ... | grep -qxF "$fn"` under `set -o pipefail`. When `grep -q` exits on its first match, the writer can take SIGPIPE and return about 141; `pipefail` makes that the pipeline status; the `if !` inverts it to success; and the gate prints a finding for a file whose registration is present. The same shape produced false `UNREGISTERED` and `DANGLING` findings on byte-identical input, at random, while multiple suites ran concurrently, and the gate is blocking, so one phantom finding aborts the whole run with no test results. The trigger is concurrent load and the mechanism is timing-dependent; on an idle tree the same gate reports zero findings.

The rule: run one suite at a time, and re-run any finding on an idle tree before acting on it. A finding that names a file whose registration is visibly present is suspect and must be confirmed with the gate alone. The durable fix is to stop deriving membership from a pipeline's status: write the list to a variable and test it with a here-string, or use a `case` statement.

## Exercises

Three exercises, in increasing order of difficulty. Each is self-contained. Run them from the repository root. The third one mutates a production file; it restores the file at the end, and the restore is verified by `cmp`.

### Exercise 1 - Conditional exit statuses

Goal: predict each status before running the command, then confirm.

```bash
bash -c '[[ -z "" ]]; echo "empty string: $?"'
bash -c 'unset U; [[ -z "$U" ]]; echo "unset, no -u: $?"'
bash -c 'set -u; unset U; [[ -z "$U" ]]; echo "unset, -u on: $?"'
bash -c '[[ -n /dev/null ]]; echo "-n /dev/null: $?"'
bash -c 'x=hi; [[ "$x" && false ]]; echo "AND false: $?"'
bash -c 'x=""; [[ -z "$x" && -n /dev/null ]]; echo "double trap: $?"'
```

Expected: the first returns 0; the second returns 0; the third aborts with an unbound-variable error before the test can evaluate, so the `echo` never runs and the shell reports the failure itself; the fourth returns 0 because `/dev/null` is a non-empty string; the fifth and sixth return 0 for the same reason. Write one sentence for the fifth and sixth explaining why the operand cannot change the branch. Then answer: what is the smallest edit that makes the fifth command's condition false for `x=hi`?

### Exercise 2 - Probe the registration gate on a fixture

Goal: see the `UNREGISTERED` finding without touching the real suite.

```bash
mkdir -p /tmp/liveness-fixture
cat > /tmp/liveness-fixture/test_sample.sh <<'EOF'
#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

test_registered() { pass "registered unit runs"; }
test_orphan() { pass "orphan unit never runs"; }

run_test test_registered

test_done
EOF

bash scripts/check_test_liveness.sh /tmp/liveness-fixture
echo "gate exit: $?"
```

Expected: the gate prints one `UNREGISTERED` line naming `test_orphan`, then its summary, and exits 1. Now add `run_test test_orphan` before `test_done`, rerun, and confirm the gate exits 0. Then move the `run_test test_orphan` line below `test_done` and confirm the `DEAD-REGISTRATION` finding. The gate takes a directory argument, which is why this fixture is possible; the real suite passes the real `tests/` directory.

### Exercise 3 - A hand-run mutation

Goal: prove that one unit actually bites, using a mutation that changes behaviour, and prove the restore. Do not run two suites at once; Trap 5 explains why.

Step 1, back up the file and record the target line:

```bash
cp src/libs/common.sh /tmp/common.sh.bak
sed -n '79p' src/libs/common.sh
```

The line is `if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then` (two leading spaces inside the file). This is the guard that requires both `--name` and `--sandbox`.

Step 2, mutate one operator. Replace the `||` with `&&`, which weakens the guard so that supplying only one of the two is accepted:

```bash
sed -i '79s/||/\&\&/' src/libs/common.sh
sed -n '79p' src/libs/common.sh
cmp -s src/libs/common.sh /tmp/common.sh.bak; echo "cmp exit (1 = differs): $?"
```

The second `sed -n` must print the `&&` form, and `cmp` must exit 1. If `cmp` exits 0, the mutation did not apply; stop and fix it before running anything, per Trap 1.

Step 3, run the suite. The command is the full runner, not the single file, so the gate ordering is exercised:

```bash
bash scripts/run_tests.sh
```

Expected: the run exits non-zero and names `tests/test_common_lib.sh`. That file's `UNIT:` line must have `fail=2`, and the two failing units are `test_check_base_flags_missing_name` and `test_check_base_flags_missing_sandbox`. Both supply exactly one of the two flags, so the weakened guard no longer rejects them and each unit's `fail()` fires. If the run is non-zero but `tests/test_common_lib.sh` is not named, do not record PROVEN: read the failure as Trap 3 and re-run.

Step 4, restore and prove it:

```bash
cp /tmp/common.sh.bak src/libs/common.sh
cmp src/libs/common.sh /tmp/common.sh.bak && echo "restore verified (byte-identical)"
sed -n '79p' src/libs/common.sh
```

`cmp` prints nothing and exits 0 when the files match, so the `&&` echoes the confirmation. The last command must print the original `||` line. If you also ran the single file in step 3 instead of the runner, note what the runner's file-level record adds: a missing `UNIT:` line and a timeout both fail the run, and neither is visible from a bare `bash tests/test_common_lib.sh` invocation.

## Self-check

Answer these without looking back. The area in parentheses is where the answer lives.

1. What do `-n` and `-z` return for an unset variable without `set -u`, and what changes with `set -u` on? Then explain why `[[ -z "$x" && -n /dev/null ]]` is true when `$x` is empty. (Area 1, Trap 1)
2. Give the difference between `${V-d}`, `${V:-d}`, and `${V:=d}`, and say which one `src/libs/common.sh:32` uses. (Area 1)
3. What exit status does a true `[[ ]]` return, and which three shell constructs read that status without triggering `set -e`? (Area 1, Area 2)
4. Why is `set -e` suspended for the whole body of a function invoked in a `||` list or an `if` condition? (Area 2)
5. Why must a function in `src/libs/` use `return 1` and not `exit 1`, and which gate enforces this? (Area 2, Area 4)
6. How can `$( ... )` hide a failure, and what two repository patterns keep the status visible? (Area 2)
7. Why can `set -o pipefail` plus `grep -q` yield a non-zero pipeline status after a match, and what pipeline-free form avoids it? (Area 2, Trap 5)
8. Why do `scripts/dry_run_capability.sh` and `scripts/dry_run_reasoning.sh` omit `set -e` and `set -u` while keeping `set -o pipefail`? (Area 2)
9. What are the three outcomes a single test unit can produce, and what makes a unit a FAIL rather than a PASS when it exits 0? (Area 3)
10. Where do the suite's counts come from, what does the runner do with a file that prints no `UNIT:` line or a zero-unit report, and what does a non-zero exit with no `FAIL:` marker mean? (Area 3)
11. Name the three defect classes the liveness gate flags, and say which one leaves a test silently never executing. (Area 3, Area 4)
12. State one thing the pre-commit gate does not prove and one thing a green suite run does not prove. (Area 4)
