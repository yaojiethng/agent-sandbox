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

This returns JSON of the form `{"ok":true,"version":"0.99.2","packageName":"@earendil-works/pi-coding-agent"}`.
Record the `version` as `<NEW>`. This is the same endpoint pi's version-check
uses; the "update" is performed by pinning this version.

### 2. Read the changelog for `<NEW>`

The release notes are the only place a bump's risk is written down. `npm view`
carries no notes, so it is the wrong source; the changelog ships in the package:

```bash
npm pack @earendil-works/pi-coding-agent@<NEW> --pack-destination /tmp
tar xzf /tmp/earendil-works-pi-coding-agent-<NEW>.tgz -C /tmp package/CHANGELOG.md
```

Read every section from `<NEW>` back to the currently pinned version, not only
the newest one. A bump across a minor line carries every fix in between, and the
one that matters is rarely the one in the top section.

While reading, watch for four kinds of entry, because each one moves something
this repository owns:

- **extensions** -- a changed extension API, a changed registration form, a new
  required field on a context an extension reads.
- **providers and model catalogs** -- a changed default model per provider, a
  refreshed baked catalog, a changed catalog merge. The `model-refresh` extension
  is built on all three.
- **model resolution and scope** -- anything about the saved default, the model
  scope, or `enabledModels`.
- **the bundled dependency tree** -- a new or removed package under
  `node_modules/@earendil-works/`, which is where `pi-ai` and the `yaml` parser
  the frontmatter gate resolves from live.

`lastChangelogVersion` gates pi's changelog display: an older value makes pi
show the full changelog on first start with the new version; matching it
suppresses that repeated output on subsequent starts.

### 3. Probe the extensions against `<NEW>`

```bash
node scripts/lint/pi-extension-compat.mjs --target <NEW>
```

The two home-spun extensions under `config/agent/extensions/` import from pi and
from pi-ai. A bump that removes one of those names does not fail the build here;
it fails at container start, inside an extension, with a stack that points at the
extension rather than at the bump. The probe reads the imported names out of the
extension sources, so an extension that starts importing something new is covered
without editing the probe. It needs network and npm, because it installs the
candidate into a temp prefix.

**A clean probe is necessary and not sufficient.** It proves every name the
extensions import is still exported. It cannot prove the semantics behind those
names held, and that class of change is real in this repository: `mergeModels`
became reachable between 0.87.1 and 0.99.1 without a single import changing.

So walk the assumption table in `model-refresh/README.md` as well. Each row names
the code that would falsify it; check those against `<NEW>` and update the table
with what moved. A row that cannot be checked from the release is recorded as
unverified rather than assumed to hold.

### 4. Report the status, then stop

Report before editing. A bump moves a pin, a settings record and a roadmap note;
a reader who wants to know whether a bump is safe should not have to undo it to
find out.

The report states: the current pin, `<NEW>`, the probe verdict, which assumption
rows moved, and the entries from step 2 that touch something this repository
owns. Then stop and wait for the operator.

**Do not edit any file before that release.** Steps 5 to 7 run only on it.

### 5. Edit the three repo files

- Bump the pin in `src/reasoning/providers/pi/base.dockerfile`.
- Bump `lastChangelogVersion` in
  `src/reasoning/providers/pi/config/agent/settings.json`.
- Refresh the pinned-version note in `devlog/roadmap_future.md`
  (M7 -> Dependency Security) to the same `<NEW>`.

Optionally bump the live `~/.pi/agent/settings.json` `lastChangelogVersion` for
immediate record consistency (it is reseeded from the baked template on next
container start regardless).

### 6. Verify

- [ ] `node scripts/lint/pi-extension-compat.mjs --target <NEW>` reports clean
- [ ] `grep -rn "<NEW>"` hits `base.dockerfile`, `settings.json`, and the
      `roadmap_future.md` note
- [ ] Every version literal in those three files equals `<NEW>`. Read them; a
      hardcoded range in a grep misses the stale pin that is actually there
- [ ] `settings.json` is valid JSON (`node -e "require('./... settings.json')"`)
- [ ] `bash scripts/lint.sh` is clean
- [ ] Run `bash tests/knowledge/knowledge_pi_config_cycle.sh`  --  its version
      fixtures are intentional and decoupled from the installed version
- [ ] The assumption table rows touched by step 2 are updated, or marked
      unverified with the reason

### 7. Commit

```text
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
