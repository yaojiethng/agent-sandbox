# `settings.json` fidelity

**Status:** settled

Environment: `@earendil-works/pi-coding-agent` 1.3.0, Node 22.22.3, Linux x64. Measurements taken 2026-11-04 in `/home/agentuser/sandbox`.

## Context

The fallback chain and the behavior test depend on the shipped `settings.json`. The operator asked whether pi writes and updates the file, whether it ever refreshes, whether the active file matches the repository, what causes drift, and whether the runtime falls back to a stale copy by default.

The short answer is that the file is not a single live document. It is a template in the repository, a copy baked into the image, a copy seeded into the container at every start, and an optional project override. pi writes the active copy, the harness overwrites it at the next start, and the repository is never read at runtime.

## Method

The settings manager and the interactive write paths are read at the cited lines. A fidelity probe drives pi's own `SettingsManager` against a fixture with unknown keys, inline formatting, and both global and project files. The preflight is run against a corrupt settings file and against a valid file with unknown keys. The active file, the repository template, and the image template are compared with `cmp` and `diff`. The seed, onboard, refresh, and image build paths are read.

## The copies

| Copy | Path | Written by | Read at runtime |
|---|---|---|---|
| Repository template | `src/reasoning/providers/pi/config/agent/settings.json` | a commit | No |
| Image template | `/opt/workflow/agent/config/agent/settings.json` | the provider Dockerfile `COPY` at image build | No, it is the seed source |
| Active global file | `$AGENT_HOME/agent/settings.json` | the entrypoint seed, the pi preflight, and pi itself | Yes, at process start and on reload |
| Project override | `<cwd>/.pi/settings.json` | the project | Yes, when the project is trusted |
| Host sandbox copy | `$SANDBOX_DIR/.pi/agent/settings.json` | nothing | No, onboard excludes it |

The host sandbox copy does not exist for the config files. `scripts/onboard.sh:283-290` excludes `agent/settings.json`, `agent/auth.json`, `agent/models.json`, and `agent/AGENTS.md` from the rsync. The docs that say onboard seeds the same tree are imprecise, and the report on the selection behavior lists the correction.

## What writes the active file

Pi writes the active file through `SettingsManager`. The write path at `dist/core/settings-manager.js:428-472` reads the current file under a lock, merges only the fields pi marked modified, and writes the result with `JSON.stringify(mergedSettings, null, 2)`. It preserves unknown keys and every key it did not modify. It normalizes formatting, so an inline array becomes multi-line. It does not use a temporary file and a rename. The lock is a lockfile beside the settings file, and `writeFileSync` is the write.

The pi actions that mark a field modified and save are:

| Action | Fields written | Evidence |
|---|---|---|
| First start on a new version, or a changelog with new entries | `lastChangelogVersion` | `dist/modes/interactive/interactive-mode.js:992-1005` |
| Model selector's "set as default" or a provider shortcut | `defaultProvider`, `defaultModel`, and a literal appended to `enabledModels` when the model is outside a non-empty scope | `dist/core/agent-session.js:1986-2010`, `dist/modes/interactive/interactive-mode.js:4458` |
| `/scoped-models` save | `enabledModels` | `dist/modes/interactive/interactive-mode.js:4539` |
| Thinking level "set as default" | `defaultThinkingLevel` | `dist/core/agent-session.js:2093` |
| Theme and other TUI settings | their own fields | the `set*` methods in `settings-manager.js` |

pi writes nothing when no field is modified. The model cycle key does not persist, because `cycleModel` is called without `persist`. The `/model` command with an argument also uses `persist: false`. Only the explicit default action writes.

On a corrupt file, pi does not overwrite it. `SettingsManager.create` records a load error, `getSettings()` returns `{}`, and `save()` returns early while `globalSettingsLoadError` is set. Measured: a file containing `{ not json` was left unchanged after `setLastChangelogVersion`, and the manager reported one load error.

The harness writes the file twice at every container start:

1. `src/reasoning/entrypoint.sh` copies `/opt/workflow/agent/config/agent/` over `$AGENT_HOME/agent/` with `cp -RT --no-preserve=all`. This overwrites the active file with the image copy.
2. `src/reasoning/providers/pi/preflight.sh` parses the file, adds the two harness entries to `packages`, and re-serializes the whole object. Valid keys, unknown keys, and `prompts` survive. Formatting is normalized.

