# The install and copy steps in the three reasoning tiers

**Status:** active

## Direction and parent story

This study belongs to the M3.6.1 layer install design, the roadmap row `The layer install design` under M3.6.1 `Disable and ship OpenCode dispatch`. That row decides where the shared dispatch CLIs and both agents' extensions install, the pin per layer and how it is checked, and the tier placement. The three options it names are keeping `<provider>-base`, making `<provider>-agent` the final image with the shared payload copied in, and a shared dispatch-tools tier. The decision rests on the census below, on the M3.6.1 `The invalidation history` measurement, and on the measured cost of build seconds times rebuild count. This study supplies only the first of those three: a read of the install and copy material already present in the tree. Parent row: [`devlog/roadmap.md`](../roadmap.md#m361---disable-and-ship-opencode-dispatch).

## Required reading

- [`src/reasoning/base.dockerfile`](../../src/reasoning/base.dockerfile) -- tier 1, image `agent-base`
- [`src/reasoning/providers/pi/base.dockerfile`](../../src/reasoning/providers/pi/base.dockerfile) -- tier 2, image `pi-base`
- [`src/reasoning/providers/opencode/base.dockerfile`](../../src/reasoning/providers/opencode/base.dockerfile) -- tier 2, image `opencode-base`
- [`src/reasoning/providers/hermes/base.dockerfile`](../../src/reasoning/providers/hermes/base.dockerfile) -- tier 2, image `hermes-base`
- [`src/reasoning/providers/pi/provider.dockerfile`](../../src/reasoning/providers/pi/provider.dockerfile) -- tier 3, image `pi-agent-<project>`
- [`src/reasoning/providers/opencode/provider.dockerfile`](../../src/reasoning/providers/opencode/provider.dockerfile) -- tier 3, image `opencode-agent-<project>`
- [`src/reasoning/providers/hermes/provider.dockerfile`](../../src/reasoning/providers/hermes/provider.dockerfile) -- tier 3, image `hermes-agent-<project>`
- [`scripts/build.sh`](../../scripts/build.sh) -- the three-tier orchestrator
- [`src/build/image.sh`](../../src/build/image.sh) -- image naming and identity
- [`src/build/container-interface.json`](../../src/build/container-interface.json) -- the container interface declared once
- [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) -- the compose template

## Summary

The reasoning layer is three tiers. Tier 1, `agent-base`, is built once from `node:22.22.3-slim` and carries the shared runtime set: apt tools, uv, uv's Python 3.11, hadolint and markdownlint-cli2. Tier 2, `<provider>-base`, adds one provider's agent install; the pi base adds two CLIs and the opencode base adds one. Tier 3, `<provider>-agent-<project>`, copies the harness payload from the repository working tree and is rebuilt on every call. The census below reads every install and copy step across the three tiers, forty-one rows, each with its file, line, input, output path and pin. Its headline is that the pins are concentrated in tier 1 and tier 2 and are absent from tier 3's `COPY` inputs, where every input is the repository working tree; tier 3's base image is a `<provider>-base` tag, produced under `_build_key` at tier 2, and the tier-3 step itself is ungated and rebuilt on every call.

## Findings

The build context for all three tiers is the repository root (`$repo_root` in [`scripts/build.sh`](../../scripts/build.sh)); `build_image` appends `"$repo_root"` as the context, so every `COPY` source below is repo-relative. There is no `.dockerignore`, so the whole working tree is sent to the daemon. Tier 1 is built with no `BASE_IMAGE` argument; tier 2 is built with `--build-arg BASE_IMAGE=agent-base`; tier 3 is built with `--build-arg BASE_IMAGE=<provider>-base`. `HOST_UID` and `HOST_GID` are passed on all three tiers: `scripts/build.sh` passes `uid_args` on each tier's build call, at line 175 for tier 1, line 182 for tier 2 and line 187 for tier 3, though tier 1's Dockerfile declares no such `ARG`, so the args are unused there.

The tiers are cache-gated differently. `build_if_missing` guards tiers 1 and 2 and skips a build only when the image exists and its stamped label `agent-sandbox.base-build-key` equals `_build_key`, which is the Dockerfile's sha256 combined with the base image's content id. Tier 3 is built by `build_image` on every `build_agent` call. The tag is a fixed name, not a digest: `agent-base`, `<provider>-base`, `<provider>-agent-<project>`.

One row per install or copy step:

