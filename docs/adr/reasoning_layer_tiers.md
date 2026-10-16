# Reasoning Layer Tiers

**Current:** 2026-10-16

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | A tier's contents are decided by kind, not by provider | the runtime, the shared dispatch tools, the provider's own agent, and the common payload are four different things |
| R2 | A dispatch tool installs exactly once | a tool the harness invokes is not a provider's agent, so it does not belong in a provider's base |
| R3 | The common payload is declared exactly once | one Dockerfile defines it, and each provider pulls it with one line |
| R4 | Docker's layer cache is the only reuse rule | nothing decides reuse before the daemon is called |
| R5 | A provider base installs only its own differential | another provider's tool in a provider base is a finding, not a choice |
| R6 | The tier list is the same for every provider | a provider differs by payload and environment, not by shape |

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

**Edge cases / drivers:** The payload changes with every commit, so it must not sit in a cached base tier: a commit would then invalidate a base for every provider, which is the propagation the tiers exist to avoid. Docker's layer cache handles it correctly at tier 4 and 5, where a changed `COPY` rebuilds and an unchanged one is a hit. The ordering constraint is real: `agent-payload` builds before any provider image, and `build.sh` owns it. This ADR moves the dispatch-CLI home that [`opencode_dispatch_backend.md`](opencode_dispatch_backend.md) states: the pi image's `opencode-ai` install becomes an `agent-tools` install, and the decision that the CLI is a dispatch tool rather than a replacement runtime is unchanged.

## 2026-10-16 -- Docker's layer cache is the only reuse rule

**Decision:** `build_if_missing`, `_build_key` and the `agent-sandbox.base-build-key` label are removed. Every tier is built on every call, and docker decides what is reused.

**Rationale:** The skip mechanism sat in front of the daemon and decided from a stamped label whether to call it. Its benefit was about one second, and its failure mode was an image that never rebuilt with nothing reporting it, which is the defect that landed: the key did not cover the base image, so a rebuilt shared base left a provider base stale. Docker's cache is content-addressed already, and a `COPY` layer's key includes the copied bytes.

The measured evidence bounds the trade. A tier-3-only rebuild costs 1 second wall and 0.1 second of steps, and the skip path costs the same order. So the mechanism bought no measurable time and carried a correctness risk.

**Rejected alternatives:**

- *Keep the content key with the base image folded in, as the build-skip fix landed it* -- the fix is correct, and it pays for a check that a second copy of the reuse rule must maintain. Deleting the rule removes the second copy.
- *Keep the skip at tier 1 only* -- the same second copy, for the tier least likely to change.

**Edge cases / drivers:** The build probe's meaning changes with this decision. It measured "tiers that rebuilt" by parsing per-step `DONE` lines, and a fully cached build prints `CACHED` and no `DONE`, so it now measures "tiers with a step that was not cached". A `.dockerignore` becomes worth adding, because the whole working tree including `.git/` and `devlog/` is the build context today.
