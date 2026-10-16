# The reasoning layer install: tiers, payload, pins and the OpenCode surface

**Status:** settled

## Context

The M3.6.1 row `The layer install design` decides where the shared dispatch CLIs and each agent's payload install, the cache model, and the pin policy for every build input. Three inputs feed it and all three have landed: the install-step census at 41 rows ([`20261016-study-settled-install_step_census.md`](20261016-study-settled-install_step_census.md)), the invalidation history with trigger counts of 1, 22 and 448 per tier ([`20261016-study-settled-invalidation_history.md`](20261016-study-settled-invalidation_history.md)), and the host build probe's measured cost of 1 second for a tier-3-only rebuild, 2 to 3 seconds for a base change and 77 seconds cold.

Three facts made the question urgent rather than theoretical. `opencode-ai@1.19.1` installs twice, once in the pi base as a dispatch tool and once in the opencode base as its runtime. The skip mechanism `build_if_missing` buys about one second, and its failure mode is a silently stale image, which is the defect that landed in `26595bff`. And the OpenCode instruction transport has no caller, so the surfaces it generates reach no runtime.

Two constraints bound the answer. The repository working tree is the build context for all three tiers, and there is no `.dockerignore`. And OpenCode validates its config strictly and rejects an unknown top-level key, so the generated config is a checked artifact rather than a comment.

## Options Considered

### Option A - keep three tiers and one base per provider

The status quo. Each provider base installs its own agent, and each provider's final Dockerfile carries its own payload `COPY` list: ten lines for pi, five for opencode, five for hermes.

Rejected. It keeps the duplicate `opencode-ai` install, and the payload is declared once per provider, so a new instruction surface is three edits that no gate compares.

### Option B - one base carrying every agent, differentiation only at the final image

The operator's proposal. Everything installs in one base, and the provider images differ only in payload and environment.

Rejected as stated. The hermes base is nine install rows including a `NousResearch/hermes-agent` clone at default-branch HEAD, a `uv venv` pip install of `.[all]`, an npm install and `ffmpeg`. Consolidating it puts the only unpinned build in the tree on the path of every provider, so a hermes clone failure blocks pi and opencode, and every pi image carries a Python venv it never uses. The measured cost does not argue for it either: a base rebuild is 2 to 3 seconds warm, so the saving is small and the blast radius is not. The operator's ruling is that OpenCode working outranks unifying hermes, and the unification is indefinitely deferred.

### Option C - four cached layers plus a shared payload image

Chosen. The tiers split by kind rather than by provider: the runtime, the shared dispatch tools, the provider's own differential, and the common payload.

## Decision

### The tier shape

| Tier | Image | Contents | Cache |
|---|---|---|---|
| 1 | `agent-base` | the runtime set: Node, uv's Python 3.11, apt tools, hadolint, markdownlint-cli2 | docker's layer cache |
| 2 | `agent-tools` | the shared dispatch CLIs. Today `opencode-ai@1.19.1`, and any later dispatch tool | docker's layer cache |
| 3 | `<provider>-base` | only the provider's differential: pi's `pi-coding-agent@1.3.0`, hermes's clone and venv, nothing for opencode | docker's layer cache |
| 4 | `agent-payload` | the common instruction base, copied once into `/opt/` | docker's layer cache, rebuilt from the working tree on every call |
| 5 | `<provider>-agent-<project>` | the provider's final image: `FROM <provider>-base`, one `COPY --from=agent-payload /opt/ /opt/`, the provider's own config, environment and entrypoint | always built |

Two tiers are provider-neutral. `agent-tools` is where a dispatch CLI belongs, and it deletes the duplicate `opencode-ai` install outright, which is the census's first open question. `agent-payload` is where the common instruction base belongs, and it is the payload's single declaration.

The provider base stays in the shape for one reason: the provider interface requires it ([`provider_onboarding_guide.md`](../../docs/development/provider_onboarding_guide.md), step 2). For opencode it becomes an empty `FROM agent-tools`, which keeps the interface uniform and satisfies `tests/test_shared_base_contract.sh`.

A payload image rather than a payload tier in the chain, because a Dockerfile has one `FROM`. Tier 5 inherits the provider base and pulls the payload in with a single line. The alternative, copying the payload inside each provider's Dockerfile, is what option A does and is rejected for the same reason.

