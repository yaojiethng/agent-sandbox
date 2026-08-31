# Investigation - Harness-Sig Requirements

**Status:** Complete. Outcome: deferred -- see `roadmap_future.md` Harness Packaging and Versioning.

**[SUPERSEDED in 20260831 - image & harness version identity:](./20260831-story-active-image_and_harness_version_identity.md) the harness-sig requirement is subsumed as the host-surface branch of the version-identity reconciliation; supersedes this doc's standalone harness-sig framing.**

**Related:**
- [`devlog/roadmap.md`](../../devlog/roadmap.md) -- M2.7 (container-sig settled, harness-sig deferred)
- [`devlog/discussions/design_session_identity_hash_based.md`](../discussions/design_session_identity_hash_based.md) -- container-sig design
- [`devlog/handovers/20260513-11-plan-rescope_items_1_7.md`](../../devlog/handovers/20260513-11-plan-rescope_items_1_7.md) -- rescoping context
- [`devlog/handovers/20260513-12-study-grill_harness_sig_investigation.md`](../../devlog/handovers/20260513-12-study-grill_harness_sig_investigation.md) -- current open session

---

## Change Class Analysis

Re-framed from per-file scenarios to broad classes of changes that could make the installed harness out of sync with the repo:

| Class | What changes | Example | Severity |
|---|---|---|---|
| 1. Script dispatch | `scripts/*.sh` -- entry points, flag parsing, session lifecycle | `start_agent.sh` logic change, `stop.sh` filter redesign | Medium -- behavior changes silently |
| 2. Lib dispatch | `libs/*.sh` -- core business logic sourced by scripts | `containers.sh` build logic, `routing.sh` path resolution | Medium -- core behavior changes |
| 3. Command shape | CLI interface contract -- flags, subcommands, arguments | Renaming `--name` to `--project`, adding `--refresh` flag | High -- can break invocations |
| 4a. Makefile template | `libs/_templates/Makefile.template` -- generated into sandbox | Adding new targets, changing env var names | Low -- caught by `MAKEFILE_VERSION` |
| 4b. Compose template | `libs/docker-compose.yml` -- generated fresh each start | New mount paths, new service definitions | None -- picked up automatically |
| 5. Install contract | Install target itself -- path, file dependencies | `INSTALL_DIR` changes, new files need to be co-located | Low -- infrequent |

## Host-side detection gap

Container-sig (image content hash) covers classes that affect the image. The compose template (4b) is loaded fresh at every `make start` -- no staleness risk. The Makefile template (4a) has its own version check.

**The remaining gap harness-sig would fill:** changes to classes 1, 2, and 3 (scripts, libs, command shape) that:
- Don't change the image (host-side only logic)
- Aren't caught by `MAKEFILE_VERSION`
- But do change the behavior of the installed CLI

## Candidate comparison

| Criterion | Self-contained binary | Semantic versioning |
|---|---|---|
| Covers class 1 (script dispatch) | ✅ Scripts baked in | ✅ If version bumped |
| Covers class 2 (lib dispatch) | ✅ Libs baked in | ✅ If version bumped |
| Covers class 3 (command shape) | ✅ Binary replaced atomically | ✅ If version bumped |
| Covers class 4a (Makefile template) | ❌ Existing sandbox dirs stale | ✅ If version bumped |
| Covers class 4b (compose template) | ✅ Embedded in binary | ✅ If version bumped |
| Covers class 5 (install contract) | ✅ Binary is self-describing | ✅ If version bumped |
| Engineering cost | High -- packer or compiled rewrite | Low -- add VERSION file + start_agent check |
| Maintenance burden | One-time build transition | Ongoing -- discipline of bumping on every meaningful change |
| False positive risk | None -- atomic replacement | Low -- version only changes when bumped intentionally |
| Existing infra required | Major deployment model change | `git describe --tags` or manual VERSION file |

## Status

Grilling in progress -- outcome not yet settled.

## Open questions for the design session

1. **Self-contained binary vs semver vs nothing?** Which path resolves the drift problem at an acceptable cost.
2. **Does container-sig + MAKEFILE_VERSION cover enough** that harness-sig is genuinely unnecessary?
3. **If semver: what qualifies as a bump?** Policy for major/minor/patch on each change class.
4. **If self-contained: what mechanism?** Shar archive, compiled language, proper package?
5. **Dogfood vs non-dogfood.** Does non-dogfood even have a repo checkout to compare against?

---

## Recommendation (preliminary)

Do not design harness-sig until a comparison target exists. The two viable paths are:
1. Self-contained binary -- eliminates the entire class of drift problems at high engineering cost.
2. Semantic versioning -- pragmatic, low cost, but relies on bump discipline.

Until one of these paths is taken, container-sig + MAKEFILE_VERSION cover the most common and highest-severity staleness scenarios.
