# Investigation — provider-entrypoint.sh TUI / Signal Regression

**Status:** Resolved — adopt background-without-job-control + `wait` pattern; `set -m` + `fg` approach retired after Finding 10 identified it as the root cause of TUI startup failures in Docker containers.

---

## Direction + Parent story

Emergency investigation. No formal parent story — triggered by a regression that broke
interactive TUI use in standard start mode. The regression is in `libs/provider-entrypoint.sh`.
Two candidate versions (`v1`, `v2`) were produced during iterative repair but neither resolves
the issue. This document records the root cause analysis across both candidates and the
confirmed fix.

---

## Required reading

- [`docs/architecture/container_model.md`](../architecture/container_model.md) — entrypoint sequence, stop sequence
- [`docs/architecture/sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) — provider config copy-in / copy-out lifecycle
- [`docs/architecture/tool_interface.md`](../architecture/tool_interface.md) — provider interface contract
- [`docs/operations/provider_onboarding_guide.md`](../operations/provider_onboarding_guide.md) — `provider.Dockerfile` ENTRYPOINT contract

---

## Summary

`provider-entrypoint.sh` is the harness-owned wrapper injected into every reasoning layer
provider image. Its job is to copy provider config into `AGENT_HOME` before the agent starts,
run the agent, and copy `AGENT_HOME` back to the host-mounted bind directory on exit. All three
responsibilities must work correctly regardless of whether the agent exits normally, via Ctrl-C,
or via `docker stop`. The regression broke TUI interaction: key input, raw mode, and signal
delivery (Ctrl-C) stopped working in standard start mode.

---

## Findings

### Finding 1 — Background jobs have SIGINT ignored by POSIX

Both v1 and v2 run the agent as a background job (`"$@" &`) and then `wait`. POSIX specifies
that asynchronous commands (background jobs) have SIGINT and SIGQUIT set to `SIG_IGN` at spawn
time. This cannot be overridden from the parent after the fact. Ctrl-C is therefore never
delivered to the agent regardless of any `trap` statement in the wrapper.

v1 acknowledges this with the comment "The agent receives it directly via the process group"
and sets `trap '' INT` in the parent, which is incorrect: background children do not share
the foreground process group and cannot receive keyboard-generated signals through it.

v2 sets `trap '_forward_signal' TERM INT` and forwards INT to the agent, which would work for
`kill -INT` from another process but does not restore the SIGINT delivery that was suppressed
at spawn time.

**Verified:** confirmed by review of POSIX async-list signal semantics and bash manual §3.7.6.

### Finding 2 — Background jobs are not the terminal foreground process group

A background process (`"$@" &`) is placed in its own process group and is not the terminal
foreground job. TUI applications require terminal foreground ownership to function correctly:

- **Raw mode / `tcsetattr`** — works, but input is consumed by the wrapper shell's readline,
  not the agent.
- **SIGWINCH** — terminal resize signal is delivered to the foreground process group. Agent
  does not receive it; window resize is not reflected in the TUI.
- **SIGTSTP (Ctrl-Z)** — sent to foreground group; agent does not receive it.
- **Key input** — the terminal is attached to the wrapper shell as the foreground job. The
  agent, running as a background job, does not have stdin as a readable TTY in the normal
  interactive sense, even though it is the same file descriptor.

Both v1 and v2 are affected. This is the root cause of the TUI breakage.

### Finding 3 — `exec` discards the EXIT trap (known; the cause of the regression)

The previous working version most likely used `exec "$@"`, which replaces the shell with the
agent and correctly makes the agent the foreground process. The regression was introduced when
copy-out was added: `exec` discards the EXIT trap, so copy-out never ran. The fix attempted
in v1 and v2 was to background the agent and `wait`, which resolves the copy-out problem but
introduces the TUI breakage described in Findings 1 and 2.

### Finding 4 — `set -euo pipefail` + `fg` + SIGTERM exit code causes copy-out to be skipped

The v3 candidate (proposed fix) addressed Findings 1–3 by using `set -m` (job control) to
start the agent in the background, then immediately bringing it to the foreground with `fg %1`.
`fg` hands terminal ownership to the agent's process group, resolving both TUI problems.

However, a further bug was discovered during test execution: when the agent is stopped via
`docker stop` (SIGTERM), the `_forward_term` handler kills the agent, and `fg` returns with
exit code 143 (128 + 15). With `set -euo pipefail` active, bash treats this as a command
failure and exits the script immediately — before `EXIT_CODE=$?` and `_copy_out` are reached.
Copy-out does not run.

**Verified by test execution:**

```
bash -c '
  set -euo pipefail; set -m
  sleep 0.5 &; AGENT_PID=$!
  (sleep 0.1; kill -TERM $AGENT_PID) &
  fg %1
  EXIT_CODE=$?         # never reached
  _copy_out            # never reached
' 2>/dev/null
# outer exit: 143, copy-out: did not run
```

### Finding 5 — `PROVIDER_CONFIG_DIR` is hardcoded; cannot be overridden for testing

The script sets `PROVIDER_CONFIG_DIR="/opt/provider-config"` as an unconditional assignment,
ignoring any environment variable of the same name. This makes isolated unit testing impossible
without Docker — tests cannot redirect the host-side bind mount path to a tmpdir. The fix is
`PROVIDER_CONFIG_DIR="${PROVIDER_CONFIG_DIR:-/opt/provider-config}"`, which preserves the
production default and enables test override.

### Finding 6 — `_run` wrapper causes PID mismatch in signal tests; orphans entrypoint before copy-out

The test suite uses a `_run` helper that invokes the entrypoint as a synchronous child:

```bash
_run() {
  AGENT_HOME="$1" PROVIDER_NAME=... PROVIDER_CONFIG_DIR="$2" bash "$ENTRYPOINT" "${@:3}"
}
_run "$ah" "$pc" bash -c "..." &
wpid=$!
```

When the test harness itself runs inside `bash -c '...'`, the backgrounded `_run "$ah" "$pc" ... &`
causes `$!` to capture the PID of the outer `bash -c` subshell, not the entrypoint process. The
entrypoint is a child of that subshell. When the test sends `kill -TERM $wpid`, it kills the
outer subshell; the entrypoint becomes an orphan, adopted by init, and continues running
`_copy_out` asynchronously. The test's `wait $wpid` returns as soon as the subshell dies —
before the orphaned copy-out completes — so the check finds an empty `PROVIDER_CONFIG_DIR`.

**Verified by process tree inspection:** `ps --forest` confirms `$wpid` is `bash -c <entire
script body>` with the entrypoint as a child. `kill -TERM $wpid` terminates the subshell; the
entrypoint continues briefly as an orphan. Adding `sleep 0.3` after `wait` does not fix this
reliably because the orphan's lifetime is non-deterministic.

**Fix:** Signal tests must invoke the entrypoint directly without `_run`, so `$wpid` IS the
entrypoint process — matching the production scenario where the entrypoint is PID 1 and
`docker stop` sends SIGTERM directly to it.

### Finding 7 — SIGINT trap-firing cannot be tested without a TTY; correct guard is disposition check

The initial SIGINT test attempted to verify that a bash `trap ... INT` handler fires in the
agent when `kill -INT` is sent to the process group. This approach has two problems:

1. **Bash trap deferral**: when a bash script is blocked in `sleep`, SIGINT delivered to the
   bash PID does not immediately interrupt `sleep` — bash defers the trap until `sleep` exits
   or returns. The trap fires eventually but not within a short test window.

2. **TTY dependency**: the kernel delivers Ctrl-C SIGINT to the *terminal foreground process
   group*, which requires a real or pseudo TTY. In the test environment there is no TTY, so
   `kill -INT -$pgid` does not replicate kernel Ctrl-C delivery faithfully.

What *can* be tested, and what matters for the regression guard, is signal *disposition*: is
SIGINT set to `SIG_IGN` or `SIG_DFL` on the agent? The broken v1/v2 background-job approach
sets SIGINT to `SIG_IGN` via POSIX async-command semantics. The correct `fg`-based approach
leaves SIGINT at `SIG_DFL`. A process with `SIG_DFL` for SIGINT is killed by `kill -INT $pid`;
a process with `SIG_IGN` survives it.

**Verified experimentally:** a background child (`bash script &`) survives `kill -INT $pid`
(SIG_IGN confirmed). A foreground-style child via the fixed entrypoint is killed by
`kill -INT $pid` (SIG_DFL confirmed). This is the observable property the test must verify.

### Finding 8 — `fg` races with fast-exiting agents; causes test failure and non-zero exit

When the agent command exits before `fg %1` executes (e.g. `true`, `bash -c "exit 42"`),
bash prints `fg: job has terminated` to stderr and returns 1. With `set +e` active this does not
abort the script, but `EXIT_CODE` captures 1 regardless of the agent's real exit code. For
`true`, the entrypoint exits 1 instead of 0 — the `copy-in skipped when provider config absent`
test checks `rc -eq 0` and fails.

The fix cannot be "always use `wait` for exit code" because `wait $pid` returns 127 after a
successful `fg` has already reaped the job (job table entry cleared by fg). The correct pattern:

```bash
if kill -0 "$AGENT_PID" 2>/dev/null; then
  fg %1 2>/dev/null   # job running — fg for TTY; fg exit code is agent exit code
  EXIT_CODE=$?
else
  wait "$AGENT_PID" 2>/dev/null   # job already done — no fg needed; wait has exit code
  EXIT_CODE=$?
fi
```

`kill -0` checks process existence without sending a signal. If the job is still running, `fg`
both transfers terminal ownership and waits, returning the agent's exit code. If the job has
already finished, `wait` retrieves the cached exit code from the job table. No case is ambiguous.

**Verified:** tested against `true` (exit 0), `bash -c "exit 42"` (exit 42), and a slow agent
(`sleep 0.1; exit 7`). All three return the correct exit code.

### Finding 9 — `_forward_term` kills agent PID only; child processes become orphans

`_forward_term` sends `kill -TERM "$AGENT_PID"`, which delivers SIGTERM to the agent bash
process only. Any subprocesses the agent has spawned (e.g. `sleep 30` inside the agent command)
are children of `$AGENT_PID`, not direct targets of the kill. When `$AGENT_PID` dies, its
children are reparented to init and continue running until their natural exit — up to 30 seconds
for `sleep 30`. This causes the SIGTERM test to terminate correctly but leaves orphaned processes
running for the full duration of the agent's sleep command.

With job control enabled (`set -m`), the backgrounded agent (`"$@" &`) is placed in its own
process group with `$AGENT_PID` as the group leader. Sending SIGTERM to the process group
(`kill -TERM -"$AGENT_PID"`, note the negation) delivers the signal to all group members,
including `$AGENT_PID` and all its children. This terminates the agent and all its subprocesses
immediately.

**Verified:** confirmed that `kill -TERM $PID` leaves a `sleep 30` child alive; `kill -TERM -$PID`
kills it.

### Finding 10 — `set -m` isolates agent in its own process group, outside the terminal foreground group; SIGTTIN on first read causes TUI startup failure

`set -m` (job control) places each background command in its own process group. The agent
started with `"$@" &` under `set -m` gets a new PGID equal to its own PID. The terminal's
foreground process group is the shell's PGID (PID 1 in the container). These are different
groups. When the agent makes its first read from the terminal — which every TUI does during
initialisation — the kernel delivers SIGTTIN to the agent's process group. SIGTTIN stops the
process.

`fg %1` then sends SIGCONT, resuming the agent. But at this point the TUI library has
already attempted initialisation, received a stop signal mid-way, and is in an inconsistent
state. In the case of opencode, this results in exit code 150.

**Verified by process group inspection:**

```
# with set -m:
shell PGID=9  agent PGID=11  same=NO   ← agent outside foreground group → SIGTTIN on read

# without set -m:
shell PGID=9  agent PGID=9   same=YES  ← agent in foreground group → reads work normally
```

**Fix:** Remove `set -m`. Without job control, background children inherit the shell's PGID
and are therefore in the terminal foreground process group. The agent can read the terminal
immediately without stopping. `fg` is no longer needed or used.

**Effect on SIGTERM forwarding:** without `set -m`, the agent's PGID equals the shell's PGID
(1 in the container). `kill -TERM -$AGENT_PID` targets process group `$AGENT_PID`, which does
not exist as a group — it is a safe no-op. `_forward_term` must use `kill -TERM $AGENT_PID`
(single PID, no negation) to reach the agent. Direct children of the agent become orphans on
SIGTERM, but Docker sends SIGKILL to all container processes after the stop grace period
(default 10 s), so orphans are cleaned up.

**Effect on SIGINT:** POSIX sets SIGINT to SIG_IGN for background jobs regardless of whether
`set -m` is enabled. Without `set -m`, the agent still has SIGINT=SIG_IGN at the signal level.
However, raw-mode TUI applications do not rely on the SIGINT signal — they read Ctrl-C as the
raw byte `\x03` via the terminal in raw mode. The agent being in the foreground process group
(same PGID as shell) is what ensures it can read the terminal; SIGINT signal disposition is
irrelevant for normal TUI operation.

**Effect on wait:** `wait $AGENT_PID` without `set -m` behaves identically to the previous
implementation. SIGTERM interrupts `wait` immediately, the TERM trap fires, copy-out runs.
The `kill -0` guard and `fg` block are eliminated entirely.

### Finding 11 — POSIX mandates stdin=/dev/null for background jobs in non-interactive shells; every background approach was broken from the start

The entire sequence of background-job approaches (v1, v2, Finding 10 fix) shared a
fundamental flaw: **POSIX specifies that in a non-interactive shell without job control,
background commands have stdin redirected from /dev/null**. GNU bash implements this. The
entrypoint script runs non-interactively. Every `"$@" &` therefore gave the agent `/dev/null`
as stdin — no input from the terminal was ever possible.

**Verified:**

```bash
# Non-interactive bash, no job control:
bash << 'EOF'
bash -c 'ls -la /proc/$$/fd/0' &
wait
EOF
# → /dev/null
```

`set -m` (job control) avoids the `/dev/null` redirect — with job control enabled, background
job stdin is the inherited PTY. This is why the `set -m` + `fg` approach did not have a
stdin problem but instead had the SIGTTIN problem (Finding 10): the agent could receive input
in principle, but was stopped before `fg` transferred terminal ownership.

Without `set -m` (Finding 10 fix): stdin = /dev/null → no input regardless of process group.
With `set -m` + `fg`: stdin = PTY, but SIGTTIN stops TUI during initialisation.

**The correct approach eliminates the background job entirely.** A synchronous foreground
child inherits stdin directly from the shell (the PTY in Docker context). No redirect occurs.
The child is in the foreground process group. It can read from the terminal without SIGTTIN.

```bash
# Synchronous child: stdin is PTY, inherited directly, in foreground group:
bash << 'EOF'
bash -c 'ls -la /proc/$$/fd/0'   # synchronous — no &
EOF
# → PTY (pipe in test; PTY in Docker container with -it)
```

**SIGTERM tradeoff with synchronous execution:** when a TERM trap is set and a synchronous
foreground child is running, bash defers the trap until the child exits. Verified by timing:
SIGTERM sent at T+300ms, trap fires at T+2000ms (when `sleep 2` completes). This means
`docker stop` does not promptly deliver SIGTERM to the agent; after the 10s grace period,
Docker sends SIGKILL and copy-out does not run. For the normal case — user quits the TUI
themselves — the synchronous child exits, copy-out runs immediately. The docker-stop case is
an accepted limitation.

---

## Open Questions

None. All questions resolved during investigation.

---

## Constraints

Any solution must satisfy all of the following:

1. The agent process must be the terminal foreground process group leader so that TUI raw
   mode, SIGWINCH, SIGTSTP, and keyboard input all work correctly.
2. SIGINT (Ctrl-C) must be delivered to the agent by the kernel via the foreground process
   group — not forwarded by the wrapper.
3. `docker stop` (SIGTERM to PID 1) must reach the agent and all its child processes and cause
   them to exit cleanly.
4. Copy-out must run after the agent exits regardless of exit cause: normal, SIGINT, SIGTERM,
   or non-zero exit code.
5. The agent's exit code must be preserved as the wrapper's exit code, including for
   fast-exiting agents that terminate before `fg` runs.
6. The script must remain testable in isolation without Docker.
7. No filesystem paths may be hardcoded in the script; all paths must be supplied via
   environment variables set in the provider Dockerfile.

---

## Resolution

**Recommendation: adopt.** Replace `libs/provider-entrypoint.sh` with the pattern described
below. All constraints are satisfied. The test suite (11 tests) passes against the fixed
implementation.

### The pattern

```bash
set -euo pipefail
# ... validate AGENT_HOME, PROVIDER_NAME, PROVIDER_CONFIG_DIR ...

_copy_in() { ... }
_copy_out() { ... }

_copy_in

# Run synchronously. Agent inherits stdin (PTY), stdout, stderr.
# Agent is in the shell's foreground process group from the start.
# No SIGTTIN. No /dev/null redirect. TUI input works correctly.
set +e
"$@"
EXIT_CODE=$?
set -e

_copy_out
exit "$EXIT_CODE"
```

### Why this is correct

| Property | Synchronous child | Background (`"$@" &`) |
|---|---|---|
| stdin in non-interactive shell | Inherited (PTY in Docker) | `/dev/null` — POSIX mandate |
| Process group | Shell's PGID = terminal foreground | New PGID (`set -m`) or shell's PGID (no `set -m`) |
| SIGTTIN on terminal read | Never — already in foreground group | With `set -m`: yes; without: moot (stdin is `/dev/null`) |
| SIGTERM trap during execution | Deferred until child exits | Fires immediately (`wait` returns) |
| Copy-out on normal exit | Runs immediately after child exits | Runs after `wait` returns |
| Copy-out on `docker stop` | Does not run (SIGKILL after grace period) | Runs (SIGTERM interrupts `wait`) |

### SIGTERM / docker stop limitation

When the agent is a synchronous foreground child and SIGTERM arrives:
- A TERM trap fires only after the child exits (bash defers traps during foreground execution)
- `docker stop` → SIGTERM to PID 1 → deferred → 10s grace period expires → SIGKILL → copy-out does not run

This limitation affects only the `docker stop` mid-session path. For all normal exit paths
(user quits the TUI, agent exits cleanly, Ctrl-C handled by the TUI), the synchronous child
returns and copy-out runs.

The limitation is accepted. Mitigation options if needed in future:
- Harness-level copy-out: `run_agent.sh` performs copy-out via `docker cp` after container exit, independent of the entrypoint
- tini/init as PID 1 with our script as a child: our script receives SIGTERM promptly since it is no longer PID 1, and can run copy-out before exiting

### TUI expectations — what a TUI process requires

A terminal UI framework (bubbletea, tcell, etc.) requires the following at startup:

1. **stdin is a TTY** — `isatty(STDIN_FILENO)` must return true. The framework detects this
   and enters interactive mode. If stdin is `/dev/null`, the TUI sees a non-TTY and either
   falls back to headless mode or exits immediately.
2. **stdin is readable without SIGTTIN** — the process must be in the terminal foreground
   process group, otherwise reads generate SIGTTIN and stop the process.
3. **tcsetattr access** — to set raw mode (disable echo, line buffering, Ctrl-C signal
   generation). Any process with the terminal open can call this; no foreground group
   requirement.
4. **SIGWINCH delivery** — sent to the foreground process group when the terminal is resized.
   The TUI uses this to re-render at the new size. Requires foreground group membership.
5. **tcgetpgrp == getpgrp** — many TUI frameworks verify they are the foreground process
   by checking `tcgetpgrp(stdin) == getpgrp()`. For a synchronous child of PID 1 (which IS
   the foreground group leader), both calls return the same PGID. ✓

The synchronous child approach satisfies all five requirements. Every background approach
failed requirements 1 or 2.

### Testing plan

Eleven tests. The foreground group test from the previous iteration is replaced by a stdin
TTY test, which is the property that was actually failing. The SIGTERM test is removed
(synchronous execution makes SIGTERM mid-session a harness-level concern).

| Test | What it verifies |
|---|---|
| Missing `AGENT_HOME` env var | Exits non-zero with diagnostic |
| Missing `PROVIDER_NAME` env var | Exits non-zero with diagnostic |
| Missing `PROVIDER_CONFIG_DIR` env var | Exits non-zero with diagnostic; no hardcoded default |
| Copy-in runs at session start | Files in `PROVIDER_CONFIG_DIR` present in `AGENT_HOME` before agent runs |
| Copy-in skipped when provider config empty | `AGENT_HOME` not created when source is empty |
| Copy-in skipped when provider config absent | Script exits 0 when source does not exist |
| Copy-out runs on normal agent exit | Files in `AGENT_HOME` appear in `PROVIDER_CONFIG_DIR` after clean exit |
| Copy-out runs on non-zero agent exit | Copy-out runs even when agent exits non-zero |
| Exit code 0 preserved | Wrapper exits 0 when agent exits 0 |
| Exit code 42 preserved | Wrapper exits 42 when agent exits 42 |
| Agent stdin is not /dev/null | Regression guard: confirms stdin is inherited (not redirected). Under any background-job approach this test would fail |