### The payload home

The common instruction base ships once into `/opt/`, and every provider reads from there. That is the operator's ruling and it settles the question the census left open about whether the pi extension payload belongs in tier 2 or tier 3: it belongs to neither, because it is not provider-specific.

The payload image carries the four provider-neutral cells of [`container-interface.json`](../../src/build/container-interface.json) and the reference docs:

- `src/reasoning/agent/prompts/` to `/opt/workflow/agent/prompts/`
- `src/reasoning/agent/skills/` to `/opt/workflow/agent/skills/`
- `workflow/coding-agent/prompts/` to `/opt/workflow/agent/modules/coding-agent/prompts/`
- `workflow/coding-agent/skills/` to `/opt/workflow/agent/modules/coding-agent/skills/`
- `docs/reference/` and `docs/policies/`

`src/libs/` and the entrypoint are harness files rather than payload, and they stay where the provider contract puts them.

### The cache model

The cache model is the set of rules that decide when a build step's output is reused. The decision is to use one rule and to delete the other.

| Rule | Owner | Key | Decision |
|---|---|---|---|
| skip the daemon entirely | `build_if_missing` | `_build_key`: the Dockerfile's sha256 plus the base image's content id, stamped as `agent-sandbox.base-build-key` | removed |
| reuse a step's output | docker | a `RUN` layer's command plus its parents; a `COPY` layer's command plus the copied content | the only rule in use |

`build_if_missing`, `_build_key` and the `agent-sandbox.base-build-key` label are removed. Docker's layer cache is content-addressed already: a `COPY` layer's key includes the copied bytes, and a `RUN` layer's key includes its command and its parents. The skip mechanism sat in front of that and saved roughly a second, and its failure mode was an image that never rebuilt with nothing reporting it. A correctness guarantee is worth more than a second.

Held as data, the model is this: every tier is built on every `build_agent` call, docker decides what is reused, the key inputs are the Dockerfile's own content, its base image and the content of every `COPY`, and [`container-interface.json`](../../src/build/container-interface.json) is the one declaration of the `COPY` rows.

Two consequences the operator accepted. The build probe's meaning changes: it measures "tiers with a step that was not `CACHED`", not "tiers that rebuilt", because a fully cached build prints no `DONE` line. And a `.dockerignore` becomes worth adding, since the whole tree including `.git/` and `devlog/` is sent to the daemon on every call today.

### The pin policy

A pin fixes the resolved artifact, not the requested name. One form per input class.

| Input class | Form | Check |
|---|---|---|
| a Docker base image | a digest, with the tag kept for readability | the Dockerfile carries `@sha256:` |
| a package a registry resolves | an exact version plus a committed lockfile with integrity hashes, installed frozen | the lockfile is present and the install passes its frozen flag |
| an archive or an installer fetched by URL | the version in the URL plus the publisher's checksum | the checksum is verified in the same `RUN` |
| a git source | a commit SHA | the clone checks out the SHA, never a branch |
| an apt package | a dated snapshot | the source list names the snapshot date |
| an output of the repository working tree | the git revision, recorded by the build | not an external pin, and excluded from the policy by name |

The last row is the class the census called unpinned. Every tier-5 `COPY` and the payload image are of this class, and they cannot take a version, because their identity is the commit the working tree stands at. The policy names them and excludes them rather than pretending they are pinnable.

An exact version alone is not enough, and the reason is the operator's own question. A pin freezes whatever vulnerability that version carried and blocks the patch. So the policy pairs every pin with a way to move it: one automated bump path, and a scan. The census's unpinned list is the worklist the `Pin every build input` row applies.

### The OpenCode surface

The config stays generated by [`src/build/opencode-config.mjs`](../../src/build/opencode-config.mjs), which stays the single writer for the surfaces it owns.

A hand-authored config was considered and rejected. It would write the same roots out by hand with nothing comparing them to the manifest, which is the defect class that already cost us one: the generator exists, is tested, and nothing calls it.

Four changes to the generator:

