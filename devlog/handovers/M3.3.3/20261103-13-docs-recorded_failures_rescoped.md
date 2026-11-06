---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Documentation
status: Closed
---

# Handover - the recorded failures are five resolved cases and one live one

## Objective

Confirm whether the six failures the 2026-11-01 survey recorded still reproduce, and rescope the row to what survives.

## Scope

In scope: one read per case, and the row's rewrite.

Out of scope: the fix for the surviving case, which the row now carries as open work.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The rename shipped | `ls -d src/reasoning/agent/skills/domain-modeling` | Agent [x] |
| The cross-runtime skill sits in the agent layer | the same path, not under `src/reasoning/providers/pi/config/agent/skills/` | Agent [x] |
| The orphaned runbook is gone | `ls workflow/coding-agent/skills/prose-review/runbooks/` names `instruction-cleanup` and `reference-staleness` | Agent [x] |
| No package manifest exists to duplicate | `find . -name package.json` returns nothing | Agent [x] |
| The image and the tree are held equal | `scripts/check_container_layout.sh` compares the manifest against the dockerfiles, the mounts and the instruction surfaces' folder sets | Agent [x] |
| The phantom path survives in the sandbox | `bash tests/test_onboard.sh` passes 23 of 23, and it asserts a mode on `$SANDBOX_DIR/.pi/agent/AGENTS.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Five cases close as resolved or moot, and the row rescopes to the sixth | A fixture for a failure that no longer reproduces catches nothing, and keeping the history in the row made one live defect look like six | `devlog/roadmap.md` |
| The surviving case is a dead copy, not a missing reader | The container's `AGENTS.md` is seeded into `AGENT_HOME` from the image, so a consumer exists and it reads the image's copy; the sandbox copy is a second one that nothing names | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

- The phantom is created by design, not by accident. `scripts/onboard.sh` rsyncs each provider's whole `config/` directory into `$SANDBOX_DIR/.<provider>/` with `--chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r`, so `config/agent/AGENTS.md` arrives beside the files that do have consumers, `auth.json`, `models.json` and `settings.json`.
- Nothing mounts it. The compose file mounts `prompts`, `sessions`, `skills`, `packages` and `model-recommendations.md`, and `provider.dockerfile` copies `config/` to `/opt/workflow/agent/config/` for the entrypoint to seed into `AGENT_HOME`.
- So the sandbox copy refreshes only when onboard runs, while the image's copy refreshes when the image is built. Two copies of the instruction surface, and the stale one is the one on the host.
- The only reader is `tests/test_onboard.sh`'s `test_provider_config_modes_resist_umask`, and it reads the file's mode, not its text, as a proxy for the rsync flags. That is why the file looks like a live contract.

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | the row is rescoped to the phantom `AGENTS.md` |
