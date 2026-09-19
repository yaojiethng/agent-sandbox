# Docker Output Presentation

**Current:** 2026-09-19

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | Harness console stays clean | The operator sees the harness's own progress lines, not raw docker/compose tables |
| R2 | Progress is still visible | A long build must not look hung; the operator can tell work is happening |
| R3 | The harness never blocks on an external prompt | A docker/compose interactive prompt must not hang an unattended path on stdin |
| R4 | Failures stay readable | Build, up, and down failures surface their real error text, not silence |

## 2026-09-19 -- Quiet at source: `--quiet`, `--progress quiet`, `< /dev/null`

**Decision:** Docker build and compose output are muted at the source instead of filtered after the fact:

1. **`docker build --quiet`** suppresses per-step build output (the fancy-renderer staircase). Success prints only the final digest; failures still print their error text. The `Building image:` / `Build complete:` lines come from the harness.
2. **`docker compose ... up --progress quiet`** suppresses the compose resource table at source. The `Network` / `Container` rows never emit.
3. **`< /dev/null`** closes stdin for every unattended `docker compose up` call, so compose cannot block on an interactive prompt (R3). Same precedent as the seeder guard (handover `20260904-05`).
4. The `compose_output_filter` function (grep of compose progress-table lines) is deleted. It was cosmetic downstream filtering; `--progress quiet` makes it dead at the source.

**Rationale:** The operator needs a clean console (R1) and visible progress (R2), but docker's own compact live-updating view only renders on a real TTY. In the harness's unattended context that view degrades to a per-step staircase (the vertical sprawl), which is noise for fully-cached builds. Quieting at the source is "working with docker": the flag that suppresses the noise exists in the tool, so the harness neither re-implements progress nor pipes output through a filter. The `< /dev/null` guard closes stdin so an interactive compose prompt (volume/config mismatch on a stale-session resume) cannot hang the harness (R3). Failures remain readable under every path (R4).

**Diagnostic trail (host commands that back these conclusions):** on a real host, under a pty, with `TERM=xterm-256color`:

```
# 1. Are the fds TTYs in this shell?
for f in 0 1 2; do [ -t $f ] && echo "fd$f: tty" || echo "fd$f: NOT tty"; done
# Results: fd0/fd1/fd2 all tty

# 2. Same check inside a make recipe (make does not change the fds):
make -f /tmp/Makefile probe
# Results: fd0/fd1/fd2 all tty, TERM preserved  -> make is NOT the cause

# 3. docker build --progress=auto, PIPED: forces plain renderer (#1 lines)
docker build --progress=auto -t probe-tty -f /dev/null /tmp 2>&1 | head -5

# 4/5. docker build --progress=tty vs --progress=auto, unpiped, instant build:
# Results: byte-identical staircase  -> auto is already the fancy renderer, not plain

# 6/7. Same pair with a RUN sleep 3 (a step that actually runs):
docker build --progress=tty   -t probe-sleep /tmp/probectx
docker build --progress=auto  -t probe-sleep /tmp/probectx
# Results: 6 == 7, both fancy staircase  -> forcing tty buys nothing; the dump is
# the fancy renderer showing instant-cached steps, not plain.

# 8. Compose progress at source:
docker compose --progress quiet up -d; docker compose down
# Results: up emits nothing; -> --progress quiet replaces the downstream filter.
```

A goroutine dump of the hung `docker compose up` on a stale-session resume showed the compose plugin blocked in `survey/v2.(*Confirm).Prompt` reading stdin, waiting for an answer to `Recreate (data will be lost)? (y/N)`. That established that the hang was an interactive prompt in an unattended context, not a docker/daemon defect (R3).

**Prior attempts that this overturns** (recorded because each was an assumption we later disproved):

1. **`--progress=plain`** (used until `20260810-11`), then changed to `--progress=auto` under the assumption that `auto` produces "a single self-overwriting line." Disproved by the host diagnostics: on a TTY, `auto` delegates to the fancy renderer, which is multi-line, not single-line. `20260812-01` recorded this but then tried a different fix.
2. **TTY detection + background build + BuildKit step parsing** (`_buildkit_run`, `src/libs/buildkit_progress.sh`, `20260812-01`): ran `docker build --progress=plain` in the background, polled the log for the current step header, and rendered a single live line. This was the project's most elaborate answer. It was later removed as dead code (`271eda4`, 2026-08-21) after the background/pipe exit-code handling proved fragile under `set -euo pipefail` (`20260812-03`). The host diagnostics show why it was over-engineered for this problem: the whole need is "do not block, mute the noise at source," not "parse docker's progress stream."
3. **The grep filter** (`compose_output_filter`: `grep -vE '^ ?Container |^ ?Network |^ ?Volume |^ ?$'`): filtered the compose progress table downstream. Disproved by host probe 8: `--progress quiet` silences the same lines at source, making the filter dead.

**The mistake behind the failed attempts:** each prior attempt assumed the vertical output was docker's *plain* renderer, so each tried to coax docker into a compact render (auto, tty) or to re-render docker's stream ourselves. The host diagnostics showed the output is already the *fancy* renderer and the compaction problem only exists for instant-cached steps, which no progress renderer can meaningfully collapse. The correct lever was not progress-mode selection but output *volume*: `--quiet` (build) and `--progress quiet` (compose), plus `< /dev/null` (stdin) for the interactive-prompt hazard.

**Edge cases / drivers:** stale-session resume where a session's named volume predates the current compose config (prompts + blocks); fully-cached refresh builds where every step completes in ~0.0s (vertical staircase with no live phase); the `2>&1 | grep` pipe introducing the interactive-prompt hang class; `set -euo pipefail` around the compose call.

**Known tradeoff (accepted):** `--quiet` removes the live progress line for genuinely long (uncached) builds -- the operator sees the harness's `Building image:` line without step detail until completion. This satisfies R1/R2 at the cost of step-level visibility for first-time/`--no-cache` builds, which the operator accepted in preference to per-step noise (R1 overrides R2 when the steps are instant-cached anyway).