| Tier | Dockerfile | Line | Step | Input | Output path | Pinned? |
|---|---|---|---|---|---|---|
| 1 | `src/reasoning/base.dockerfile` | 22 | base image | `node:22.22.3-slim` | image rootfs | tag `22.22.3-slim` (mutable tag, no digest) |
| 1 | `src/reasoning/base.dockerfile` | 24-27 | apt install | `ca-certificates curl git rsync fd-find ripgrep shellcheck jq` | system paths (`/usr/bin`, `/usr/lib`) | unpinned; Debian bookworm archive, no version pins |
| 1 | `src/reasoning/base.dockerfile` | 31 | curl install | `https://astral.sh/uv/install.sh` | `/usr/local/bin` (`UV_INSTALL_DIR`) | unpinned; latest installer, no version |
| 1 | `src/reasoning/base.dockerfile` | 35 | uv Python install | uv-managed CPython `3.11` | `/opt/uv-python` (`UV_PYTHON_INSTALL_DIR`) | version `3.11`, minor level; patch unpinned (resolves at or above the 3.11.12 floor) |
| 1 | `src/reasoning/base.dockerfile` | 40-41 | curl install | `hadolint-Linux-x86_64` from the `v2.14.0` release | `/usr/local/bin/hadolint` | tag `v2.14.0`; no checksum |
| 1 | `src/reasoning/base.dockerfile` | 44 | npm install | `markdownlint-cli2@0.23.2` | global node_modules, `/usr/local/bin` | `@0.23.2` |
| 2 | `src/reasoning/providers/pi/base.dockerfile` | 2 | base image | `agent-base` (`BASE_IMAGE`) | image rootfs | build arg; tier-1 content id held in `_build_key` |
| 2 | `src/reasoning/providers/pi/base.dockerfile` | 4 | npm install | `@earendil-works/pi-coding-agent@1.3.0` | global node_modules, `/usr/local/bin` | `@1.3.0` |
| 2 | `src/reasoning/providers/pi/base.dockerfile` | 11 | npm install | `opencode-ai@1.19.1` | global node_modules, `/usr/local/bin` | `@1.19.1` |
| 2 | `src/reasoning/providers/opencode/base.dockerfile` | 6 | base image | `agent-base` (`BASE_IMAGE`) | image rootfs | build arg; tier-1 content id held in `_build_key` |
| 2 | `src/reasoning/providers/opencode/base.dockerfile` | 8 | npm install | `opencode-ai` | global node_modules, `/usr/local/bin` | unpinned; no version |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 23 | base image (builder stage) | `agent-base` (`BASE_IMAGE`) | builder stage rootfs | build arg; tier-1 content id held in `_build_key` |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 25-27 | apt install | `gcc libffi-dev` | builder stage system paths | unpinned; Debian bookworm archive, no version pins |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 31 | git clone | `https://github.com/NousResearch/hermes-agent` | `/opt/hermes` | unpinned; no branch, tag or commit, so the default branch HEAD |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 33-34 | uv venv + pip install | cloned source extras `.[all]`, Python `3.11` | `/opt/venv` | interpreter `3.11`; dependencies unpinned, resolved from the clone at build time |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 36 | npm install | cloned source `package.json`, `--omit=dev` | `/opt/hermes/node_modules` | unpinned; resolved from the clone at build time |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 39 | base image (runtime stage) | `agent-base` (`BASE_IMAGE`) | runtime stage rootfs | build arg; tier-1 content id held in `_build_key` |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 41-43 | apt install | `ffmpeg` | runtime system paths | unpinned; Debian bookworm archive, no version pin |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 45 | COPY (stage-to-stage) | `/opt/venv` (builder stage) | `/opt/venv` | unpinned; builder-stage content (no version or digest) |
| 2 | `src/reasoning/providers/hermes/base.dockerfile` | 46 | COPY (stage-to-stage) | `/opt/hermes` (builder stage) | `/opt/hermes` | unpinned; builder-stage content (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 6 | base image | `pi-base` (`BASE_IMAGE`) | image rootfs | build arg; `pi-base` tag, produced under `_build_key` at tier 2, and the tier-3 step itself is ungated and rebuilt on every call |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 12 | COPY | `src/libs/` | `/opt/sandbox/lib/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 13 | COPY | `src/reasoning/entrypoint.sh` | `/opt/sandbox/bin/provider-entrypoint.sh` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 14 | COPY | `src/reasoning/providers/pi/preflight.sh` | `/opt/sandbox/bin/provider-preflight.sh` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 15 | COPY | `src/reasoning/agent/skills/` | `/opt/workflow/agent/skills/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 16 | COPY | `src/reasoning/agent/prompts/` | `/opt/workflow/agent/prompts/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 17 | COPY | `workflow/coding-agent/prompts/` | `/opt/workflow/agent/modules/coding-agent/prompts/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 18 | COPY | `workflow/coding-agent/skills/` | `/opt/workflow/agent/modules/coding-agent/skills/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 19 | COPY (pi extension payload) | `src/reasoning/providers/pi/config/` | `/opt/workflow/agent/config/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 20 | COPY | `docs/reference/` | `/opt/sandbox/docs/reference/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/pi/provider.dockerfile` | 21 | COPY | `docs/policies/` | `/opt/sandbox/docs/policies/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/opencode/provider.dockerfile` | 16 | base image | `opencode-base` (`BASE_IMAGE`) | image rootfs | build arg; `opencode-base` tag, produced under `_build_key` at tier 2, and the tier-3 step itself is ungated and rebuilt on every call |
| 3 | `src/reasoning/providers/opencode/provider.dockerfile` | 25 | COPY | `src/libs/` | `/opt/sandbox/lib/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/opencode/provider.dockerfile` | 26 | COPY | `src/reasoning/entrypoint.sh` | `/opt/sandbox/bin/provider-entrypoint.sh` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/opencode/provider.dockerfile` | 33 | COPY | `docs/reference/` | `/opt/sandbox/docs/reference/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/opencode/provider.dockerfile` | 34 | COPY | `docs/policies/` | `/opt/sandbox/docs/policies/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/hermes/provider.dockerfile` | 16 | base image | `hermes-base` (`BASE_IMAGE`) | image rootfs | build arg; `hermes-base` tag, produced under `_build_key` at tier 2, and the tier-3 step itself is ungated and rebuilt on every call |
| 3 | `src/reasoning/providers/hermes/provider.dockerfile` | 25 | COPY | `src/libs/` | `/opt/sandbox/lib/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/hermes/provider.dockerfile` | 26 | COPY | `src/reasoning/entrypoint.sh` | `/opt/sandbox/bin/provider-entrypoint.sh` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/hermes/provider.dockerfile` | 32 | COPY | `docs/reference/` | `/opt/sandbox/docs/reference/` | unpinned; repository working tree (no version or digest) |
| 3 | `src/reasoning/providers/hermes/provider.dockerfile` | 33 | COPY | `docs/policies/` | `/opt/sandbox/docs/policies/` | unpinned; repository working tree (no version or digest) |

Step count per tier: tier 1 has 6 rows; tier 2 has 14 rows (pi 3, opencode 2, hermes 9); tier 3 has 21 rows (pi 11, opencode 5, hermes 5); forty-one rows in all. A `base image` row counts as a step because it is the tier's input, and its provenance is the pin the rest of the tier inherits.

### Coverage of the named classes

The `COPY` steps are rows 19 and 20 (hermes stage-to-stage) and every tier-3 COPY (pi 12-21, opencode 25-34, hermes 25-33). The agent packages are rows 8, 9 and 11: `@earendil-works/pi-coding-agent@1.3.0` and `opencode-ai@1.19.1` in the pi base, and `opencode-ai` in the opencode base. The pi extension payload is row 29, `src/reasoning/providers/pi/config/` to `/opt/workflow/agent/config/`, whose `agent/extensions/` subtree holds the model-failover, model-refresh and task-queue extensions. The apt installs are rows 2, 13 and 18; the curl installs are rows 3 and 5; the uv Python install is row 4 (and its reuse in row 15). The opencode plugin set is the one named class with no row, because the tree carries no such install.

### The opencode plugin set

No OpenCode plugin or extension install exists in the tree. The opencode provider image installs only the `opencode-ai` npm package (row 11) and copies no config, prompt, skill or plugin payload; its Dockerfile states that the harness payload ships in pi's image only and that a payload there would ship unreachable. The nearest artifact is the OpenCode instruction transport, `src/build/opencode-config.mjs`, which derives an `instructions` and `skills` config from `src/build/container-interface.json` at generation time and is consumed through `OPENCODE_CONFIG`, not baked by a `COPY`. It is generated from the manifest, so it is pinned to the manifest content rather than to a version, and it is absent from every tier's install steps. Whether OpenCode grows a baked plugin set is a question for the layer install design, not a fact of the present tree.

### The unpinned inputs

Unpinned: the tier-1 apt package set; the uv installer fetched from `astral.sh`; the hermes build-tools and `ffmpeg` apt installs; the hermes `git clone` at the default branch HEAD; the hermes pip and npm dependency resolution from that clone; the `opencode-ai` install in the opencode base; and every `COPY` whose input is the repository working tree or a builder stage, the pi extension payload among them. Tag-pinned but not digest-pinned: `node:22.22.3-slim` and hadolint `v2.14.0`. Version-pinned at the minor level only: uv's Python `3.11`. Version-pinned exactly: `markdownlint-cli2@0.23.2`, `@earendil-works/pi-coding-agent@1.3.0` and `opencode-ai@1.19.1` in the pi base.

## Open Questions

- Whether the unpinned `opencode-ai` in the opencode base and the pinned `opencode-ai@1.19.1` in the pi base should collapse to one pinned install and one check, which the M3.6.1 `The dispatch-CLI pin and gate` row owns.
- Whether the pi extension payload belongs in tier 2 or tier 3, since it is reachable only through the pi image and changes with the harness rather than with the agent package.
- Whether the hermes `git clone` should pin a ref, given that it is the only external source fetched without one.
- Whether `node:22.22.3-slim` and the hadolint release should move from a tag to a digest.

## Constraints

- This is a read. The census adds no file outside this record and edits no Dockerfile, build script or roadmap.
- Every cell is drawn from the tree with its file and line; no cell is inferred from a build log.
- The three reasoning tiers are the scope. The capability layer image (`src/capability/dockerfile`) and the base images' own upstream layers are outside it.

## Next Steps

The census feeds the M3.6.1 `The layer install design` row together with the invalidation history and the measured build cost. The immediate use is the choice among keeping `<provider>-base`, making `<provider>-agent` the final image, and adding a shared dispatch-tools tier: the tier-3 rows show which payloads move, and the unpinned-input list shows which new pins each option would need.

## Resolution

Open. This study is the evidence the layer install design rests on; it closes when that design is decided.
