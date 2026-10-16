# The invalidation history of the three reasoning tiers

**Status:** settled

## Direction and parent story

This study belongs to the M3.6.1 layer install design, the roadmap row `The layer install design` under M3.6.1 `Disable and ship OpenCode dispatch`. That row decides where the shared dispatch CLIs and both agents' extensions install, the pin per layer and how it is checked, and the tier placement among keeping `<provider>-base`, making `<provider>-agent` the final image, and a shared dispatch-tools tier. The decision rests on three measurements: the census of install and copy steps, this invalidation history, and the measured cost of build seconds times rebuild count. This study supplies the last two: a counted per-tier trigger history from git, and whatever the session store records about rebuilds and their durations. The sibling study [`20261016-study-settled-install_step_census.md`](20261016-study-settled-install_step_census.md) supplies the census. Parent row: [`devlog/roadmap.md`](../roadmap.md#m361---disable-and-ship-opencode-dispatch).

## Required reading

- [`devlog/discussions/20261016-study-settled-install_step_census.md`](20261016-study-settled-install_step_census.md) -- the sibling census of the install and copy steps
- [`devlog/roadmap.md`](../roadmap.md#m361---disable-and-ship-opencode-dispatch) -- the parent row and its two options
- [`scripts/build.sh`](../../scripts/build.sh) -- the three-tier orchestrator and the `_build_key` cache gate
- [`src/build/image.sh`](../../src/build/image.sh) -- image naming and the stamped `agent-sandbox.base-build-key` label
- [`src/reasoning/base.dockerfile`](../../src/reasoning/base.dockerfile) -- tier 1, image `agent-base`
- [`src/reasoning/providers/pi/base.dockerfile`](../../src/reasoning/providers/pi/base.dockerfile) -- tier 2, image `pi-base`
- [`src/reasoning/providers/pi/provider.dockerfile`](../../src/reasoning/providers/pi/provider.dockerfile) -- tier 3, image `pi-agent-<project>`

## Summary

This study measures both sides of the invalidation question. Side one counts, per tier and per input path, the commits that changed it, using `git log --oneline -- <path>` and `git log --format='%ci %s' -- <path>` over the sandbox snapshot. Side two reads `$AGENT_HOME/agent/sessions/` for recorded builds, per-tier build starts, cache hits and durations, and reads the harness logs under `$AGENT_HOME/run/`. The git side carries a clear signal: the tier-3 payload roots changed on the order of a hundred times each and last changed on 2026-10-16, while the tier-1 input changed once and the tier-2 inputs changed a handful of times, so the git side supports the invalidation asymmetry the design must weigh. The session side does not support a counted rebuild figure: real build telemetry exists only in four August-and-September sessions, predates the current `agent-base` tier, and records a tier-1 and a tier-2 duration once each, so the cost side is a coverage gap rather than a count.

## Findings

### The repository measured

Every git number below comes from the sandbox snapshot at `/home/agentuser/sandbox`, branch `feat/M3_6-free-tokens`, HEAD `727f8357` (`docs: census the install and copy steps in the three reasoning tiers`), whose tracked history runs from `2026-03-06 16:47:23 +0800` (`git log --format='%ci' | tail -1`) to `2026-10-16 07:46:57 +0000` (`git log --format='%ci' | head -1`). The snapshot's `origin` is `git@github.com:yaojiethng/agent-sandbox.git` (`git remote -v`), but the snapshot is a copy of the host repository, so its history and the host's history may differ; every count here describes the snapshot and not the host. Path-scoped `git log` stops at the last rename, so a path created by a move carries only its post-move history; `git log --oneline --follow -- src/reasoning/providers/pi/provider.dockerfile` returns 35 against the 17 below, which bounds, for that one file, how much the move-hiding effect suppresses.

### Side 1: the trigger counts, from git

In every row, the commit count is `git log --oneline -- <path> | wc -l`, the first change is the last line of `git log --format='%ci' -- <path>`, and the last change and subject are the first line of `git log --format='%ci %s' -- <path>`.

| Tier | Input path | Commits | First change | Last change | Latest subject |
|---|---|---|---|---|---|
| 1 | `src/reasoning/base.dockerfile` | 1 | 2026-10-01 | 2026-10-01 | impl: one shared runtime base for the reasoning layer |
| 2 | `src/reasoning/providers/pi/base.dockerfile` | 16 | 2026-05-29 | 2026-10-16 | build: ship the opencode CLI to the pi image |
| 2 | `src/reasoning/providers/opencode/base.dockerfile` | 2 | 2026-05-29 | 2026-10-01 | impl: one shared runtime base for the reasoning layer |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 4 | 2026-05-29 | 2026-10-01 | impl: one shared runtime base for the reasoning layer |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 17 | 2026-05-29 | 2026-10-14 | workflow: give the docs tree the reader's classes |
| 3 | `src/reasoning/providers/opencode/provider.dockerfile` | 15 | 2026-05-29 | 2026-10-15 | feat: transport the instruction surfaces into OpenCode |
| 3 | `src/reasoning/providers/hermes/provider.dockerfile` | 14 | 2026-05-29 | 2026-10-14 | workflow: give the docs tree the reader's classes |
| 3 | `src/reasoning/providers/pi/config/` | 97 | 2026-05-26 | 2026-10-16 | workflow: file the show-dont-describe communication principle |
| 3 | `src/libs/` | 103 | 2026-05-26 | 2026-10-16 | feat: harden the runner seam |
| 3 | `src/reasoning/agent/` | 71 | 2026-05-26 | 2026-10-16 | workflow: retire the handover policy |
| 3 | `workflow/coding-agent/` | 115 | 2026-09-04 | 2026-10-16 | workflow: add the read-back prompt |
| 3 | `docs/reference/` | 7 | 2026-10-14 | 2026-10-16 | workflow: retire the roadmap policy |
| 3 | `docs/policies/` | 9 | 2026-10-14 | 2026-10-16 | docs: give the work-unit decomposition one owner |

Tier 1 `agent-base` has one input and one commit. Tier 2 `<provider>-base` has three Dockerfiles, `16 + 2 + 4 = 22` commits, with the pi base carrying 16 of them. Tier 3 has the three provider Dockerfiles at `17 + 15 + 14 = 46` commits and six payload roots at `97 + 103 + 71 + 115 + 7 + 9 = 402` commits, 448 in all; a commit that touches two tier-3 paths is counted once per path, so 448 is an upper bound on distinct commits, not a union.

Read against the census's cache model, the distribution is the invalidation set. Tier 1 and tier 2 are gated by `_build_key`, the Dockerfile's sha256 plus the base image's content id, so they rebuild only when their Dockerfiles change; the tier-1 Dockerfile has not changed since it was created on 2026-10-01, and the tier-2 Dockerfiles last changed on 2026-10-01 except the pi base, which changed on 2026-10-16. Tier 3 has no such gate and copies the payload roots, every one of which last changed on 2026-10-16, with `src/libs/`, the pi config root and `src/reasoning/agent/` at 103, 97 and 71 commits. The git side therefore supports the claim that tier 3 is invalidated far more often than tier 1 and tier 2.

### Side 2: the rebuilds and their cost, from the session store

`$AGENT_HOME/agent/sessions/` held 596 `*.jsonl` transcripts on 2026-10-16 (`find $AGENT_HOME/agent/sessions -name '*.jsonl' | wc -l`); the count grows with every session, so the store figure names its date, and the reproducible set is the transcripts dated before 2026-10-01, `find $AGENT_HOME/agent/sessions -name '2026-0[1-9]-*.jsonl' | wc -l`, which counts 514. Over that boundary, 200 contain the string `scripts/build.sh` and 134 contain `docker build` (`find $AGENT_HOME/agent/sessions -name '2026-0[1-9]-*.jsonl' -print0 | xargs -0 grep -lF '<string>' | wc -l`), against whole-store counts of 221 and 141. The named tier strings appear over the boundary in 55, 13, 23 and 19 transcripts for `pi-base`, `agent-base`, `hermes-base` and `opencode-base`, against whole-store 63, 32, 29 and 26; the record's earlier 62 for `pi-base` does not reproduce, because every session that prints the string adds a transcript to the store. A mention is not a build: those strings occur in reads of the script, in quotations of it, and in test fixtures that mock the builder. Over the boundary, 56 transcripts contain the build script's own progress echo `Building image:` and 56 contain `Image exists, skipping:` (74 contain either; the whole store holds 60, 60 and 78). The `[+] Building` prefix appears in 6 boundary transcripts (`find $AGENT_HOME/agent/sessions -name '2026-0[1-9]-*.jsonl' -print0 | xargs -0 grep -lF '[+] Building '`), but only 4 of them carry a real BuildKit summary line; the other two only discuss the format in prose.

Recorded build starts, by the `grep -rlF 'Building image: <tier>'` count over the pre-2026-10-01 boundary: tier 1 appears as the pre-rename `agent-node-base` in 3 transcripts and as `agent-base` in 0; tier 2 appears as `pi-base` in 3 transcripts and as `opencode-base` and `hermes-base` in 0; tier 3 appears as `pi-agent-<project>` in 10, `hermes-agent-<project>` in 3 and `opencode-agent-<project>` in 1. Recorded cache hits, by `grep -rlF 'Image exists, skipping: <tier>'` over the same boundary: `agent-node-base` in 8, `agent-base` in 0, `pi-base` in 7, `opencode-base` in 1 and `hermes-base` in 3. That string is the skip echo the script wrote until `26595bff` changed it to `Image up to date, skipping:` on 2026-10-16, so these counts read the historical transcripts and a future count must use the current string. Each count is transcripts, not invocations, and a transcript that loops the builder counts once. Every matched line lies inside the boundary set, so each count is identical over the whole store.

A duration is recorded when BuildKit prints `[+] Building <n>s (<i>/<j>) FINISHED` (`grep -rhoE '\[\+\] Building [0-9.]+s \([0-9]+/[0-9]+\) FINISHED' <set> | sort | uniq -c`). Over the pre-2026-10-01 boundary the command yields 12 lines totalling 24 matches in four transcripts, dated 2026-08-03, 2026-08-28, 2026-09-12 and 2026-09-19; over the whole store the count is larger and climbs as the measurement proceeds, because the store holds the transcript of the measuring session and of every session that quotes the pattern, and each quote is a new match. Attributed by the `Building image:` line that immediately precedes the summary and by the step count: tier 1 `agent-node-base` 19.3s over 7 steps and tier 2 `pi-base` 16.2s over 6 steps, both in the clean build in transcript `2026-08-28T03-06-35`; tier 3 `pi-agent-<project>` at 4.1s over 22 steps in `2026-08-28T03-06-35`, 5.9s over 24 steps in `2026-09-12T05-31-40`, 0.7s over 20 steps in `2026-08-03T11-16-35` and 0.3s over 25 steps in `2026-09-19T02-13-02`. The capability-layer `sandbox-<project>` image is not one of the three reasoning tiers and is outside this scope; it carries 2.7s (16/16) in `2026-08-28T03-06-35` and `2026-09-12T05-31-40` and 1.9s (16/16) in `2026-08-03T11-16-35` and `2026-09-19T02-13-02`.

The strings the tier and capability attributions do not reach are the `0.0s (1/1)` three times, the `2.0s (16/16)` nine times, the `0.5s (6/6)` once and the `6.6s (6/6)` once. The three `0.0s (1/1)` are probe builds in `2026-09-19T02-13-02`: two from `docker build -f /dev/null` under `--progress=tty` and `--progress=auto`, and one re-quoted from that same probe output, and none is a reasoning-tier build. The nine `2.0s (16/16)` are a single capability-layer `sandbox-agent-sandbox` build, quoted once in the user's pasted `make start` output and eight times again in the assistant's reasoning in the same transcript; they are not nine builds, and reading them as nine would inflate the cost side. The `6.6s (6/6)` and `0.5s (6/6)` are the two runs of the probe `FROM alpine; RUN sleep 3`, the second cached, in `2026-09-19T02-13-02`, and neither is a reasoning-tier build. With those, all 12 distinct strings are accounted for.

No duration is recorded for the current tier-1 image `agent-base`, for `opencode-base`, for `hermes-base`, or for an `opencode-agent` or `hermes-agent` tier-3 build, and the only tier-1 and tier-2 durations predate the `agent-node-base` to `agent-base` rename (`fcec329e`, 2026-10-01) and the current three-tier shape. The harness logs under `$AGENT_HOME/run/` are a working directory, not a build log: the tree accumulates this work's briefs, logs and pi session transcripts, so a bare count over it grows during the measurement and does not reproduce. Bound to the 2026-10-16 measurement, `grep -rhoE '\[\+\] Building [0-9.]+s' $AGENT_HOME/run | wc -l` yields 45 and `grep -rhoE 'Building image:' $AGENT_HOME/run | wc -l` yields 155, with every match inside this work's own artifacts -- 147 in the pi session transcript `m361-d-review.session`, 7 in its log `m361-d-review.log` and 1 in `m361-c-rereview.session`, and the count climbs with each new artifact, reaching 157 once this correction pass's own `m361-d-fix2.brief` lands -- which quote the build lines this record measures; excluding those artifacts, the tree held no reasoning-tier build telemetry at the time of measurement. This is a coverage gap, recorded as such and scoped: the git side already supplies the counted rebuild proxy the requirement asks for -- the per-tier invalidation counts of 1 for tier 1, 22 for tier 2 and 448 for tier 3 from Side 1, since under the cache model a change to a gated tier's Dockerfile is exactly what makes it rebuild -- and the transcript-level build starts and cache hits above are counted too, so what the session store cannot supply is a cost and an invocation-level rebuild count for the current tier shape. No duration here is estimated, and no mention is presented as a rebuild.

### The host build measurement

The cost side, measured on the host by `scripts/build_probe.sh` on 2026-10-16, against Docker 29.6.2 on Linux under WSL2. Two runs were taken. The second is the settled one, and it followed a change to the builder: the first run exposed that `build_image` builds with `docker build --quiet`, so it printed no per-step lines and every row reported a step total of zero. The builder now takes `--progress=<mode>` and the probe asks for `plain`.

| Row | Rebuilt | Wall seconds | Summed step seconds |
|---|---|---|---|
| baseline, the tree as it stands on a warm machine | tier 3 alone | 1 | 0.1 |
| a touch to the tier-2 Dockerfile | tier 3 alone | 1 | 0.1 |
| a comment appended to the tier-1 Dockerfile | all three tiers | 3 | 1.6 |
| the comment removed | all three tiers | 2 | 0.6 |
| a cold rebuild, `--rebuild` | all three tiers | 77 | 75.4 |

Three numbers matter to the design. A change that invalidates tier 3 alone, which is every payload change, costs 1 second. A change to a base costs 2 to 3 seconds, because its dependants follow it. A full cold rebuild costs 77 seconds. The first run's baseline read 43 seconds because it installed the tier-2 layer the pin-and-gate row had just changed, and an npm install is most of that; the second run's baseline reads 1 second on the same machine, which is the steady state. A record that kept the 43 would have priced a one-off as the norm.

The mtime row is the cache assertion. Touching the tier-2 Dockerfile rebuilt tier 3 alone, so tiers 1 and 2 skipped, on both runs. The key reads the file's content and not its identity, which is what the build-skip fix set out to achieve, and the host probe is its end-to-end proof on a real Docker.

Wall seconds and step seconds diverge on the cheap rows and converge on the cold one. The gap is docker's own work outside the steps, which dominates a 1 second build and is about two percent of a cold rebuild.

### What the data supports

The trigger side is supported: git shows the tier-3 inputs changing hundreds of times and as recently as 2026-10-16 while the tier-1 and tier-2 inputs barely move, which is the invalidation asymmetry the layer install design has to weigh. The rebuild side is not supported at invocation level or cost: the git side already supplies the counted per-tier rebuild proxy the requirement asks for -- the invalidation counts of 1 for tier 1, 22 for tier 2 and 448 for tier 3 from Side 1, since under the cache model a change to a gated tier's Dockerfile is exactly what makes it rebuild -- and Side 2 counts transcript-level build starts and cache hits per tier, but the session store records real builds in only four transcripts, all before the current tiering, so it cannot supply a cost or an invocation-level rebuild count for the current tier shape. The cost side inherits that gap, and the four tier-3 durations plus the single tier-1 and tier-2 durations are recorded facts, not an average.

## Open Questions

- Whether the host keeps a build log outside `$AGENT_HOME/agent/sessions/` that would carry the rebuild counts and per-tier durations the session store lacks.
- Whether the host build probe, `scripts/build_probe.sh`, is the instrument intended to supply the counted rebuild count after the layer install design lands, since the agent's container has no Docker by design.
- What produced the rough figure in the chat logs, and whether it can be traced to a countable source at all.
- Whether tier-1 and tier-2 durations under the current shape can be recovered, given that the only recorded ones predate the rename and the shared base.

## Constraints

- This is a measurement. It adds no file outside this record and changes no Dockerfile, build script, image script or roadmap row.
- Every number reproduces from the command stated beside it, run against the sandbox snapshot at `/home/agentuser/sandbox`; a count taken over the growing session store names the date it was taken and the exclusions that fix its set, or it does not reproduce.
- The three reasoning tiers are the scope. The capability-layer image and the base images' own upstream layers are outside it.
- Where the data does not support a number, the gap is named rather than filled; no duration is estimated and a mention is never counted as a rebuild.

## Next Steps

This study feeds the M3.6.1 `The layer install design` row together with the census and the measured cost. Its immediate use is to show that the trigger side already decides part of the question: any option that leaves tier 3 rebuilding on every call keeps the frequent-payload invalidation, while moving the payload into a gated tier would rebuild only when that tier's own key changes. The cost side cannot yet be closed from the session store, so the design proceeds on the trigger counts and marks the rebuild count as an open data gap.

## Resolution

Adopted. The layer install design is decided in [`20261016-design-settled-reasoning_layer_install.md`](20261016-design-settled-reasoning_layer_install.md). This study's standing finding is that the session store carries the cost of no current-shape image, so the cost side waited on a measurement. The host build probe supplied it and it is recorded above: 1 second for a tier-3-only rebuild, 2 to 3 seconds for a base change and 77 seconds cold. That measurement is what turns the trigger counts of 1, 22 and 448 into a design input rather than a threat, and the design's answer is that docker's layer cache is the only reuse rule.
