# Module Instruction Payload

**Current:** 2026-10-06

## 2026-10-06 -- The payload ships in pi's image only, and two providers start on a fresh install

**Decision:** The harness payload reaches pi's image only. The hermes and opencode dockerfiles carry their agent's own install and the harness's documentation, and no prompt or skill, which supersedes the 2026-10-05 clause that gave each provider a `COPY` line per payload kind. Neither of those providers ships a provider config either: the hermes `config/config.yaml` and `config/env.stub` are deleted, so both images start on their agent's own defaults, with credentials and the iteration cap arriving as environment variables from the compose overlay.

**Rationale:** A payload needs a loader, and those two harnesses have no config transport that could name one, so a payload there would sit unreachable in the image and read as support that does not exist. The same reasoning removes the config: the hermes file was that agent's own default dump, carrying a model pin this harness does not use, an iteration cap the overlay already sets, and upstream defaults for sandboxes and media the harness never touches, so nothing in it was harness policy. What the harness keeps is the transport it actually uses, environment variables the operator fills, and `onboard.sh` still seeds a provider that does ship a config directory.

**Edge cases / drivers:** Wiring a second harness is that harness's own work, done when someone runs it. The container manifest drops those two providers' payload rows, and the layout gate holds the manifest and the dockerfiles equal in both directions. The `session` rows still name `/opt/workflow/agent/` paths, because they describe what a pi session reaches rather than what every image bakes.

## 2026-10-06 -- The package key is the harness payload's only switch

**Decision:** `packages` enables the harness payload, and no `skills` or `prompts` list names a harness root. The shipped `settings.json` carries two package entries, `/opt/workflow/agent` and `/opt/workflow/agent/modules/coding-agent`, and each contributes its `prompts/` and `skills/` subdirectories as roots. The harness-key merge in `preflight.sh` re-injects both entries and leaves a user's own `skills` and `prompts` lists untouched.

**Rationale:** The two switches were never equivalent. `/opt/workflow/agent` was named both ways, but the module root appeared in no list, so `packages` was the only thing that enabled it: dropping `packages` would have lost the module, while dropping the lists lost nothing. The 2026-10-05 decision rejected the list route as two entries where one will do, and this is the same argument applied to the first payload. The change also made a mismatch visible: the merge re-injected the root with two switches and not the one with a single switch, which is backwards. Both entries ride the merge now, and the module entry is the one that needs it.

**Edge cases / drivers:** The layout gate reads the roots from either form, because `settings_root_keys()` unions an explicit list with each package's conventional subdirectories, so this decision does not move what the gate sees; a case pins the package-only shape. A settings record left over from an older image may still carry the two lists. They name roots the package entries already reach, so they are inert, and the merge does not remove them, because a user's own list is not the harness's to touch.

## 2026-10-05 -- A workflow module ships its payload to its own roots, enabled by one package entry

**Decision:** `workflow/<module>/` is a toggle unit. Its `prompts/` and `skills/` folders are its payload, and each ships to its own root under `/opt/workflow/agent/modules/<module>/`, with a `COPY` line per payload kind in each provider dockerfile. Nothing merges into the harness roots `/opt/workflow/agent/prompts/` and `/opt/workflow/agent/skills/`. A module is enabled by naming its directory as a package in the provider's config: pi's `settings.json` carries `/opt/workflow/agent/modules/coding-agent` in its `packages` key, and the package convention contributes that directory's `prompts/` and `skills/` subdirectories as roots. The layout gate derives the roots from the same entry, so a module root that no entry enables fails, and it fails when two roots under one settings key hold a file, or a skill directory, of the same name.

**Rationale:** The three record-check skills under `workflow/coding-agent/skills/` were filed in the coding-project-generic scope and reached by nothing but a hand-written pointer: no dockerfile copied the folder, so no provider config named it and no runtime loaded it. Giving the module a root makes them a declared and loaded surface, and it does so without what a merge would destroy. A merge of two sources onto one root is invisible afterwards: the image cannot say which module a file came from, and when two modules ship a file of the same name the later `COPY` wins with nothing reported. Separate roots keep the provenance, and the collision becomes checkable, which is why the gate grew that check.

The toggle is one settings entry rather than two root entries. pi already has the unit this needs: a package bundles prompts, skills, extensions and themes, and the module's layout already matches the convention, with `prompts/` and `skills/` at the module root. Two explicit root entries would work, and they are the smaller change, but they would name the two folders the package entry already implies, and a module that later ships an extension would need a third entry.

The package route is verified rather than assumed. A bare directory listed under `packages`, holding only those two subdirectories and no `package.json`, contributes its skills to the injected skill list and its prompts as commands, and a local package is loaded from its resolved path without a copy. The absence of a copy is what made the route acceptable: the retired provider-config transport failed because a stale copy shadowed the image's own files, and that failure cannot arise here.

**Rejected alternatives:**

- *Merge the module's folders into the harness roots* -- two sources on one root lose the module boundary, hide a same-named file, and cannot be checked for a collision, because the manifest no longer sees which file came from which source.
- *Name the module's two roots in the settings' `prompts` and `skills` lists* -- workable and smaller, but it is two entries where one will do, it does not extend to a module that ships an extension, and it bypasses the mechanism pi already has for this unit.
- *Keep the skills at `.agents/skills/` with no runtime path* -- rejected by the operator. That cell is for a skill specific to one repository; these three are written against the harness's convention set, so the module owns them, and the scope keeps its name for a future occupant.
- *Copy the whole module directory* -- it would ship `drafts/` and `audits/`, which are working records rather than payload.

**Edge cases / drivers:** The payload ships in pi's image only, by the 2026-10-06 decision, and the hermes and opencode images carry no harness prompt or skill, because neither harness has a config transport that could load one. A module cell belongs to no single provider, so its loader names none. The package entry takes a directory path in pi's form; an npm or git source installs elsewhere and is out of scope here.
