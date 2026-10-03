---
name: pi-bump
description: Bump the pinned pi version in the agent-sandbox reasoning layer. Use when the operator asks to update pi, bump the pi version, upgrade the pi-coding-agent install, or refresh the pinned @earendil-works/pi-coding-agent version and its config record.
---

# Pi Version Bump

Updates the pinned `@earendil-works/pi-coding-agent` version used by the pi reasoning-layer provider. The repository config is the source of truth. The container's pi updates only at the next image rebuild; a bump does not update it in place.

## Do not use `pi update --self`

`pi update --self` fails in this container for two reasons:

1. The pi provider overlay (`src/reasoning/providers/pi/docker-compose.pi.yml`) sets `PI_SKIP_VERSION_CHECK=1`, so pi's version probe returns `undefined` and the update fails before it reaches the install step.
2. The global install lives at `/usr/local`, which the container's `agentuser` does not own, and there is no `sudo`.

Bump the pin instead: source the latest version from the version-check API (step 1) and edit the files below (step 5).

## Files to edit (repo source of truth)

| File | Change |
|---|---|
| `src/reasoning/providers/pi/base.dockerfile` | `RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@<NEW>` |
| `src/reasoning/providers/pi/config/agent/settings.json` | `"lastChangelogVersion": "<NEW>"` |

A bump does not edit `devlog/roadmap_future.md`. The M7 -> Dependency Security note names the bump unit, not a version literal.

## Steps

### 1. Source the latest version from the API

```bash
curl -sS https://pi.dev/api/latest-version
```

This returns JSON of the form `{"ok":true,"version":"<version>","packageName":"@earendil-works/pi-coding-agent"}`. Read the `version` field and record it as `<NEW>`. This is the same endpoint pi's version-check uses, and pinning this version performs the update.

### 2. Read the changelog for `<NEW>`

The release notes are the only place a bump's risk is written down. `npm view` carries no notes, so it is the wrong source. The changelog ships in the package:

```bash
npm pack @earendil-works/pi-coding-agent@<NEW> --pack-destination /tmp
tar xzf /tmp/earendil-works-pi-coding-agent-<NEW>.tgz -C /tmp package/CHANGELOG.md
```

Read every section from `<NEW>` back to the currently pinned version, not only the newest one. A bump across a minor line carries every fix in between, and the fix that matters is rarely in the top section. A major version can also remove, rename or redefine an interface. Read its migration or breaking-change notes as well as the sections, and walk the four categories below against them.

While reading, watch for four kinds of entry, because each one moves something this repository owns:

- **extensions** -- a changed extension API, a changed registration form, a new required field on a context an extension reads.
- **providers and model catalogs** -- a changed default model per provider, a refreshed baked catalog, a changed catalog merge. The `model-refresh` extension is built on all three.
- **model resolution and scope** -- anything about the saved default, the model scope, or `enabledModels`.
- **the bundled dependency tree** -- a new or removed package under `node_modules/@earendil-works/`, which is where `pi-ai` and the `yaml` parser the frontmatter gate resolves from live.

`lastChangelogVersion` gates pi's changelog display. An older value makes pi show the full changelog on first start with the new version. A matching value suppresses that repeated output on subsequent starts.

### 3. Probe the extensions, then walk each extension's bump semantics

Run the compat probe first:

```bash
node scripts/lint/pi-extension-compat.mjs --target <NEW>
```

The probe checks the names the extensions under `config/agent/extensions/` import. It proves a name is still exported, not that the behaviour behind it held.

Each extension owns its bump semantics: the assumptions it makes about pi, with the code that would falsify each, in its `README.md`. An extension with no such record has an unaudited surface; note the gap. For each extension, read its record and dispatch one subagent per row, in parallel. Give each subagent this brief, filled in:

```text
Decide whether the assumption below still holds against pi <NEW>.

Assumption: <the row, verbatim>
Falsifier: <the code the row names>
Candidate: pi <NEW>

Install the candidate if you need it:
npm install --silent --prefix /tmp/pi-<NEW> @earendil-works/pi-coding-agent@<NEW>

Read the candidate's bundled code, or probe it live. Do not guess.

Report one line, then the evidence:
- holds
- moved: <the change>
- unverified: <the reason>
```

Use the subagent form in the provider `AGENTS.md` `## Running Review Subagents`. Record every verdict in the extension's record and refresh its `Verified` date.

### 4. Report the status, then stop

Report before editing. A bump moves a pin and a settings record, and a reader who wants to know whether the bump is safe should not have to undo it first.

The report states: the current pin, `<NEW>`, the probe verdict, which assumption rows moved, and the entries from step 2 that touch something this repository owns. Then stop and wait for the operator.

**Do not edit any file before the operator releases.** Steps 5 to 7 run only after that release.

### 5. Edit the two repo files

- Bump the pin in `src/reasoning/providers/pi/base.dockerfile`.
- Bump `lastChangelogVersion` in `src/reasoning/providers/pi/config/agent/settings.json`.

Optionally bump the live `~/.pi/agent/settings.json` `lastChangelogVersion` for immediate record consistency. The next container start reseeds it from the baked template regardless.

### 6. Verify

- [ ] `node scripts/lint/pi-extension-compat.mjs --target <NEW>` reports clean
- [ ] `grep -rn "<NEW>"` hits `base.dockerfile` and `settings.json`
- [ ] Every version literal in those two files equals `<NEW>`. Read them. A grep with a hardcoded range misses the stale pin that is actually there.
- [ ] `settings.json` is valid JSON (`node -e "require('./... settings.json')"`)
- [ ] `bash scripts/lint.sh` is clean
- [ ] Run `bash tests/knowledge/knowledge_pi_config_cycle.sh`. Its version fixtures are intentional and decoupled from the installed version.
- [ ] The assumption table rows touched by step 2 are updated, or marked unverified with the reason

### 7. Commit

Use this message, with `<NEW>` filled in:

```text
chore: bump pi to <NEW>

Refresh the pinned version and the changelog record.
```

A pin bump changes no governance, so it needs no handover. An extension change or a skill edit is a separate `workflow:` commit with its own iteration.

## Notes

- The container updates pi only at the next image rebuild, when the `base.dockerfile` `npm install -g` runs as root and installs the pinned `<NEW>`.
- `lastChangelogVersion` only gates the post-update changelog display. With `PI_SKIP_VERSION_CHECK=1` it is effectively the installed-version record. Keeping it in step prevents drift and avoids a huge changelog on first start.
- No changelog entry in `devlog/changelog.md`  --  version bumps are not milestone completions.
- No lockfile is produced for the global install. An open roadmap item under M7 Dependency Security covers this.
