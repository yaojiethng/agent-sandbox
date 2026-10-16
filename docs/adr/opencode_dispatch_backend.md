# OpenCode as a Dispatch Backend

**Current:** 2026-10-15

## 2026-10-15 -- OpenCode stays a base-level provider and ships its CLI in the pi image

**Decision:** OpenCode remains a base-level provider, a sibling runtime with its own image and provider contract. Separately, the pi image installs `opencode-ai@1.19.1` globally, so the runner seam can invoke `opencode run` from a pi session. The two roles are independent: the provider image hosts an OpenCode session, and the pi image carries the CLI as a dispatch tool.

**Rationale:** A dispatch backend and a session runtime are different jobs. The seam needs a command, and a command needs only the CLI. Removing the provider image would delete a capability the seam does not replace, on evidence that no one uses it, and that evidence is not in hand. Installing the CLI into the pi image is the smaller change: one `RUN` line, pinned to the measured version, and the seam's OpenCode backend resolves from `PATH` rather than from a manual install in the agent home.

The measurement that forces the install is a provider refusal. `pi --provider opencode --model cat-jam-free` answers `403 FreeTierError`, whose own text says the free tier is served only from inside the OpenCode app. The sanctioned route is the real CLI. That makes the CLI a dependency of the pi runtime rather than an optional convenience, so it belongs in the pi image and not in a hand-managed directory.

**Rejected alternatives:**

- *Demote OpenCode from a base-level provider to a CLI-only tool* -- it removes a session runtime to add a command, and the two are not substitutes. A removal needs evidence the runtime is unused; the seam's needs say nothing about the provider's.
- *Keep the CLI only at `$AGENT_HOME/opencode/node_modules/.bin/opencode`* -- it works today but is invisible to the image. A fresh container would dispatch nothing, and the failure would read as a missing binary rather than a missing declaration. The seam keeps that path as a fallback, not as the contract.
- *Reach the free tier by presenting pi as the OpenCode app* -- attribution spoofing, refused by operator ruling.

**Edge cases / drivers:** The seam resolves the binary in three steps: an explicit `DISPATCH_OPENCODE_BIN`, then `opencode` on `PATH`, then the agent-home path. The fallback keeps a session whose image predates the install working, and the override keeps the seam testable without an install. The free tier needs no credential, so a global install serves it; a paid model that needs the operator's OpenCode authentication stays a provider-image concern until the dispatch-rule surface names it.