- **Respect the provider tag.** A cell tagged `provider: pi` is pi's differential and must not reach OpenCode. Today the generator emits cell 7, `src/reasoning/providers/pi/config/agent/skills/`, into OpenCode's `skills.paths`, so an OpenCode worker is offered `pi-bump`, `pi-reviewer-dispatch`, `opencode-dispatch` and `active-tracker`. The rule becomes: a cell with no provider tag, or one tagged `opencode`, reaches OpenCode.
- **Emit the prompt files as commands.** pi's `prompts/` maps onto OpenCode's `command` surface, so this is interface parity rather than a compromise. An inline `command` entry takes a `description` and a `template`, and the template is the prompt body. The generator reads each prompt file's frontmatter and body and emits one entry per file, so the prompt list stays declared once.
- **Carry the ambient directories as `references`.** A reference is an alias for a directory: OpenCode lists it in `@` autocomplete, admits it through the external-directory boundary, and advertises it to the agent in system context when it carries a `description`. pi's `@` reaches a path directly, so a reference has no pi analogue, and the prompt root is not its home now that commands carry the prompts. It carries what is discovered rather than invoked: the workspace, and the reference documents the image ships at `/opt`.
- **Declare `$schema`.** OpenCode rejects an unknown top-level key and refuses to start on an invalid config, so the emitted file names the schema, and a check validates the output rather than trusting it.

The two surfaces are generated from the same prompt cells, so neither restates the prompt list. `command` carries invocability, which is the parity a pi session already has, and `references` carries discovery for the directories worth advertising. A prompt file therefore reaches a pi session and an OpenCode session from one declaration, and the OpenCode side keeps no hand-maintained list of prompt names.

**The argument placeholder unifies on `$ARGUMENTS`.** pi accepts `$@` and `$ARGUMENTS`, and OpenCode accepts `$ARGUMENTS` only. Rather than transform each template at generation time, the prompt files are rewritten to `$ARGUMENTS`, which leaves one spelling in the repository and one form a writer must remember. The change is mechanical and it reaches further than the prompt root: 23 prompt files carry `$@` today, across the module prompts, the harness prompts and pi's config prompts. No file uses a shell-style form such as `${@:-default}`, so the rewrite is a substitution rather than a restructuring.

**The duplicated runtime documentation is deleted.** `src/reasoning/agent/prompt-templates.md` describes pi's template format in 88 lines. Nothing references it, no `COPY` line ships it, and no manifest cell declares it, so the deletion is clean. Its substitution table and its loading rules restate pi's own documentation, and with two runtimes in play it would have to become the intersection of two formats: authoritative for neither, and correct only by maintenance.

The authoring rules get one carrier instead. [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) names each runtime's own reference rather than restating either: pi's template documentation at its image path, and OpenCode's documentation and config schema URL. The rule it states is the intersection: a placeholder must be one both runtimes substitute, and `$ARGUMENTS` is the only all-arguments form both accept.

The wiring is the first unit. `OPENCODE_CONFIG` is set nowhere in the tree, and `opencode-config.mjs` is invoked only by its own test. So the surfaces reach no runtime today, and the fix ships with a check that fails when the emitted set stops matching the provider-neutral and opencode cells.

### Hermes

Hermes keeps its own base. The unification intent is recorded in `devlog/roadmap.md` under `Not in scope: M3.6` as indefinitely deferred, with the trigger to revisit: a dependency conflict that consolidation would resolve.

## Consequences

**Enabled.** A dispatch CLI has one home, so `opencode-ai` installs once and a second dispatch tool is one line. A new instruction surface is one manifest cell. The provider contract is unchanged, so a new provider still follows the onboarding guide. Dropping the skip removes the fail-closed label, the fail-open label and the dead `image_label` path with it.

**Changed.** Tier 5 pulls the payload from a shared image rather than copying it, so `build.sh` gains a fourth build call and an ordering constraint: `agent-payload` builds before any provider image. The build probe measures cache hits rather than rebuilds. The OpenCode generator gains a filter, a `references` block and a schema declaration, and `OPENCODE_CONFIG` gains a caller.

**Foreclosed.** The skip mechanism does not come back without a new argument, since its measured benefit is one second. `agent-tools` becomes the place a dispatch CLI goes, so a provider base that installs another provider's tool is a finding rather than a choice.

**Owed to other records.** [`provider_onboarding_guide.md`](../../docs/development/provider_onboarding_guide.md) states the three-tier build in two places and calls opencode "the minimum", and both become wrong. The layer table in [`system_overview.md`](../../docs/reference/system_overview.md) is not affected: the build shape is not a layer-scope concern, and nothing is unfrozen.
