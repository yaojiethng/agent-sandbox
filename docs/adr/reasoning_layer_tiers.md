# Reasoning Layer Tiers

**Current:** 2026-11-07

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | A tier's contents are decided by kind, not by provider | the language runtime set, a registry-package agent-runtime and a source-built agent-runtime are different kinds, and each has its own tier (2026-10-17) |
| R2 | An agent-runtime installs exactly once | each agent-runtime has one Dockerfile home, and a second home is a finding (2026-10-17) |
| R3 | The common payload is declared exactly once | the manifest declares every COPY pair, and the layout gate holds the Dockerfiles equal to it in both directions (2026-10-17) |
| R4 | Docker's layer cache is the only reuse rule | nothing decides reuse before the daemon is called |
| R5 | A provider base installs only its own differential | the one surviving provider base, hermes-base, carries only the hermes install (2026-10-17) |
| R6 | The tier list is the same for every provider that shares an install mechanism | pi and opencode share one list of tiers because both install from a registry; hermes adds one base because its install is a source build (2026-10-17) |

## 2026-11-07 -- The provider directory is `agent-runtime`

**Decision:** `src/reasoning/providers/` is `src/reasoning/agent-runtime/`. The directory holds the agent-runtimes (pi, opencode, hermes); `provider` is reserved for the model-id namespace, so the path no longer carries it. The provider ids, the image names and the tier shape are unchanged.

**Rationale:** The directory holds agent-runtimes, not providers. A provider id names a model-id namespace, and the runtimes are the executables the harness serves. The move is structural, and every live reference moved with it.

**Rejected alternatives:**

- *Keep `src/reasoning/providers/`* -- intent: it is the path the build has always used, so a move costs a sweep for no behaviour. Execution: the name states a subject the directory does not hold, and the reserved term already exists.

**Edge cases / drivers:** Historical records keep the old path: the entries below, the archived handovers, the discussions and the changelog state what was true when written, and their links point at the current directory. The directory is a live path, so the live documents and the open roadmap rows carry the new one.

## 2026-11-07 -- The shared tier is `agent-runtimes`

**Decision:** The shared tier is named `agent-runtimes`, its Dockerfile is `src/reasoning/runtimes.dockerfile`, and the image-name function is `runtimes_base_image_name`. The tier holds the two registry-package agent-runtimes, `@earendil-works/pi-coding-agent` and `opencode-ai`, each installed once. `harness` is reserved for the whole setup: the skills and prompts, the agent-runtime, the images and the execution environment.

**Rationale:** The tier's name used `harness` for the parts while the word now names the whole, and the tier installs two runtimes, so the plural names what it holds. The prior entry's decision is unchanged: four tiers, hermes keeps its base, no payload image. The image is internal, so no compatibility surface moves. The directory `src/reasoning/providers/` to `src/reasoning/agent-runtime/` is a separate row.

**Rejected alternatives:**

- *Keep `agent-harnesses`* -- intent: it names the parts with the word the operator now reserves for the whole, so a reader cannot tell which subject a sentence holds.
- *`agent-runtime` singular* -- execution: the tier holds two runtimes, and the singular names one.
- *`provider-base`* -- intent: it collides with the surviving per-provider base, `<provider>-base`, and names the wrong axis.

**Edge cases / drivers:** Historical records keep the old name: the 2026-10-17 entry below, the archived handovers and the changelog state what was true when written. The directory rename `src/reasoning/providers/` to `src/reasoning/agent-runtime/` is filed as its own M3.6.4 row because it is a 121-reference move and a separate outcome.

## 2026-10-17 -- One shared harness tier, hermes keeps its base, no payload image

**Decision:** The reasoning layer is four tiers, and the install's mechanism decides which tier a harness joins.

| Tier | Image | Contents |
|---|---|---|
| 1 | `agent-base` | the runtime set: Node, Python from uv, the shared CLI tools, the lint gates |
| 2 | `agent-harnesses` | the two registry-package harnesses, `@earendil-works/pi-coding-agent` and `opencode-ai`, each installed once |
| 3 | `hermes-base` | the hermes install only: a source build with a compiler, a cloned tree and its own language environment, inheriting `agent-base` |
| 4 | `<provider>-agent-<project>` | the provider's config, environment, entrypoint and its own COPY lines; pi and opencode inherit `agent-harnesses`, hermes inherits `hermes-base` |

**Rationale:** The five-tier shape had two defects. `agent-tools` named the tools an agent wields, not the harnesses the tier installs, and `opencode-ai` had two homes: the shared dispatch row for pi and the opencode provider's own base. One shared tier holding both registry-package harnesses fixes the name and the double home together, because the pi and opencode bases carried nothing but their harness install, so deleting those two bases and inheriting `agent-harnesses` directly loses nothing. Hermes keeps its base because its install is a source build, not a registry package: a compiler, a cloned tree and its own language environment have no place in a shared registry tier, and folding them in would put the tree's only unpinned build on every provider's path. `agent-payload` is dropped because an image is a carrier, not a declaration: `src/build/container-interface.json` already declares every COPY pair, and `scripts/check_container_layout.sh` holds the Dockerfiles equal to it in both directions. This entry promotes R1, R2, R3, R5 and R6.

**Rejected alternatives:**

- *Keep five tiers* -- intent: it keeps the misnamed `agent-tools`, the `opencode-ai` double home across the shared row and the opencode base, and the `agent-payload` image that declares nothing.
- *Fold hermes into the shared tier* -- intent: it puts the tree's only unpinned build on every provider's path, gates pi and opencode on a hermes failure, and adds a compiler, a Python venv and `ffmpeg` to images that do not run that workflow.
- *Keep the `agent-payload` image* -- neither: it removes no declaration and leaves the layout gate necessary, at the cost of a tag and a build-order coupling.