On an invalid settings file, the preflight writes `{"packages":["/opt/workflow/agent","/opt/workflow/agent/modules/coding-agent"]}` and continues. Measured. Every other key is dropped, and pi then starts on its own defaults. This path is reachable when the image template is invalid JSON or when the seed is skipped and an existing file is corrupt. The preflight reports no failure for the loss.

No harness step copies the active file back out at stop. `scripts/run_agent.sh` and the compose overlay contain no `docker cp` for settings. The next start always begins from the image.

## Current sync

The three copies agree semantically right now. The repository template and the image template are byte-identical. The image was built on 2026-10-29, after the last settings commit on 2026-10-19. The active file has the same keys and values as the repository, but it is not byte-identical. The preflight expanded `defaultTools` from `["+codemode"]` to a multi-line array. The active file's mtime is the session start, not the repository commit.

So there is no current staleness in the settings content. The drift is in the mechanism.

## What causes drift

The repository is not the runtime source. The image is. A repository change reaches a session only after the provider image is rebuilt from that tree. `make build` or `make start REFRESH=1` rebuilds. `make refresh` rewrites the sandbox Makefile and `.env` only and does not re-provision the provider or rebuild the image. `scripts/onboard.sh:162-220` and `scripts/templates/Makefile.template:399` are the evidence.

Pi's own writes are session-local. The entrypoint seed overwrites the file at the next start, so a model set as default, a scope addition, a thinking default, a theme change, or a changelog version does not survive a restart. The host has no copy to preserve them. This is the largest drift source, and it is a deliberate ownership choice in `docs/reference/provider_lifecycle.md:21,59`.

A project-level `.pi/settings.json` overrides the global file. The merge is deep for objects and replacing for arrays. Measured: a project file with `enabledModels: ["opencode-go/*"]` made the session start on `opencode-go/claude-haiku-5-5`; a project file with `packages: ["/project"]` replaced the global `["/opt/workflow/agent"]`. The project file is trusted by `defaultProjectTrust: always` and is not seeded or overwritten. It can bypass the fallback chain and the harness package roots.

A corrupt settings file has two different outcomes. pi runs on defaults and preserves the file. The preflight reduces it to `packages` and continues. The second outcome is a silent fallback to pi defaults, and it is the one that runs at every start before pi.

Two code-level risks are inferred rather than measured. The settings write is not atomic, so a crash during `writeFileSync` can leave a truncated file; the next start's seed replaces it. A stale lockfile can make the next save fail after ten retries, and `enqueueWrite` records the error and loses the change. Both are worth a unit test if the file is meant to hold anything durable.

## Does pi refresh?

At process start, pi loads the global file and, when the project is trusted, the project file. On `/reload` or a session reload, `SettingsManager.reload()` re-reads both (`dist/core/agent-session.js:2970-2980`). There is no file watcher. An external edit to the active file or the project file is invisible until a reload. The harness does not reload the file during a session; it writes it only at container start.

The answers to the operator's questions are therefore:

| Question | Answer |
|---|---|
| Can pi write and update the file? | Yes. It writes modified fields in place, preserves unknown and unmodified keys, and normalizes formatting. |
| Does it ever refresh? | It loads at start and on explicit reload. It does not watch the file. |
| Is the active file in sync with the repository? | Semantically yes right now. The image is the runtime source, so a repository change without a rebuild is not in sync. The active file also differs byte-wise because the preflight reformats it. |
| What causes drift? | A stale image, pi's session-local writes being overwritten, a project-level override, a corrupt preflight fallback, and the preflight's formatting rewrite. |
| Are we falling back to a stale version by default? | The runtime always uses the image's build-time copy. If the image predates the repository, yes. The current image is current for settings. Pi's persisted settings are always discarded at the next start, so the session reverts to the image copy rather than the last session's settings. |

## Consequences for the chain and the behavior test

The chain is in the global template. It takes effect only when the image is rebuilt, the preflight succeeds, and no project-level file replaces `enabledModels`. The behavior test must isolate the global layer. A test run from a cwd with a `.pi/settings.json` would assert the project file, not the shipped template. The test should use a temporary cwd with no project settings and a temporary `PI_CODING_AGENT_DIR` seeded from the shipped template, not the container's active file.

The implementation must name the rebuild step. A settings change that lands in the repository but not in the image is a change that never reaches a session. `make refresh` is not enough.

The project-level override is a bypass. If the chain is meant to be a hard rule, the harness needs a guard or a documented exclusion. That is a separate decision.

## Durable settings: the options

