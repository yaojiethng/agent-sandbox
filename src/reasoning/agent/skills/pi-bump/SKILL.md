---
name: pi-bump
description: Bump the pinned pi version in the agent-sandbox reasoning layer. Use when the operator asks to update pi, bump the pi version, upgrade the pi-coding-agent install, or refresh the pinned @earendil-works/pi-coding-agent version and its config record.
---

# Pi Version Bump

Updates the pinned `@earendil-works/pi-coding-agent` version used by the
pi reasoning-layer provider, in the repo config (the source of truth). The
running container's pi is updated at the next image rebuild  --  it is not updated
in place during a bump.

## Version policy

The operator decides when to bump (new functionality, critical fix, security
vulnerability). No automation. This is manual maintenance.

## Why `pi update --self` is not used here

`pi update --self` cannot complete in a running pi container for two reasons:

1. `PI_SKIP_VERSION_CHECK=1` is set in the pi provider overlay
   (`src/reasoning/providers/pi/docker-compose.pi.yml`) to keep startup clean
   (no version-check noise). This env var makes pi's own version probe return
   `undefined`, so `pi update --self` fails with "Could not determine latest pi
   version" before reaching the install step.
2. Even with the env var unset, pi refuses to self-update because the global
   install lives at `/usr/local`, which is root-owned and not writable by the
   container's `agentuser`. There is no `sudo` for elevated privileges.

These are deliberate design choices (clean startup; image-time global install as
root). Do not remove the env var or relocate the prefix to work around them.
Instead, source the latest version directly from the version-check API, which is
the same data `pi update --self` would use, and commit the pin.

## Files to edit (repo source of truth)

| File | Change |
|---|---|
| `src/reasoning/providers/pi/base.dockerfile` | `RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@<NEW>` |
| `src/reasoning/providers/pi/config/agent/settings.json` | `"lastChangelogVersion": "<NEW>"` |
| `devlog/roadmap_future.md` | Refresh the stale pinned-version note under M7 -> Dependency Security |

## Steps

### 1. Source the latest version from the API

```bash
curl -sS https://pi.dev/api/latest-version
```

This returns JSON of the form `{"ok":true,"version":"0.84.1","packageName":"@earendil-works/pi-coding-agent"}`.
Record the `version` as `<NEW>`. This is the same endpoint pi's version-check
uses; the "update" is performed by pinning this version.

### 2. Review the changelog first (update-first-then-pin)

Before you set `lastChangelogVersion` to `<NEW>`, review what changed in the
release so the version bump is informed. `lastChangelogVersion` gates pi's
changelog display: an older value makes pi show the full changelog on first
start with the new version; matching it suppresses that repeated output on
subsequent starts. Source the notes from
`npm view @earendil-works/pi-coding-agent` or the pi release notes. Confirm
`<NEW>` with the operator before editing.

### 3. Edit the three repo files

- Bump the pin in `src/reasoning/providers/pi/base.dockerfile`.
- Bump `lastChangelogVersion` in
  `src/reasoning/providers/pi/config/agent/settings.json`.
- Refresh the pinned-version note in `devlog/roadmap_future.md`
  (M7 -> Dependency Security) to the same `<NEW>`.

Optionally bump the live `~/.pi/agent/settings.json` `lastChangelogVersion` for
immediate record consistency (it is reseeded from the baked template on next
container start regardless).

### 4. Verify

- [ ] `curl -sS https://pi.dev/api/latest-version` reports `<NEW>`
- [ ] `grep -rn "<NEW>"` hits `base.dockerfile`, `settings.json`, and the
      `roadmap_future.md` note
- [ ] No stale `0.x` pin remains in those files (`grep -rn "0\.8[0-3]\."`)
- [ ] `settings.json` is valid JSON (`node -e "require('./... settings.json')"`)
- [ ] Run `bash tests/knowledge/knowledge_pi_config_cycle.sh`  --  its version
      fixtures are intentional and decoupled from the installed version

### 5. Commit

```
workflow: bump pi to <NEW> and codify the bump procedure
```

Wrap the configuration changes and the new skill in a single `workflow:`
commit. Skill files under `src/reasoning/agent/` count as governance, so the
skill addition makes this a workflow commit rather than a chore.

## Notes

- The running container updates pi only at the next image rebuild, when the
  `base.dockerfile` `npm install -g` (as root) installs the pinned `<NEW>`.
- `lastChangelogVersion` only gates the post-update changelog display. With
  `PI_SKIP_VERSION_CHECK=1` it is effectively the installed-version record;
  keeping it in step prevents drift and avoids a huge changelog on first start.
- No changelog entry in `devlog/changelog.md`  --  version bumps are not milestone
  completions.
- No lockfile is produced for the global install (open roadmap item under M7
  Dependency Security: "Consider lockfile for npm install -g dependencies").