**Edge cases / drivers:** The payload's declaration moved from a Dockerfile to the manifest. Each provider image still carries its own COPY lines, and the layout gate holds them equal to the manifest in both directions. The dispatch CLI's home moves with this entry: `opencode-ai` is now an `agent-harnesses` install, so the [`opencode_runtime_dispatch.md`](opencode_runtime_dispatch.md) statement that the CLI ships in the pi image is superseded, and both the pi and opencode images carry the CLI. The decisions that OpenCode stays a base-level provider, that the CLI is a dispatch dependency rather than a replacement runtime, and that there is no attribution spoofing are unchanged.

## 2026-10-16 -- Five tiers, one dispatch-tool home and one payload declaration

**Decision:** The reasoning layer is five tiers.

| Tier | Image | Contents |
|---|---|---|
| 1 | `agent-base` | the runtime set: Node, Python from uv, the shared CLI tools, the lint gates |
| 2 | `agent-tools` | the shared dispatch CLIs the harness invokes |
| 3 | `<provider>-base` | the provider's own agent install and nothing else |
| 4 | `agent-payload` | the common instruction base and the reference docs, copied into `/opt/` |
| 5 | `<provider>-agent-<project>` | `FROM <provider>-base`, one `COPY --from=agent-payload /opt/ /opt/`, plus the provider's config, environment and entrypoint |

A provider base stays in the shape because the provider interface requires it. A provider with no agent install of its own inherits the tools tier directly, which keeps the interface uniform.

`agent-payload` is a sibling image rather than a link in the provider chain, because a Dockerfile has one `FROM`. Tier 5 inherits the provider base and pulls the payload in with a single line, so the payload's `COPY` list is written once rather than once per provider.

**Rationale:** The three tiers as they stood put the same dispatch CLI in two provider bases and the same payload list in three provider Dockerfiles. The census read both: `opencode-ai@1.19.1` installs in the pi base as a dispatch tool and in the opencode base as its runtime, and the payload is ten `COPY` lines for pi, five for opencode and five for hermes. Declaring a thing once and deriving the rest is the principle the instruction surfaces already follow, and it applies to the image layers for the same reason.

The measured cost does not argue for a different shape. A base rebuild costs 2 to 3 seconds warm and a payload rebuild costs about 1 second, so the tiers earn their place through declaration and layering rather than through time saved.

**Rejected alternatives:**

- *Keep three tiers with one base per provider* -- it keeps the duplicate dispatch-tool install, and it makes a new instruction surface three edits that no gate compares.
- *One base carrying every agent, differentiated only at the final image* -- the hermes base is nine install rows including an unpinned clone at default-branch HEAD, a `uv venv` install and `ffmpeg`. Consolidating it puts the tree's only unpinned build on every provider's path, so a hermes failure blocks pi and opencode, and every pi image carries a Python venv it never uses. The unification is indefinitely deferred, and the trigger to revisit is a dependency conflict that consolidation would resolve.
- *Copy the payload inside each provider's Dockerfile* -- that is the duplication this decision removes.
- *Give the payload its own tier in the provider chain* -- a Dockerfile has one `FROM`, so a chain link would mean inheriting the payload image and re-deriving the provider base, which is the same work in a worse order.

**Edge cases / drivers:** The payload changes with every commit, so it must not sit in a cached base tier: a commit would then invalidate a base for every provider, which is the propagation the tiers exist to avoid. Docker's layer cache handles it correctly at tier 4 and 5, where a changed `COPY` rebuilds and an unchanged one is a hit. The ordering constraint is real: `agent-payload` builds before any provider image, and `build.sh` owns it. This ADR moves the dispatch-CLI home that [`opencode_runtime_dispatch.md`](opencode_runtime_dispatch.md) states: the pi image's `opencode-ai` install becomes an `agent-tools` install, and the decision that the CLI is a dispatch tool rather than a replacement runtime is unchanged.

**Reason superseded by 2026-10-17:** The five-tier shape misnames `agent-tools` and keeps the `opencode-ai` double home across the shared row and the opencode base. The `agent-tools` and `agent-payload` rows are superseded, and the `<provider>-base` row is narrowed to hermes alone; `agent-base`, the layer-cache rule and the `<provider>-agent-<project>` specialization layer stand.

## 2026-10-16 -- Docker's layer cache is the only reuse rule

**Decision:** `build_if_missing`, `_build_key` and the `agent-sandbox.base-build-key` label are removed. Every tier is built on every call, and docker decides what is reused.

**Rationale:** The skip mechanism sat in front of the daemon and decided from a stamped label whether to call it. Its benefit was about one second, and its failure mode was an image that never rebuilt with nothing reporting it, which is the defect that landed: the key did not cover the base image, so a rebuilt shared base left a provider base stale. Docker's cache is content-addressed already, and a `COPY` layer's key includes the copied bytes.

The measured evidence bounds the trade. A tier-3-only rebuild costs 1 second wall and 0.1 second of steps, and the skip path costs the same order. So the mechanism bought no measurable time and carried a correctness risk.

**Rejected alternatives:**

- *Keep the content key with the base image folded in, as the build-skip fix landed it* -- the fix is correct, and it pays for a check that a second copy of the reuse rule must maintain. Deleting the rule removes the second copy.
- *Keep the skip at tier 1 only* -- the same second copy, for the tier least likely to change.

**Edge cases / drivers:** The build probe's meaning changes with this decision. It measured "tiers that rebuilt" by parsing per-step `DONE` lines, and a fully cached build prints `CACHED` and no `DONE`, so it now measures "tiers with a step that was not cached". A `.dockerignore` becomes worth adding, because the whole working tree including `.git/` and `devlog/` is the build context today.
