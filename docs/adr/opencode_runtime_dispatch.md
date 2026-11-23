# OpenCode as a Dispatch Runtime

**Current:** 2026-11-22

## 2026-11-22 -- OpenCode is a dispatch agent-runtime only

**Decision:** The OpenCode provider image is removed, with its directory, its compose overlays, its onboarding and its interactive instruction surface. OpenCode remains an agent-runtime and a model-provider namespace: `agent-runtimes` installs the pinned CLI, and `scripts/dispatch.sh` reaches it as one assignment's runtime. The generic provider base and the dispatch instruction transport are deferred to M3.6.7; the provider-shaped generator is deleted with the provider.

**Rationale:** A dispatch runtime and a session runtime are different jobs. The CLI needs no provider image, and the provider image had no consumer while the tree carried its build, onboarding, serve overlay and generated config. The generated surface was provider-shaped: it emitted `command` and `references` for an interactive session and a `skills` set filtered by a provider tag. The later dispatch transport is smaller and reads the provider-neutral base instead.

**Rejected alternatives:**

- *Keep the provider as a dormant image* -- execution: it leaves a second session runtime for the build, gates and documents to carry, so the retirement does not happen.
- *Keep the provider only for serve mode* -- intent: it retains the browser surface. Execution: it is still a second session runtime, and the vault work that used the surface is now sandbox-only.
- *Keep the generator as scaffolding for M3.6.7* -- execution: the artifact assumes an interactive OpenCode session; the later transport is built from the neutral base, not from a provider config.
- *Retarget the generator now* -- execution: it couples the deletion to a design that is not ready, and the deletion is safe without it because the CLI and its pin are independent of the provider image.

**Edge cases / drivers:** `opencode` remains two names: an agent-runtime and a set of model-provider prefixes. The two senses never share a field, and the removal touches the provider image, not the prefix. The `<provider>-base` build extension point stays, because it is generic and carries a fixture test. The removed provider is not a model-provider removal: `opencode` and `opencode-go` model ids still resolve through the role table.

## 2026-10-17 -- The dispatch CLI moves to the shared agent-runtime tier

**Decision:** The dispatch CLI's home moves from the pi image to the shared `agent-runtimes` tier, so both the pi and opencode images carry it and either image can reach either agent-runtime. The rest of the 2026-10-15 decision stands: OpenCode remains a base-level provider, the CLI is a dispatch dependency rather than a replacement runtime, and there is no attribution spoofing.

**Rationale:** The 2026-10-15 entry installed the CLI in the pi image because the pi image was the only home that needed it. The shared `agent-runtimes` tier now holds both agent-runtimes, so pinning the CLI to one image is a needless asymmetry: both images inherit the tier, both carry the CLI, and the seam's agent-runtime choice no longer depends on which image a session runs in. Renamed 2026-11-07 from `agent-harnesses`; the decision is unchanged.

**Rejected alternatives:**

- *Keep the CLI in the pi image only* -- intent: it leaves the opencode image without the pi backend's binary, so a pi-backend role stays unrunnable there and the two images stay asymmetric.

**Edge cases / drivers:** The seam's three-step binary resolution is unchanged from the 2026-10-15 entry: an explicit `DISPATCH_OPENCODE_BIN`, then `opencode` on `PATH`, then the agent-home path. The shared tier install puts `opencode` on `PATH` in both images, so the second step resolves in either.

## 2026-10-15 -- OpenCode stays a base-level provider and ships its CLI in the pi image

**Decision:** OpenCode remains a base-level provider, a sibling runtime with its own image and provider contract. Separately, the pi image installs `opencode-ai@1.19.1` globally, so the runner seam can invoke `opencode run` from a pi session. The two roles are independent: the provider image hosts an OpenCode session, and the pi image carries the CLI as a dispatch tool.

**Rationale:** A dispatch runtime and a session runtime are different jobs. The seam needs a command, and a command needs only the CLI. Removing the provider image would delete a capability the seam does not replace, on evidence that no one uses it, and that evidence is not in hand. Installing the CLI into the pi image is the smaller change: one `RUN` line, pinned to the measured version, and the seam's OpenCode backend resolves from `PATH` rather than from a manual install in the agent home.

The measurement that forces the install is a provider refusal. `pi --provider opencode --model cat-jam-free` answers `403 FreeTierError`, whose own text says the free tier is served only from inside the OpenCode app. The sanctioned route is the real CLI. That makes the CLI a dependency of the pi runtime rather than an optional convenience, so it belongs in the pi image and not in a hand-managed directory.

**Rejected alternatives:**

- *Demote OpenCode from a base-level provider to a CLI-only tool* -- it removes a session runtime to add a command, and the two are not substitutes. A removal needs evidence the runtime is unused; the seam's needs say nothing about the provider's.
- *Keep the CLI only at `$AGENT_HOME/opencode/node_modules/.bin/opencode`* -- it works today but is invisible to the image. A fresh container would dispatch nothing, and the failure would read as a missing binary rather than a missing declaration. The seam keeps that path as a fallback, not as the contract.
- *Reach the free tier by presenting pi as the OpenCode app* -- attribution spoofing, refused by operator ruling.

**Edge cases / drivers:** The seam resolves the binary in three steps: an explicit `DISPATCH_OPENCODE_BIN`, then `opencode` on `PATH`, then the agent-home path. The fallback keeps a session whose image predates the install working, and the override keeps the seam testable without an install. The free tier needs no credential, so a global install serves it; a paid model that needs the operator's OpenCode authentication stays a provider-image concern until the dispatch-rule surface names it.

**Reason superseded by 2026-10-17:** the CLI's home moves from the pi image to the shared `agent-runtimes` tier, so both images carry it. The rest of the entry stands: OpenCode remains a base-level provider, the CLI is a dispatch dependency rather than a replacement runtime, and there is no attribution spoofing.