The operator rejected the directory-mount symlink. The reason is the parallel-work topology. One `SANDBOX_DIR` can host several worktrees and branches. A settings file under `.pi/agent/config` sits outside every worktree, so all tracks share it. A change made by one track is in no branch, bypasses review, and a later write from another track clobbers it. The same objection applies to a single-file mount, a copy-out bridge to one per-sandbox file, and any other single host file per sandbox.

The safe scope is per branch or per track, not per sandbox. This design is deferred to the config-ownership work recorded in `devlog/roadmap.md`, M3.2.3. The target semantics is that `.pi` config is defined once per repository, seeded at onboard, and managed by the user. Until that exists, the durable-settings shape is a TODO, not part of the original `settings.json` selection fix.

| Option | Scope | Parallel safety | Live | Cost |
|---|---|---|---|---|
| Single-file bind mount of `settings.json` | Per sandbox | Shared by all tracks | Yes | `mv` replaces the mount point. The docs reject this shape |
| Directory mount plus a symlink at the seeded path | Per sandbox | Shared by all tracks | Yes | The rejected shape. A track's change bypasses its branch and can be clobbered |
| Container copy-out to one per-sandbox file | Per sandbox | Shared at close | No | A stop hook, and a crash loses the change |
| Project `.pi/settings.json` in the worktree | Per branch | Git merge | At edit time | Settings become project code and can conflict |
| Per-track `PI_CODING_AGENT_DIR` | Per track | Isolated | Yes | A dispatch change and per-track state |
| Close-time capture of the settings diff | Per branch or per session | Mergeable | No | A capture and promotion step |

A candidate shape is a layered model, not one file.

1. **Image template.** Defaults and harness-owned keys, shared by every branch. The model chain lands here. A shared default has no conflict because no branch changes it.
2. **Project `.pi/settings.json`.** Branch-scoped settings that the operator wants reviewed and merged. Pi reads it over the global file, and the merge is deep for objects and replacing for arrays. Each worktree has its own copy, so a track's change is in its branch. Parallel tracks resolve a conflict in git, visibly. The agent can edit this file directly, and a capture step can write it at close.
3. **Personal preferences.** `followUpMode`, theme, and similar operator choices are not project code. Keep the global active file ephemeral. At close, capture the diff against the image template to a per-session record and let the operator promote it. Do not put a shared live file across tracks.

The operator's example, changing `followUpMode` from one-at-a-time to all, is a personal preference. The model chain is a project default. Mixing both in one shared file is what creates the clobbering.

A candidate capture step:

1. Compare the active `$AGENT_HOME/agent/settings.json` to the image template.
2. Drop `lastChangelogVersion` and the harness-owned keys.
3. Write the remaining diff to the branch when the setting is project-scoped, or to a host record keyed by the branch when it is personal.
4. The operator reviews and merges or promotes.

This is not live. If live persistence is required, the per-track `PI_CODING_AGENT_DIR` option isolates the file, but it needs a dispatch change and a capture step of its own.

The open questions below are for that future row, not this iteration.

## Open questions for the durable-settings row

1. Should pi's persisted settings survive a restart? If yes, the directory mount plus symlink is the recommended shape. If no, the "set as default" action should be documented as session-local.
2. Should the host file live at `$SANDBOX_DIR/.pi/agent/config/settings.json`, or is a different path required? The canonical `agent/settings.json` cannot be the mount source without a single-file mount or a whole-directory mount.
3. Which keys are harness-owned and forced at every start, and which are user-owned? `packages` is forced today; `prompts` is not. The model chain is currently a default, not a forced policy.
4. Should an existing host file receive new keys from a newer image template, or is it created once and left alone? This decides whether a pi upgrade adds new defaults.
5. Should the `mv` edge get a stop-time copy-out, a resume repair, or be accepted because pi's own write path follows the symlink?
6. Should a project `.pi/settings.json` remain allowed to override the durable host file? If yes, the chain is still bypassable by a project file.
7. Should the behavior test isolate the global layer, include the project-override scenario, or both?
8. Should the preflight fail loudly on invalid JSON instead of writing a minimal file? This is our script, so a unit test can pin the choice.
9. Should the repository template be validated against pi's settings schema at build or test time? The container-layout gate parses it; it does not check the schema.

## Artifacts

This report is the record. The probes are session-local under `.scratchpad/`: `probe-settings-fidelity.mjs`, `probe-project-settings.mjs`, `probe-merge.mjs`, and the preflight runs. The handover records the iteration.
